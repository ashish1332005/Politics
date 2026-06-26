const fs = require('fs');
const path = require('path');
const multer = require('multer');

const uploadRoot = path.join(__dirname, '../../', process.env.UPLOAD_PATH || 'uploads');
fs.mkdirSync(uploadRoot, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadRoot),
  filename: (req, file, cb) => {
    const originalName = String(file?.originalname || file?.filename || 'upload');
    const safeName = originalName.replace(/[^a-z0-9.]/gi, '-').toLowerCase();
    cb(null, `${Date.now()}-${safeName}`);
  },
});

module.exports = multer({
  storage,
  limits: {
    fileSize: Number(process.env.MAX_UPLOAD_MB || 250) * 1024 * 1024,
    files: 1,
  },
  fileFilter: (req, file, cb) => {
    const originalName = String(file?.originalname || file?.filename || '');
    const allowed = /\.(pdf|xlsx|xls|csv)$/i.test(originalName);
    if (!allowed) {
      const error = new Error('Only PDF, Excel and CSV files are allowed.');
      error.status = 400;
      return cb(error);
    }
    cb(null, true);
  },
});

