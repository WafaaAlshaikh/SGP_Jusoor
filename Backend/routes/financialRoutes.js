const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const parentFinancialController = require('../controllers/parentFinancialController');

// ==============================================
// 📋 التقييم المالي (المسارات الجديدة والأصلية)
// ==============================================

// 🔄 NEW: General Financial Assessment (بدون طفل/مؤسسة)
router.post('/assessment/general/initiate', authMiddleware, parentFinancialController.initiateGeneralFinancialAssessment);
router.post('/assessment/general/submit', authMiddleware, parentFinancialController.submitGeneralFinancialAssessment);

// 🔄 NEW: Apply assessment to specific child
router.post('/assessment/apply-to-child', authMiddleware, parentFinancialController.applyFinancialAssessmentToChild);

// 📋 ORIGINAL: Specific Financial Assessment (مع طفل/مؤسسة - للتوافق)
router.post('/assessment/initiate', authMiddleware, parentFinancialController.initiateFinancialAssessment);
router.post('/assessment/submit', authMiddleware, parentFinancialController.submitFinancialAssessment);

// ==============================================
// 📝 طلبات المساعدة المالية
// ==============================================

// 📋 طلب المساعدة المالية (محدث لدعم كلا النوعين)
router.post('/assistance/request', authMiddleware, parentFinancialController.requestFinancialAssistance);

// 📋 متابعة حالة الطلب
router.get('/assistance/:request_id/status', authMiddleware, parentFinancialController.getFinancialAssistanceStatus);

// 📋 رفع الوثائق الداعمة
router.post('/assistance/:request_id/documents', authMiddleware, parentFinancialController.uploadFinancialDocuments);

// ==============================================
// 👤 الملف الشخصي والطلبات
// ==============================================

// 📋 الملف الشخصي المالي للوالد
router.get('/profile', authMiddleware, parentFinancialController.getParentFinancialProfile);

// 📋 قائمة الطلبات المالية
router.get('/requests', authMiddleware, parentFinancialController.getFinancialAssistanceRequests);

// 📋 عروض الجلسات المجانية للأهل
router.get('/free-session-offers', authMiddleware, parentFinancialController.getFreeSessionOffers);
router.post('/free-session-offers/:offer_id/accept', authMiddleware, parentFinancialController.acceptFreeSessionOffer);

// ==============================================
// 🔧 مسارات إضافية مقترحة (اختيارية)
// ==============================================

// تجديد التقييم المالي
router.post('/assessment/renew', authMiddleware, async (req, res) => {
  try {
    const parentId = req.user.user_id;
    
    // يمكنك إما:
    // 1. استخدام التقييم الموجود وإعادة حسابه مع بيانات جديدة
    // 2. أو إعادة التوجيه إلى التقييم العام
    res.status(200).json({
      success: true,
      message: 'Assessment renewal endpoint',
      redirect_to: '/api/financial/assessment/general/initiate'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to renew assessment',
      error: error.message
    });
  }
});

// تنزيل ملخص التقييم
router.get('/assessment/summary/pdf', authMiddleware, async (req, res) => {
  try {
    const parentId = req.user.user_id;
    
    // سيتم تنفيذ هذا في المستقبل
    res.status(200).json({
      success: true,
      message: 'PDF summary generation endpoint',
      coming_soon: true
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to generate PDF summary',
      error: error.message
    });
  }
});

// مقارنة المؤسسات
router.get('/institutions/compare', authMiddleware, async (req, res) => {
  try {
    const { child_id } = req.query;
    
    // يمكن تنفيذ هذا لاحقاً
    res.status(200).json({
      success: true,
      message: 'Institution comparison endpoint',
      feature: 'planned'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to compare institutions',
      error: error.message
    });
  }
});

module.exports = router;