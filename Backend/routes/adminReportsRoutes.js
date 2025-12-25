const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const adminMiddleware = require('../middleware/adminMiddleware');
const reportsController = require('../controllers/reportsController');

router.use(authMiddleware);
router.use(adminMiddleware);

router.get('/', reportsController.listAllReportsForAdmin);
router.get('/:id', reportsController.getReportDetails);
router.post('/:id/messages', reportsController.addMessage);
router.put('/:id', reportsController.adminUpdateReport);

module.exports = router;
