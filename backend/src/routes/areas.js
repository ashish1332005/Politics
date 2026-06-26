const router = require('express').Router();
const auth = require('../middleware/auth');
const role = require('../middleware/role');
const controller = require('../controllers/areaController');

router.use(auth);
router.get('/', controller.list);
router.get('/tree', controller.tree);
router.post('/', role('admin'), controller.create);
router.delete('/all', role('admin'), controller.removeAll);
router.put('/:id', role('admin'), controller.update);
router.delete('/:id', role('admin'), controller.remove);

module.exports = router;

