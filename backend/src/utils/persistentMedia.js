const fs = require('fs');
const path = require('path');
const MediaAsset = require('../models/MediaAsset');
const { resolveUploadPublicPath } = require('./uploadPath');

const contentTypes = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
};

const persistLocalImage = async (filePath, userId, removeOriginal = false) => {
  const original = String(filePath || '');
  const source = /^[/\\]?uploads[/\\]/i.test(original)
    ? resolveUploadPublicPath(original)
    : original;
  if (!source || !fs.existsSync(source)) return source;
  const stat = fs.statSync(source);
  if (!stat.isFile() || stat.size < 1 || stat.size > 5 * 1024 * 1024) {
    throw new Error('Photo must be a non-empty image smaller than 5 MB.');
  }
  const extension = path.extname(source).toLowerCase();
  const asset = await MediaAsset.create({
    data: fs.readFileSync(source),
    contentType: contentTypes[extension] || 'image/jpeg',
    filename: path.basename(source),
    createdBy: userId,
  });
  if (removeOriginal) fs.rmSync(source, { force: true });
  return '/media/' + asset._id;
};

module.exports = { persistLocalImage };
