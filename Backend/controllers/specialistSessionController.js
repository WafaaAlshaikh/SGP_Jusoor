const Session = require('../model/Session');
const User = require('../model/User');
const Child = require('../model/Child');
const Institution = require('../model/Institution');
const SessionType = require('../model/SessionType');
const Notification = require('../model/Notification');
const { Op } = require('sequelize');
const ZoomMeeting = require('../model/ZoomMeeting');
const { createZoomMeeting } = require('../services/zoomService');

// ✅ 1. جلب كل الجلسات للأخصائي - النسخة المعدلة
exports.getAllSessionsForSpecialist = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    const sessions = await Session.findAll({
      where: { 
        specialist_id: specialistId,
        is_visible: true // 🔥 إظهار الجلسات المرئية فقط
      },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id'] 
        },
        { 
          model: Institution, 
          as: 'institution',
          attributes: ['institution_id', 'name'] 
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'duration', 'category']
        }
      ],
      attributes: [
        'session_id', 
        'date', 
        'time', 
        'status',
        'session_type',
        'session_type_id', 
        'child_id', 
        'institution_id',
        'delete_request',
        'delete_status',
        'requested_by_parent',
        'is_pending',
        'original_session_id',
        'reason'
      ],
      order: [['date', 'ASC'], ['time', 'ASC']]
    });

    res.status(200).json(sessions);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error retrieving sessions' });
  }
};


// ✅ 2. حذف الجلسة مباشرة مع إشعار للأهل - النسخة المحدثة
exports.requestDeleteSession = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const specialistId = req.user.user_id;

    const session = await Session.findOne({ 
      where: { session_id: id, specialist_id: specialistId },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id'] 
        }
      ]
    });
    
    if (!session) {
      return res.status(404).json({ message: 'Session not found' });
    }

    // ⭐ تحديث حالة الجلسة إلى Cancelled مباشرة
    await Session.update(
      {
        status: 'Cancelled',
        is_visible: false, // إخفاء الجلسة
        reason: reason || 'Cancelled by specialist'
      },
      {
        where: { session_id: id, specialist_id: specialistId }
      }
    );

    // ⭐ إرسال إشعار للأهل فقط - بدون مدير
    if (session.child && session.child.parent_id) {
      await Notification.create({
        user_id: session.child.parent_id,
        title: 'Session Cancelled',
        message: `The session for ${session.child.full_name} scheduled on ${session.date} at ${session.time} has been cancelled. ${reason ? `Reason: ${reason}` : ''}`,
        type: 'session_cancelled',
        related_id: session.session_id,
        is_read: false
      });
    }

    res.status(200).json({ 
      message: 'Session cancelled successfully and parent notified',
      reason: reason || 'No reason provided'
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error cancelling session' });
  }
};

// ✅ 3. تعديل الجلسة مع إشعار للأهل - النسخة المحدثة
exports.requestSessionUpdate = async (req, res) => {
  try {
    const { id } = req.params;
    const { date, time, status, session_type, reason } = req.body; // ⭐ نأخذ السبب
    const specialistId = req.user.user_id;

    const session = await Session.findOne({ 
      where: { session_id: id, specialist_id: specialistId },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id'] 
        }
      ]
    });

    if (!session) return res.status(404).json({ message: 'Session not found' });

    // 🔥 تحديث الجلسة القديمة لتصبح Pending Approval مع السبب
    await Session.update(
      {
        status: 'Pending Approval',
        is_pending: true,
        reason: reason || null // ⭐ إضافة السبب للتعديل
      },
      {
        where: { session_id: id, specialist_id: specialistId }
      }
    );

    // 🔥 إنشاء الجلسة الجديدة لكن مخفية مع السبب
    const newSession = await Session.create({
      child_id: session.child_id,
      specialist_id: session.specialist_id,
      institution_id: session.institution_id,
      session_type_id: session.session_type_id,
      date: date || session.date,
      time: time || session.time,
      status: 'Rescheduled',
      session_type: session_type || session.session_type,
      is_pending: true,
      is_visible: false,
      original_session_id: session.session_id,
      reason: reason || 'Rescheduled from original session' // ⭐ السبب
    });

    // إشعار للأهل
    if (session.child && session.child.parent_id) {
      await Notification.create({
        user_id: session.child.parent_id,
        title: 'Session rescheduling requested',
        message: `The specialist has requested to reschedule ${session.child.full_name}'s session from ${session.date} ${session.time} to ${date} ${time}. ${reason ? `Reason: ${reason}` : ''}`,
        type: 'session_update',
        related_id: session.session_id,
        is_read: false
      });
    }

    res.status(200).json({
      message: 'Session rescheduling requested. Waiting for parent approval.',
      reason: reason || 'No reason provided',
      originalSessionUpdated: true
    });

  } catch (err) {
    console.error('Request session update error:', err);
    res.status(500).json({ message: 'Server error requesting session update' });
  }
};

// ✅ 4. الموافقة على الجلسة المعلقة - النسخة المعدلة
exports.approvePendingSession = async (req, res) => {
  try {
    const { id } = req.params;  // id = الجلسة القديمة
    const { approve } = req.body;

    // 🔥 البحث عن الجلسة القديمة
    const originalSession = await Session.findOne({ 
      where: { session_id: id } 
    });
    
    if (!originalSession) return res.status(404).json({ message: 'Session not found' });

    // 🔥 البحث عن الجلسة الجديدة المرتبطة
    const newSession = await Session.findOne({
      where: { original_session_id: id, is_pending: true }
    });

    if (approve) {
      // 🔥 الموافقة: إخفاء الجلسة القديمة وإظهار الجلسة الجديدة
      if (newSession) {
        await Session.update(
          { 
            status: 'Scheduled',
            is_pending: false,
            is_visible: true // 🔥 جعل الجلسة الجديدة ظاهرة
          }, 
          { 
            where: { session_id: newSession.session_id } 
          }
        );
      }

      // 🔥 إخفاء الجلسة القديمة
      await Session.update(
        { 
          status: 'Rescheduled - Approved',
          is_visible: false, // 🔥 إخفاء الجلسة القديمة
          is_pending: false
        }, 
        { 
          where: { session_id: id } 
        }
      );

    } else {
      // 🔥 الرفض: إعادة الجلسة القديمة وحذف الجلسة الجديدة
      await Session.update(
        { 
          status: 'Scheduled',
          is_pending: false,
          is_visible: true
        }, 
        { 
          where: { session_id: id } 
        }
      );

      // حذف الجلسة الجديدة
      if (newSession) {
        await newSession.destroy();
      }
    }

    res.status(200).json({ 
      message: approve ? 'Session rescheduling approved' : 'Session rescheduling rejected'
    });

  } catch (err) {
    console.error('Approve pending session error:', err);
    res.status(500).json({ message: 'Server error approving/rejecting session' });
  }
};

// ✅ 5. إكمال جلسات اليوم
exports.completeTodaySessions = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // البحث عن جلسات اليوم مع معلومات الطفل
    const todaySessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        date: today,
        status: {
          [Op.in]: ['Scheduled', 'Confirmed', 'Pending Approval']
        }
      },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id']
        }
      ]
    });

    // تحديث الجلسات
    const result = await Session.update(
      { status: 'Completed' },
      {
        where: {
          specialist_id: specialistId,
          date: today,
          status: {
            [Op.in]: ['Scheduled', 'Confirmed', 'Pending Approval']
          }
        }
      }
    );

    const updatedCount = result[0];

    // إرسال إشعارات للأهل
    for (const session of todaySessions) {
      if (session.child && session.child.parent_id) {
        await Notification.create({
          user_id: session.child.parent_id,
          title: 'Session complete',
          message: `${session.child.full_name} session has been completed successfully.`,
          type: 'session_completed',
          related_id: session.session_id,
          is_read: false
        });
      }
    }

    res.status(200).json({
      message: `Completed ${updatedCount} sessions for today`,
      updatedCount: updatedCount
    });
  } catch (err) {
    console.error('Complete today sessions error:', err);
    res.status(500).json({ message: 'Server error completing today sessions' });
  }
};

// ✅ 6. جلب الجلسات القادمة (7 أيام)
exports.getUpcomingSessions = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const nextWeek = new Date();
    nextWeek.setDate(today.getDate() + 7);
    nextWeek.setHours(23, 59, 59, 999);

    const sessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        date: {
          [Op.between]: [today, nextWeek]
        },
        status: 'Scheduled',
        is_visible: true // 🔥 إظهار الجلسات المرئية فقط
      },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name'] 
        },
        { 
          model: Institution, 
          as: 'institution',
          attributes: ['institution_id', 'name'] 
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'duration', 'category']
        }
      ],
      attributes: [
        'session_id', 
        'date', 
        'time', 
        'status',
        'session_type',
        'session_type_id'
      ],
      order: [['date', 'ASC'], ['time', 'ASC']]
    });

    res.status(200).json(sessions);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error retrieving upcoming sessions' });
  }
};

// ✅ 7. التقرير الشهري
exports.getMonthlyReport = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { month, year } = req.query;
    
    const targetMonth = month || new Date().getMonth() + 1;
    const targetYear = year || new Date().getFullYear();

    const startDate = new Date(targetYear, targetMonth - 1, 1);
    const endDate = new Date(targetYear, targetMonth, 0);
    endDate.setHours(23, 59, 59, 999);

    const sessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        date: {
          [Op.between]: [startDate, endDate]
        },
        is_visible: true // 🔥 إظهار الجلسات المرئية فقط
      },
      attributes: [
        'session_id', 
        'date', 
        'status',
        'session_type'
      ]
    });

    const totalSessions = sessions.length;
    const completedSessions = sessions.filter(s => s.status === 'Completed').length;
    const cancelledSessions = sessions.filter(s => s.status === 'Cancelled').length;
    const onlineSessions = sessions.filter(s => s.session_type === 'Online').length;
    const onsiteSessions = sessions.filter(s => s.session_type === 'Onsite').length;

    const report = {
      month: targetMonth,
      year: targetYear,
      totalSessions,
      completedSessions,
      cancelledSessions,
      onlineSessions,
      onsiteSessions,
      completionRate: totalSessions > 0 ? (completedSessions / totalSessions * 100).toFixed(2) : 0
    };

    res.status(200).json(report);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error generating monthly report' });
  }
};

// ✅ 8. ضبط التذكيرات
exports.setSessionReminders = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { reminderTime } = req.body;

    res.status(200).json({
      message: 'Reminders set successfully',
      reminderTime: reminderTime
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error setting reminders' });
  }
};

// ✅ 9. الانضمام إلى جلسة زوم
exports.joinZoomSession = async (req, res) => {
  try {
    const { id } = req.params;
    const specialistId = req.user.user_id;

    const session = await Session.findOne({
      where: {
        session_id: id,
        specialist_id: specialistId,
        session_type: 'Online'
      },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id'] 
        }
      ]
    });

    if (!session) {
      return res.status(404).json({ message: 'Online session not found' });
    }

    // تحقق أولًا إذا كان الاجتماع موجود مسبقًا في قاعدة بيانات ZoomMeeting
    let zoomMeeting = await ZoomMeeting.findOne({ where: { session_id: id } });

    if (!zoomMeeting) {
      // إنشاء اجتماع جديد عبر خدمة Zoom
      const startTime = `${session.date}T${session.time}:00`;
      const meetingData = await createZoomMeeting(`Session ${session.child.full_name}`, startTime);

      // حفظ اجتماع Zoom في قاعدة البيانات
      zoomMeeting = await ZoomMeeting.create({
        session_id: session.session_id,
        meeting_id: meetingData.id,
        join_url: meetingData.join_url,
        start_time: meetingData.start_time,
        topic: meetingData.topic
      });

      // إرسال إشعار للأهل إذا موجود parent_id
      if (session.child && session.child.parent_id) {
        await Notification.create({
          user_id: session.child.parent_id,
          title: 'Zoom session created',
          message: `A Zoom meeting for ${session.child.full_name}'s session has been created. Join here: ${meetingData.join_url}`,
          type: 'session_update',
          related_id: session.session_id,
          is_read: false
        });
      }
    }

    res.status(200).json({
      message: 'Zoom meeting retrieved successfully',
      meeting: {
        meetingId: zoomMeeting.meeting_id,
        joinUrl: zoomMeeting.join_url,
        startTime: zoomMeeting.start_time,
        topic: zoomMeeting.topic
      }
    });
  } catch (err) {
    console.error('Zoom session error:', err.response?.data || err.message);
    res.status(500).json({ message: 'Server error creating/retrieving Zoom meeting' });
  }
};

// ✅ 10. جلب التعديلات المعلقة للأهل
exports.getPendingSessionsForParent = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const pendingSessions = await Session.findAll({
      where: {
        is_pending: true,
        is_visible: true
      },
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'full_name'],
          where: { parent_id: parentId }
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'duration', 'category']
        }
      ]
    });

    res.status(200).json(pendingSessions);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error retrieving pending sessions' });
  }
};

// ✅ جلب الجلسات الجديدة المعلقة للموافقة (أنشأها المختص)
exports.getNewPendingSessionsForParent = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    
    // جلب الجلسات التي بحالة "Pending Approval" و parent_approved = null
    const pendingSessions = await Session.findAll({
      where: {
        status: 'Pending Approval',
        parent_approved: null,
        is_pending: true
      },
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'full_name', 'photo'],
          where: { parent_id: parentId }
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['user_id', 'full_name', 'profile_picture']
        },
        {
          model: Institution,
          as: 'institution',
          attributes: ['institution_id', 'name']
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'duration', 'price', 'category']
        }
      ],
      order: [['date', 'ASC'], ['time', 'ASC']]
    });

    res.status(200).json({
      success: true,
      message: 'تم جلب الجلسات المعلقة بنجاح',
      data: pendingSessions,
      count: pendingSessions.length
    });
  } catch (err) {
    console.error('Error in getNewPendingSessionsForParent:', err);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في جلب الجلسات المعلقة',
      error: err.message 
    });
  }
};

// ✅ موافقة أو رفض الجلسة الجديدة من قبل الأهل
exports.approveNewSession = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { session_id } = req.params;
    const { approve } = req.body; // true = موافقة, false = رفض

    // جلب الجلسة
    const session = await Session.findOne({
      where: {
        session_id,
        status: 'Pending Approval',
        parent_approved: null
      },
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id'],
          where: { parent_id: parentId }
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['user_id', 'full_name']
        }
      ]
    });

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'الجلسة غير موجودة أو تمت معالجتها مسبقاً'
      });
    }

    if (approve) {
      // الموافقة: تحديث حالة الجلسة إلى "Scheduled"
      await session.update({
        status: 'Scheduled',
        parent_approved: true,
        is_pending: false
      });

      // إرسال إشعار للمختص
      await Notification.create({
        user_id: session.specialist_id,
        title: 'تمت الموافقة على الجلسة',
        message: `تمت موافقة الأهل على الجلسة لطفل ${session.child.full_name} في ${session.date} الساعة ${session.time}.`,
        type: 'session_update',
        related_id: session.session_id,
        is_read: false
      });

      res.status(200).json({
        success: true,
        message: 'تمت الموافقة على الجلسة بنجاح',
        data: {
          session_id: session.session_id,
          status: 'Scheduled'
        }
      });
    } else {
      // الرفض: تحديث حالة الجلسة إلى "Rejected"
      await session.update({
        status: 'Rejected',
        parent_approved: false,
        is_pending: false,
        is_visible: false
      });

      // إرسال إشعار للمختص
      await Notification.create({
        user_id: session.specialist_id,
        title: 'تم رفض الجلسة',
        message: `تم رفض الجلسة لطفل ${session.child.full_name} في ${session.date} الساعة ${session.time} من قبل الأهل.`,
        type: 'session_update',
        related_id: session.session_id,
        is_read: false
      });

      res.status(200).json({
        success: true,
        message: 'تم رفض الجلسة بنجاح',
        data: {
          session_id: session.session_id,
          status: 'Rejected'
        }
      });
    }

  } catch (err) {
    console.error('Error in approveNewSession:', err);
    res.status(500).json({
      success: false,
      message: 'خطأ في معالجة الموافقة',
      error: err.message
    });
  }
};

// ✅ 11. جلب إحصائيات سريعة
exports.getQuickStats = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // جلسات اليوم
    const todaySessions = await Session.count({
      where: {
        specialist_id: specialistId,
        date: today,
        is_visible: true
      }
    });

    // جلسات هذا الأسبوع
    const weekStart = new Date(today);
    weekStart.setDate(weekStart.getDate() - weekStart.getDay());
    
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 6);
    weekEnd.setHours(23, 59, 59, 999);

    const weekSessions = await Session.count({
      where: {
        specialist_id: specialistId,
        date: {
          [Op.between]: [weekStart, weekEnd]
        },
        is_visible: true
      }
    });

    // جلسات معلقة للموافقة
    const pendingSessions = await Session.count({
      where: {
        specialist_id: specialistId,
        status: 'Pending Approval',
        is_visible: true
      }
    });

    // جلسات مكتملة هذا الشهر
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
    const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);
    monthEnd.setHours(23, 59, 59, 999);

    const completedThisMonth = await Session.count({
      where: {
        specialist_id: specialistId,
        status: 'Completed',
        date: {
          [Op.between]: [monthStart, monthEnd]
        },
        is_visible: true
      }
    });

    const stats = {
      todaySessions,
      weekSessions,
      pendingSessions,
      completedThisMonth
    };

    res.status(200).json(stats);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error getting quick stats' });
  }
};
// ✅ ⭐ NEW: جلب الجلسات المطلوب حذفها وتنتظر الموافقة - النسخة المصححة
exports.getDeleteRequestedSessions = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    const deleteRequestedSessions = await Session.findAll({
      where: { 
        specialist_id: specialistId,
        status: 'Cancelled',
        is_visible: false
      },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id'] 
        },
        { 
          model: Institution, 
          as: 'institution',
          attributes: ['institution_id', 'name'] 
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'duration', 'category']
        }
      ],
      attributes: [ // ⭐ تم التصحيح هنا - إزالة createdAt
        'session_id', 
        'date', 
        'time', 
        'status',
        'session_type',
        'delete_request',
        'delete_status',
        'reason'
      ],
      order: [['date', 'ASC'], ['time', 'ASC']]
    });

    res.status(200).json({
      message: 'Delete  sessions retrieved successfully',
      count: deleteRequestedSessions.length,
      sessions: deleteRequestedSessions
    });
  } catch (err) {
    console.error('Get delete  sessions error:', err);
    res.status(500).json({ message: 'Server error retrieving delete  sessions' });
  }
};

// ✅ الحل الصحيح - يرجع البيانات الأصلية والمعدلة معاً
exports.getPendingUpdateRequests = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    // أولاً: نجيب الجلسات المعلقة (الجلسات المعدلة الجديدة)
    const pendingSessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        is_pending: true,
        is_visible: false,
        original_session_id: { [Op.not]: null }
      },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id'] 
        },
        { 
          model: Institution, 
          as: 'institution',
          attributes: ['institution_id', 'name'] 
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'duration', 'category']
        }
      ],
      order: [['session_id', 'DESC']]
    });

    // ثانياً: نجيب بيانات الجلسات الأصلية ونتأكد من الربط
    const sessionsWithOriginalData = await Promise.all(
      pendingSessions.map(async (session) => {
        // 🔥 نجيب الجلسة الأصلية
        const originalSession = await Session.findOne({
          where: { session_id: session.original_session_id },
          include: [
            { 
              model: Child, 
              as: 'child',
              attributes: ['child_id', 'full_name', 'parent_id'] 
            },
            { 
              model: Institution, 
              as: 'institution',
              attributes: ['institution_id', 'name'] 
            }
          ],
          attributes: ['session_id', 'date', 'time', 'status', 'session_type']
        });

        console.log('🔍 Session Debug:');
        console.log('  - Modified Session ID:', session.session_id);
        console.log('  - Original Session ID:', session.original_session_id);
        console.log('  - Found Original:', !!originalSession);
        if (originalSession) {
          console.log('  - Original Date:', originalSession.date);
          console.log('  - Original Time:', originalSession.time);
        }

        // نرجع البيانات مع الجلسة الأصلية
        return {
          // 🔥 بيانات الجلسة المعدلة (الجديدة)
          session_id: session.session_id,
          child: session.child,
          institution: session.institution,
          SessionType: session.SessionType,
          date: session.date,           // الموعد الجديد
          time: session.time,           // الوقت الجديد
          status: session.status,
          session_type: session.session_type,
          is_pending: session.is_pending,
          reason: session.reason,
          original_session_id: session.original_session_id,
          
          // 🔥 بيانات الجلسة الأصلية (القديمة)
          originalSession: originalSession ? {
            session_id: originalSession.session_id,
            date: originalSession.date,     // الموعد القديم
            time: originalSession.time,     // الوقت القديم
            status: originalSession.status,
            session_type: originalSession.session_type,
            child: originalSession.child,
            institution: originalSession.institution
          } : null
        };
      })
    );

    console.log(`✅ Found ${sessionsWithOriginalData.length} pending sessions with original data`);
    
    res.status(200).json(sessionsWithOriginalData);
  } catch (err) {
    console.error('Get pending update requests error:', err);
    res.status(500).json({ message: 'Server error retrieving pending update requests' });
  }
};