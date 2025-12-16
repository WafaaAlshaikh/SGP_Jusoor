// jobs/autoApprovalCron.js
const cron = require('node-cron');
const AutoApprovalService = require('../services/autoApprovalService');

// تشغيل كل 15 دقيقة
cron.schedule('*/15 * * * *', async () => {
  console.log('⏰ [CRON] بدء المعالجة التلقائية للطلبات...');
  
  try {
    const results = await AutoApprovalService.processPendingRegistrationRequests();
    
    // تسجيل النتائج في ملف Log
    console.log('📊 [CRON] نتائج المعالجة:', {
      timestamp: new Date().toISOString(),
      total_processed: results.approved.length + results.rejected.length + results.pending_manager_review.length,
      approved: results.approved.length,
      rejected: results.rejected.length,
      needs_manager: results.pending_manager_review.length
    });
    
  } catch (error) {
    console.error('❌ [CRON] خطأ في المعالجة التلقائية:', error);
  }
});

console.log('✅ تم جدولة وظيفة الموافقة التلقائية (كل 15 دقيقة)');