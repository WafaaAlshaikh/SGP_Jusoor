const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const authorizeManager = require('../middleware/managerAuth');
const reportsController = require('../controllers/reportsController');

router.use(authMiddleware);
router.use(authorizeManager);

router.get('/', reportsController.listInstitutionReportsForManager);
router.post('/', reportsController.managerCreateReport);
router.get('/:id', reportsController.getReportDetails);
router.post('/:id/messages', reportsController.addMessage);

module.exports = router;
