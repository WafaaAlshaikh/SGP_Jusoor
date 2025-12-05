const express = require('express');
const router = express.Router();
const specialistStatsController = require('../../controllers/manager/specialistStatsController');
const authMiddleware = require('../../middleware/authMiddleware');

// التحقق من أن المستخدم مدير
const managerOnly = (req, res, next) => {
  if (req.user.role !== 'Manager') {
    return res.status(403).json({
      success: false,
      message: 'Access denied. Manager role required.'
    });
  }
  next();
};

// تطبيق middleware المصادقة والتحقق من المدير
router.use(authMiddleware);
router.use(managerOnly);

// ==================== وظائف الإحصائيات الحالية ====================

/**
 * @route   GET /api/manager/stats/by-session-type
 * @desc    Get specialists count by session type
 * @access  Private/Manager
 */
router.get('/stats/by-session-type', specialistStatsController.getSpecialistsBySessionType);

/**
 * @route   GET /api/manager/stats/active-count
 * @desc    Get active specialists count
 * @access  Private/Manager
 */
router.get('/stats/active-count', specialistStatsController.getActiveSpecialistsCount);

/**
 * @route   GET /api/manager/stats/vacations
 * @desc    Get vacation statistics
 * @access  Private/Manager
 */
router.get('/stats/vacations', specialistStatsController.getVacationStatistics);

/**
 * @route   GET /api/manager/stats/average-sessions
 * @desc    Get average sessions per day
 * @access  Private/Manager
 */
router.get('/stats/average-sessions', specialistStatsController.getAverageSessionsPerDay);

/**
 * @route   GET /api/manager/stats/comprehensive
 * @desc    Get all specialist statistics (comprehensive)
 * @access  Private/Manager
 */
router.get('/stats/comprehensive', specialistStatsController.getComprehensiveStatistics);

// ==================== وظائف إدارة الأخصائيين الجديدة ====================

/**
 * @route   POST /api/manager/specialists
 * @desc    Add new specialist
 * @access  Private/Manager
 */
router.post('/specialists', specialistStatsController.addSpecialist);


router.get('/session-types', specialistStatsController.getAllSessionTypes);

/**
 * @route   POST /api/manager/session-types
 * @desc    Add new session type
 * @access  Private/Manager
 */
router.post('/session-types', specialistStatsController.addSessionType);

/**
 * @route   GET /api/manager/specialists/schedules
 * @desc    Get all specialists schedules
 * @access  Private/Manager
 */
router.get('/specialists/schedules', specialistStatsController.getAllSpecialistsSchedules);

/**
 * @route   GET /api/manager/specialists/:id/schedule
 * @desc    Get specialist schedule by ID
 * @access  Private/Manager
 */
router.get('/specialists/:id/schedule', specialistStatsController.getSpecialistSchedule);

/**
 * @route   POST /api/manager/specialists/:id/schedule
 * @desc    Add schedule for specialist
 * @access  Private/Manager
 */
router.post('/specialists/:id/schedule', specialistStatsController.addSpecialistSchedule);

/**
 * @route   POST /api/manager/specialists/:id/schedules/bulk
 * @desc    Add multiple schedules for specialist
 * @access  Private/Manager
 */
router.post('/specialists/:id/schedules/bulk', specialistStatsController.addMultipleSchedules);

/**
 * @route   PUT /api/manager/schedules/:scheduleId
 * @desc    Update specialist schedule
 * @access  Private/Manager
 */
router.put('/schedules/:scheduleId', specialistStatsController.updateSpecialistSchedule);

/**
 * @route   DELETE /api/manager/schedules/:scheduleId
 * @desc    Delete specialist schedule
 * @access  Private/Manager
 */
router.delete('/schedules/:scheduleId', specialistStatsController.deleteSpecialistSchedule);

// ==================== وظائف إدارة طلبات الإجازات ====================

/**
 * @route   GET /api/manager/vacation-requests
 * @desc    Get all vacation requests for institution
 * @access  Private/Manager
 */
router.get('/vacation-requests', specialistStatsController.getVacationRequests);

/**
 * @route   GET /api/manager/vacation-requests/:requestId
 * @desc    Get vacation request details
 * @access  Private/Manager
 */
router.get('/vacation-requests/:requestId', specialistStatsController.getVacationRequestDetails);

/**
 * @route   PUT /api/manager/vacation-requests/:requestId/status
 * @desc    Update vacation request status
 * @access  Private/Manager
 */
router.put('/vacation-requests/:requestId/status', specialistStatsController.updateVacationRequestStatus);

// ==================== وظائف إدارة أنواع الجلسات ====================

/**
 * @route   GET /api/manager/session-types/pending
 * @desc    Get pending session types
 * @access  Private/Manager
 */
router.get('/session-types/pending', specialistStatsController.getPendingSessionTypes);

/**
 * @route   PUT /api/manager/session-types/:sessionTypeId/approval
 * @desc    Update session type approval
 * @access  Private/Manager
 */
router.put('/session-types/:sessionTypeId/approval', specialistStatsController.updateSessionTypeApproval);

/**
 * @route   PUT /api/manager/session-types/:sessionTypeId
 * @desc    Edit session type
 * @access  Private/Manager
 */
router.put('/session-types/:sessionTypeId', specialistStatsController.editSessionType);

/**
 * @route   DELETE /api/manager/session-types/:sessionTypeId
 * @desc    Delete session type
 * @access  Private/Manager
 */
router.delete('/session-types/:sessionTypeId', specialistStatsController.deleteSessionType);

// ==================== وظائف عرض الأخصائيين ====================

/**
 * @route   GET /api/manager/specialists
 * @desc    Get all specialists with details
 * @access  Private/Manager
 */
router.get('/specialists', specialistStatsController.getAllSpecialists);

/**
 * @route   GET /api/manager/specialists/:specialistId
 * @desc    Get specialist details
 * @access  Private/Manager
 */
router.get('/specialists/:specialistId', specialistStatsController.getSpecialistDetails);
module.exports = router;


