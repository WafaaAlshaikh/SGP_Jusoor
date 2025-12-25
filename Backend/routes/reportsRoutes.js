const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const reportsController = require('../controllers/reportsController');

router.use(authMiddleware);

router.post('/', reportsController.createReport);
router.get('/', reportsController.listMyReports);
router.get('/:id', reportsController.getReportDetails);
router.post('/:id/messages', reportsController.addMessage);

module.exports = router;
