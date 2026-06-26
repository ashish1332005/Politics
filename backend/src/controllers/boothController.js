const Booth = require('../models/Booth');
const Ward = require('../models/Ward');

const isObjectId = (value) => /^[a-f\d]{24}$/i.test(String(value || ''));

const resolveWard = async (value) => {
  if (!value || isObjectId(value)) return value;
  const text = String(value).trim();
  const ward = await Ward.findOne({
    $or: [
      { number: text },
      { name: new RegExp(`^${text}$`, 'i') },
    ],
  });
  return ward?._id;
};

exports.list = async (req, res, next) => {
  try {
    const filter = req.currentUser.role === 'booth' ? { _id: req.currentUser.assignedBooth?._id } : {};
    res.json(await Booth.find(filter).populate('ward').sort({ number: 1 }));
  } catch (e) { next(e); }
};
exports.create = async (req, res, next) => {
  try {
    const data = { ...req.body, ward: await resolveWard(req.body.ward) };
    if (!data.ward) return res.status(400).json({ message: 'Valid ward is required. Use ward number, ward name, or ward ID.' });
    res.status(201).json(await Booth.create(data));
  } catch (e) { next(e); }
};
exports.update = async (req, res, next) => {
  try {
    const data = { ...req.body };
    if (data.ward) data.ward = await resolveWard(data.ward);
    if (req.body.ward && !data.ward) return res.status(400).json({ message: 'Valid ward is required. Use ward number, ward name, or ward ID.' });
    res.json(await Booth.findByIdAndUpdate(req.params.id, data, { new: true }).populate('ward'));
  } catch (e) { next(e); }
};
exports.remove = async (req, res, next) => {
  try { await Booth.findByIdAndDelete(req.params.id); res.json({ message: 'Deleted' }); } catch (e) { next(e); }
};
