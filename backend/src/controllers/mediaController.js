const mongoose = require('mongoose');
const MediaAsset = require('../models/MediaAsset');

exports.get = async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).end();
    }
    const asset = await MediaAsset.findById(req.params.id).select('+data').lean();
    if (!asset?.data) return res.status(404).end();
    res.set({
      'Content-Type': asset.contentType || 'image/jpeg',
      'Content-Length': asset.data.length,
      'Cache-Control': 'public, max-age=31536000, immutable',
      'X-Content-Type-Options': 'nosniff',
    });
    return res.send(asset.data);
  } catch (error) {
    return next(error);
  }
};
