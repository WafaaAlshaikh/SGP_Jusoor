// routes/adminRoutes.js
const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { adminMiddleware,
  requirePermission,
  checkContentPermission,
  requireAdminLevel,
  preventSelfModification,
  auditAdminRequests } = require('../middleware/adminMiddleware');

// 👤 Public Content (for regular users) - MUST be before adminMiddleware
router.get('/public/help-sections', adminController.getHelpSections);
router.get('/public/about-content', adminController.getAboutContent);

// Apply admin middleware to all admin-protected routes
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

// Content Moderation
router.post('/moderate/remove', requirePermission('can_manage_users'), adminController.removeContent);

// Audit Logs
router.get('/audit-logs', requirePermission('can_view_statistics'), adminController.getAuditLogs);


// App Content Management
router.get('/content', 
  checkContentPermission('view'),
  auditAdminRequests('content_list'),
  adminController.getAllContent
);

router.get('/content/:content_id',
  checkContentPermission('view'),
  auditAdminRequests('content_view'),
  adminController.getContentDetails
);

router.post('/content',
  checkContentPermission('create'),
  auditAdminRequests('content_create'),
  adminController.createContent
);

router.put('/content/:content_id',
  checkContentPermission('edit'),
  auditAdminRequests('content_update'),
  adminController.updateContent
);

router.delete('/content/:content_id',
  checkContentPermission('delete'),
  auditAdminRequests('content_delete'),
  requireAdminLevel('super_admin', 'admin'), // فقط super_admin و admin يمكنهم الحذف
  adminController.deleteContent
);

router.post('/content/reorder',
  checkContentPermission('reorder'),
  auditAdminRequests('content_reorder'),
  adminController.reorderContent
);

// 📊 Content Statistics
router.get('/content/statistics',
  checkContentPermission('view'),
  adminController.getContentStatistics
);

// 📋 Batch Operations
router.post('/content/batch-update',
  checkContentPermission('edit'),
  requireAdminLevel('super_admin', 'admin'),
  adminController.batchUpdateContentStatus
);

router.post('/content/import',
  adminMiddleware,
  checkContentPermission('create'),
  requireAdminLevel('super_admin'),
  adminController.importContent
);

router.get('/content/export',
  adminMiddleware,
  checkContentPermission('view'),
  adminController.exportContent
);
module.exports = router;