const Session = require('../model/Session');
const Child = require('../model/Child');
const User = require('../model/User');
const Parent = require('../model/Parent');
const Specialist = require('../model/Specialist');
const Institution = require('../model/Institution');
const SessionType = require('../model/SessionType');
const Diagnosis = require('../model/Diagnosis');
const Notification = require('../model/Notification');
const NotificationService = require('../services/notificationService');
const UserDeviceToken = require('../model/UserDeviceToken');
const { Op } = require('sequelize');
const { sequelize } = require('../config/db');
const ZoomMeeting = require('../model/ZoomMeeting');
const { createZoomMeeting } = require('../services/zoomService');

const getUpcomingSessionsCount = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    const count = await Session.count({
      where: {
        specialist_id: specialistId,
        date: { [Op.gte]: new Date() },
        status: 'Scheduled'
      }
    });

    res.json({ upcoming_sessions: count });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};


const getChildrenCount = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    const children = await Session.findAll({
      where: { specialist_id: specialistId },
      attributes: ['child_id'],
      group: ['child_id']
    });

    res.json({ children_count: children.length });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};


const getAvailableSlots = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { date } = req.query; 

    if (!date) {
      return res.status(400).json({
        success: false,
        message: 'التاريخ مطلوب'
      });
    }

    const SpecialistSchedule = require('../model/SpecialistSchedule');
    const schedules = await SpecialistSchedule.findAll({
      where: { specialist_id: specialistId },
      attributes: ['day_of_week', 'start_time', 'end_time']
    });

    if (schedules.length === 0) {
      return res.status(200).json({
        success: true,
        message: 'لا يوجد جدول مخصص للمختص',
        data: []
      });
    }

    const targetDate = new Date(date);
    const dayOfWeek = targetDate.toLocaleDateString('en-US', { weekday: 'long' });

    const daySchedule = schedules.find(schedule => 
      schedule.day_of_week === dayOfWeek
    );

    if (!daySchedule) {
      return res.status(200).json({
        success: true,
        message: 'لا يوجد جدول عمل في هذا اليوم',
        data: []
      });
    }

    const availableSlots = generateTimeSlots(
      daySchedule.start_time,
      daySchedule.end_time
    );

    const bookedSessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        date: date,
        status: {
          [Op.notIn]: ['Cancelled', 'Rejected', 'Completed']
        }
      },
      attributes: ['time']
    });

    const bookedTimes = bookedSessions.map(session => {
      const time = session.time;
      return time.substring(0, 5);
    });

    const filteredSlots = availableSlots.filter(slot => 
      !bookedTimes.includes(slot)
    );

    res.status(200).json({
      success: true,
      message: 'تم جلب الأوقات المتاحة بنجاح',
      data: {
        date: date,
        day_of_week: dayOfWeek,
        available_slots: filteredSlots,
        total_available: filteredSlots.length
      }
    });

  } catch (err) {
    console.error('Error in getAvailableSlots:', err);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب الأوقات المتاحة',
      error: err.message
    });
  }
};


const generateTimeSlots = (startTime, endTime) => {
  const slots = [];
  const start = new Date(`1970-01-01T${startTime}`);
  const end = new Date(`1970-01-01T${endTime}`);

  let current = new Date(start);
  
  while (current < end) {
    const hours = current.getHours().toString().padStart(2, '0');
    const minutes = current.getMinutes().toString().padStart(2, '0');
    slots.push(`${hours}:${minutes}`);
    
    current.setMinutes(current.getMinutes() + 30);
  }

  return slots;
};


// ============== Helper Function ==============
async function updateCompletionTableOnSessionAdd(childId, specialistId, institutionId) {
  try {
    const ChildSpecialistCompletion = require('../model/ChildSpecialistCompletion');
    const Child = require('../model/Child');
    
    // 1. البحث عن سجل موجود
    const existingRecord = await ChildSpecialistCompletion.findOne({
      where: {
        child_id: childId,
        specialist_id: specialistId,
        institution_id: institutionId
      }
    });
    
    // 2. تحديث أو إنشاء السجل
    if (existingRecord) {
      await existingRecord.update({
        has_no_active_sessions: false, // أصبحت فيه جلسة نشطة
        status: 'pending',
        updated_at: new Date()
      });
    } else {
      await ChildSpecialistCompletion.create({
        child_id: childId,
        specialist_id: specialistId,
        institution_id: institutionId,
        has_no_active_sessions: false,
        has_final_evaluation: false,
        has_no_pending_requests: true,
        specialist_confirmed: false,
        status: 'pending'
      });
    }
    
    // 3. التحقق إذا الطفل كان مكمل وإعادته لحالة Active
    const child = await Child.findOne({ where: { child_id: childId } });
    if (child && child.registration_status === 'Completed') {
      await child.update({
        registration_status: 'Approved',
        current_institution_id: institutionId,
        updated_at: new Date()
      });
    }
    
    return true;
  } catch (error) {
    console.warn('⚠️ Warning in updateCompletionTableOnSessionAdd:', error.message);
    return false;
  }
}

const addSession = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { child_id, institution_id, date, time, duration = 60, price = 0, session_type = 'Onsite' } = req.body;

    if (!child_id || !date || !time) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    if (duration <= 0) return res.status(400).json({ message: 'Duration must be positive' });
    if (price < 0) return res.status(400).json({ message: 'Price cannot be negative' });

    const sessionDateTime = new Date(`${date}T${time}`);
    if (sessionDateTime < new Date()) return res.status(400).json({ message: 'Cannot schedule session in the past' });

    if (session_type === 'Onsite' && !institution_id) {
      return res.status(400).json({ message: 'Institution is required for onsite sessions' });
    }

    const conflictSession = await Session.findOne({
      where: {
        specialist_id: specialistId,
        date,
        time,
        status: 'Scheduled'
      }
    });
    if (conflictSession) return res.status(400).json({ message: 'You already have a session scheduled at this time' });

    const session = await Session.create({
      child_id,
      specialist_id: specialistId,
      institution_id: institution_id || null,
      date,
      time,
      duration,
      price,
      session_type,
      status: 'Scheduled'
    });

    res.status(201).json({ message: 'Session created successfully', session });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getProfileInfo = async (req, res) => {
  try {
    const userId = req.user.user_id;

    const user = await User.findByPk(userId, {
      attributes: ['full_name', 'profile_picture']
    });

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({
      name: user.full_name,
      avatar: user.profile_picture 
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};
const getChildrenInInstitution = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId }
    });

    if (!specialist || !specialist.institution_id) {
      return res.status(404).json({ message: 'Specialist or institution not found' });
    }

    const sessions = await Session.findAll({
      where: { institution_id: specialist.institution_id },
      attributes: ['child_id'],
      group: ['child_id']
    });

    if (!sessions.length) {
      return res.json([]); 
    }

    const childIds = sessions.map(s => s.child_id);

    const children = await Child.findAll({
      where: { child_id: { [Op.in]: childIds } },
      attributes: ['child_id', 'full_name', 'gender', 'date_of_birth', 'photo']
    });

    res.json(children);
  } catch (err) {
    console.error('Error in getChildrenInInstitution:', err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getImminentSessions = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const now = new Date();
    
    const in5Minutes = new Date(now.getTime() + 5 * 60000);
    const in10Minutes = new Date(now.getTime() + 10 * 60000);

    const imminentSessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        status: 'Scheduled',
        date: now.toISOString().split('T')[0] 
      },
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['full_name', 'photo']
        },
        {
          model: Institution,
          as: 'institution',
          attributes: ['name']
        }
      ],
      order: [
        ['date', 'ASC'],
        ['time', 'ASC']
      ]
    });

    const sessionsIn5Minutes = [];
    const sessionsIn10Minutes = [];

    for (let session of imminentSessions) {
      const sessionDateTime = new Date(`${session.date}T${session.time}`);
      
      if (sessionDateTime > now) {
        const sessionData = session.toJSON();
        
        if (session.session_type === 'Online') {
          const zoomMeeting = await ZoomMeeting.findOne({ 
            where: { session_id: session.session_id } 
          });
          
          if (zoomMeeting) {
            sessionData.zoomMeeting = {
              meeting_id: zoomMeeting.meeting_id,
              join_url: zoomMeeting.join_url,
              start_time: zoomMeeting.start_time,
              topic: zoomMeeting.topic
            };
          } else {
            try {
              const startTime = `${session.date}T${session.time}:00`;
              const meetingData = await createZoomMeeting(
                `Session with ${session.child.full_name}`, 
                startTime
              );

              const newZoomMeeting = await ZoomMeeting.create({
                session_id: session.session_id,
                meeting_id: meetingData.id,
                join_url: meetingData.join_url,
                start_time: meetingData.start_time,
                topic: meetingData.topic
              });

              sessionData.zoomMeeting = {
                meeting_id: newZoomMeeting.meeting_id,
                join_url: newZoomMeeting.join_url,
                start_time: newZoomMeeting.start_time,
                topic: newZoomMeeting.topic
              };
            } catch (zoomError) {
              console.error('Error creating Zoom meeting:', zoomError);
              sessionData.zoomMeeting = null;
            }
          }
        }

        if (sessionDateTime <= in5Minutes) {
          sessionsIn5Minutes.push(sessionData);
        } else if (sessionDateTime <= in10Minutes) {
          sessionsIn10Minutes.push(sessionData);
        }
      }
    }

    res.json({
      has_sessions_in_5_min: sessionsIn5Minutes.length > 0,
      has_sessions_in_10_min: sessionsIn10Minutes.length > 0,
      sessions_in_5_min: sessionsIn5Minutes,
      sessions_in_10_min: sessionsIn10Minutes,
      total_imminent_sessions: sessionsIn5Minutes.length + sessionsIn10Minutes.length,
      current_time: now.toISOString(),
      check_range: {
        in_5_min: in5Minutes.toISOString(),
        in_10_min: in10Minutes.toISOString()
      }
    });

  } catch (err) {
    console.error('Error in getImminentSessions:', err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};
const getEligibleChildren = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId },
      include: [
        {
          model: User,
          attributes: ['full_name']
        }
      ]
    });

    if (!specialist || !specialist.institution_id) {
      return res.status(404).json({ 
        success: false,
        message: 'المختص أو المؤسسة غير موجودة' 
      });
    }

    const specialistSpecialization = specialist.specialization || '';

    const matchingSessionTypes = await SessionType.findAll({
      where: {
        institution_id: specialist.institution_id,
        approval_status: 'Approved',
        specialist_specialization: { [Op.like]: `%${specialistSpecialization}%` }
      },
      attributes: ['session_type_id', 'target_conditions', 'specialist_specialization']
    });

    const targetConditionsSet = new Set();
    matchingSessionTypes.forEach(sessionType => {
      if (sessionType.target_conditions) {
        let conditions = [];
        try {
          if (typeof sessionType.target_conditions === 'string') {
            conditions = JSON.parse(sessionType.target_conditions);
          } else if (Array.isArray(sessionType.target_conditions)) {
            conditions = sessionType.target_conditions;
          }
        } catch (e) {
          console.error('Error parsing target_conditions:', e);
        }
        
        conditions.forEach(condition => {
          if (condition) {
            targetConditionsSet.add(condition.toString().trim());
          }
        });
      }
    });

    if (targetConditionsSet.size === 0) {
      return res.status(200).json({
        success: true,
        message: 'لا توجد أنواع جلسات متطابقة مع تخصص المختص',
        data: [],
        count: 0
      });
    }

    const children = await Child.findAll({
      where: {
        current_institution_id: specialist.institution_id,
        registration_status: 'Approved',
        deleted_at: null
      },
      include: [
        {
          model: Diagnosis,
          as: 'Diagnosis',
          attributes: ['diagnosis_id', 'name']
        },
        {
          model: Parent,
          attributes: ['parent_id']
        }
      ],
      attributes: [
        'child_id', 
        'full_name', 
        'gender', 
        'date_of_birth', 
        'photo',
        'diagnosis_id',
        'suspected_condition'
      ]
    });

    const eligibleChildren = children.filter(child => {
      let childCondition = null;
      
      if (child.diagnosis_id && child.Diagnosis) {
        childCondition = child.Diagnosis.name;
      } else if (child.suspected_condition) {
        childCondition = child.suspected_condition;
      }

      if (!childCondition) {
        return false;
      }

      const childConditionLower = childCondition.toLowerCase().trim();
      for (const targetCondition of targetConditionsSet) {
        const targetConditionLower = targetCondition.toLowerCase().trim();
        if (childConditionLower === targetConditionLower ||
            childConditionLower.includes(targetConditionLower) ||
            targetConditionLower.includes(childConditionLower)) {
          return true;
        }
      }
      
      return false;
    });

    res.status(200).json({
      success: true,
      message: 'تم جلب الأطفال بنجاح',
      data: eligibleChildren.map(child => ({
        child_id: child.child_id,
        full_name: child.full_name,
        gender: child.gender,
        date_of_birth: child.date_of_birth,
        photo: child.photo,
        condition: child.Diagnosis ? child.Diagnosis.name : child.suspected_condition,
        diagnosis_id: child.diagnosis_id
      })),
      count: eligibleChildren.length
    });

  } catch (err) {
    console.error('Error in getEligibleChildren:', err);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في جلب الأطفال', 
      error: err.message 
    });
  }
};

const getAvailableSessionTypes = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { condition } = req.query; 

    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId }
    });

    if (!specialist || !specialist.institution_id) {
      return res.status(404).json({ 
        success: false,
        message: 'المختص أو المؤسسة غير موجودة' 
      });
    }

    const specialistSpecialization = specialist.specialization || '';

    const whereClause = {
      institution_id: specialist.institution_id,
      approval_status: 'Approved', 
      specialist_specialization: { [Op.like]: `%${specialistSpecialization}%` }
    };

    const sessionTypes = await SessionType.findAll({
      where: whereClause,
      attributes: [
        'session_type_id',
        'name',
        'duration',
        'price',
        'category',
        'specialist_specialization',
        'target_conditions'
      ],
      order: [['name', 'ASC']]
    });

    let filteredSessionTypes = sessionTypes;
    if (condition) {
      filteredSessionTypes = sessionTypes.filter(sessionType => {
        if (!sessionType.target_conditions) {
          return false;
        }

        let targetConditions = [];
        try {
          if (typeof sessionType.target_conditions === 'string') {
            targetConditions = JSON.parse(sessionType.target_conditions);
          } else if (Array.isArray(sessionType.target_conditions)) {
            targetConditions = sessionType.target_conditions;
          }
        } catch (e) {
          return false;
        }

        const conditionLower = condition.toLowerCase().trim();
        return targetConditions.some(targetCondition => {
          const targetConditionLower = targetCondition.toString().toLowerCase().trim();
          return targetConditionLower === conditionLower ||
                 targetConditionLower.includes(conditionLower) ||
                 conditionLower.includes(targetConditionLower);
        });
      });
    }

    res.status(200).json({
      success: true,
      message: 'تم جلب أنواع الجلسات بنجاح',
      data: filteredSessionTypes,
      count: filteredSessionTypes.length
    });

  } catch (err) {
    console.error('Error in getAvailableSessionTypes:', err);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في جلب أنواع الجلسات', 
      error: err.message 
    });
  }
};

const addSessionsForChildren = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { 
      child_ids, 
      session_type_id,
      date, 
      time, 
      session_type = 'Onsite',
      notes 
    } = req.body;

    if (!child_ids || !Array.isArray(child_ids) || child_ids.length === 0) {
      return res.status(400).json({ 
        success: false,
        message: 'يجب تحديد طفل واحد على الأقل' 
      });
    }

    if (!session_type_id || !date || !time) {
      return res.status(400).json({ 
        success: false,
        message: 'الحقول المطلوبة: session_type_id, date, time' 
      });
    }

    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId }
    });

    if (!specialist || !specialist.institution_id) {
      return res.status(404).json({ 
        success: false,
        message: 'المختص أو المؤسسة غير موجودة' 
      });
    }

    const sessionType = await SessionType.findOne({
      where: {
        session_type_id,
        institution_id: specialist.institution_id,
        approval_status: 'Approved'
      }
    });

    if (!sessionType) {
      return res.status(404).json({ 
        success: false,
        message: 'نوع الجلسة غير موجود أو غير موافق عليه' 
      });
    }

    const children = await Child.findAll({
      where: {
        child_id: { [Op.in]: child_ids },
        current_institution_id: specialist.institution_id,
        registration_status: 'Approved',
        deleted_at: null
      },
      include: [
        {
          model: Parent,
          attributes: ['parent_id']
        }
      ]
    });

    if (children.length !== child_ids.length) {
      return res.status(400).json({ 
        success: false,
        message: 'بعض الأطفال غير موجودين أو غير مسجلين في المؤسسة' 
      });
    }

    const sessionDateTime = new Date(`${date}T${time}`);
    if (sessionDateTime < new Date()) {
      return res.status(400).json({ 
        success: false,
        message: 'لا يمكن جدولة جلسة في الماضي' 
      });
    }

    const dayOfWeek = sessionDateTime.toLocaleDateString('en-US', { weekday: 'long' });
    const SpecialistSchedule = require('../model/SpecialistSchedule');
    
    const specialistSchedule = await SpecialistSchedule.findOne({
      where: {
        specialist_id: specialistId,
        day_of_week: dayOfWeek
      }
    });

    if (!specialistSchedule) {
      return res.status(400).json({ 
        success: false,
        message: 'لا يوجد جدول عمل للمختص في هذا اليوم' 
      });
    }

    const sessionTime = time.substring(0, 5); 
    const scheduleStart = specialistSchedule.start_time.substring(0, 5);
    const scheduleEnd = specialistSchedule.end_time.substring(0, 5);

    if (sessionTime < scheduleStart || sessionTime >= scheduleEnd) {
      return res.status(400).json({ 
        success: false,
        message: `الوقت المحدد خارج ساعات العمل (${scheduleStart} - ${scheduleEnd})` 
      });
    }

    const conflictSessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        date,
        time: { [Op.like]: `${sessionTime}%` }, 
        status: { 
          [Op.notIn]: ['Cancelled', 'Rejected', 'Completed', 'Pending Approval'] 
        }
      }
    });

    if (conflictSessions.length > 0) {
      return res.status(400).json({ 
        success: false,
        message: 'هذا الوقت محجوز مسبقاً' 
      });
    }

   const createdSessions = [];
    const notifications = [];

    console.log('🔔 Preparing to send notifications to parents...');

    for (const child of children) {
      const session = await Session.create({
        child_id: child.child_id,
        specialist_id: specialistId,
        institution_id: specialist.institution_id,
        session_type_id,
        date,
        time: `${sessionTime}:00`, 
        session_type,
        status: 'Pending Approval', 
        parent_approved: null, 
        is_pending: true,
        parent_notes: notes || null,
        original_price: sessionType.price,
        final_price: sessionType.price,
        applied_discount_percentage: 0,
        financial_assistance_applied: false
      });
      
      await updateCompletionTableOnSessionAdd(
        child.child_id,
        specialistId,
        specialist.institution_id
      );
      
      let financialAidResult = null;
      try {
        const AutoFinancialAidService = require('../services/autoFinancialAidService');
        financialAidResult = await AutoFinancialAidService.autoApplyFinancialAid(session.session_id);
        
        console.log(`✅ Auto financial aid for session ${session.session_id}:`, 
          financialAidResult.auto_applied ? 
          `Discount ${financialAidResult.discount_percentage}% - Final price: ${financialAidResult.final_price}` : 
          'No discount');
        
      } catch (aidError) {
        console.error(`❌ Error in financial aid for session ${session.session_id}:`, aidError);
      }

      // ==================== 🔥 NOTIFICATION SECTION ====================
      if (child.Parent && child.Parent.parent_id) {
        let notificationMessage = `A new session has been created for your child ${child.full_name} on ${date} at ${sessionTime}. `;
        
        if (financialAidResult && financialAidResult.auto_applied) {
          if (financialAidResult.final_price === 0) {
            notificationMessage += `🎉 Good news: the session is free of charge!`;
          } else if (financialAidResult.discount_percentage > 0) {
            notificationMessage += `💰 Good news: an automatic discount of ${financialAidResult.discount_percentage}% was applied. Final price: ${financialAidResult.final_price}.`;
          }
        } else {
          notificationMessage += `Price: ${sessionType.price}.`;
        }
        
        notificationMessage += `\nPlease approve or reject as soon as possible.`;

        // 🔥 Send FCM push notifications
        try {
          const tokens = await UserDeviceToken.findAll({
            where: { user_id: child.Parent.parent_id, is_active: true },
            attributes: ['token']
          });
          const uniqueTokens = [...new Set(tokens.map(t => t.token))];

          // 1. FCM Notification (simple)
          const fcmMessage = `New session created for ${child.full_name} on ${date} at ${sessionTime}`;
          
          for (const fcmToken of uniqueTokens) {
            if (fcmToken && fcmToken.trim() !== '') {
              await NotificationService.sendToToken(
                fcmToken,
                '📅 New Session Created',
                fcmMessage,
                {
                  type: 'session_created',
                  childId: child.child_id.toString(),
                  childName: child.full_name,
                  sessionId: session.session_id.toString(),
                  date: date,
                  time: sessionTime,
                  action: 'view_session',
                  channel: 'default_channel'
                }
              );
              console.log(`✅ FCM sent to parent for ${child.full_name}`);
            }
          }
          
          // 2. In-app notification (with financial details)
          const notification = await Notification.create({
            user_id: child.Parent.parent_id,
            title: 'New Session Approval Request',
            message: notificationMessage,
            type: financialAidResult && financialAidResult.auto_applied ? 'auto_financial_aid' : 'session_update',
            related_id: session.session_id,
            is_read: false,
            metadata: financialAidResult || {}
          });
          notifications.push(notification);
          
        } catch (pushErr) {
          console.error('❌ Error sending push to parent:', pushErr);
          
          // Fallback: create in-app notification only
          const notification = await Notification.create({
            user_id: child.Parent.parent_id,
            title: 'New Session Approval Request',
            message: notificationMessage,
            type: financialAidResult && financialAidResult.auto_applied ? 'auto_financial_aid' : 'session_update',
            related_id: session.session_id,
            is_read: false,
            metadata: financialAidResult || {}
          });
          notifications.push(notification);
        }
      }
      // ==================== END NOTIFICATION SECTION ====================

      createdSessions.push({
        ...session.toJSON(),
        financial_aid_applied: financialAidResult?.auto_applied || false,
        discount_percentage: financialAidResult?.discount_percentage || 0,
        final_price: financialAidResult?.final_price || sessionType.price
      });
    }

    // Notification for specialist
    await Notification.create({
      user_id: specialistId,
      title: 'New sessions created',
      message: `Created ${createdSessions.length} session(s) on ${date} at ${sessionTime}. ${createdSessions.filter(s => s.financial_aid_applied).length} sessions received automatic financial aid.`,
      type: 'sessions_created',
      related_id: null,
      is_read: false
    });

    // Log notification summary
    console.log('📊 Notification Summary:');
    console.log(`   - Sessions created: ${createdSessions.length}`);
    console.log(`   - Parents notified: ${notifications.length}`);
    console.log(`   - Financial aid applied: ${createdSessions.filter(s => s.financial_aid_applied).length}`);

    res.status(201).json({
      success: true,
      message: `Successfully created ${createdSessions.length} sessions`,
      data: {
        sessions: createdSessions,
        summary: {
          total: createdSessions.length,
          with_financial_aid: createdSessions.filter(s => s.financial_aid_applied).length,
          total_discount: createdSessions.reduce((sum, session) => sum + (session.financial_aid_applied ? session.discount_percentage : 0), 0),
          estimated_total_original: createdSessions.reduce((sum, session) => sum + parseFloat(sessionType.price), 0),
          estimated_total_final: createdSessions.reduce((sum, session) => sum + parseFloat(session.final_price || sessionType.price), 0),
          total_savings: createdSessions.reduce((sum, session) => sum + (session.financial_aid_applied ? (parseFloat(sessionType.price) - parseFloat(session.final_price || sessionType.price)) : 0), 0)
        }
      }
    });

  } catch (err) {
    console.error('Error in addSessionsForChildren:', err);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في إنشاء الجلسات', 
      error: err.message 
    });
  }
};


const addSessionType = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const {
      name,
      duration,
      price,
      category, 
      target_conditions
    } = req.body;

    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId }
    });

    if (!specialist || !specialist.institution_id) {
      return res.status(404).json({ 
        success: false,
        message: 'Specialist or institution not found' 
      });
    }

    const sessionType = await SessionType.create({
      institution_id: specialist.institution_id,
      name,
      duration: parseInt(duration),
      price: parseFloat(price),
      category: specialist.specialization || 'General', 
      specialist_specialization: specialist.specialization || '',
      target_conditions: target_conditions || null,
      approval_status: 'Pending',
      created_by_specialist_id: specialistId
    });

    const Manager = require('../model/Manager');
    const managers = await Manager.findAll({
      where: {
        institution_id: specialist.institution_id,
        is_active: true
      }
    });

    for (const manager of managers) {
      await Notification.create({
        user_id: manager.manager_id,
        title: 'New Session Type Approval Request',
        message: `Specialist ${specialist.specialization} requested to add new session type: ${name}. Please review and approve.`,
        type: 'general',
        related_id: sessionType.session_type_id,
        is_read: false
      });
    }

    res.status(201).json({
      success: true,
      message: 'Session type request sent for admin approval',
      data: sessionType
    });

  } catch (err) {
    console.error('Error in addSessionType:', err);
    res.status(500).json({ 
      success: false,
      message: 'Error adding session type', 
      error: err.message 
    });
  }
};

module.exports = {
  getUpcomingSessionsCount,
  getChildrenCount,
  addSession,
  getProfileInfo,
  getChildrenInInstitution,
  getImminentSessions,
  getEligibleChildren,
  getAvailableSessionTypes,
  addSessionsForChildren,
  addSessionType,
  getAvailableSlots ,
  updateCompletionTableOnSessionAdd 

};