const SessionType = require('../model/SessionType');
const Manager = require('../model/Manager');
const User = require('../model/User');
const Notification = require('../model/Notification');
const { Op } = require('sequelize');

// ✅ جلب أنواع الجلسات المعلقة للموافقة
exports.getPendingSessionTypes = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    // التحقق من أن المستخدم مدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'المستخدم غير مصرح له'
      });
    }

    // جلب أنواع الجلسات المعلقة في نفس المؤسسة
    const pendingSessionTypes = await SessionType.findAll({
      where: {
        institution_id: manager.institution_id,
        approval_status: 'Pending'
      },
      order: [['session_type_id', 'DESC']]
    });

    // جلب معلومات المختصين الذين أنشأوا أنواع الجلسات
    const sessionTypesWithSpecialist = await Promise.all(
      pendingSessionTypes.map(async (st) => {
        const sessionTypeData = st.toJSON();
        if (st.created_by_specialist_id) {
          const specialist = await User.findByPk(st.created_by_specialist_id, {
            attributes: ['user_id', 'full_name', 'email']
          });
          sessionTypeData.created_by_specialist = specialist;
        }
        return sessionTypeData;
      })
    );

    res.status(200).json({
      success: true,
      message: 'تم جلب أنواع الجلسات المعلقة بنجاح',
      data: sessionTypesWithSpecialist,
      count: sessionTypesWithSpecialist.length
    });

  } catch (error) {
    console.error('Error in getPendingSessionTypes:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب أنواع الجلسات المعلقة',
      error: error.message
    });
  }
};

// ✅ الموافقة على نوع جلسة
exports.approveSessionType = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { session_type_id } = req.params;
    const { notes } = req.body;

    // التحقق من أن المستخدم مدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'المستخدم غير مصرح له'
      });
    }

    // جلب نوع الجلسة
    const sessionType = await SessionType.findOne({
      where: {
        session_type_id,
        institution_id: manager.institution_id,
        approval_status: 'Pending'
      }
    });

    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'نوع الجلسة غير موجود أو غير معلق للموافقة'
      });
    }

    // الموافقة على نوع الجلسة
    await sessionType.update({
      approval_status: 'Approved'
    });

    // إرسال إشعار للمختص الذي أنشأ نوع الجلسة
    if (sessionType.created_by_specialist_id) {
      await Notification.create({
        user_id: sessionType.created_by_specialist_id,
        title: 'تمت الموافقة على نوع الجلسة',
        message: `تمت الموافقة على نوع الجلسة "${sessionType.name}" من قبل المدير. يمكنك الآن استخدامه في إنشاء الجلسات.`,
        type: 'general',
        related_id: sessionType.session_type_id,
        is_read: false
      });
    }

    res.status(200).json({
      success: true,
      message: 'تمت الموافقة على نوع الجلسة بنجاح',
      data: sessionType
    });

  } catch (error) {
    console.error('Error in approveSessionType:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في الموافقة على نوع الجلسة',
      error: error.message
    });
  }
};

// ✅ رفض نوع جلسة
exports.rejectSessionType = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { session_type_id } = req.params;
    const { reason } = req.body;

    // التحقق من أن المستخدم مدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'المستخدم غير مصرح له'
      });
    }

    // جلب نوع الجلسة
    const sessionType = await SessionType.findOne({
      where: {
        session_type_id,
        institution_id: manager.institution_id,
        approval_status: 'Pending'
      }
    });

    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'نوع الجلسة غير موجود أو غير معلق للموافقة'
      });
    }

    // رفض نوع الجلسة
    await sessionType.update({
      approval_status: 'Rejected'
    });

    // إرسال إشعار للمختص الذي أنشأ نوع الجلسة
    if (sessionType.created_by_specialist_id) {
      await Notification.create({
        user_id: sessionType.created_by_specialist_id,
        title: 'تم رفض نوع الجلسة',
        message: `تم رفض نوع الجلسة "${sessionType.name}" من قبل المدير. ${reason ? `السبب: ${reason}` : ''}`,
        type: 'general',
        related_id: sessionType.session_type_id,
        is_read: false
      });
    }

    res.status(200).json({
      success: true,
      message: 'تم رفض نوع الجلسة بنجاح',
      data: sessionType
    });

  } catch (error) {
    console.error('Error in rejectSessionType:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في رفض نوع الجلسة',
      error: error.message
    });
  }
};

module.exports = exports;

