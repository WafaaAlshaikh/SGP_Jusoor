// routes/childCompletionRoutes.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const childCompletionController = require('../controllers/childCompletionController');

/**
 * @route   GET /api/specialist/completion-candidates
 * @desc    عرض الأطفال المؤهلين للتأكيد من قبل الأخصائي
 * @access  Private (Specialist only)
 */
router.get('/completion-candidates', 
  authMiddleware,
  (req, res, next) => {
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({
        success: false,
        message: 'غير مصرح - للأخصائيين فقط'
      });
    }
    next();
  },
  childCompletionController.getCompletionCandidates
);

/**
 * @route   POST /api/specialist/confirm-completion
 * @desc    تأكيد الأخصائي أن الطفل انتهى العلاج
 * @access  Private (Specialist only)
 */
router.post('/confirm-completion',
  authMiddleware,
  (req, res, next) => {
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({
        success: false,
        message: 'غير مصرح - للأخصائيين فقط'
      });
    }
    next();
  },
  childCompletionController.confirmChildCompletion
);

// routes/childCompletionRoutes.js
router.get('/completion-status/:child_id',
  authMiddleware,
  async (req, res) => {
    try {
      const childId = req.params.child_id;
      const userId = req.user.user_id || req.user.id;
      const userRole = req.user.role;

      // التحقق من الصلاحيات
      let canAccess = false;
      
      if (userRole === 'Specialist') {
        const Session = require('../model/Session');
        const hasAccess = await Session.findOne({
          where: {
            child_id: childId,
            specialist_id: userId,
            status: 'Completed'
          }
        });
        canAccess = !!hasAccess;
      } else if (userRole === 'Manager') {
        const Child = require('../model/Child');
        const institutionId = req.user.institution_id;
        const child = await Child.findOne({
          where: {
            child_id: childId,
            current_institution_id: institutionId
          }
        });
        canAccess = !!child;
      }

      if (!canAccess) {
        return res.status(403).json({
          success: false,
          message: 'ليس لديك صلاحية للوصول إلى هذه البيانات'
        });
      }

      const ChildSpecialistCompletion = require('../model/ChildSpecialistCompletion');
      const User = require('../model/User');
      const Session = require('../model/Session');
      const Child = require('../model/Child');
      
      // ⭐⭐ الطريقة الصحيحة بدون include معقد ⭐⭐
      // جلب جميع تأكيدات الأخصائيين لهذا الطفل
      const completionRecords = await ChildSpecialistCompletion.findAll({
        where: { child_id: childId },
        order: [['confirmed_at', 'DESC']]
      });

      // جلب جميع الأخصائيين الذين عملوا مع الطفل
      const allSpecialists = await Session.findAll({
        where: {
          child_id: childId,
          status: 'Completed'
        },
        attributes: ['specialist_id'],
        group: ['specialist_id']
      });

      const child = await Child.findByPk(childId, {
        attributes: ['child_id', 'full_name', 'registration_status', 'current_institution_id']
      });

      // 🔴 الحل: الحصول على أسماء الأخصائيين بطريقة منفصلة
      const specialistIds = [
        ...completionRecords.map(r => r.specialist_id),
        ...allSpecialists.map(s => s.specialist_id)
      ];
      
      const uniqueSpecialistIds = [...new Set(specialistIds.filter(id => id))];
      
      let specialistNames = {};
      if (uniqueSpecialistIds.length > 0) {
        const users = await User.findAll({
          where: {
            user_id: uniqueSpecialistIds
          },
          attributes: ['user_id', 'full_name', 'email']
        });
        
        users.forEach(user => {
          specialistNames[user.user_id] = user.full_name;
        });
      }

      res.json({
        success: true,
        child: {
          id: child.child_id,
          name: child.full_name,
          status: child.registration_status,
          has_active_institution: !!child.current_institution_id
        },
        all_specialists: allSpecialists.map(s => ({
          id: s.specialist_id,
          name: specialistNames[s.specialist_id] || 'Unknown'
        })),
        confirmations: completionRecords.map(record => ({
          specialist_id: record.specialist_id,
          specialist_name: specialistNames[record.specialist_id] || 'Unknown',
          confirmed: record.specialist_confirmed,
          confirmed_at: record.confirmed_at,
          notes: record.specialist_notes,
          conditions: {
            has_no_active_sessions: record.has_no_active_sessions,
            has_final_evaluation: record.has_final_evaluation,
            has_no_pending_requests: record.has_no_pending_requests
          },
          status: record.status
        })),
        all_confirmed: allSpecialists.length > 0 && 
                       completionRecords.length === allSpecialists.length && 
                       completionRecords.every(r => r.specialist_confirmed)
      });

    } catch (error) {
      console.error('Error in completion status:', error);
      res.status(500).json({
        success: false,
        message: 'حدث خطأ في جلب حالة الإكمال'
      });
    }
  }
);

module.exports = router;