// middleware/ratingMiddleware.js
const Session = require('../model/Session');
const Child = require('../model/Child');
const SessionRating = require('../model/SessionRating');

/**
 * التحقق من أن الجلسة يمكن تقييمها
 */
const canRateSession = async (req, res, next) => {
  try {
    const { sessionId } = req.params;
    const parentId = req.user.user_id;

    const session = await Session.findOne({
      where: { 
        session_id: sessionId,
        status: 'Completed'
      },
      include: [{
        model: Child,
        as: 'child',  // ✅ أضف as هنا
        where: { parent_id: parentId }
      }]
    });

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'الجلسة غير موجودة أو لا يمكن تقييمها'
      });
    }

    // التحقق من الوقت (بعد 24 ساعة من الجلسة)
    const sessionDate = new Date(session.date);
    const now = new Date();
    const hoursDiff = Math.abs(now - sessionDate) / (1000 * 60 * 60);
    
    if (hoursDiff < 24) {
      return res.status(400).json({
        success: false,
        message: 'يمكنك التقييم بعد 24 ساعة من انتهاء الجلسة'
      });
    }

    // التحقق إذا سبق التقييم
    const existingRating = await SessionRating.findOne({
      where: { 
        session_id: sessionId,
        parent_id: parentId 
      }
    });

    if (existingRating) {
      return res.status(400).json({
        success: false,
        message: 'لقد قيمت هذه الجلسة مسبقاً'
      });
    }

    // إضافة الجلسة إلى request للاستخدام في controller
    req.session = session;
    next();
  } catch (error) {
    console.error('Can rate session middleware error:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في التحقق من صلاحية التقييم'
    });
  }
};

/**
 * التحقق من وجود زيارات سابقة للمؤسسة
 */
const hasVisitedInstitution = async (req, res, next) => {
  try {
    const { institutionId } = req.params;
    const parentId = req.user.user_id;

    const visitCount = await Session.count({
      where: {
        institution_id: institutionId,
        status: 'Completed',
        session_type: 'Onsite'
      },
      include: [{
        model: Child,
        as: 'child',  // ✅ أضف as هنا
        where: { parent_id: parentId }
      }]
    });

    if (visitCount < 1) {
      return res.status(400).json({
        success: false,
        message: 'يجب أن يكون لديك زيارات سابقة للمؤسسة لتقييمها'
      });
    }

    req.visitCount = visitCount;
    next();
  } catch (error) {
    console.error('Has visited institution middleware error:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في التحقق من الزيارات'
    });
  }
};

/**
 * التحقق من وجود جلسات سابقة مع الأخصائي
 */
const hasSessionsWithSpecialist = async (req, res, next) => {
  try {
    const { specialist_id } = req.body;
    const parentId = req.user.user_id;

    const sessionCount = await Session.count({
      where: {
        specialist_id: specialist_id,
        status: 'Completed'
      },
      include: [{
        model: Child,
        as: 'child',  // ✅ أضف as هنا
        where: { parent_id: parentId }
      }]
    });

    if (sessionCount < 3) {
      return res.status(400).json({
        success: false,
        message: 'يجب أن يكون لديك 3 جلسات على الأقل مع الأخصائي لتقديم ملاحظات'
      });
    }

    req.sessionCount = sessionCount;
    next();
  } catch (error) {
    console.error('Has sessions with specialist middleware error:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في التحقق من الجلسات'
    });
  }
};

/**
 * التحقق من أن المدير مرتبط بالمؤسسة
 */
const isManagerOfInstitution = async (req, res, next) => {
  try {
    const managerId = req.user.user_id;

    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      attributes: ['institution_id']
    });

    if (!manager || !manager.institution_id) {
      return res.status(404).json({
        success: false,
        message: 'المدير غير مرتبط بمؤسسة'
      });
    }

    req.managerInstitutionId = manager.institution_id;
    next();
  } catch (error) {
    console.error('Is manager of institution middleware error:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في التحقق من صلاحية المدير'
    });
  }
};

module.exports = {
  canRateSession,
  hasVisitedInstitution,
  hasSessionsWithSpecialist,
  isManagerOfInstitution
};