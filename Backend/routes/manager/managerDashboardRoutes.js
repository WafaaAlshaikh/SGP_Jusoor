// routes/managerDashboardRoutes.js
const express = require('express');
const router = express.Router();
const managerDashboardController = require('../../controllers/manager/managerDashboardController');
const authMiddleware = require('../../middleware/authMiddleware');

// جميع routes تتطلب مصادقة
router.use(authMiddleware);
// في routes/managerDashboardRoutes.js
router.get('/debug', managerDashboardController.getDebugInfo);
// إحصائيات لوحة تحكم المدير
router.get('/dashboard/stats', managerDashboardController.getManagerDashboardStats);
// تفاصيل التبرعات للمؤسسة
router.get('/dashboard/donations', managerDashboardController.getDonationDetails);
// تقرير مالي للمؤسسة
router.get('/financial/report', managerDashboardController.getFinancialReport);

module.exports = router;