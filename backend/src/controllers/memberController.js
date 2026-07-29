const QRCode = require('qrcode');
const Member = require('../models/Member');
const Family = require('../models/Family');
const Booth = require('../models/Booth');
const { applyMemberScope, assertBoothAccess, assertWardAccess } = require('../utils/boothAccess');
const { writeActivity } = require('../middleware/activityLogger');
const { requireValidEpic } = require('../utils/epic');
const { syncMemberFamily, removeMemberFromFamilies } = require('../utils/familySync');
const { persistLocalImage } = require('../utils/persistentMedia');
const { buildSearchConditions, searchExactCandidates } = require('../utils/memberSearch');

const populate = 'party ward booth area createdBy updatedBy';
const maskMobile = (value) => {
  const text = String(value || '');
  return text.length >= 4 ? `${'*'.repeat(Math.max(0, text.length - 4))}${text.slice(-4)}` : text;
};
const maskMemberMobile = (member, user) => {
  if (user.role === 'admin' || user.permissions?.canViewFullMobile) return member;
  const value = member.toObject ? member.toObject() : { ...member };
  value.mobile = maskMobile(value.mobile);
  value.altMobile = maskMobile(value.altMobile);
  return value;
};

const searchRegex = (value) => new RegExp(String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
const escapeRegex = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const hindiEnglishCollator = new Intl.Collator(['en', 'hi'], {
  numeric: true,
  sensitivity: 'base',
  ignorePunctuation: true,
});

function compareLabels(a, b) {
  const left = String(a?.label ?? a?.value ?? '').trim();
  const right = String(b?.label ?? b?.value ?? '').trim();
  return hindiEnglishCollator.compare(left, right);
}

const duplicateWarnings = async (data, excludeId) => {
  const or = [];
  if (data.mobile) or.push({ mobile: data.mobile });
  if (data.address) or.push({ address: data.address });
  if (!or.length) return [];
  const query = { $or: or };
  if (excludeId) query._id = { $ne: excludeId };
  const matches = await Member.find(query).select('mobile address name surname');
  return matches.flatMap((m) => {
    const warnings = [];
    if (data.mobile && m.mobile === data.mobile) warnings.push({ field: 'mobile', member: m._id, value: data.mobile });
    if (data.address && m.address === data.address) warnings.push({ field: 'address', member: m._id, value: data.address });
    return warnings;
  });
};

const attachBoothWard = async (data, user) => {
  if (user.role === 'booth') {
    data.booth = user.assignedBooth?._id || user.assignedBooth;
  }
  if (user.role === 'ward_head') {
    data.ward = user.assignedWard?._id || user.assignedWard;
  }
  if (data.booth) {
    const booth = await Booth.findById(data.booth).select('ward');
    if (!booth) {
      const err = new Error('Valid booth is required');
      err.status = 400;
      throw err;
    }
    data.ward = booth.ward;
  }
  return data;
};

exports.create = async (req, res, next) => {
  try {
    const data = { ...req.body };
    data.voterId = requireValidEpic(data.voterId);
    if (req.file) data.photo = await persistLocalImage(req.file.path, req.currentUser._id, true);
    await attachBoothWard(data, req.currentUser);
    assertBoothAccess(req.currentUser, data.booth);
    assertWardAccess(req.currentUser, data.ward);
    data.createdBy = req.currentUser._id;
    data.updatedBy = req.currentUser._id;
    data.duplicateWarnings = await duplicateWarnings(data);
    if (data.duplicateWarnings.length) data.verificationStatus = 'duplicate';
    const member = await Member.create(data);
    member.qrCode = await QRCode.toDataURL(`${process.env.APP_PUBLIC_URL || 'political-booth-crm'}:/members/${member._id}`);
    await member.save();
    await syncMemberFamily(member, req.currentUser._id);
    await writeActivity({ req, action: 'member.created', module: 'members', entityId: member._id, after: member });
    res.status(201).json(await Member.findById(member._id).populate(populate));
  } catch (error) {
    next(error);
  }
};

exports.list = async (req, res, next) => {
  try {
    const { q, party, supportLevel, gender, booth, ward, area, verificationStatus, location, village, gramPanchayat, tehsil, municipality, caste, organizationPost, sectionNumber, sectionName, assemblyNumber, assemblyName, partNumber, letter } = req.query;
    const limit = Math.min(Number(req.query.limit) || 100, 500);
    const page = Math.max(Number(req.query.page) || 1, 1);
    const paged = String(req.query.paged || '').toLowerCase() === 'true' || req.query.page !== undefined;
    const filter = applyMemberScope(req.currentUser, {});
    if (q) {
      const conditions = buildSearchConditions(q);
      filter.$and = [...(filter.$and || []), ...conditions];
    }
    if (party) filter.party = party;
    if (supportLevel) filter.supportLevel = supportLevel;
    if (gender) filter.gender = gender;
    if (ward) filter.ward = ward;
    if (area) filter.area = area;
    if (location) filter.location = searchRegex(location);
    if (village) filter.village = searchRegex(village);
    if (gramPanchayat) filter.gramPanchayat = searchRegex(gramPanchayat);
    if (tehsil) filter.tehsil = searchRegex(tehsil);
    if (municipality) filter.municipality = searchRegex(municipality);
    if (caste) filter.caste = searchRegex(caste);
    if (organizationPost) filter.organizationPost = searchRegex(organizationPost);
    if (sectionNumber) filter.sectionNumber = new RegExp(`^${String(sectionNumber).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i');
    if (sectionName) filter.sectionName = searchRegex(sectionName);
    if (assemblyNumber) filter.assemblyNumber = assemblyNumber;
    if (assemblyName) filter.assemblyName = searchRegex(assemblyName);
    if (partNumber) filter.partNumber = partNumber;
    if (verificationStatus) filter.verificationStatus = verificationStatus;
    if (letter) {
      const escapedLetter = escapeRegex(String(letter).trim());
      filter.name = new RegExp(`^${escapedLetter}`, 'i');
    }
    if (req.query.missingMobile === 'true') filter.$and = [...(filter.$and || []), { $or: [{ mobile: '' }, { mobile: null }, { mobile: { $exists: false } }] }];
    if (req.query.missingHouse === 'true') filter.$and = [...(filter.$and || []), { $or: [{ houseNumber: '' }, { houseNumber: null }, { houseNumber: { $exists: false } }] }];
    if (booth && req.currentUser.role === 'admin') filter.booth = booth;
    const listQuery = (query) => Member.find(query)
      .select('photo name surname mobile altMobile voterId voterSerial guardianName houseNumber address location area tehsil gramPanchayat village municipality caste subCaste organizationPost organizationLevel influenceLevel occupation education extraDetails supportLevel ward booth updatedAt age gender sectionNumber sectionName assemblyNumber assemblyName partNumber')
      .populate(populate)
      .sort(req.query.sort === 'recent' ? { updatedAt: -1 } : { name: 1, surname: 1, houseNumber: 1 })
      .collation({ locale: 'en', numericOrdering: true, strength: 1 });
    const start = paged ? (page - 1) * limit : 0;
    let members;
    let total;
    if (q) {
      const exactValues = searchExactCandidates(q);
      const exactFilter = exactValues.length ? { ...filter, searchExact: { $in: exactValues } } : null;
      const [matchingTotal, exactTotal] = await Promise.all([
        Member.countDocuments(filter),
        exactFilter ? Member.countDocuments(exactFilter) : 0,
      ]);
      total = matchingTotal;
      const exactMembers = start < exactTotal
        ? await listQuery(exactFilter).skip(start).limit(limit).lean()
        : [];
      const remaining = Math.max(0, limit - exactMembers.length);
      let generalMembers = [];
      if (remaining) {
        const generalFilter = exactValues.length
          ? {
              ...filter,
              $and: [...(filter.$and || []), { searchExact: { $nin: exactValues } }],
            }
          : filter;
        generalMembers = await listQuery(generalFilter)
          .skip(Math.max(0, start - exactTotal))
          .limit(remaining)
          .lean();
      }
      members = [...exactMembers, ...generalMembers];
    } else {
      members = await listQuery(filter).skip(start).limit(limit).lean();
      if (paged) total = await Member.countDocuments(filter);
    }
    const items = members.map((member) => maskMemberMobile(member, req.currentUser));
    if (!paged) return res.json(items);
    res.json({
      items,
      total,
      page,
      limit,
      pages: Math.max(Math.ceil(total / limit), 1),
    });
  } catch (error) {
    next(error);
  }
};

const optionDefinitions = {
  assembly: {
    group: { number: '$assemblyNumber', name: '$assemblyName' },
    match: { $or: [{ assemblyNumber: { $nin: ['', null] } }, { assemblyName: { $nin: ['', null] } }] },
    option: (id, count) => ({
      value: id.number || id.name,
      label: [id.number, id.name].filter(Boolean).join(' - '),
      count,
      filters: {
        ...(id.number ? { assemblyNumber: id.number } : {}),
        ...(id.name ? { assemblyName: id.name } : {}),
      },
    }),
  },
  section: {
    group: { number: '$sectionNumber', name: '$sectionName' },
    match: { $or: [{ sectionNumber: { $nin: ['', null] } }, { sectionName: { $nin: ['', null] } }] },
    option: (id, count) => ({
      value: id.number || id.name,
      label: [id.number, id.name].filter(Boolean).join(' - '),
      count,
      filters: {
        ...(id.number ? { sectionNumber: id.number } : {}),
        ...(id.name ? { sectionName: id.name } : {}),
      },
    }),
  },
  village: { field: 'village' },
  gramPanchayat: { field: 'gramPanchayat' },
  tehsil: { field: 'tehsil' },
  municipality: { field: 'municipality' },
  partNumber: { field: 'partNumber' },
  caste: { field: 'caste' },
  organizationPost: { field: 'organizationPost' },
};

function addOptionFilter(filter, key, value) {
  if (!value) return;
  if (['assemblyNumber', 'partNumber', 'sectionNumber', 'supportLevel', 'verificationStatus', 'gender'].includes(key)) {
    filter[key] = value;
  } else if (['assemblyName', 'sectionName', 'village', 'gramPanchayat', 'tehsil', 'municipality', 'caste', 'organizationPost'].includes(key)) {
    filter[key] = new RegExp(String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
  }
}

const locationFields = [
  'assemblyNumber',
  'assemblyName',
  'gramPanchayat',
  'village',
  'partNumber',
  'tehsil',
  'municipality',
  'sectionNumber',
  'sectionName',
  'location',
];

const cleanText = (value) => String(value ?? '').trim();

const exactLocationFilter = (source = {}) => {
  const filter = {};
  for (const field of ['assemblyNumber', 'assemblyName', 'gramPanchayat', 'village', 'partNumber']) {
    if (Object.prototype.hasOwnProperty.call(source, field)) {
      filter[field] = cleanText(source[field]);
    }
  }
  return filter;
};

const cleanLocationUpdates = (updates = {}) => {
  const cleaned = {};
  for (const field of locationFields) {
    if (Object.prototype.hasOwnProperty.call(updates, field)) {
      cleaned[field] = cleanText(updates[field]);
    }
  }
  return cleaned;
};

exports.locationGroups = async (req, res, next) => {
  try {
    const filter = applyMemberScope(req.currentUser, {});
    for (const key of ['assemblyNumber', 'assemblyName', 'gramPanchayat', 'village', 'partNumber']) {
      addOptionFilter(filter, key, req.query[key]);
    }
    const q = cleanText(req.query.q).toLocaleLowerCase('hi-IN');
    const rows = await Member.aggregate([
      { $match: filter },
      {
        $group: {
          _id: {
            assemblyNumber: { $ifNull: ['$assemblyNumber', ''] },
            assemblyName: { $ifNull: ['$assemblyName', ''] },
            gramPanchayat: { $ifNull: ['$gramPanchayat', ''] },
            village: { $ifNull: ['$village', ''] },
            partNumber: { $ifNull: ['$partNumber', ''] },
          },
          count: { $sum: 1 },
          sampleNames: { $push: '$name' },
        },
      },
      { $sort: { count: -1 } },
      { $limit: Math.min(Number(req.query.limit) || 200, 500) },
    ]);
    const items = rows.map((row) => {
      const key = row._id || {};
      const label = [
        key.assemblyNumber || key.assemblyName ? `विधानसभा ${[key.assemblyNumber, key.assemblyName].filter(Boolean).join(' - ')}` : '',
        key.gramPanchayat ? `पंचायत ${key.gramPanchayat}` : '',
        key.village ? `गाँव ${key.village}` : '',
        key.partNumber ? `भाग ${key.partNumber}` : '',
      ].filter(Boolean).join(' • ') || 'Location खाली';
      return {
        key,
        label,
        count: row.count,
        sampleNames: (row.sampleNames || []).filter(Boolean).slice(0, 3),
      };
    }).filter((item) => !q || item.label.toLocaleLowerCase('hi-IN').includes(q));
    res.json({ items });
  } catch (error) {
    next(error);
  }
};

exports.bulkLocationCorrection = async (req, res, next) => {
  try {
    const source = exactLocationFilter(req.body?.source || {});
    const updates = cleanLocationUpdates(req.body?.updates || {});
    const dryRun = req.body?.dryRun !== false;
    const sourceKeyCount = Object.values(source).filter((value) => value !== '').length;
    if (!source.village || sourceKeyCount < 2) {
      return res.status(400).json({
        message: 'गाँव अकेला unique नहीं माना जाएगा। Source में कम से कम गाँव + विधानसभा/पंचायत/भाग में से एक value दें।',
      });
    }
    if (!Object.keys(updates).length) {
      return res.status(400).json({ message: 'Correct location values required.' });
    }
    const filter = applyMemberScope(req.currentUser, source);
    const count = await Member.countDocuments(filter);
    const sample = await Member.find(filter)
      .select('name voterId guardianName houseNumber assemblyNumber assemblyName gramPanchayat village partNumber')
      .limit(20)
      .lean();
    if (dryRun) {
      return res.json({ dryRun: true, matched: count, source, updates, sample });
    }
    if (count > 5000) {
      return res.status(400).json({ message: 'एक बार में 5000 से ज्यादा voters update नहीं होंगे। Filter छोटा करें।', matched: count });
    }
    const members = await Member.find(filter);
    let updated = 0;
    for (const member of members) {
      Object.assign(member, updates);
      member.updatedBy = req.currentUser._id;
      await member.save();
      updated += 1;
    }
    await writeActivity({
      req,
      action: 'members.location_corrected',
      module: 'members',
      after: { matched: count, updated, source, updates },
    });
    res.json({ dryRun: false, matched: count, updated, source, updates });
  } catch (error) {
    next(error);
  }
};

exports.filterOptions = async (req, res, next) => {
  try {
    const definition = optionDefinitions[req.query.field];
    if (!definition) return res.status(400).json({ message: 'Invalid filter field' });
    const filter = applyMemberScope(req.currentUser, {});
    for (const key of [
      'assemblyNumber', 'assemblyName', 'partNumber', 'sectionNumber', 'sectionName',
      'village', 'gramPanchayat', 'tehsil', 'municipality', 'caste',
      'organizationPost', 'supportLevel', 'verificationStatus', 'gender',
    ]) addOptionFilter(filter, key, req.query[key]);
    if (req.query.missingMobile === 'true') filter.$and = [...(filter.$and || []), { $or: [{ mobile: '' }, { mobile: null }, { mobile: { $exists: false } }] }];
    if (req.query.missingHouse === 'true') filter.$and = [...(filter.$and || []), { $or: [{ houseNumber: '' }, { houseNumber: null }, { houseNumber: { $exists: false } }] }];

    const search = String(req.query.q || '').trim();
    const groupId = definition.group || `$${definition.field}`;
    const nonEmpty = definition.match || { [definition.field]: { $nin: ['', null] } };
    const rows = await Member.aggregate([
      { $match: { ...filter, ...nonEmpty } },
      { $group: { _id: groupId, count: { $sum: 1 } } },
      { $sort: { count: -1, _id: 1 } },
      { $limit: 500 },
    ]);
    const normalizedSearch = search.toLocaleLowerCase('hi-IN');
    const items = rows.map((row) => definition.option
      ? definition.option(row._id || {}, row.count)
      : ({ value: String(row._id), label: String(row._id), count: row.count, filters: { [definition.field]: String(row._id) } }))
      .filter((item) => item.value && (!normalizedSearch || item.label.toLocaleLowerCase('hi-IN').includes(normalizedSearch)))
      .sort((a, b) => {
        if (!normalizedSearch) return compareLabels(a, b);
        const aStarts = a.label.toLocaleLowerCase('hi-IN').startsWith(normalizedSearch);
        const bStarts = b.label.toLocaleLowerCase('hi-IN').startsWith(normalizedSearch);
        if (aStarts !== bStarts) return aStarts ? -1 : 1;
        return compareLabels(a, b);
      })
      .slice(0, Math.min(Math.max(Number(req.query.limit) || 80, 1), 200));
    res.json({ items });
  } catch (error) { next(error); }
};
exports.suggestions = async (req, res, next) => {
  try {
    const scope = applyMemberScope(req.currentUser, {});
    const { q = '' } = req.query;
    const matcher = q ? new RegExp(q, 'i') : /.*/;
    const [sections, locations, assemblies] = await Promise.all([
      Member.distinct('sectionName', { ...scope, sectionName: matcher }),
      Member.distinct('location', { ...scope, location: matcher }),
      Member.distinct('assemblyName', { ...scope, assemblyName: matcher }),
    ]);
    res.json({
      sections: sections.filter(Boolean).slice(0, 30),
      locations: locations.filter(Boolean).slice(0, 30),
      assemblies: assemblies.filter(Boolean).slice(0, 30),
    });
  } catch (error) {
    next(error);
  }
};

exports.get = async (req, res, next) => {
  try {
    const member = await Member.findById(req.params.id).populate(populate);
    if (!member) return res.status(404).json({ message: 'Member not found' });
    assertBoothAccess(req.currentUser, member.booth?._id || member.booth);
    assertWardAccess(req.currentUser, member.ward?._id || member.ward);
    res.json(maskMemberMobile(member, req.currentUser));
  } catch (error) {
    next(error);
  }
};

exports.update = async (req, res, next) => {
  try {
    const member = await Member.findById(req.params.id);
    if (!member) return res.status(404).json({ message: 'Member not found' });
    assertBoothAccess(req.currentUser, member.booth);
    assertWardAccess(req.currentUser, member.ward);
    if (req.body.booth) assertBoothAccess(req.currentUser, req.body.booth);
    if (req.body.ward) assertWardAccess(req.currentUser, req.body.ward);
    const before = member.toObject();
    const updates = { ...req.body };
    await attachBoothWard(updates, req.currentUser);
    if (updates.booth) assertBoothAccess(req.currentUser, updates.booth);
    if (updates.ward) assertWardAccess(req.currentUser, updates.ward);
    if (updates.voterId && requireValidEpic(updates.voterId) !== member.voterId) {
      return res.status(409).json({ message: 'EPIC नंबर स्थायी है और बदला नहीं जा सकता।' });
    }
    delete updates.voterId;
    Object.assign(member, updates);
    if (req.file) member.photo = await persistLocalImage(req.file.path, req.currentUser._id, true);
    member.updatedBy = req.currentUser._id;
    member.duplicateWarnings = await duplicateWarnings(member, member._id);
    if (member.duplicateWarnings.length && member.verificationStatus !== 'verified') member.verificationStatus = 'duplicate';
    await member.save();
    await syncMemberFamily(member, req.currentUser._id);
    await writeActivity({ req, action: 'member.updated', module: 'members', entityId: member._id, before, after: member });
    res.json(await Member.findById(member._id).populate(populate));
  } catch (error) {
    next(error);
  }
};

exports.remove = async (req, res, next) => {
  try {
    const member = await Member.findById(req.params.id);
    if (!member) return res.status(404).json({ message: 'Member not found' });
    assertBoothAccess(req.currentUser, member.booth);
    assertWardAccess(req.currentUser, member.ward);
    await removeMemberFromFamilies(member._id, req.currentUser._id);
    await member.deleteOne();
    await writeActivity({ req, action: 'member.deleted', module: 'members', entityId: member._id, before: member });
    res.json({ message: 'Deleted' });
  } catch (error) {
    next(error);
  }
};

exports.removeAll = async (req, res, next) => {
  try {
    if (req.body?.confirmation !== 'DELETE ALL VOTERS') {
      return res.status(400).json({ message: 'Bulk delete confirmation is invalid.' });
    }
    const [members, families] = await Promise.all([
      Member.deleteMany({}),
      Family.deleteMany({}),
    ]);
    await writeActivity({
      req,
      action: 'members.bulk_deleted',
      module: 'members',
      after: { members: members.deletedCount, families: families.deletedCount },
    });
    res.json({
      message: 'All voter and family data deleted.',
      deletedMembers: members.deletedCount,
      deletedFamilies: families.deletedCount,
    });
  } catch (error) {
    next(error);
  }
};

exports.birthdays = async (req, res, next) => {
  try {
    const now = new Date();
    const month = now.getMonth() + 1;
    const filter = applyMemberScope(req.currentUser, {
      $expr: { $eq: [{ $month: '$dob' }, month] },
    });
    res.json(await Member.find(filter).populate(populate).sort({ dob: 1 }));
  } catch (error) {
    next(error);
  }
};

exports.duplicates = async (req, res, next) => {
  try {
    const scope = applyMemberScope(req.currentUser, {});
    const mobile = await Member.aggregate([
      { $match: { ...scope, mobile: { $ne: null } } },
      { $group: { _id: '$mobile', count: { $sum: 1 }, members: { $push: '$_id' } } },
      { $match: { count: { $gt: 1 } } },
    ]);
    const address = await Member.aggregate([
      { $match: { ...scope, address: { $nin: [null, ''] } } },
      { $group: { _id: '$address', count: { $sum: 1 }, members: { $push: '$_id' } } },
      { $match: { count: { $gt: 1 } } },
    ]);
    res.json({ mobile, address });
  } catch (error) {
    next(error);
  }
};


