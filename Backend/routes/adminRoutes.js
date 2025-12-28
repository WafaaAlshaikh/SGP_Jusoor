// routes/adminRoutes.js
const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { adminMiddleware, requirePermission } = require('../middleware/adminMiddleware');

// Apply admin middleware to all routes
router.use(adminMiddleware);

// 📊 Dashboard
router.get('/dashboard', adminController.getDashboardStats);
router.get('/detailed-stats', requirePermission('can_view_statistics'), adminController.getDetailedStats);
router.get('/analytics/overview', requirePermission('can_view_statistics'), adminController.getAnalyticsOverview);

router.get('/institutions/analytics/overview', requirePermission('can_view_statistics'), adminController.getInstitutionsAnalyticsOverview);
router.get('/institutions/analytics/top', requirePermission('can_view_statistics'), adminController.getInstitutionsAnalyticsTop);
router.get('/institutions/analytics/history', requirePermission('can_view_statistics'), adminController.getInstitutionsAnalyticsHistory);

// 🏢 Institution Management
router.get('/institutions/pending', requirePermission('can_manage_institutions'), adminController.getPendingInstitutions);
router.get('/institutions', requirePermission('can_manage_institutions'), adminController.getAllInstitutions);
router.post('/institutions', requirePermission('can_manage_institutions'), adminController.createInstitution);
router.get('/institutions/:institution_id', requirePermission('can_manage_institutions'), adminController.getInstitutionDetails);
router.put('/institutions/:institution_id', requirePermission('can_manage_institutions'), adminController.updateInstitution);
router.delete('/institutions/:institution_id', requirePermission('can_manage_institutions'), adminController.deleteInstitution);
router.post('/institutions/:institution_id/approve', requirePermission('can_manage_institutions'), adminController.approveInstitution);
router.post('/institutions/:institution_id/reject', requirePermission('can_manage_institutions'), adminController.rejectInstitution);
router.post('/institutions/:institution_id/suspend', requirePermission('can_manage_institutions'), adminController.suspendInstitution);

// 👥 User Management
router.get('/users/pending', requirePermission('can_manage_users'), adminController.getPendingUsers);
router.get('/users', requirePermission('can_manage_users'), adminController.getAllUsers);
router.get('/users/:user_id', requirePermission('can_manage_users'), adminController.getUserDetails);
router.put('/users/:user_id/status', requirePermission('can_manage_users'), adminController.updateUserStatus);
router.delete('/users/:user_id', requirePermission('can_manage_users'), adminController.deleteUser);
router.post('/users/:user_id/approve', requirePermission('can_manage_users'), adminController.approveUser);
router.post('/users/:user_id/suspend', requirePermission('can_manage_users'), adminController.suspendUser);

// 📋 Report Management
router.get('/reports', requirePermission('can_manage_reports'), adminController.getAllReports);
router.put('/reports/:report_id/status', requirePermission('can_manage_reports'), adminController.updateReportStatus);

// 💰 Donation Management
router.get('/donations', requirePermission('can_manage_donations'), adminController.getAllDonations);

// ⚙️ System Settings
router.get('/system/health', adminController.getSystemHealth);
router.get('/settings', requirePermission('can_manage_settings'), adminController.getSettings);
router.put('/settings/:setting_id', requirePermission('can_manage_settings'), adminController.updateSetting);

// 🗑️ Content Moderation
router.post('/moderate/remove', requirePermission('can_manage_users'), adminController.removeContent);

// 📜 Audit Logs
router.get('/audit-logs', requirePermission('can_view_statistics'), adminController.getAuditLogs);

module.exports = router;