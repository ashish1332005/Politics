const QRCode = require('qrcode');
const Member = require('../models/Member');
const Family = require('../models/Family');
const { applyMemberScope, assertBoothAccess, assertWardAccess } = require('../utils/boothAccess');
const { writeActivity } = require('../middleware/activityLogger');
const { requireValidEpic } = require('../utils/epic');
const { syncMemberFamily, removeMemberFromFamilies } = require('../utils/familySync');

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

exports.create = async (req, res, next) => {
  try {
    const data = { ...req.body };
    data.voterId = requireValidEpic(data.voterId);
    if (req.file) data.photo = `/uploads/${req.file.filename}`;
    if (req.currentUser.role === 'booth') data.booth = req.currentUser.assignedBooth?._id || req.currentUser.assignedBooth;
    if (req.currentUser.role === 'ward_head') data.ward = req.currentUser.assignedWard?._id || req.currentUser.assignedWard;
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
    const { q, party, supportLevel, gender, booth, ward, area, verificationStatus, location, village, gramPanchayat, tehsil, municipality, caste, organizationPost, sectionNumber, sectionName, assemblyNumber, assemblyName, partNumber } = req.query;
    const limit = Math.min(Number(req.query.limit) || 100, 500);
    const page = Math.max(Number(req.query.page) || 1, 1);
    const paged = String(req.query.paged || '').toLowerCase() === 'true' || req.query.page !== undefined;
    const filter = applyMemberScope(req.currentUser, {});
    if (q) filter.$or = [
      { name: new RegExp(q, 'i') },
      { surname: new RegExp(q, 'i') },
      { mobile: new RegExp(q, 'i') },
      { voterId: new RegExp(q, 'i') },
      { guardianName: new RegExp(q, 'i') },
      { houseNumber: new RegExp(q, 'i') },
      { address: new RegExp(q, 'i') },
      { location: new RegExp(q, 'i') },
      { village: new RegExp(q, 'i') },
      { gramPanchayat: new RegExp(q, 'i') },
      { tehsil: new RegExp(q, 'i') },
      { caste: new RegExp(q, 'i') },
      { organizationPost: new RegExp(q, 'i') },
      { sectionName: new RegExp(q, 'i') },
      { assemblyName: new RegExp(q, 'i') },
      { partNumber: new RegExp(q, 'i') },
    ];
    if (party) filter.party = party;
    if (supportLevel) filter.supportLevel = supportLevel;
    if (gender) filter.gender = gender;
    if (ward) filter.ward = ward;
    if (area) filter.area = area;
    if (location) filter.location = new RegExp(location, 'i');
    if (village) filter.village = new RegExp(village, 'i');
    if (gramPanchayat) filter.gramPanchayat = new RegExp(gramPanchayat, 'i');
    if (tehsil) filter.tehsil = new RegExp(tehsil, 'i');
    if (municipality) filter.municipality = new RegExp(municipality, 'i');
    if (caste) filter.caste = new RegExp(caste, 'i');
    if (organizationPost) filter.organizationPost = new RegExp(organizationPost, 'i');
    if (sectionNumber) filter.sectionNumber = new RegExp(`^${String(sectionNumber).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i');
    if (sectionName) filter.sectionName = new RegExp(sectionName, 'i');
    if (assemblyNumber) filter.assemblyNumber = assemblyNumber;
    if (assemblyName) filter.assemblyName = new RegExp(assemblyName, 'i');
    if (partNumber) filter.partNumber = partNumber;
    if (verificationStatus) filter.verificationStatus = verificationStatus;
    if (req.query.missingMobile === 'true') filter.$and = [...(filter.$and || []), { $or: [{ mobile: '' }, { mobile: null }, { mobile: { $exists: false } }] }];
    if (req.query.missingHouse === 'true') filter.$and = [...(filter.$and || []), { $or: [{ houseNumber: '' }, { houseNumber: null }, { houseNumber: { $exists: false } }] }];
    if (booth && req.currentUser.role === 'admin') filter.booth = booth;
    const members = await Member.find(filter)
      .select('photo name surname mobile altMobile voterId guardianName houseNumber address location area tehsil gramPanchayat village municipality caste subCaste organizationPost organizationLevel influenceLevel occupation education extraDetails supportLevel ward booth updatedAt age gender sectionNumber sectionName assemblyNumber assemblyName partNumber')
      .populate(populate)
      .sort({ updatedAt: -1 })
      .skip(paged ? (page - 1) * limit : 0)
      .limit(limit)
      .lean();
    const items = members.map((member) => maskMemberMobile(member, req.currentUser));
    if (!paged) return res.json(items);
    const total = await Member.countDocuments(filter);
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
    if (updates.voterId && requireValidEpic(updates.voterId) !== member.voterId) {
      return res.status(409).json({ message: 'EPIC नंबर स्थायी है और बदला नहीं जा सकता।' });
    }
    delete updates.voterId;
    Object.assign(member, updates);
    if (req.file) member.photo = `/uploads/${req.file.filename}`;
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













