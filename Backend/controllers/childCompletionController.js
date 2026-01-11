// controllers/childCompletionController.js
const { Op } = require('sequelize');
const Child = require('../model/Child');
const Session = require('../model/Session');
const Evaluation = require('../model/Evaluation');
const ChildSpecialistCompletion = require('../model/ChildSpecialistCompletion');
const Specialist = require('../model/Specialist');
const Institution = require('../model/Institution');
const NotificationService = require('../services/notificationService');
const UserDeviceToken = require('../model/UserDeviceToken');
const Notification = require('../model/Notification');

/**
 * /api/specialist/completion-candidates
 */
exports.getCompletionCandidates = async (req, res) => {
  try {
    const specialistId = req.user.user_id || req.user.id;
    let institutionId = req.user.institution_id;

    // If institution_id is not present in token, try to resolve it from Specialist or User tables
    if (!institutionId) {
      try {
        const specialistRecord = await Specialist.findByPk(specialistId);
        if (specialistRecord && specialistRecord.institution_id) {
          institutionId = specialistRecord.institution_id;
        } else {
          // fallback: try User model
          const User = require('../model/User');
          const userRecord = await User.findByPk(specialistId);
          if (userRecord && userRecord.institution_id) {
            institutionId = userRecord.institution_id;
          }
        }
      } catch (err) {
        console.error('Error resolving institution for specialist in getCompletionCandidates:', err);
      }
    }

    if (!institutionId) {
      return res.status(400).json({
        success: false,
        message: 'الأخصائي غير مرتبط بمؤسسة'
      });
    }

    // الحصول على جميع الأطفال الذين لديهم جلسات مكتملة مع هذا الأخصائي
    const childrenWithSessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        institution_id: institutionId,
        status: 'Completed'
      },
      attributes: ['child_id'],
      group: ['child_id'],
      include: [{
        model: Child,
        as: 'child',
        attributes: ['child_id', 'full_name', 'date_of_birth', 'registration_status']
      }]
    });

    const results = [];

    for (const session of childrenWithSessions) {
      const childId = session.child_id;
      const child = session.child;

      // التحقق التلقائي للشروط الثلاثة
      const conditions = await checkChildConditions(childId, specialistId, institutionId);
      
      // التحقق إذا كان الأخصائي قد أكد سابقاً
      const existingCompletion = await ChildSpecialistCompletion.findOne({
        where: {
          child_id: childId,
          specialist_id: specialistId,
          institution_id: institutionId
        }
      });

      let status = 'pending';
      let needsConfirmation = false;
      let alreadyConfirmed = false;

      if (existingCompletion) {
        status = existingCompletion.status;
        alreadyConfirmed = existingCompletion.specialist_confirmed;
      } else if (conditions.allConditionsMet) {
        // إنشاء سجل جديد إذا تحققت الشروط
        await ChildSpecialistCompletion.create({
          child_id: childId,
          specialist_id: specialistId,
          institution_id: institutionId,
          has_no_active_sessions: conditions.has_no_active_sessions,
          has_final_evaluation: conditions.has_final_evaluation,
          has_no_pending_requests: conditions.has_no_pending_requests,
          status: 'eligible'
        });
        status = 'eligible';
        needsConfirmation = true;
      }

      // إضافة للنتائج فقط إذا كان يحتاج تأكيد أو لم يؤكد بعد
      if (status === 'eligible' || !alreadyConfirmed) {
        results.push({
          child_id: childId,
          full_name: child.full_name,
          date_of_birth: child.date_of_birth,
          current_status: child.registration_status,
          conditions: {
            has_no_active_sessions: conditions.has_no_active_sessions,
            has_final_evaluation: conditions.has_final_evaluation,
            has_no_pending_requests: conditions.has_no_pending_requests
          },
          completion_status: status,
          needs_confirmation: needsConfirmation && !alreadyConfirmed,
          specialist_confirmed: alreadyConfirmed,
          can_confirm: status === 'eligible' && !alreadyConfirmed
        });
      }
    }

    res.json({
      success: true,
      count: results.length,
      candidates: results
    });

  } catch (error) {
    console.error('Error in getCompletionCandidates:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب البيانات'
    });
  }
};

/**
 * 2. POST - تأكيد الأخصائي أن الطفل انتهى العلاج
 * /api/specialist/confirm-completion
 */
exports.confirmChildCompletion = async (req, res) => {
  try {
    const body = req.body || {};
    if (!body || Object.keys(body).length === 0) {
      console.warn('confirmChildCompletion: empty request body. Headers:', {
        contentType: req.get('content-type'),
        contentLength: req.get('content-length')
      });
      return res.status(400).json({
        success: false,
        message: 'البيانات مفقودة في جسم الطلب (body). تأكد من إرسال JSON مع رأس Content-Type: application/json',
        hint: 'أضف Header: Content-Type: application/json وارسِل JSON مماثل: {"child_id":1,"notes":"..."}'
      });
    }

    const child_id = body.child_id;
    const notes = body.notes || null;
    const specialistId = req.user?.user_id || req.user?.id;
    let institutionId = req.user?.institution_id;

    // Resolve institution if not present on token
    if (!institutionId) {
      try {
        const specialistRecord = await Specialist.findByPk(specialistId);
        if (specialistRecord && specialistRecord.institution_id) {
          institutionId = specialistRecord.institution_id;
        } else {
          const User = require('../model/User');
          const userRecord = await User.findByPk(specialistId);
          if (userRecord && userRecord.institution_id) {
            institutionId = userRecord.institution_id;
          }
        }
      } catch (err) {
        console.error('Error resolving institution for specialist in confirmChildCompletion:', err);
      }
    }

    if (!child_id) {
      return res.status(400).json({
        success: false,
        message: 'رقم الطفل مطلوب'
      });
    }

    // التحقق من أن الأخصائي له علاقة بالطفل
    const hasSessions = await Session.findOne({
      where: {
        child_id,
        specialist_id: specialistId,
        institution_id: institutionId,
        status: 'Completed'
      }
    });

    if (!hasSessions) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية لتأكيد انتهاء علاج هذا الطفل'
      });
    }

    // التحقق من الشروط التلقائية
    const conditions = await checkChildConditions(child_id, specialistId, institutionId);
    
    if (!conditions.allConditionsMet) {
      return res.status(400).json({
        success: false,
        message: 'لم تتحقق جميع الشروط بعد',
        conditions
      });
    }

    // تأكد أن الطفل موجود
    const child = await Child.findByPk(child_id);
    if (!child) {
      return res.status(404).json({
        success: false,
        message: 'الطفل غير موجود'
      });
    }

    // البحث عن السجل إن وجد
    let completionRecord = await ChildSpecialistCompletion.findOne({
      where: {
        child_id,
        specialist_id: specialistId,
        institution_id: institutionId
      }
    });

    // إذا السجل موجود وتم التأكيد سابقاً
    if (completionRecord && completionRecord.specialist_confirmed) {
      return res.status(400).json({
        success: false,
        message: 'لقد قمت بتأكيد انتهاء العلاج لهذا الطفل سابقاً'
      });
    }

    // إذا لم يوجد السجل، انشئه مع وضع التأكيد مباشرة (لأن الشروط متحققة)
    if (!completionRecord) {
      completionRecord = await ChildSpecialistCompletion.create({
        child_id,
        specialist_id: specialistId,
        institution_id: institutionId,
        has_no_active_sessions: conditions.has_no_active_sessions,
        has_final_evaluation: conditions.has_final_evaluation,
        has_no_pending_requests: conditions.has_no_pending_requests,
        specialist_confirmed: true,
        confirmed_at: new Date(),
        specialist_notes: notes || null,
        status: 'confirmed'
      });
    } else {
      // حدث السجل الموجود: حدّث الحقول وعلّم أنه مُؤكّد
      await completionRecord.update({
        has_no_active_sessions: conditions.has_no_active_sessions,
        has_final_evaluation: conditions.has_final_evaluation,
        has_no_pending_requests: conditions.has_no_pending_requests,
        specialist_confirmed: true,
        confirmed_at: new Date(),
        specialist_notes: notes || null,
        status: 'confirmed'
      });

      // أعِد تحميل السجل للحصول على القيم المحدثة
      await completionRecord.reload();
    }

    // التحقق إذا جميع الأخصائيين أكدوا
    const allSpecialistsConfirmed = await checkAllSpecialistsConfirmed(child_id, institutionId);

    if (allSpecialistsConfirmed) {
      console.log('All specialists confirmed for child_id', child_id, '- updating child registration_status to Completed');
      // تحديث حالة الطفل إلى Completed
      await Child.update({
        registration_status: 'Completed',
        current_institution_id: null, // إزالة ارتباطه بالمؤسسة الحالية
        updated_at: new Date()
      }, {
        where: { child_id }
      });

      // إنشاء إشعار في قاعدة البيانات للأهل
      try {
        if (child.parent_id) {
          await Notification.create({
            user_id: child.parent_id,
            title: '🎉 Child Treatment Completed',
            message: `Your child ${child.full_name}'s treatment has been confirmed as completed. Thank you for your cooperation.`,
            type: 'child_completed',
            related_id: child.child_id,
            is_read: false
          });

          // Send push notifications via FCM
          try {
            const tokens = await UserDeviceToken.findAll({
              where: { user_id: child.parent_id, is_active: true },
              attributes: ['token']
            });
            const uniqueTokens = [...new Set(tokens.map(t => t.token))];
            for (const tk of uniqueTokens) {
              await NotificationService.sendToToken(
                tk,
                '🎉 Treatment Completed',
                `Your child ${child.full_name}'s treatment has been confirmed as completed.`,
                { type: 'child_completed', childId: child.child_id.toString() }
              );
            }
          } catch (pushErr) {
            console.error('Error sending push on child completion:', pushErr);
          }
        }
      } catch (notifErr) {
        console.error('Error creating parent notification on child completion:', notifErr);
      }

      // هنا يمكنك إضافة إشعار للأهل أو المدير
      // await sendNotification(...);
    }

    // احصل على حالة الطفل المحدثة للرد
    const updatedChild = await Child.findByPk(child_id, {
      attributes: ['child_id', 'registration_status', 'current_institution_id']
    });

    res.json({
      success: true,
      message: 'تم تأكيد انتهاء العلاج بنجاح',
      data: {
        child_id,
        confirmed_at: completionRecord.confirmed_at,
        all_specialists_confirmed: allSpecialistsConfirmed,
        child_status_updated: allSpecialistsConfirmed,
        child_status: updatedChild ? updatedChild.registration_status : null
      }
    });

  } catch (error) {
    console.error('Error in confirmChildCompletion:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في تأكيد انتهاء العلاج'
    });
  }
};

/**
 * دالة مساعدة: التحقق التلقائي للشروط الثلاثة
 */
async function checkChildConditions(childId, specialistId, institutionId) {
  const conditions = {
    has_no_active_sessions: false,
    has_final_evaluation: false,
    has_no_pending_requests: false
  };

  try {
    // 1. التحقق من عدم وجود جلسات نشطة
    const activeSessions = await Session.count({
      where: {
        child_id: childId,
        specialist_id: specialistId,
        institution_id: institutionId,
        status: {
          [Op.in]: [
            'Pending Manager Approval',
            'Pending Specialist Approval',
            'Approved',
            'Confirmed',
            'Scheduled',
            'Reschedule Requested'
          ]
        }
      }
    });
    conditions.has_no_active_sessions = (activeSessions === 0);

    // 2. التحقق من وجود تقييم نهائي
    const finalEvaluation = await Evaluation.findOne({
      where: {
        child_id: childId,
        specialist_id: specialistId,
        evaluation_type: 'Final'
      }
    });
    conditions.has_final_evaluation = !!finalEvaluation;

    // 3. التحقق من عدم وجود طلبات معلقة
    const pendingRequests = await Session.count({
      where: {
        child_id: childId,
        specialist_id: specialistId,
        institution_id: institutionId,
        status: {
          [Op.in]: ['Pending Manager Approval', 'Reschedule Requested']
        }
      }
    });
    conditions.has_no_pending_requests = (pendingRequests === 0);

    // حساب إذا جميع الشروط متحققة
    conditions.allConditionsMet = Object.values(conditions).every(val => val === true);

    return conditions;
  } catch (error) {
    console.error('Error in checkChildConditions:', error);
    return conditions;
  }
}

/**
 * دالة مساعدة: التحقق إذا جميع الأخصائيين أكدوا
 */
async function checkAllSpecialistsConfirmed(childId, institutionId) {
  try {
    // الحصول على جميع الأخصائيين الذين عملوا مع الطفل
    const allSpecialists = await Session.findAll({
      where: {
        child_id: childId,
        institution_id: institutionId,
        status: 'Completed'
      },
      attributes: ['specialist_id'],
      group: ['specialist_id']
    });

    if (allSpecialists.length === 0) {
      return false;
    }

    // dedupe specialist IDs
    const specialistIds = [...new Set(allSpecialists.map(s => s.specialist_id))];

    // التحقق من سجلات التأكيد لكل أخصائي (نطابق على child_id + specialist_id فقط لضمان عدم فقدان قواعد بيانات قد تحتوي institution_id مختلف)
    const completionRecords = await ChildSpecialistCompletion.findAll({
      where: {
        child_id: childId,
        specialist_id: {
          [Op.in]: specialistIds
        },
        specialist_confirmed: true
      }
    });

    const confirmedSpecialistIds = [...new Set(completionRecords.map(r => r.specialist_id))];

    // Debug logging to help diagnose mismatches
    if (confirmedSpecialistIds.length !== specialistIds.length) {
      console.warn('checkAllSpecialistsConfirmed: mismatch counts', {
        childId,
        institutionId,
        expectedSpecialistIds: specialistIds,
        confirmedSpecialistIds
      });
    }

    // شرط الإكمال: جميع الأخصائيين أكدوا
    return confirmedSpecialistIds.length === specialistIds.length;
  } catch (error) {
    console.error('Error in checkAllSpecialistsConfirmed:', error);
    return false;
  }
}