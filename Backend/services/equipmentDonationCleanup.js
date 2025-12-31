const { EquipmentDonation } = require('../model');
const { Op } = require('sequelize');
const cron = require('node-cron');

// تنظيف الطلبات المنتهية (التي مضى عليها أكثر من 30 يوم ولم يتم تحديثها)
async function cleanupOldEquipmentDonations() {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const result = await EquipmentDonation.update(
      {
        status: 'cancelled',
        admin_notes: 'تم إلغاء الطلب تلقائياً بسبب عدم تحديث الحالة لأكثر من 30 يوم'
      },
      {
        where: {
          status: 'pending',
          updated_at: { [Op.lt]: thirtyDaysAgo }
        }
      }
    );

    if (result[0] > 0) {
      console.log(`✅ تم إلغاء ${result[0]} طلب تبرع قديم تلقائياً`);
    }

  } catch (error) {
    console.error('❌ خطأ في تنظيف طلبات التبرع القديمة:', error);
  }
}

// جدولة المهمة لتشغيل يومياً في منتصف الليل
cron.schedule('0 0 * * *', cleanupOldEquipmentDonations);

// تصدير الدالة للاستخدام المباشر إذا لزم الأمر
module.exports = {
  cleanupOldEquipmentDonations
};