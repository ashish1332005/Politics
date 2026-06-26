const Area = require('../models/Area');
const Member = require('../models/Member');

exports.list = async (req, res, next) => {
  try {
    const filter = { active: true };
    if (req.query.parent === 'root') filter.parent = null;
    else if (req.query.parent) filter.parent = req.query.parent;
    if (req.query.type) filter.type = req.query.type;
    res.json(await Area.find(filter).populate('parent', 'name type').sort({ name: 1 }));
  } catch (error) { next(error); }
};

exports.tree = async (req, res, next) => {
  try {
    const areas = await Area.find({ active: true }).sort({ name: 1 }).lean();
    const directCounts = await Member.aggregate([
      { $match: { area: { $ne: null } } },
      { $group: { _id: '$area', count: { $sum: 1 } } },
    ]);
    const counts = new Map(directCounts.map((item) => [String(item._id), item.count]));
    const grouped = new Map();
    for (const area of areas) {
      area.voterCount = counts.get(String(area._id)) || 0;
      const key = String(area.parent || 'root');
      if (!grouped.has(key)) grouped.set(key, []);
      grouped.get(key).push(area);
    }
    const build = (parent = 'root') => (grouped.get(parent) || []).map((area) => {
      const children = build(String(area._id));
      area.voterCount += children.reduce((sum, child) => sum + child.voterCount, 0);
      return { ...area, children };
    });
    res.json(build());
  } catch (error) { next(error); }
};

exports.create = async (req, res, next) => {
  try {
    res.status(201).json(await Area.create({ ...req.body, createdBy: req.currentUser._id }));
  } catch (error) { next(error); }
};

exports.update = async (req, res, next) => {
  try {
    res.json(await Area.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true }));
  } catch (error) { next(error); }
};

exports.removeAll = async (req, res, next) => {
  try {
    const result = await Area.updateMany({ active: true }, { active: false });
    res.json({ message: 'All areas removed', deletedCount: result.modifiedCount });
  } catch (error) { next(error); }
};
exports.remove = async (req, res, next) => {
  try {
    if (await Area.exists({ parent: req.params.id, active: true })) {
      return res.status(400).json({ message: 'पहले इसके अंदर के क्षेत्र हटाएँ या स्थानांतरित करें।' });
    }
    await Area.findByIdAndUpdate(req.params.id, { active: false });
    res.json({ message: 'Area removed' });
  } catch (error) { next(error); }
};

