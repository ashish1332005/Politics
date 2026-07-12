const router = require('express').Router();
const auth = require('../middleware/auth');
const express = require('express');
const upload = require('../middleware/upload');
const c = require('../controllers/importController');

router.get('/status/:uploadId', auth, c.importStatus);
router.put('/members/pdf/chunks/:uploadId/:index', auth,
  express.raw({ type: 'application/octet-stream', limit: '2mb' }), c.uploadPdfChunk);
router.post('/members/pdf/chunks/:uploadId/complete', auth, c.completePdfChunks);
router.post('/members', auth, c.trackUploadProgress, upload.single('file'), c.importMembers);
router.post('/members/pdf', auth, c.trackUploadProgress, upload.single('file'), c.importPdfMembers);

module.exports = router;


