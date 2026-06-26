const Ward = require('../models/Ward');

exports.list = async (req, res, next) => {
  try { res.json(await Ward.find().populate('wardHead').sort({ number: 1 })); } catch (e) { next(e); }
};
exports.create = async (req, res, next) => {
  try { res.status(201).json(await Ward.create(req.body)); } catch (e) { next(e); }
};
exports.update = async (req, res, next) => {
  try { res.json(await Ward.findByIdAndUpdate(req.params.id, req.body, { new: true }).populate('wardHead')); } catch (e) { next(e); }
};
exports.remove = async (req, res, next) => {
  try { await Ward.findByIdAndDelete(req.params.id); res.json({ message: 'Deleted' }); } catch (e) { next(e); }
};
