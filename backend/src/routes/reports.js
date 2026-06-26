const router = require('express').Router();
const auth = require('../middleware/auth');
const c = require('../controllers/reportController');

router.get('/dashboard', auth, c.dashboard);

module.exports = router;
