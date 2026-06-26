const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const Member = require('../models/Member');
const Area = require('../models/Area');
const Ward = require('../models/Ward');
const Booth = require('../models/Booth');
const Family = require('../models/Family');
const ImportReview = require('../models/ImportReview');
const { assertBoothAccess, assertWardAccess } = require('../utils/boothAccess');
const { findPartyFromText } = require('../utils/partySeed');
const { ocrPdf } = require('../utils/pdfOcr');
const { normalizeEpic, isValidEpic } = require('../utils/epic');
const { convertKrutiDevToUnicode } = require('../utils/legacyHindi');
const importProgress = new Map();

const progressId = (req) => String(req.body?.uploadId || req.params?.uploadId || req.query?.uploadId || '').replace(/[^a-z0-9_-]/gi, '').slice(0, 80);
const setProgress = (id, patch) => {
  if (!id) return;
  importProgress.set(id, { id, updatedAt: new Date().toISOString(), ...importProgress.get(id), ...patch });
};
const finishProgressSoon = (id, patch) => {
  setProgress(id, patch);
  if (id) setTimeout(() => importProgress.delete(id), 15 * 60 * 1000).unref?.();
};

exports.importStatus = (req, res) => {
  const current = importProgress.get(progressId(req));
  res.json(current || { status: 'waiting', stage: 'Waiting for upload', imported: 0, skipped: 0, total: 0, processed: 0, uploadBytes: 0, uploadTotalBytes: 0 });
};
exports.trackUploadProgress = (req, res, next) => {
  const id = progressId(req);
  if (!id) return next();
  const totalBytes = Number(req.headers['content-length'] || 0);
  let receivedBytes = 0;
  setProgress(id, {
    status: 'uploading',
    stage: 'Receiving file on server',
    uploadBytes: 0,
    uploadTotalBytes: totalBytes,
    imported: 0,
    skipped: 0,
    processed: 0,
    total: 0,
  });
  req.on('data', (chunk) => {
    receivedBytes += chunk.length;
    setProgress(id, {
      status: 'uploading',
      stage: 'Receiving file on server',
      uploadBytes: receivedBytes,
      uploadTotalBytes: totalBytes,
    });
  });
  req.on('end', () => {
    setProgress(id, {
      status: 'processing',
      stage: 'Upload received. Preparing import',
      uploadBytes: receivedBytes,
      uploadTotalBytes: totalBytes,
    });
  });
  next();
};

const estimateDobFromAge = (age) => {
  const value = Number(age);
  if (!value || value < 1 || value > 120) return undefined;
  return new Date(Date.UTC(new Date().getFullYear() - value, 0, 1));
};

const cleanValue = (value = '') => String(value).replace(/\s+/g, ' ').replace(/^[\uFF1A:\-\s]+/, '').trim();
const cleanHeaderName = (value, rejectPattern) => {
  const text = cleanValue(value).replace(/^[^\u0900-\u097F]*/, '').trim();
  if (!text || (rejectPattern && rejectPattern.test(text))) return '';
  return text;
};

const pick = (row, ...keys) => {
  for (const key of keys) {
    const value = row[key];
    if (value !== undefined && value !== null && String(value).trim() !== '') return value;
  }
  return undefined;
};

const normalizeGender = (value) => {
  const gender = String(value || '').trim().toLowerCase();
  if (['m', 'male', '?????', '??'].includes(gender)) return 'male';
  if (['f', 'female', '?????', '??????'].includes(gender)) return 'female';
  if (['o', 'other', 'others', '????', 'third gender', 'transgender'].includes(gender)) return 'other';
  return '';
};

const legacyLocation = (value) => {
  const text = cleanValue(value);
  return text ? convertKrutiDevToUnicode(text) : undefined;
};

const knownImportHeaders = new Set([
  'ac no', 'part no.', 'part no', 'sl. no. in part',
  'epic no', 'name', 'age', 'gender', 's/o, d/o, w/o name', 'rln type',
  'mobile no', 'mobile', 'cast', 'caste', 'address', 'villege', 'village',
  'gram panchayat', 'block', 'tehsil', 'education', 'occupation',
  'presant city', 'present city', 'presant state', 'present state',
  'post', 'support level', 'sectionnumber', 'section number', 'sectionname',
  'section name', 'assemblynumber', 'assembly number', 'assemblyname',
  'assembly name',
]);

const buildExtraDetails = (row) => Object.entries(row)
  .filter(([key, value]) => (
    value !== undefined
    && value !== null
    && String(value).trim() !== ''
    && !knownImportHeaders.has(String(key).trim().toLowerCase())
  ))
  .map(([label, value]) => ({ label: cleanValue(label), value: cleanValue(value) }));
const normalize = (row) => {
  const age = pick(row, 'age', 'Age', '????');
  const address = legacyLocation(pick(row, 'address', 'Address', '???'));
  const village = legacyLocation(pick(row, 'village', 'villege', 'Village', '????', '????'));
  const gramPanchayat = legacyLocation(pick(row, 'gramPanchayat', 'gram panchayat', 'Gram Panchayat', '????? ??????'));
  const tehsil = legacyLocation(pick(row, 'tehsil', 'Tehsil', 'block', 'Block', '?????'));
  const presentCity = legacyLocation(pick(row, 'presant city', 'present city', 'Present City'));
  const presentState = legacyLocation(pick(row, 'presant state', 'present state', 'Present State'));
  const extraDetails = buildExtraDetails(row);
  if (presentCity) extraDetails.push({ label: 'Present City', value: presentCity });
  if (presentState) extraDetails.push({ label: 'Present State', value: presentState });
  return {
    name: pick(row, 'name', 'Name', 'firstName', 'First Name', '???'),
    surname: pick(row, 'surname', 'Surname', 'lastName', 'Last Name', '?????'),
    mobile: String(pick(row, 'mobile', 'Mobile', 'Mobile No', 'phone', 'Phone', '??????') || '').trim(),
    altMobile: String(pick(row, 'altMobile', 'Alternate Mobile', '???????? ??????') || '').trim(),
    address,
    location: village || gramPanchayat || address,
    gender: normalizeGender(pick(row, 'gender', 'Gender', '????')),
    occupation: pick(row, 'occupation', 'Occupation', '???????'),
    education: pick(row, 'education', 'Education', '??????'),
    caste: pick(row, 'caste', 'Caste', 'Cast', '????'),
    subCaste: pick(row, 'subCaste', 'Sub Caste', 'Sub-Caste', '??????'),
    organizationPost: pick(row, 'organizationPost', 'Post', 'post', '??'),
    organizationLevel: pick(row, 'organizationLevel', 'Post Level', '?? ????'),
    supportLevel: String(pick(row, 'supportLevel', 'Support Level') || 'undecided').toLowerCase(),
    voterId: pick(row, 'voterId', 'Voter ID', 'EPIC No', 'EPIC Number', 'EPIC', '???? ID', '?????? ????? ????'),
    voterSerial: pick(row, 'voterSerial', 'Serial', 'Serial No', 'Sl. No. In Part', '???????'),
    guardianName: pick(row, 'guardianName', 'Father/Husband', 's/o, d/o, w/o Name', '????/??? ?? ???', '???? ?? ???', '??? ?? ???'),
    relationType: pick(row, 'relationType', 'RLN Type'),
    houseNumber: pick(row, 'houseNumber', 'House Number', '??? ??????'),
    age,
    estimatedDob: estimateDobFromAge(age),
    assemblyNumber: pick(row, 'assemblyNumber', 'AC No', 'Assembly No', '???????? ??????'),
    assemblyName: pick(row, 'assemblyName', 'AC Name', 'Assembly Name', 'vidhansabha', '????????'),
    partNumber: pick(row, 'partNumber', 'Part No.', 'Part No', '??? ??????'),
    sectionNumber: pick(row, 'sectionNumber', 'Section Number', '?????? ??????'),
    sectionName: legacyLocation(pick(row, 'sectionName', 'Section Name', '?????? ???')),
    tehsil,
    gramPanchayat,
    village,
    extraDetails,
  };
};

const cleanImportData = (data) => Object.fromEntries(
  Object.entries(data).filter(([, value]) => (
    value !== undefined
    && value !== null
    && (Array.isArray(value) ? value.length > 0 : String(value).trim() !== '')
  )),
);

const assignNonEmptyFields = (target, source, fields) => {
  for (const field of fields) {
    const value = source?.[field];
    if (
      value !== undefined
      && value !== null
      && (Array.isArray(value) ? value.length > 0 : String(value).trim() !== '')
    ) {
      target[field] = value;
    }
  }
};
const mergeExtraDetails = (current = [], incoming = []) => {
  const merged = new Map();
  [...current, ...incoming].forEach((item) => {
    const label = cleanValue(item?.label);
    const value = cleanValue(item?.value);
    if (label && value) merged.set(label.toLowerCase(), { label, value });
  });
  return [...merged.values()];
};

const areaImportCache = new Map();
const getOrCreateArea = async ({ name, type, parent = null, assemblyNumber = '', userId }) => {
  const cleanName = cleanValue(name);
  if (!cleanName) return parent;
  const cleanAssemblyNumber = String(assemblyNumber || '').trim();
  const cacheIdentity = type === 'assembly' && cleanAssemblyNumber ? cleanAssemblyNumber : cleanName.toLowerCase();
  const cacheKey = `${String(parent || 'root')}|${type}|${cacheIdentity}`;
  if (areaImportCache.has(cacheKey)) return areaImportCache.get(cacheKey);
  const query = type === 'assembly' && cleanAssemblyNumber
    ? { parent, type, assemblyNumber: cleanAssemblyNumber }
    : { parent, type, name: cleanName };
  const area = await Area.findOneAndUpdate(
    query,
    {
      $set: { name: cleanName, active: true },
      $setOnInsert: { type, parent, assemblyNumber: cleanAssemblyNumber, createdBy: userId },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );
  areaImportCache.set(cacheKey, area._id);
  return area._id;
};

const ensureAreaHierarchy = async (data, userId) => {
  let parent = null;
  const assemblyNumber = String(data.assemblyNumber || '').trim();
  if (assemblyNumber) {
    const existingAssembly = await Area.findOne({ parent: null, type: 'assembly', assemblyNumber });
    if (existingAssembly) {
      existingAssembly.active = true;
      if (data.assemblyName) existingAssembly.name = cleanValue(data.assemblyName);
      await existingAssembly.save();
      parent = existingAssembly._id;
    } else {
      parent = await getOrCreateArea({
        name: data.assemblyName || `Assembly ${assemblyNumber}`,
        type: 'assembly',
        assemblyNumber,
        userId,
      });
    }
  } else {
    parent = await getOrCreateArea({ name: data.assemblyName, type: 'assembly', userId });
  }
  parent = await getOrCreateArea({ name: data.tehsil, type: 'tehsil', parent, userId });
  parent = await getOrCreateArea({ name: data.gramPanchayat, type: 'gram_panchayat', parent, userId });
  parent = await getOrCreateArea({ name: data.village, type: 'village', parent, userId });
  return parent;
};

const areaMatchKey = (value) => cleanValue(value)
  .toLowerCase()
  .replace(/[ािीुूृेैोौंँः]/g, '')
  .replace(/[^\u0900-\u097fa-z0-9]/g, '');
const pdfAreaHierarchyCache = new Map();
const enrichPdfAreaHierarchy = async (data, assemblyArea) => {
  const locationText = cleanValue([
    data.sectionName,
    data.address,
    data.location,
  ].filter(Boolean).join(' ')).toLowerCase();
  if (!locationText || !assemblyArea) return assemblyArea;
  const cacheKey = `${String(assemblyArea)}|${locationText}`;
  if (pdfAreaHierarchyCache.has(cacheKey)) {
    const cached = pdfAreaHierarchyCache.get(cacheKey);
    Object.assign(data, cached.fields);
    return cached.area;
  }

  const tehsils = await Area.find({
    parent: assemblyArea,
    type: 'tehsil',
    active: true,
  }).lean();
  for (const tehsil of tehsils) {
    const gramPanchayats = await Area.find({
      parent: tehsil._id,
      type: 'gram_panchayat',
      active: true,
    }).lean();
    for (const gramPanchayat of gramPanchayats) {
      const villages = await Area.find({
        parent: gramPanchayat._id,
        type: 'village',
        active: true,
      }).lean();
      const locationKey = areaMatchKey(locationText);
      const village = villages.find((entry) => {
        const exactName = cleanValue(entry.name).toLowerCase();
        const matchKey = areaMatchKey(entry.name);
        return locationText.includes(exactName)
          || (matchKey.length >= 2 && locationKey.includes(matchKey));
      });
      if (!village) continue;
      data.tehsil = tehsil.name;
      data.gramPanchayat = gramPanchayat.name;
      data.village = village.name;
      const fields = {
        tehsil: data.tehsil,
        gramPanchayat: data.gramPanchayat,
        village: data.village,
      };
      pdfAreaHierarchyCache.set(cacheKey, { area: village._id, fields });
      return village._id;
    }
  }
  return assemblyArea;
};
const assertReadablePdf = (filePath) => {
  const buffer = fs.readFileSync(filePath);
  if (buffer.length < 8 || buffer.slice(0, 5).toString('ascii') !== '%PDF-') {
    const err = new Error('Uploaded file is not a valid PDF. Please upload the original voter-list PDF, not a renamed or incomplete file.');
    err.status = 400;
    throw err;
  }
  return buffer;
};
const isObjectId = (value) => /^[a-f\d]{24}$/i.test(String(value || ''));

const resolveWard = async (value) => {
  if (!value || isObjectId(value)) return value;
  const text = String(value).trim();
  const ward = await Ward.findOne({ $or: [{ number: text }, { name: new RegExp(`^${text}$`, 'i') }] });
  return ward?._id;
};

const resolveBooth = async (value, ward) => {
  if (!value || isObjectId(value)) return value;
  const text = String(value).trim();
  const query = { $or: [{ number: text }, { name: new RegExp(`^${text}$`, 'i') }] };
  if (ward) query.ward = ward;
  const booth = await Booth.findOne(query);
  return booth?._id;
};

const getOrCreateImportScope = async ({ user, body, firstMember }) => {
  if (user.role === 'booth') {
    return {
      ward: user.assignedBooth?.ward,
      booth: user.assignedBooth?._id || user.assignedBooth,
    };
  }
  if (user.role === 'ward_head') {
    const ward = user.assignedWard?._id || user.assignedWard;
    const booth = await resolveBooth(body.booth || firstMember?.partNumber || 'default', ward);
    if (booth) return { ward, booth };
    const createdBooth = await Booth.create({
      ward,
      number: String(firstMember?.partNumber || '1'),
      name: `Part ${firstMember?.partNumber || '1'}`,
      area: firstMember?.assemblyName || firstMember?.sectionName,
    });
    return { ward, booth: createdBooth._id };
  }

  let ward = await resolveWard(body.ward);
  if (!ward && firstMember?.assemblyNumber) {
    const wardSet = { active: true };
    const wardInsert = {
      number: String(firstMember.assemblyNumber),
    };
    if (firstMember.assemblyName) {
      wardSet.name = firstMember.assemblyName;
      wardSet.area = firstMember.assemblyName;
    } else {
      wardInsert.name = `Assembly ${firstMember.assemblyNumber}`;
    }
    const createdWard = await Ward.findOneAndUpdate(
      { number: String(firstMember.assemblyNumber) },
      {
        $set: wardSet,
        $setOnInsert: wardInsert,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true },
    );
    ward = createdWard._id;
  }

  let booth = await resolveBooth(body.booth, ward);
  if (!booth && ward) {
    const number = String(firstMember?.partNumber || body.booth || '1');
    const createdBooth = await Booth.findOneAndUpdate(
      { ward, number },
      {
        ward,
        number,
        name: `Part ${number}`,
        area: firstMember?.assemblyName || firstMember?.sectionName,
        address: firstMember?.assemblyName || firstMember?.sectionName,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true },
    );
    booth = createdBooth._id;
  }
  return { ward, booth };
};

const parseHeader = (text) => {
  const normalized = String(text || '')
    .normalize('NFKC')
    .replace(/\s+/g, ' ')
    .trim();
  const assembly = normalized.match(
    /(?:विधान\s*सभा\s*(?:क्षेत्र)?|assembly\s*(?:constituency)?|AC)\s*(?:की)?\s*(?:संख्या|नं\.?|number|no\.?)?\s*(?:व\s*नाम|and\s*name)?\s*[:：-]?\s*([0-9O]{1,3})\s*(?:[-–:]\s*)?(.+?)(?=\s*(?:अनुभाग|भाग\s*(?:संख्या|नं)|section|part\s*(?:number|no)|निर्वाचक)|$)/i,
  );
  const part = normalized.match(
    /(?:भाग|part)\s*(?:संख्या|नं\.?|number|no\.?)?\s*[:：-]*\s*([0-9O]{1,4})/i,
  );
  const section = normalized.match(
    /(?:अनुभाग|section)\s*(?:की)?\s*(?:संख्या|नं\.?|number|no\.?)?\s*(?:व|एवं|and)?\s*(?:नाम|name)?\s*[:：-]*\s*([0-9O]{1,3})?\s*(?:[-–:]\s*)?(.+?)(?=\s*(?:भाग\s*(?:संख्या|नं)|निर्वाचक|मतदाता|part\s*(?:number|no))|$)/i,
  );
  const digits = (value) => value?.replace(/O/gi, '0');
  return {
    assemblyNumber: digits(assembly?.[1]),
    assemblyName: cleanValue(assembly?.[2]),
    partNumber: digits(part?.[1]),
    sectionNumber: digits(section?.[1]),
    sectionName: cleanValue(section?.[2]),
  };
};

const extractVoterId = (chunk) => {
  const compact = chunk
    .toUpperCase()
    .replace(/[|\\]/g, '/')
    .replace(/[^A-Z0-9/]/g, '')
    .replace(/\s+/g, '');
  const modern = compact.match(/[A-Z]{3}[0-9O]{7}/)?.[0];
  if (modern) {
    return `${modern.slice(0, 3)}${modern.slice(3).replace(/O/g, '0')}`;
  }
  const legacy = compact.match(/RJ\/[0-9O]{1,3}\/[0-9O]{1,3}\/[0-9O]{5,8}/)?.[0];
  return legacy?.replace(/O/g, '0');
};

const parseHindiVoterRoll = (text, headerOverride) => {
  const header = headerOverride || parseHeader(text);
  const normalized = text.replace(/\r/g, '\n');
  const serialMatches = [...normalized.matchAll(/(?:^|\n)\s*(\d{1,6})\s*(?:\n|\s)+(?:\d{1,4}\s*)?(SNE|RJ\/|MBY|[A-Z]{2,4})/g)];
  const chunks = [];
  for (let i = 0; i < serialMatches.length; i += 1) {
    const start = serialMatches[i].index;
    const end = serialMatches[i + 1]?.index || normalized.length;
    chunks.push(normalized.slice(start, end));
  }
  const fallbackChunks = chunks.length ? chunks : normalized.split(/(?=à¤¨à¤¿à¤°à¥à¤µà¤¾\S*\s+à¤•à¤¾\s+à¤¨à¤¾à¤®)/);

  return fallbackChunks.map((chunk) => {
    const voterId = extractVoterId(chunk);
    const serial = chunk.match(/^\s*(\d{1,6})/m)?.[1];
    const name = chunk.match(/(?:à¤¨à¤¿à¤°à¥à¤µà¤¾\S*|à¤®à¤¤à¤¦à¤¾à¤¤à¤¾)\s*(?:à¤•à¤¾)?\s*à¤¨à¤¾à¤®\s*[:ï¼š-]?\s*([^\n]+)/)?.[1];
    const father = chunk.match(/(?:à¤ªà¤¿à¤¤à¤¾|à¤ªà¤¿\S*)\s*(?:à¤•à¤¾)?\s*à¤¨à¤¾à¤®\s*[:ï¼š-]?\s*([^\n]+)/)?.[1];
    const husband = chunk.match(/(?:à¤ªà¤¤à¤¿|à¤ªà¤¤à¥à¤¤à¤¿|à¤ªà¥à¤°à¤¤à¤¿)\s*(?:à¤•à¤¾)?\s*à¤¨à¤¾à¤®\s*[:ï¼š-]?\s*([^\n]+)/)?.[1];
    const mother = chunk.match(/à¤®à¤¾à¤¤à¤¾\s+à¤•à¤¾\s+à¤¨à¤¾à¤®\s*[:ï¼š-]?\s*([^\n]+)/)?.[1];
    const house = chunk.match(/à¤—à¥ƒà¤¹\s*à¤¸à¤‚à¤–à¥à¤¯à¤¾\s*[:ï¼š-]?\s*([^\n]+)/)?.[1];
    const age = chunk.match(/(?:à¤‰à¤®à¥à¤°|à¤‰à¤ªà¥à¤°|à¤†à¤¯à¥)\s*[:ï¼š-]?\s*([0-9]{1,3})/i)?.[1];
    const genderText = chunk.match(/à¤²à¤¿à¤‚à¤—\s*[:ï¼š-]?\s*([^\n\s]+)/)?.[1];
    const cleanOcrField = (value) => cleanValue(value)
      .replace(/\s+(?:of|fire|fra|rs|à¤—à¥ƒà¤¹|à¤‰à¤®à¥à¤°|à¤²à¤¿à¤‚à¤—)\b.*$/i, '')
      .replace(/[|\\]+$/g, '')
      .trim();
    const guardianName = cleanOcrField(father || husband || mother || '');
    const relationType = father ? 'father' : husband ? 'husband' : mother ? 'mother' : '';
    const gender = /\u092A\u0941\u0930\u0941\u0937/.test(genderText || '') ? 'male' : /\u092E\u0939\u093F\u0932\u093E/.test(genderText || '') ? 'female' : '';
    const cleanName = cleanOcrField(name);
    const devanagariCount = (cleanName.match(/[\u0900-\u097F]/g) || []).length;
    const latinCount = (cleanName.match(/[A-Za-z]/g) || []).length;
    if (
      !cleanName
      || devanagariCount < 2
      || latinCount > devanagariCount
      || /^(?:ASSEMBLYNUMBER|PARTNUMBER|SECTIONNUMBER)$/i.test(cleanName)
    ) return null;
    return {
      ...header,
      voterSerial: serial,
      voterId,
      name: cleanName,
      mobile: '',
      guardianName,
      relationType,
      houseNumber: cleanOcrField(house),
      address: [header.sectionName || header.assemblyName, cleanOcrField(house)].filter(Boolean).join(', '),
      location: header.sectionName || header.assemblyName || '',
      age: age ? Number(age) : undefined,
      estimatedDob: estimateDobFromAge(age),
      gender,
      rawText: chunk.trim(),
    };
  }).filter(Boolean);
};

const extractTextWithFallback = async (filePath, importFileName) => {
  const pdfBuffer = assertReadablePdf(filePath);
  const extractionErrors = [];
  try {
    const pdfParse = require('pdf-parse');
    const parsed = await pdfParse(pdfBuffer);
    if (parsed.text?.trim().length > 40) return { text: parsed.text, ocr: null };
  } catch (firstError) {
    extractionErrors.push('pdf-parse: ' + firstError.message);
    const originalConsoleWarn = console.warn;
    const originalConsoleError = console.error;
    try {
      const PDFParser = require('pdf2json');
      const text = await new Promise((resolve, reject) => {
        const parser = new PDFParser();
        parser.on('pdfParser_dataError', (error) => reject(error.parserError || error));
        parser.on('pdfParser_dataReady', (data) => {
          const pageText = (data.Pages || []).flatMap((page) => (
            page.Texts || []
          ).map((item) => (
            item.R || []
          ).map((run) => decodeURIComponent(run.T || '')).join(''))).join('\n');
          resolve(pageText);
        });
        console.warn = () => {};
        console.error = () => {};
        try {
          parser.loadPDF(filePath);
        } catch (error) {
          reject(error);
        }
      });
      if (text?.trim().length > 40) return { text, ocr: null };
    } catch (secondError) {
      extractionErrors.push('pdf2json: ' + secondError.message);
    } finally {
      console.warn = originalConsoleWarn;
      console.error = originalConsoleError;
    }
  }
  try {
    const ocr = await ocrPdf(filePath, importFileName);
    return { text: ocr.text, ocr };
  } catch (ocrError) {
    const detail = [...extractionErrors, 'OCR: ' + ocrError.message].filter(Boolean).join(' | ');
    const corruptHint = /trailer dictionary|xref|Invalid PDF|bad XRef|endobj/i.test(detail)
      ? ' The PDF appears damaged or incomplete; download/export it again and retry.'
      : '';
    const err = new Error('PDF text extraction and OCR failed.' + corruptHint + ' Ensure Poppler/Tesseract are installed and PDFTOPPM_PATH, TESSERACT_PATH, and Hindi language data are configured. Detail: ' + detail);
    err.status = 400;
    throw err;
  }
};

const parsePdfTextLayerMembers = async (filePath) => {
  const pdfjs = require('pdf-parse/lib/pdf.js/v1.10.100/build/pdf.js');
  const document = await pdfjs.getDocument(new Uint8Array(fs.readFileSync(filePath)));
  const members = [];
  const documentText = [];
  const imageOnlyPages = [];
  let documentHeader = {};

  for (let pageNumber = 1; pageNumber <= document.numPages; pageNumber += 1) {
    const page = await document.getPage(pageNumber);
    const content = await page.getTextContent({ normalizeWhitespace: true, disableCombineTextItems: false });
    const items = content.items
      .map((item) => ({ text: String(item.str || ''), x: item.transform?.[4], y: item.transform?.[5] }))
      .filter((item) => item.text.trim() && Number.isFinite(item.x) && Number.isFinite(item.y));
    if (!items.length) imageOnlyPages.push(pageNumber);
    const width = page.view[2] - page.view[0];
    const height = page.view[3] - page.view[1];
    const orderedItems = items
      .slice()
      .sort((a, b) => Math.abs(b.y - a.y) > 1 ? b.y - a.y : a.x - b.x);
    const pageText = orderedItems.map((item) => item.text).join(' ');
    const headerText = orderedItems
      .filter((item) => item.y >= height * 0.955)
      .map((item) => item.text)
      .join(' ');
    documentText.push(pageText);
    const pageHeader = parseHeader(headerText);
    documentHeader = {
      ...documentHeader,
      ...Object.fromEntries(Object.entries(pageHeader).filter(([, value]) => value)),
    };

    const gridTop = height * 0.969;
    const rowStep = height * 0.094;
    const cards = Array.from({ length: 30 }, () => []);
    for (const item of items) {
      const column = item.x < width / 3 ? 0 : item.x < (width * 2) / 3 ? 1 : 2;
      const row = Math.floor((gridTop - item.y) / rowStep);
      if (row >= 0 && row < 10) cards[row * 3 + column].push(item);
    }

    for (const cardItems of cards) {
      if (!cardItems.length) continue;
      const lines = [];
      for (const item of cardItems.sort((a, b) => Math.abs(b.y - a.y) > 1 ? b.y - a.y : a.x - b.x)) {
        let line = lines.find((entry) => Math.abs(entry.y - item.y) <= 1.2);
        if (!line) {
          line = { y: item.y, items: [] };
          lines.push(line);
        }
        line.items.push(item);
      }
      const cardText = lines
        .sort((a, b) => b.y - a.y)
        .map((line) => line.items.sort((a, b) => a.x - b.x).map((item) => item.text).join(''))
        .join('\n');
      const voterId = extractVoterId(cardText);
      const name = cleanValue(cardText.match(/(?:निर्वाचक|मतदाता)\s*(?:का)?\s*नाम\s*[:：ः-]?\s*([^\n]+)/i)?.[1]);
      if (!name || !voterId) continue;
      const father = cleanValue(cardText.match(/पिता\s*(?:का)?\s*नाम\s*[:：ः-]?\s*([^\n]+)/i)?.[1]);
      const husband = cleanValue(cardText.match(/पति\s*(?:का)?\s*नाम\s*[:：ः-]?\s*([^\n]+)/i)?.[1]);
      const mother = cleanValue(cardText.match(/माता\s*(?:का)?\s*नाम\s*[:：ः-]?\s*([^\n]+)/i)?.[1]);
      const houseNumber = cleanValue(cardText.match(/(?:गृह|मकान)\s*संख्या\s*[:：-]?\s*([^\n]+)/i)?.[1]);
      const ageText = cardText.match(/(?:उम्र|आयु)\s*[:：-]?\s*(\d{1,3})/i)?.[1];
      const serial = cardText.match(/^\s*(\d{1,4})/)?.[1];
      const header = {
        ...documentHeader,
        ...Object.fromEntries(Object.entries(pageHeader).filter(([, value]) => value)),
      };
      members.push({
        ...header,
        name,
        mobile: '',
        voterId,
        voterSerial: serial,
        guardianName: father || husband || mother || '',
        relationType: father ? 'father' : husband ? 'husband' : mother ? 'mother' : '',
        houseNumber,
        age: ageText ? Number(ageText) : undefined,
        estimatedDob: estimateDobFromAge(ageText),
        gender: /महिला/.test(cardText) ? 'female' : /पुरुष/.test(cardText) ? 'male' : '',
        address: [header.sectionName || header.assemblyName, houseNumber].filter(Boolean).join(', '),
        location: header.sectionName || header.assemblyName || '',
        rawText: cardText,
      });
    }
  }
  const normalizedMembers = members.map((member) => ({
    ...member,
    assemblyNumber: documentHeader.assemblyNumber || member.assemblyNumber,
    assemblyName: documentHeader.assemblyName || member.assemblyName,
    partNumber: documentHeader.partNumber || member.partNumber,
  }));
  return { text: documentText.join('\n'), members: normalizedMembers, imageOnlyPages, header: documentHeader };
};
const parsePdfMembers = async (filePath, importFileName) => {
  const textLayer = await parsePdfTextLayerMembers(filePath);
  if (textLayer.members.length && !textLayer.imageOnlyPages.length) {
    return { text: textLayer.text, members: textLayer.members, ocr: null };
  }
  if (textLayer.members.length && textLayer.imageOnlyPages.length) {
    const firstPage = Math.min(...textLayer.imageOnlyPages);
    const lastPage = Math.max(...textLayer.imageOnlyPages);
    const ocr = await ocrPdf(filePath, importFileName, { firstPage, lastPage });
    const header = { ...(ocr.header || {}), ...textLayer.header };
    const sectionNames = new Map();
    for (const member of textLayer.members) {
      if (member.sectionNumber && member.sectionName && !sectionNames.has(String(member.sectionNumber))) {
        sectionNames.set(String(member.sectionNumber), member.sectionName);
      }
    }
    const ocrMembers = (ocr.voterRecords || []).map((record) => {
      const sectionNumber = record.sectionNumber || header.sectionNumber;
      const sectionKey = String(sectionNumber || '');
      const sectionName = sectionNames.get(sectionKey) || record.sectionName || header.sectionName;
      if (sectionKey && sectionName && !sectionNames.has(sectionKey)) sectionNames.set(sectionKey, sectionName);
      return {
        ...header,
        assemblyNumber: header.assemblyNumber || record.assemblyNumber,
        assemblyName: header.assemblyName || record.assemblyName,
        partNumber: header.partNumber || record.partNumber,
        sectionNumber,
        sectionName,
        name: record.name || '',
        guardianName: record.guardianName || '',
        relationType: record.relationType || '',
        houseNumber: cleanValue(record.houseNumber),
        age: record.age,
        estimatedDob: estimateDobFromAge(record.age),
        gender: record.gender || '',
        voterSerial: record.voterSerial || undefined,
        voterId: record.voterId || undefined,
        mobile: '',
        address: [sectionName || header.assemblyName, cleanValue(record.houseNumber)].filter(Boolean).join(', '),
        location: sectionName || header.assemblyName || '',
        photo: record.photo,
        rawText: record.rawText || record.text,
        ocrConfidence: record.confidence,
      };
    });    const merged = new Map();
    [...textLayer.members, ...ocrMembers].forEach((member, index) => {
      const epic = normalizeEpic(member.voterId);
      merged.set(epic || `review-${index}`, { ...member, voterId: epic || member.voterId });
    });
    return { text: `${textLayer.text}\n${ocr.text || ''}`, members: [...merged.values()], ocr };
  }
  const extracted = await extractTextWithFallback(filePath, importFileName);
  let text = String(extracted?.text || '');
  const header = {
    ...parseHeader(text),
    ...(extracted.ocr?.header || {}),
  };
  header.assemblyName = cleanHeaderName(header.assemblyName, /à¤­à¤¾à¤—\s*à¤¸à¤‚à¤–à¥à¤¯à¤¾|à¤…à¤¨à¥à¤­à¤¾à¤—/i);
  header.sectionName = cleanHeaderName(header.sectionName, /à¤­à¤¾à¤—\s*à¤¸à¤‚à¤–à¥à¤¯à¤¾|à¤µà¤¿à¤§à¤¾à¤¨\s*à¤¸à¤­à¤¾/i);
  const voterRollMembers = extracted.ocr?.voterRecords?.length
    ? extracted.ocr.voterRecords.flatMap((record) => (
      record.name
        ? [{
          ...header,
          name: record.name,
          guardianName: record.guardianName || '',
          relationType: record.relationType || '',
          houseNumber: cleanValue(record.houseNumber),
          age: record.age,
          estimatedDob: estimateDobFromAge(record.age),
          gender: record.gender || '',
          voterSerial: record.voterSerial || undefined,
          voterId: record.voterId || undefined,
          mobile: '',
          address: [header.sectionName || header.assemblyName, cleanValue(record.houseNumber)].filter(Boolean).join(', '),
          location: header.sectionName || header.assemblyName || '',
          photo: record.photo,
          rawText: record.rawText || record.text,
          ocrConfidence: record.confidence,
        }]
        : parseHindiVoterRoll(record.text || record.rawText || '', header)
          .map((member) => ({ ...member, ...header, photo: record.photo }))
    ))
    : parseHindiVoterRoll(text);
  if (voterRollMembers.length) return { text, members: voterRollMembers, ocr: extracted.ocr };

  const members = [];
  let current = {};
  const lines = text.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  for (const line of lines) {
    const mobile = line.match(/(?:\+91[-\s]?)?[6-9]\d{9}/);
    if (mobile) current.mobile = mobile[0].replace(/\D/g, '').slice(-10);
    if (/name\s*:/i.test(line)) current.name = line.split(/name\s*:/i)[1].trim();
    if (/address\s*:/i.test(line)) current.address = line.split(/address\s*:/i)[1].trim();
    if (/location|area\s*:/i.test(line)) current.location = line.split(/:\s*/).slice(1).join(':').trim();
    if (/party/i.test(line)) current.partyText = line;
    if (current.name && current.mobile) {
      members.push({ ...current, rawText: line });
      current = {};
    }
  }
  if (members.length || extracted.ocr) return { text, members, ocr: extracted.ocr };

  try {
    const ocr = await ocrPdf(filePath, importFileName);
    text = ocr.text;
    const ocrMembers = parseHindiVoterRoll(text);
    return { text, members: ocrMembers, ocr };
  } catch (ocrError) {
    const err = new Error(`PDF contained no readable voter records and OCR failed. Detail: ${ocrError.message}`);
    err.status = 400;
    throw err;
  }
};

const extractPdfImages = async (filePath, importFileName) => {
  const pdfimages = process.env.PDFIMAGES_PATH || 'pdfimages';
  const safeBase = path.basename(importFileName, path.extname(importFileName)).replace(/[^a-z0-9_-]/gi, '-');
  const imageDir = path.join(__dirname, '../../uploads/pdf-images', `${Date.now()}-${safeBase}`);
  fs.mkdirSync(imageDir, { recursive: true });
  const prefix = path.join(imageDir, 'photo');

  try {
    await new Promise((resolve, reject) => {
      const child = spawn(pdfimages, ['-png', filePath, prefix], { windowsHide: true });
      let stderr = '';
      child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
      child.on('error', reject);
      child.on('close', (code) => (code === 0 ? resolve() : reject(new Error(stderr || `pdfimages exited with code ${code}`))));
    });
  } catch (error) {
    return {
      images: [],
      status: `Photo extraction skipped. Install Poppler and set PDFIMAGES_PATH. Detail: ${error.message}`,
    };
  }

  const files = fs.readdirSync(imageDir)
    .filter((file) => /\.(png|jpg|jpeg)$/i.test(file))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
    .map((file) => `/uploads/pdf-images/${path.basename(imageDir)}/${file}`);

  return {
    images: files,
    status: files.length ? `Extracted ${files.length} image(s) from PDF.` : 'No embedded images found in PDF.',
  };
};
const AUTO_FAMILY_MAX_MEMBERS = Math.max(2, Number(process.env.AUTO_FAMILY_MAX_MEMBERS || 15));
const normalizeFamilyHouse = (value) => cleanValue(value)
  .replace(/[०-९]/g, (digit) => String('०१२३४५६७८९'.indexOf(digit)))
  .replace(/\s+/g, '')
  .toLowerCase();
const escapeFamilyRegex = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const rebuildFamiliesForMembers = async (members, userId) => {
  const targets = new Map();
  for (const member of members) {
    const houseNumber = normalizeFamilyHouse(member.houseNumber);
    if (!houseNumber) continue;
    const sectionNumber = cleanValue(member.sectionNumber);
    const sectionName = cleanValue(member.sectionName);
    const section = cleanValue(sectionNumber || sectionName || 'no-section').toLowerCase();
    const groupingKey = `${member.booth || ''}:${section}:${houseNumber}`;
    if (!targets.has(groupingKey)) {
      targets.set(groupingKey, {
        groupingKey,
        booth: member.booth,
        houseNumber,
        rawHouseNumber: cleanValue(member.houseNumber),
        sectionNumber,
        sectionName,
      });
    }
  }

  let rebuilt = 0;
  for (const target of targets.values()) {
    const query = {
      booth: target.booth,
      houseNumber: new RegExp(`^${escapeFamilyRegex(target.rawHouseNumber)}$`, 'i'),
    };
    if (target.sectionNumber) query.sectionNumber = target.sectionNumber;
    else if (target.sectionName) query.sectionName = target.sectionName;
    else query.$or = [
      { sectionNumber: '' },
      { sectionNumber: null },
      { sectionNumber: { $exists: false } },
    ];
    const fullGroup = await Member.find(query);
    if (!fullGroup.length || fullGroup.length > AUTO_FAMILY_MAX_MEMBERS) continue;
    const head = [...fullGroup].sort((a, b) => (Number(b.age) || 0) - (Number(a.age) || 0))[0];
    await Family.findOneAndUpdate(
      { groupingKey: target.groupingKey },
      {
        $set: {
          source: 'auto',
          groupingKey: target.groupingKey,
          familyHead: head._id,
          headName: head.name,
          houseNumber: normalizeFamilyHouse(head.houseNumber),
          sectionNumber: cleanValue(head.sectionNumber),
          sectionName: cleanValue(head.sectionName),
          address: head.address,
          ward: head.ward,
          booth: head.booth,
          members: fullGroup.map((member) => member._id),
          updatedBy: userId,
        },
        $setOnInsert: { createdBy: userId },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true },
    );
    rebuilt += 1;
  }
  return rebuilt;
};
exports.importMembers = async (req, res, next) => {
  const uploadId = progressId(req);
  try {
    setProgress(uploadId, { status: 'processing', stage: 'Reading Excel/CSV file', imported: 0, skipped: 0, processed: 0, total: 0 });
    if (!req.file) return res.status(400).json({ message: 'Excel/CSV file required' });
    const workbook = XLSX.readFile(req.file.path);
    const rows = XLSX.utils.sheet_to_json(workbook.Sheets[workbook.SheetNames[0]]);
    setProgress(uploadId, { stage: 'Importing voter rows', total: rows.length });
    if (!rows.length) return res.status(400).json({ message: 'Excel/CSV file has no voter rows.' });
    const firstMember = cleanImportData(normalize(rows[0]));
    const { ward, booth } = await getOrCreateImportScope({
      user: req.currentUser,
      body: req.body,
      firstMember,
    });
    if (!ward || !booth) {
      return res.status(400).json({
        message: 'Excel se Vidhan Sabha/Part detect nahi hua. AC No aur Part No columns rakhein, ya ward/booth select karein.',
      });
    }
    assertBoothAccess(req.currentUser, booth);
    assertWardAccess(req.currentUser, ward);

    const affected = [];
    const skipped = [];
    let createdCount = 0;
    let updatedCount = 0;
    let processed = 0;
    const sourceType = req.file.mimetype === 'text/csv' ? 'csv' : 'excel';
    const sourceFile = `/uploads/${req.file.filename}`;
    for (const row of rows) {
      const data = cleanImportData(normalize(row));
      data.assemblyNumber ||= firstMember.assemblyNumber;
      data.assemblyName ||= firstMember.assemblyName;
      data.partNumber ||= firstMember.partNumber;
      data.voterId = normalizeEpic(data.voterId);
      if (data.relationType) {
        const relation = String(data.relationType).trim().toLowerCase();
        data.relationType = ({
          f: 'father', father: 'father',
          h: 'husband', husband: 'husband',
          m: 'mother', mother: 'mother',
        })[relation] || 'other';
      }
      if (!data.name) {
        skipped.push({ row, reason: 'Name missing' });
        processed += 1;
        setProgress(uploadId, { processed, imported: affected.length, skipped: skipped.length });
        continue;
      }
      if (!isValidEpic(data.voterId)) {
        skipped.push({ row, reason: 'Valid EPIC number required' });
        processed += 1;
        setProgress(uploadId, { processed, imported: affected.length, skipped: skipped.length });
        continue;
      }
      data.area = await ensureAreaHierarchy(data, req.currentUser._id);
      const existing = await Member.findOne({ voterId: data.voterId });
      if (existing) {
        const preservedEpic = existing.voterId;
        const extraDetails = mergeExtraDetails(existing.extraDetails, data.extraDetails);
        Object.assign(existing, {
          ...data,
          voterId: preservedEpic,
          extraDetails,
          booth,
          ward,
          updatedBy: req.currentUser._id,
          sourceDocument: {
            ...(existing.sourceDocument?.toObject?.() || existing.sourceDocument || {}),
            type: sourceType,
            file: sourceFile,
          },
        });
        await existing.save();
        affected.push(existing);
        updatedCount += 1;
        processed += 1;
        setProgress(uploadId, { processed, imported: affected.length, skipped: skipped.length });
        continue;
      }
      const mobileDuplicates = data.mobile
        ? await Member.find({ mobile: data.mobile }).select('_id mobile voterId')
        : [];
      const member = await Member.create({
        ...data,
        booth,
        ward,
        createdBy: req.currentUser._id,
        updatedBy: req.currentUser._id,
        sourceDocument: { type: sourceType, file: sourceFile },
        verificationStatus: mobileDuplicates.length ? 'duplicate' : 'pending',
        duplicateWarnings: mobileDuplicates.map((duplicate) => ({
          field: 'mobile',
          member: duplicate._id,
          value: data.mobile,
        })),
      });
      affected.push(member);
      createdCount += 1;
      processed += 1;
      setProgress(uploadId, { processed, imported: affected.length, skipped: skipped.length });
    }
    setProgress(uploadId, { stage: 'Building family records', processed, imported: affected.length, skipped: skipped.length });
    const families = await rebuildFamiliesForMembers(affected, req.currentUser._id);
    finishProgressSoon(uploadId, { status: 'completed', stage: 'Import complete', processed, total: rows.length, imported: affected.length, skipped: skipped.length });
    res.json({ imported: affected.length, created: createdCount, updated: updatedCount, skipped, reviewRequired: 0, families, importedIds: affected.map((member) => member._id) });
  } catch (e) {
    finishProgressSoon(uploadId, {
      status: 'failed',
      stage: e.message || 'Excel/CSV import failed',
    });
    next(e);
  }
};

exports.importPdfMembers = async (req, res, next) => {
  const uploadId = progressId(req);
  try {
    setProgress(uploadId, { status: 'processing', stage: 'Reading PDF/OCR text', imported: 0, skipped: 0, processed: 0, total: 0 });
    if (!req.file) return res.status(400).json({ message: 'PDF file required' });
    assertReadablePdf(req.file.path);
    let parsed = await parsePdfMembers(req.file.path, req.file.filename);
    setProgress(uploadId, { stage: 'PDF records detected', total: parsed.members.length, processed: 0 });
    if (
      req.currentUser.role === 'admin'
      && !req.body.ward
      && !parsed.members[0]?.assemblyNumber
      && !parsed.ocr
    ) {
      const ocr = await ocrPdf(req.file.path, req.file.filename);
      parsed = {
        text: ocr.text,
        members: parseHindiVoterRoll(ocr.text),
        ocr,
      };
    }
    const shouldExtractImages = String(process.env.EXTRACT_PDF_IMAGES || '').toLowerCase() === 'true';
    const extractedImages = parsed.ocr?.images?.length
      ? { images: parsed.ocr.images, status: parsed.ocr.status }
      : shouldExtractImages
        ? await extractPdfImages(req.file.path, req.file.filename)
        : { images: [], status: 'Photo extraction skipped for faster import. Set EXTRACT_PDF_IMAGES=true to enable it.' };
    const detectedHeader = parseHeader(parsed.text);
    const firstMemberWithHeader = {
      ...detectedHeader,
      ...(parsed.members[0] || {}),
    };
    const { ward, booth } = await getOrCreateImportScope({
      user: req.currentUser,
      body: req.body,
      firstMember: firstMemberWithHeader,
    });
    if (!booth || !ward) return res.status(400).json({ message: 'PDF se ward/booth detect nahi hua. Text-based voter PDF upload karein ya manual ward/booth select karein.' });
    assertBoothAccess(req.currentUser, booth);
    assertWardAccess(req.currentUser, ward);
    const assemblyArea = await ensureAreaHierarchy(firstMemberWithHeader, req.currentUser._id);
    const created = [];
    const skipped = [];
    let processed = 0;
    const party = await findPartyFromText(parsed.text);
    for (const item of parsed.members) {
      item.voterId = normalizeEpic(item.voterId);
      if (!item.name) {
        const review = await ImportReview.create({
          sourceType: 'pdf',
          sourceFile: req.file.filename,
          reason: 'Name missing or unreadable',
          suggestedData: item,
          ward,
          booth,
          createdBy: req.currentUser._id,
        });
        skipped.push({ item, reason: 'Name missing or unreadable', reviewId: review._id });
        processed += 1;
        setProgress(uploadId, { processed, imported: created.length, skipped: skipped.length });
        continue;
      }
      if (!isValidEpic(item.voterId)) {
        const review = await ImportReview.create({
          sourceType: 'pdf',
          sourceFile: req.file.filename,
          reason: 'EPIC missing or invalid',
          suggestedData: { ...item, voterId: item.voterId || '' },
          ward,
          booth,
          createdBy: req.currentUser._id,
        });
        skipped.push({ item, reason: 'EPIC missing or invalid', reviewId: review._id });
        processed += 1;
        setProgress(uploadId, { processed, imported: created.length, skipped: skipped.length });
        continue;
      }
      const itemArea = await enrichPdfAreaHierarchy(item, assemblyArea);
      const existing = await Member.findOne({ voterId: item.voterId });
      if (existing) {
        // PDF/OCR is authoritative for roll-specific fields, but it must not
        // erase structured Excel enrichment such as mobile and village data.
        assignNonEmptyFields(existing, item, [
          'photo',
          'voterSerial',
          'houseNumber',
          'assemblyNumber',
          'assemblyName',
          'partNumber',
          'sectionNumber',
          'sectionName',
        ]);
        assignNonEmptyFields(existing, item, [
          'name',
          'surname',
          'guardianName',
          'relationType',
          'age',
          'estimatedDob',
          'gender',
          'address',
          'location',
        ].filter((field) => (
          existing[field] === undefined
          || existing[field] === null
          || String(existing[field]).trim() === ''
        )));
        existing.booth = booth;
        existing.ward = ward;
        existing.area = item.village ? itemArea : (existing.area || assemblyArea);
        assignNonEmptyFields(existing, item, ['tehsil', 'gramPanchayat', 'village']);
        if (!existing.party && party?._id) existing.party = party._id;
        existing.updatedBy = req.currentUser._id;
        existing.sourceDocument = {
          type: 'pdf',
          file: `/uploads/${req.file.filename}`,
          rawText: item.rawText || parsed.text.slice(0, 1000),
          imageExtractionStatus: extractedImages.status,
        };
        await existing.save();
        created.push(existing);
        processed += 1;
        setProgress(uploadId, { processed, imported: created.length, skipped: skipped.length });
        continue;
      }
      const duplicates = [];
      const member = await Member.create({
        photo: item.photo || '',
        name: item.name,
        surname: item.surname,
        mobile: item.mobile,
        age: item.age,
        estimatedDob: item.estimatedDob,
        gender: item.gender,
        voterSerial: item.voterSerial,
        voterId: item.voterId,
        guardianName: item.guardianName,
        relationType: item.relationType,
        houseNumber: item.houseNumber,
        assemblyNumber: item.assemblyNumber,
        assemblyName: item.assemblyName,
        partNumber: item.partNumber,
        sectionNumber: item.sectionNumber,
        sectionName: item.sectionName,
        address: item.address,
        location: item.location,
        booth,
        ward,
        area: itemArea,
        tehsil: item.tehsil,
        gramPanchayat: item.gramPanchayat,
        village: item.village,
        party: party?._id,
        createdBy: req.currentUser._id,
        updatedBy: req.currentUser._id,
        verificationStatus: duplicates.length ? 'duplicate' : 'pending',
        duplicateWarnings: duplicates.map((d) => ({
          field: d.voterId === item.voterId ? 'voterId' : d.mobile === item.mobile ? 'mobile' : 'address',
          member: d._id,
          value: d.voterId === item.voterId ? item.voterId : d.mobile === item.mobile ? item.mobile : item.address,
        })),
        sourceDocument: {
          type: 'pdf',
          file: `/uploads/${req.file.filename}`,
          rawText: item.rawText || parsed.text.slice(0, 1000),
          imageExtractionStatus: extractedImages.status,
        },
      });
      created.push(member);
      processed += 1;
      setProgress(uploadId, { processed, imported: created.length, skipped: skipped.length });
    }
    setProgress(uploadId, {
      stage: 'Building family records',
      processed,
      imported: created.length,
      skipped: skipped.length,
    });
    const families = await rebuildFamiliesForMembers(created, req.currentUser._id);
    finishProgressSoon(uploadId, {
      status: 'completed',
      stage: 'Import complete',
      processed,
      total: parsed.members.length,
      imported: created.length,
      skipped: skipped.length,
    });
    res.json({
      imported: created.length,
      reviewRequired: skipped.filter((entry) => entry.reviewId).length,
      skipped,
      families,
      imageExtractionStatus: extractedImages.status,
      extractedImages: extractedImages.images.length,
      extractedTextPreview: parsed.text.slice(0, 1500),
      extractionMode: parsed.ocr ? 'ocr-coordinate' : 'text-embedded',
      importedIds: created.map((member) => member._id),
    });
  } catch (e) {
    finishProgressSoon(uploadId, {
      status: 'failed',
      stage: e.message || 'PDF import failed',
    });
    next(e);
  }
};































