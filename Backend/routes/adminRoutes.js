const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');
const adminMiddleware = require('../middleware/adminMiddleware');

router.use(authMiddleware);
router.use(adminMiddleware);

router.get('/dashboard', adminController.getDashboardStats);

router.get('/institutions', adminController.getInstitutions);
router.get('/institutions/pending', adminController.getPendingInstitutions);
router.post('/institutions/:id/approve', adminController.approveInstitution);
router.post('/institutions/:id/reject', adminController.rejectInstitution);

router.get('/users', adminController.getUsers);
router.get('/users/pending', adminController.getPendingUsers);
router.post('/users/:id/approve', adminController.approveUser);

router.get('/system/health', adminController.getSystemHealth);

module.exports = router;