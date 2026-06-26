const router = require('express').Router();
const auth = require('../middleware/auth');
const controller = require('../controllers/printController');

router.get('/members.pdf', auth, controller.printMembers);

module.exports = router;

