const express = require('express');
const router = express.Router();

// استيراد routes المتوفرة فقط
const childrenRoutes = require('./manager/managerChildrenRoutes');
const specialistRoutes = require('./manager/managerSpecialistRoutes'); // الجديدة

// استخدام routes المتوفرة
router.use('/', childrenRoutes);
router.use('/', specialistRoutes);

// 🔹 الإحصائيات العامة للمدير (بدون session types)
router.get('/dashboard/stats', async (req, res) => {
  try {
    // استيراد الـ controllers المتوفرة فقط
    const childManagementController = require('../controllers/manager/managerChildrenController');
    const managerSpecialistController = require('../controllers/manager/managerSpecialistController');

    // جلب الإحصائيات من الـ controllers المتوفرة
    const [childrenData, specialistsData] = await Promise.all([
      getChildrenStats(req),
      getSpecialistsStats(req)
    ]);

    res.json({
      success: true,
      data: {
        children: childrenData,
        specialists: specialistsData,
        overview: {
          total_pending_approvals: (specialistsData.pending_approvals || 0),
          total_active: (childrenData.total_children || 0) + (specialistsData.total_specialists || 0),
          monthly_sessions: childrenData.monthly_sessions || 0
        }
      }
    });

  } catch (error) {
    console.error('Dashboard stats error:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب إحصائيات Dashboard',
      error: error.message
    });
  }
});

// دوال مساعدة لجلب الإحصائيات
async function getChildrenStats(req) {
  try {
    // دالة مؤقتة - سنستبدلها بالدالة الحقيقية من الـ controller
    return { 
      total_children: 25, 
      monthly_sessions: 120,
      pending_registrations: 3
    };
  } catch (error) {
    return { error: error.message };
  }
}

async function getSpecialistsStats(req) {
  try {
    // دالة مؤقتة - سنستبدلها بالدالة الحقيقية من الـ controller
    return { 
      total_specialists: 15, 
      pending_approvals: 3,
      active_specialists: 12
    };
  } catch (error) {
    return { error: error.message };
  }
}

module.exports = router;