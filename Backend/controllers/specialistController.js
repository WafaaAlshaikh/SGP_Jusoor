const Session = require('../model/Session');
const Child = require('../model/Child');
const User = require('../model/User');
const Parent = require('../model/Parent');
const Specialist = require('../model/Specialist');
const Institution = require('../model/Institution');
const SessionType = require('../model/SessionType');
const Diagnosis = require('../model/Diagnosis');
const Notification = require('../model/Notification');
const { Op } = require('sequelize');
const { sequelize } = require('../config/db');
const ZoomMeeting = require('../model/ZoomMeeting');
const { createZoomMeeting } = require('../services/zoomService');
// ✅ 1. عدد الجلسات القادمة
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

// ✅ 2. عدد الأطفال الفريدين اللي عندهم جلسات مع الأخصائي
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

// ✅ 3. إضافة جلسة جديدة
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

    // 1️⃣ نجيب بيانات الأخصائي حتى نعرف لأي مؤسسة تابع
    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId }
    });

    if (!specialist || !specialist.institution_id) {
      return res.status(404).json({ message: 'Specialist or institution not found' });
    }

    // 2️⃣ نجيب كل الـ child_id اللي ظهروا في جلسات داخل نفس المؤسسة
    const sessions = await Session.findAll({
      where: { institution_id: specialist.institution_id },
      attributes: ['child_id'],
      group: ['child_id']
    });

    if (!sessions.length) {
      return res.json([]); // ما في أطفال بهالمؤسسة
    }

    const childIds = sessions.map(s => s.child_id);

    // 3️⃣ نجيب بيانات الأطفال من جدول Children
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
    
    // نحسب الوقت بعد 5 و10 دقائق
    const in5Minutes = new Date(now.getTime() + 5 * 60000);
    const in10Minutes = new Date(now.getTime() + 10 * 60000);

    // بديل أبسط وأكثر موثوقية
    const imminentSessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        status: 'Scheduled',
        date: now.toISOString().split('T')[0] // نفس اليوم
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

    // نفلتر الجلسات يدوياً بناءً على الوقت
    const sessionsIn5Minutes = [];
    const sessionsIn10Minutes = [];

    // 🔥 نضيف: نجلب تفاصيل الزوم ميتينج للجلسات الأونلاين
    for (let session of imminentSessions) {
      const sessionDateTime = new Date(`${session.date}T${session.time}`);
      
      // نتأكد أن الجلسة في المستقبل (ليست ماضية)
      if (sessionDateTime > now) {
        const sessionData = session.toJSON();
        
        // 🔥 إذا كانت الجلسة أونلاين، نجلب تفاصيل الزوم ميتينج
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
            // 🔥 إذا ما في meeting، ننشئ واحد جديد
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
// ✅ جلب الأطفال المسجلين في نفس المؤسسة والذين يعانون من الحالة التي يختص بها المختص
const getEligibleChildren = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    // 1️⃣ جلب بيانات المختص
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

    // 2️⃣ جلب أنواع الجلسات المتاحة التي تطابق تخصص المختص
    const matchingSessionTypes = await SessionType.findAll({
      where: {
        institution_id: specialist.institution_id,
        approval_status: 'Approved',
        specialist_specialization: { [Op.like]: `%${specialistSpecialization}%` }
      },
      attributes: ['session_type_id', 'target_conditions', 'specialist_specialization']
    });

    // 3️⃣ جمع جميع الحالات المستهدفة من أنواع الجلسات المتطابقة
    const targetConditionsSet = new Set();
    matchingSessionTypes.forEach(sessionType => {
      if (sessionType.target_conditions) {
        // target_conditions هو JSON array
        let conditions = [];
        try {
          // إذا كان string، نحوله إلى array
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

    // إذا لم نجد أنواع جلسات متطابقة، نرجع قائمة فارغة
    if (targetConditionsSet.size === 0) {
      return res.status(200).json({
        success: true,
        message: 'لا توجد أنواع جلسات متطابقة مع تخصص المختص',
        data: [],
        count: 0
      });
    }

    // 4️⃣ جلب الأطفال المسجلين في نفس المؤسسة
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

    // 5️⃣ فلترة الأطفال: نتحقق من أن diagnosis الطفل موجود في target_conditions
    const eligibleChildren = children.filter(child => {
      let childCondition = null;
      
      // الحصول على حالة الطفل من diagnosis أو suspected_condition
      if (child.diagnosis_id && child.Diagnosis) {
        childCondition = child.Diagnosis.name;
      } else if (child.suspected_condition) {
        childCondition = child.suspected_condition;
      }

      if (!childCondition) {
        return false;
      }

      // التحقق من أن حالة الطفل موجودة في target_conditions
      const childConditionLower = childCondition.toLowerCase().trim();
      for (const targetCondition of targetConditionsSet) {
        const targetConditionLower = targetCondition.toLowerCase().trim();
        // مقارنة مرنة (يحتوي أو متطابق)
        if (childConditionLower === targetConditionLower ||
            childConditionLower.includes(targetConditionLower) ||
            targetConditionLower.includes(childConditionLower)) {
          return true;
        }
      }
      
      return false;
    });

    // 6️⃣ إرجاع النتائج
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

// ✅ جلب أنواع الجلسات المتاحة حسب الحالة
const getAvailableSessionTypes = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { condition } = req.query; // اسم الحالة (مثل 'ASD', 'ADHD')

    // 1️⃣ جلب بيانات المختص
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

    // 2️⃣ جلب أنواع الجلسات المتاحة في المؤسسة التي تطابق تخصص المختص
    const whereClause = {
      institution_id: specialist.institution_id,
      approval_status: 'Approved', // فقط الجلسات الموافق عليها
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

    // 3️⃣ إذا تم تحديد حالة، نفلتر حسب target_conditions
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

// ✅ تحديث دالة إضافة الجلسة لدعم عدة أطفال وطلب موافقة الأهل
const addSessionsForChildren = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { 
      child_ids, // مصفوفة من IDs الأطفال
      session_type_id,
      date, 
      time, 
      session_type = 'Onsite',
      notes 
    } = req.body;

    // التحقق من الحقول المطلوبة
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

    // 1️⃣ جلب بيانات المختص
    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId }
    });

    if (!specialist || !specialist.institution_id) {
      return res.status(404).json({ 
        success: false,
        message: 'المختص أو المؤسسة غير موجودة' 
      });
    }

    // 2️⃣ التحقق من نوع الجلسة
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

    // 3️⃣ التحقق من الأطفال
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

    // 4️⃣ التحقق من عدم وجود تعارض في المواعيد
    const sessionDateTime = new Date(`${date}T${time}`);
    if (sessionDateTime < new Date()) {
      return res.status(400).json({ 
        success: false,
        message: 'لا يمكن جدولة جلسة في الماضي' 
      });
    }

    const conflictSessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        date,
        time,
        status: { [Op.notIn]: ['Cancelled', 'Rejected', 'Completed'] }
      }
    });

    if (conflictSessions.length > 0) {
      return res.status(400).json({ 
        success: false,
        message: 'لديك جلسة أخرى في نفس الوقت' 
      });
    }

    // 5️⃣ إنشاء الجلسات للأطفال
    const createdSessions = [];
    const notifications = [];

    for (const child of children) {
      // إنشاء الجلسة بحالة "Pending Approval" (بانتظار موافقة الأهل)
      const session = await Session.create({
        child_id: child.child_id,
        specialist_id: specialistId,
        institution_id: specialist.institution_id,
        session_type_id,
        date,
        time,
        session_type,
        status: 'Pending Approval', // بانتظار موافقة الأهل
        parent_approved: null, // null = بانتظار الموافقة
        is_pending: true,
        parent_notes: notes || null
      });

      createdSessions.push(session);

      // إرسال إشعار للأهل
      if (child.Parent && child.Parent.parent_id) {
        const notification = await Notification.create({
          user_id: child.Parent.parent_id,
          title: 'طلب موافقة على جلسة جديدة',
          message: `تم إنشاء جلسة جديدة لطفلك ${child.full_name} في ${date} الساعة ${time}. يرجى الموافقة أو الرفض.`,
          type: 'session_update',
          related_id: session.session_id,
          is_read: false
        });
        notifications.push(notification);
      }
    }

    res.status(201).json({
      success: true,
      message: `تم إنشاء ${createdSessions.length} جلسة بنجاح وتم إرسال طلبات الموافقة للأهل`,
      data: {
        sessions: createdSessions,
        count: createdSessions.length
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

// ✅ إضافة نوع جلسة جديد (بحاجة لموافقة المدير)
const addSessionType = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const {
      name,
      duration,
      price,
      category,
      target_conditions // مصفوفة من الحالات المستهدفة
    } = req.body;

    // التحقق من الحقول المطلوبة
    if (!name || !duration || !price || !category) {
      return res.status(400).json({ 
        success: false,
        message: 'الحقول المطلوبة: name, duration, price, category' 
      });
    }

    // 1️⃣ جلب بيانات المختص
    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId }
    });

    if (!specialist || !specialist.institution_id) {
      return res.status(404).json({ 
        success: false,
        message: 'المختص أو المؤسسة غير موجودة' 
      });
    }

    // 2️⃣ إنشاء نوع الجلسة بحالة "Pending"
    const sessionType = await SessionType.create({
      institution_id: specialist.institution_id,
      name,
      duration: parseInt(duration),
      price: parseFloat(price),
      category,
      specialist_specialization: specialist.specialization || '',
      target_conditions: target_conditions || null,
      approval_status: 'Pending', // بانتظار موافقة المدير
      created_by_specialist_id: specialistId
    });

    // 3️⃣ إرسال إشعار للمديرين في المؤسسة
    const Manager = require('../model/Manager');
    const managers = await Manager.findAll({
      where: {
        institution_id: specialist.institution_id,
        is_active: true
      },
      include: [
        {
          model: User,
          attributes: ['user_id']
        }
      ]
    });

    for (const manager of managers) {
      await Notification.create({
        user_id: manager.manager_id,
        title: 'طلب موافقة على نوع جلسة جديد',
        message: `طلب المختص ${specialist.specialization} إضافة نوع جلسة جديد: ${name}. يرجى المراجعة والموافقة.`,
        type: 'general',
        related_id: sessionType.session_type_id,
        is_read: false
      });
    }

    res.status(201).json({
      success: true,
      message: 'تم إرسال طلب إضافة نوع الجلسة للمدير للموافقة',
      data: sessionType
    });

  } catch (err) {
    console.error('Error in addSessionType:', err);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في إضافة نوع الجلسة', 
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
  addSessionType
};