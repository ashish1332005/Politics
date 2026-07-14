const SEARCH_VERSION = 1;
const SEARCH_SOURCE_FIELDS = [
  'name',
  'surname',
  'mobile',
  'altMobile',
  'voterId',
  'voterSerial',
  'guardianName',
  'houseNumber',
  'address',
  'location',
  'village',
  'gramPanchayat',
  'tehsil',
  'municipality',
  'caste',
  'subCaste',
  'organizationPost',
  'organizationLevel',
  'occupation',
  'education',
  'sectionNumber',
  'sectionName',
  'assemblyNumber',
  'assemblyName',
  'partNumber',
  'extraDetails',
];

const hindiDigits = '\u0966\u0967\u0968\u0969\u096a\u096b\u096c\u096d\u096e\u096f';
const asciiDigits = '0123456789';

const normalizeDigits = (value) => String(value || '').replace(
  /[\u0966-\u096f]/g,
  (digit) => asciiDigits[hindiDigits.indexOf(digit)],
);

const normalizeSearchValue = (value) => normalizeDigits(value)
  .normalize('NFKC')
  .toLocaleLowerCase('hi-IN')
  .replace(/[\u200b-\u200f\u202a-\u202e\u2060\ufeff]/g, '')
  .replace(/[^\p{L}\p{M}\p{N}]+/gu, ' ')
  .replace(/\s+/g, ' ')
  .trim();

const compactIdentifier = (value) => normalizeSearchValue(value).replace(/\s+/g, '');
const compactDigits = (value) => normalizeDigits(value).replace(/\D/g, '');
const looseHindiToken = (value) => String(value || '')
  .replace(/[\u093a-\u094c\u094e-\u0957\u0962\u0963]/g, '')
  .replace(/\s+/g, '');

const canonicalEpic = (value) => {
  const compact = compactIdentifier(value).toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (!compact) return '';
  if (!/^[A-Z]{3}/.test(compact)) return compact;
  const map = { O: '0', I: '1', L: '1', S: '5', B: '8', Z: '2', G: '6' };
  return compact.slice(0, 3) + compact.slice(3).replace(/[OILSBZG]/g, (char) => map[char]);
};

const sourceValues = (member) => {
  const values = SEARCH_SOURCE_FIELDS
    .filter((field) => field !== 'extraDetails')
    .map((field) => member?.[field]);
  for (const detail of member?.extraDetails || []) {
    values.push(detail?.label, detail?.value);
  }
  return values.filter((value) => value !== undefined && value !== null && String(value).trim());
};

const addPrefixes = (keys, token) => {
  if (!token) return;
  for (let length = 1; length <= Math.min(token.length, 30); length += 1) {
    keys.add(token.slice(0, length));
  }
  keys.add(token);
};

const addLoosePrefixes = (keys, token) => {
  const loose = looseHindiToken(token);
  if (!loose || loose === token || !/[\u0900-\u097f]/.test(token)) return;
  for (let length = 1; length <= Math.min(loose.length, 30); length += 1) {
    keys.add('~' + loose.slice(0, length));
  }
};

const addPersonSubstrings = (keys, value) => {
  for (const token of normalizeSearchValue(value).split(' ')) {
    if (token.length < 3) continue;
    for (let start = 1; start < token.length - 1; start += 1) {
      keys.add(token.slice(start));
    }
  }
};

const buildMemberSearchData = (member) => {
  const values = sourceValues(member);
  const normalizedValues = values.map(normalizeSearchValue).filter(Boolean);
  const keys = new Set();
  for (const value of normalizedValues) {
    value.split(' ').forEach((token) => {
      addPrefixes(keys, token);
      addLoosePrefixes(keys, token);
    });
  }
  [member?.name, member?.surname, member?.guardianName].forEach(
    (value) => addPersonSubstrings(keys, value),
  );

  for (const field of ['mobile', 'altMobile']) {
    const digits = compactDigits(member?.[field]);
    if (!digits) continue;
    addPrefixes(keys, digits);
    for (let length = 4; length <= digits.length; length += 1) {
      keys.add(digits.slice(-length));
    }
  }

  const epic = canonicalEpic(member?.voterId);
  if (epic) addPrefixes(keys, epic.toLowerCase());

  const exact = new Set(normalizedValues);
  for (const field of ['mobile', 'altMobile']) {
    const digits = compactDigits(member?.[field]);
    if (digits) exact.add(digits);
  }
  if (epic) exact.add(epic.toLowerCase());

  return {
    searchVersion: SEARCH_VERSION,
    searchText: normalizedValues.join(' '),
    searchKeys: [...keys].slice(0, 600),
    searchExact: [...exact].slice(0, 200),
  };
};

const searchTokens = (query) => {
  const normalized = normalizeSearchValue(query);
  if (!normalized) return [];
  return normalized.split(' ').map((token) => {
    const digits = compactDigits(token);
    if (digits && digits.length === token.length) return digits;
    const epic = canonicalEpic(token);
    if (/^[a-z]{3}[a-z0-9]{3,}$/i.test(token) && epic) return epic.toLowerCase();
    return token;
  });
};

const buildSearchConditions = (query) => searchTokens(query)
  .map((token) => {
    const loose = looseHindiToken(token);
    if (loose && loose !== token && /[\u0900-\u097f]/.test(token)) {
      return { $or: [{ searchKeys: token }, { searchKeys: '~' + loose }] };
    }
    return { searchKeys: token };
  });

const searchExactCandidates = (query) => {
  const values = new Set();
  const normalized = normalizeSearchValue(query);
  const compact = compactIdentifier(query);
  const digits = compactDigits(query);
  const epic = canonicalEpic(query);
  if (normalized) values.add(normalized);
  if (compact) values.add(compact);
  if (digits) values.add(digits);
  if (epic) values.add(epic.toLowerCase());
  return [...values];
};

const ensureMemberSearchData = async (Member) => {
  const cursor = Member.find({ searchVersion: { $ne: SEARCH_VERSION } })
    .select(SEARCH_SOURCE_FIELDS.join(' '))
    .lean()
    .cursor();
  let operations = [];
  let updated = 0;
  const flush = async () => {
    if (!operations.length) return;
    await Member.bulkWrite(operations, { ordered: false });
    updated += operations.length;
    operations = [];
  };
  for await (const member of cursor) {
    operations.push({
      updateOne: {
        filter: { _id: member._id },
        update: { $set: buildMemberSearchData(member) },
        timestamps: false,
      },
    });
    if (operations.length >= 250) await flush();
  }
  await flush();
  return updated;
};

module.exports = {
  SEARCH_VERSION,
  SEARCH_SOURCE_FIELDS,
  normalizeSearchValue,
  canonicalEpic,
  buildMemberSearchData,
  buildSearchConditions,
  searchExactCandidates,
  ensureMemberSearchData,
};
