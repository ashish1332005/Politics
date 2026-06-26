const router = require('express').Router();
const auth = require('../middleware/auth');
const upload = require('../middleware/upload');
const c = require('../controllers/importController');

router.get('/status/:uploadId', auth, c.importStatus);
router.post('/members', auth, c.trackUploadProgress, upload.single('file'), c.importMembers);
router.post('/members/pdf', auth, c.trackUploadProgress, upload.single('file'), c.importPdfMembers);

module.exports = router;


