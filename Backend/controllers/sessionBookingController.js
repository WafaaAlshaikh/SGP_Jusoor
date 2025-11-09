// controllers/sessionBookingController.js
const Session = require('../model/Session');
const SessionType = require('../model/SessionType');
const Specialist = require('../model/Specialist');
const SpecialistSchedule = require('../model/SpecialistSchedule');
const Child = require('../model/Child');
const Institution = require('../model/Institution');
const User = require('../model/User');
const Diagnosis = require('../model/Diagnosis');
const Invoice = require('../model/Invoice');
const Payment = require('../model/Payment');
const PaymentGateway = require('../services/paymentGateway');

const { Op } = require('sequelize');

// ================= HELPER: إنشاء فاتورة تلقائياً =================
async function createInvoiceForSession(session, child) {
  try {
    // جلب معلومات نوع الجلسة
    const sessionType = await SessionType.findByPk(session.session_type_id);
    if (!sessionType) {
      throw new Error('Session type not found');
    }

    // حساب المبلغ
    const amount = parseFloat(sessionType.price);
    const taxAmount = 0; // يمكن إضافة ضريبة لاحقاً
    const totalAmount = amount + taxAmount;

    // توليد رقم فاتورة فريد
    const invoiceNumber = `INV-${Date.now()}-${session.session_id}`;

    // تاريخ الاستحقاق (3 أيام من تاريخ الجلسة)
    const dueDate = new Date(session.date);
    dueDate.setDate(dueDate.getDate() + 3);

    // إنشاء الفاتورة
    const invoice = await Invoice.create({
      session_id: session.session_id,
      parent_id: child.parent_id,
      institution_id: session.institution_id,
      invoice_number: invoiceNumber,
      amount: amount,
      tax_amount: taxAmount,
      total_amount: totalAmount,
      status: 'Pending',
      due_date: dueDate,
      issued_date: new Date(),
      notes: `Invoice for ${sessionType.name} session on ${session.date}`
    });

    console.log(`✅ Invoice created: ${invoiceNumber} for session ${session.session_id}`);
    return invoice;
  } catch (error) {
    console.error('❌ Error creating invoice:', error);
    throw error;
  }
}

// ================= GET AVAILABLE SLOTS =================
exports.getAvailableSlots = async (req, res) => {
  try {
    const { institution_id, session_type_id, date } = req.query;

    console.log('🔍 Searching for:', { institution_id, session_type_id, date });

    // 1. جلب نوع الجلسة المطلوبة
    const sessionType = await SessionType.findByPk(session_type_id);
    if (!sessionType) {
      return res.status(404).json({ message: 'Session type not found' });
    }

    console.log('📋 Session Type:', sessionType.name, 'Specialization:', sessionType.specialist_specialization);

    // 2. جلب الأخصائيين المناسبين
    const specialists = await Specialist.findAll({
      where: { 
        institution_id,
        specialization: sessionType.specialist_specialization,
        approval_status: 'Approved'
      },
      include: [
        {
          model: require('../model/User'),
          attributes: ['full_name', 'user_id']
        }
      ]
    });

    console.log('👨‍⚕️ Found Specialists:', specialists.length);
    specialists.forEach(s => console.log(' -', s.User.full_name, '-', s.specialization));

    // 3. جلب الجداول الزمنية للأخصائيين
    const specialistIds = specialists.map(s => s.specialist_id);
    const schedules = await SpecialistSchedule.findAll({
      where: { specialist_id: { [Op.in]: specialistIds } }
    });

    console.log('📅 Found Schedules:', schedules.length);
    schedules.forEach(s => console.log(' -', s.day_of_week, s.start_time, '-', s.end_time));

    // 4. جلب الجلسات المحجوزة مسبقاً
    const bookedSessions = await Session.findAll({
      where: { 
        institution_id,
        date,
        status: { [Op.in]: ['Scheduled', 'Confirmed'] }
      },
      attributes: ['specialist_id', 'time']
    });

    console.log('⏰ Booked Sessions:', bookedSessions.length);
    bookedSessions.forEach(s => console.log(' - Specialist:', s.specialist_id, 'Time:', s.time));

    // 5. توليد الأوقات المتاحة
    const availableSlots = [];
    
    schedules.forEach(schedule => {
      const specialist = specialists.find(s => s.specialist_id === schedule.specialist_id);
      const start = new Date(`1970-01-01T${schedule.start_time}`);
      const end = new Date(`1970-01-01T${schedule.end_time}`);
      
      console.log(`🕒 Processing schedule for ${specialist.User.full_name}: ${schedule.day_of_week} ${schedule.start_time}-${schedule.end_time}`);

      // توليد slots كل 30 دقيقة
      for (let time = new Date(start); time < end; time.setMinutes(time.getMinutes() + 30)) {
        const slotTime = time.toTimeString().slice(0, 5);
        const slotEnd = new Date(time.getTime() + sessionType.duration * 60000);
        
        // التحقق إذا الوقت ضمن نهاية الدوام
        if (slotEnd <= end) {
          // التحقق إذا ماحجوز
          const isBooked = bookedSessions.some(session => 
            session.specialist_id === schedule.specialist_id &&
            session.time === slotTime
          );
          
          if (!isBooked) {
            console.log('✅ Available Slot:', slotTime, '-', specialist.User.full_name);
            availableSlots.push({
              specialist_id: schedule.specialist_id,
              specialist_name: specialist.User.full_name,
              day_of_week: schedule.day_of_week,
              time: slotTime,
              duration: sessionType.duration,
              price: sessionType.price,
              session_type_id: session_type_id
            });
          } else {
            console.log('❌ Booked Slot:', slotTime, '-', specialist.User.full_name);
          }
        }
      }
    });

    console.log('🎯 Final Available Slots:', availableSlots.length);

    res.status(200).json({
      session_type: sessionType.name,
      available_slots: availableSlots
    });

  } catch (error) {
    console.error('Error fetching available slots:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// ================= BOOK SESSION =================
// controllers/sessionBookingController.js
exports.bookSession = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { 
      child_id, 
      institution_id, 
      session_type_id, 
      specialist_id, 
      date, 
      time,
      parent_notes 
    } = req.body;

    // التحقق من البيانات
    const child = await Child.findOne({
      where: { 
        child_id,
        parent_id: parentId,
        current_institution_id: institution_id,
        registration_status: 'Approved'
      }
    });

    if (!child) {
      return res.status(400).json({ 
        message: 'Child is not registered in this institution or not approved' 
      });
    }

    // جلب نوع الجلسة والسعر
    const sessionType = await SessionType.findOne({
      where: { 
        session_type_id,
        institution_id 
      }
    });
    
    if (!sessionType) {
      return res.status(400).json({ 
        message: 'Session type not found in this institution' 
      });
    }

    // NEW LOGIC: تحقق من وجود حجوزات سابقة تمت الموافقة عليها
    const previousApprovedSessions = await Session.count({
      where: {
        child_id,
        institution_id,
        status: 'Approved' // جلسات تمت الموافقة عليها من المدير
      }
    });

    const isFirstBooking = previousApprovedSessions === 0;

    // NEW LOGIC: تحديد الحالة بناءً على أول حجز أو لا
    let sessionStatus;
    let responseMessage;

    if (isFirstBooking) {
      // أول مرة → يذهب للمدير
      sessionStatus = 'Pending Manager Approval';
      responseMessage = 'Session booked successfully - pending manager approval (first booking)';
    } else {
      // ليس أول مرة → موافقة تلقائية ثم انتظار الدفع
      sessionStatus = 'Pending Payment';
      responseMessage = 'Session booked and approved - please proceed with payment';
    }

    // إنشاء الجلسة
    const newSession = await Session.create({
      child_id,
      specialist_id,
      institution_id,
      session_type_id,
      date,
      time,
      session_type: 'Onsite',
      status: sessionStatus,
      requested_by_parent: true,
      parent_notes: parent_notes || null,
      is_first_booking: isFirstBooking
    });

    // إنشاء فاتورة تلقائياً إذا كانت الحالة Pending Payment
    let invoiceId = null;
    if (sessionStatus === 'Pending Payment') {
      try {
        const invoice = await createInvoiceForSession(newSession, child);
        invoiceId = invoice.invoice_id;
        console.log(`📄 Invoice ${invoiceId} created for session ${newSession.session_id}`);
      } catch (invoiceError) {
        console.error('⚠️ Failed to create invoice, but session was created:', invoiceError);
      }
    }

    res.status(201).json({
      success: true,
      message: responseMessage,
      session_id: newSession.session_id,
      status: sessionStatus,
      is_first_booking: isFirstBooking,
      requires_manager_approval: isFirstBooking,
      invoice_id: invoiceId, // ⬅️ إرجاع invoice_id
      session_details: {
        duration: sessionType.duration,
        price: sessionType.price,
        session_type_name: sessionType.name
      }
    });

  } catch (error) {
    console.error('Error booking session:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};
// ================= GET SESSION DETAILS =================
exports.getSessionDetails = async (req, res) => {
  try {
    const { session_id } = req.params;

    const session = await Session.findByPk(session_id, {
      include: [
        {
          model: SessionType,
          attributes: ['name', 'duration', 'price', 'category']
        },
        {
          model: require('../model/User'),
          as: 'specialist',
          attributes: ['full_name']
        },
        {
          model: Child,
          as: 'child',
          attributes: ['full_name']
        },
        {
          model: Institution,
          as: 'institution',
          attributes: ['name']
        }
      ]
    });

    if (!session) {
      return res.status(404).json({ message: 'Session not found' });
    }

    res.status(200).json({
      session_id: session.session_id,
      date: session.date,
      time: session.time,
      status: session.status,
      session_type: session.SessionType.name,
      duration: session.SessionType.duration,
      price: session.SessionType.price,
      specialist_name: session.specialist.full_name,
      child_name: session.child.full_name,
      institution_name: session.institution.name,
      requested_by_parent: session.requested_by_parent,
      parent_notes: session.parent_notes
    });

  } catch (error) {
    console.error('Error fetching session details:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// ================= GET INSTITUTION SESSION TYPES =================

// controllers/sessionBookingController.js

// ================= GET INSTITUTION SESSION TYPES =================
exports.getInstitutionSessionTypes = async (req, res) => {
  try {
    const { institution_id } = req.params;
    const { child_id } = req.query; // ⬅️ نأخذ child_id من query parameters

    if (!child_id) {
      return res.status(400).json({ 
        message: 'Child ID is required to get suitable session types' 
      });
    }

    // 1. جلب بيانات الطفل للتأكد من المؤسسة والتشخيص
    const child = await Child.findOne({
      where: { 
        child_id: child_id,
        registration_status: 'Approved'
      },
      include: [
        {
          model: Diagnosis,
          attributes: ['name'],
          as: 'Diagnosis',
          required: false
        }
      ]
    });

    if (!child) {
      return res.status(404).json({ message: 'Child not found or not approved' });
    }

    // 2. التأكد أن الطفل مسجل في نفس المؤسسة
    if (child.current_institution_id !== parseInt(institution_id)) {
      return res.status(400).json({ 
        message: 'Child is not registered in this institution' 
      });
    }

    // 3. جلب أنواع الجلسات المناسبة
    let whereClause = { institution_id };

    // إذا كان للطفل تشخيص، نفلتر الجلسات المناسبة
    if (child.Diagnosis && child.Diagnosis.name) {
      const childCondition = child.Diagnosis.name;
      
      whereClause = {
        ...whereClause,
        [Op.or]: [
          { target_conditions: null }, // الجلسات المناسبة لجميع الحالات
          { target_conditions: { [Op.contains]: [childCondition] } }, // الجلسات المخصصة لحالة الطفل
          { target_conditions: { [Op.eq]: [] } } // إذا كانت مصفوفة فارغة
        ]
      };
    }

    const sessionTypes = await SessionType.findAll({
      where: whereClause,
      attributes: [
        'session_type_id', 
        'name', 
        'duration', 
        'price', 
        'category', 
        // 'description',
        'target_conditions', // ⬅️ نعيد هذا الحقل للفرونتند
        'specialist_specialization'
      ]
    });

    // 4. إضافة معلومات إضافية للاستجابة
    const enhancedSessionTypes = sessionTypes.map(sessionType => ({
      ...sessionType.get({ plain: true }),
      is_suitable: true, // كل الجلسات المعروضة مناسبة
      suitability_reason: child.Diagnosis ? 
        `Suitable for ${child.Diagnosis.name}` : 
        'Suitable for all conditions'
    }));

    res.status(200).json({
      success: true,
      child_info: {
        child_id: child.child_id,
        child_name: child.full_name,
        diagnosis: child.Diagnosis ? child.Diagnosis.name : 'Not diagnosed',
        institution_id: child.current_institution_id
      },
      session_types: enhancedSessionTypes,
      total_count: enhancedSessionTypes.length
    });

  } catch (error) {
    console.error('Error fetching session types:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};


// controllers/sessionBookingController.js

// ================= GET SUITABLE SESSION TYPES FOR CHILD =================
// controllers/sessionBookingController.js

// ================= GET SUITABLE SESSION TYPES FOR CHILD =================
exports.getSuitableSessionTypes = async (req, res) => {
  try {
    const { child_id } = req.params;
    const parentId = req.user.user_id;

    console.log('🔍 Getting session types for child:', child_id);

    // 1. جلب بيانات الطفل مع المؤسسة والتشخيص
    const child = await Child.findOne({
      where: { 
        child_id: child_id,
        parent_id: parentId,
        registration_status: 'Approved'
      },
      include: [
        {
          model: Diagnosis,
          attributes: ['name'],
          as: 'Diagnosis',
          required: false
        },
        {
          model: Institution,
          as: 'currentInstitution',
          attributes: ['institution_id', 'name'],
          required: false
        }
      ]
    });

    if (!child) {
      return res.status(404).json({ 
        success: false,
        message: 'Child not found or not approved' 
      });
    }

    if (!child.currentInstitution) {
      return res.status(400).json({
        success: false,
        message: 'Child is not registered in any institution'
      });
    }

    const institutionId = child.currentInstitution.institution_id;
    const childDiagnosis = child.Diagnosis ? child.Diagnosis.name : null;

    console.log('🏥 Child details:', {
      name: child.full_name,
      institution: child.currentInstitution.name,
      diagnosis: childDiagnosis
    });

    // 2. جلب كل الجلسات من المؤسسة
    const sessionTypes = await SessionType.findAll({
      where: { 
        institution_id: institutionId 
      },
      attributes: [
        'session_type_id', 
        'name', 
        'duration', 
        'price', 
        'category', 
        // 'description',
        'target_conditions',
        'specialist_specialization'
      ],
      order: [['category', 'ASC'], ['name', 'ASC']],
      raw: true
    });

    console.log('📋 All session types found:', sessionTypes.length);

    // 3. فلترة الجلسات يدوياً
    const filteredSessionTypes = sessionTypes.filter(sessionType => {
      // معالجة target_conditions لتحويلها من JSON string إلى array
      let targetConditions = [];
      try {
        if (sessionType.target_conditions) {
          targetConditions = JSON.parse(sessionType.target_conditions);
        }
      } catch (error) {
        console.warn('❌ Error parsing target_conditions:', sessionType.target_conditions);
        targetConditions = [];
      }

      // إذا الطفل بدون تشخيص، نعرض فقط الجلسات العامة
      if (!childDiagnosis) {
        return targetConditions.length === 0; // فقط الجلسات العامة
      }
      
      // إذا الطفل مع تشخيص
      if (targetConditions.length === 0) {
        return true; // الجلسات العامة مناسبة للجميع
      }
      
      return targetConditions.includes(childDiagnosis);
    });

    console.log('✅ Suitable session types after filtering:', filteredSessionTypes.length);

    // 4. تحسين البيانات المعادة
    const enhancedSessionTypes = filteredSessionTypes.map(sessionType => {
      // معالجة target_conditions للعرض
      let targetConditions = [];
      try {
        if (sessionType.target_conditions) {
          targetConditions = JSON.parse(sessionType.target_conditions);
        }
      } catch (error) {
        targetConditions = [];
      }

      // تحديد إذا الجلسة مناسبة ولماذا
      let suitability = {
        is_suitable: true,
        reason: childDiagnosis ? 
          `مناسبة لحالة ${childDiagnosis}` : 
          'جلسة عامة مناسبة للجميع'
      };

      return {
        session_type_id: sessionType.session_type_id,
        name: sessionType.name,
        duration: sessionType.duration,
        price: sessionType.price,
        category: sessionType.category,
        // description: sessionType.description,
        target_conditions: targetConditions, // ⬅️ نعيدها كـ array
        specialist_specialization: sessionType.specialist_specialization,
        ...suitability,
        institution_info: {
          institution_id: child.currentInstitution.institution_id,
          institution_name: child.currentInstitution.name
        }
      };
    });

    // 5. إضافة الجلسات غير المناسبة للمعلومات فقط (اختياري)
    const notSuitableSessions = sessionTypes.filter(sessionType => {
      if (!childDiagnosis) return false; // إذا بدون تشخيص، كل الجلسات غير العامة غير مناسبة
      
      let targetConditions = [];
      try {
        if (sessionType.target_conditions) {
          targetConditions = JSON.parse(sessionType.target_conditions);
        }
      } catch (error) {
        return false;
      }

      return targetConditions.length > 0 && !targetConditions.includes(childDiagnosis);
    }).map(sessionType => ({
      session_type_id: sessionType.session_type_id,
      name: sessionType.name,
      category: sessionType.category,
      is_suitable: false,
      reason: `غير مناسبة لحالة ${childDiagnosis}`,
      required_conditions: JSON.parse(sessionType.target_conditions || '[]')
    }));

    res.status(200).json({
      success: true,
      child_info: {
        child_id: child.child_id,
        child_name: child.full_name,
        diagnosis: childDiagnosis,
        current_institution: {
          institution_id: child.currentInstitution.institution_id,
          name: child.currentInstitution.name
        }
      },
      session_types: {
        suitable: enhancedSessionTypes,
        not_suitable: notSuitableSessions, // معلومات إضافية
        total_suitable: enhancedSessionTypes.length,
        total_available: sessionTypes.length
      },
      filters_applied: {
        by_institution: true,
        by_diagnosis: !!childDiagnosis,
        diagnosis_type: childDiagnosis
      }
    });

  } catch (error) {
    console.error('❌ Error fetching suitable session types:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

// ================= GET PENDING SESSIONS FOR MANAGER =================
exports.getPendingSessions = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // التحقق من أن المستخدم مدير
    const manager = await User.findByPk(managerId);
    if (!manager || manager.role !== 'Manager') {
      return res.status(403).json({ 
        success: false,
        message: 'Access denied. Manager role required.' 
      });
    }

    // جلب الجلسات المعلقة للمؤسسة التابعة للمدير
    const pendingSessions = await Session.findAll({
      where: {
        institution_id: manager.institution_id,
        status: 'Pending Manager Approval',
        is_first_booking: true
      },
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['full_name', 'date_of_birth'],
          include: [
            {
              model: User,
              as: 'parent',
              attributes: ['full_name', 'email', 'phone']
            }
          ]
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['full_name', 'email']
        },
        {
          model: SessionType,
          attributes: ['name', 'duration', 'price', 'category']
        }
      ],
      order: [['date', 'ASC'], ['time', 'ASC']]
    });

    res.status(200).json({
      success: true,
      total_pending: pendingSessions.length,
      sessions: pendingSessions.map(session => ({
        session_id: session.session_id,
        child_name: session.child.full_name,
        parent_name: session.child.parent.full_name,
        parent_contact: {
          email: session.child.parent.email,
          phone: session.child.parent.phone
        },
        specialist_name: session.specialist.full_name,
        session_type: session.SessionType.name,
        duration: session.SessionType.duration,
        price: session.SessionType.price,
        date: session.date,
        time: session.time,
        parent_notes: session.parent_notes,
        is_first_booking: session.is_first_booking
      }))
    });

  } catch (error) {
    console.error('Error fetching pending sessions:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

// ================= MANAGER APPROVE SESSION =================
exports.managerApproveSession = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { session_id } = req.params;
    const { manager_notes } = req.body;

    // التحقق من أن المستخدم مدير
    const manager = await User.findByPk(managerId);
    if (!manager || manager.role !== 'Manager') {
      return res.status(403).json({ 
        success: false,
        message: 'Access denied. Manager role required.' 
      });
    }

    // جلب الجلسة
    const session = await Session.findByPk(session_id);
    if (!session) {
      return res.status(404).json({ 
        success: false,
        message: 'Session not found' 
      });
    }

    // التحقق من أن الجلسة تابعة لمؤسسة المدير
    if (session.institution_id !== manager.institution_id) {
      return res.status(403).json({ 
        success: false,
        message: 'You can only approve sessions in your institution' 
      });
    }

    // التحقق من أن الجلسة في حالة انتظار موافقة المدير
    if (session.status !== 'Pending Manager Approval') {
      return res.status(400).json({ 
        success: false,
        message: 'Session is not pending manager approval' 
      });
    }

    // تحديث حالة الجلسة إلى Pending Payment (ينتظر الدفع)
    await session.update({
      status: 'Pending Payment',
      approved_by_manager_id: managerId,
      manager_approval_date: new Date(),
      manager_notes: manager_notes || null
    });

    // إنشاء فاتورة تلقائياً
    let invoiceId = null;
    try {
      const child = await Child.findByPk(session.child_id);
      const invoice = await createInvoiceForSession(session, child);
      invoiceId = invoice.invoice_id;
      console.log(`📄 Invoice ${invoiceId} created after manager approval`);
    } catch (invoiceError) {
      console.error('⚠️ Failed to create invoice after approval:', invoiceError);
    }

    res.status(200).json({
      success: true,
      message: 'Session approved successfully - parent can now proceed with payment',
      session_id: session.session_id,
      new_status: 'Pending Payment',
      requires_payment: true,
      invoice_id: invoiceId // ⬅️ إرجاع invoice_id
    });

  } catch (error) {
    console.error('Error approving session:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

// ================= MANAGER REJECT SESSION =================
exports.managerRejectSession = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { session_id } = req.params;
    const { manager_notes } = req.body;

    // التحقق من أن المستخدم مدير
    const manager = await User.findByPk(managerId);
    if (!manager || manager.role !== 'Manager') {
      return res.status(403).json({ 
        success: false,
        message: 'Access denied. Manager role required.' 
      });
    }

    // جلب الجلسة
    const session = await Session.findByPk(session_id);
    if (!session) {
      return res.status(404).json({ 
        success: false,
        message: 'Session not found' 
      });
    }

    // التحقق من أن الجلسة تابعة لمؤسسة المدير
    if (session.institution_id !== manager.institution_id) {
      return res.status(403).json({ 
        success: false,
        message: 'You can only reject sessions in your institution' 
      });
    }

    // التحقق من أن الجلسة في حالة انتظار موافقة المدير
    if (session.status !== 'Pending Manager Approval') {
      return res.status(400).json({ 
        success: false,
        message: 'Session is not pending manager approval' 
      });
    }

    // تحديث حالة الجلسة
    await session.update({
      status: 'Rejected',
      approved_by_manager_id: managerId,
      manager_approval_date: new Date(),
      manager_notes: manager_notes || 'Rejected by manager'
    });

    res.status(200).json({
      success: true,
      message: 'Session rejected successfully',
      session_id: session.session_id,
      new_status: 'Rejected'
    });

  } catch (error) {
    console.error('Error rejecting session:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

// ================= PARENT CONFIRM PAYMENT =================
exports.confirmPayment = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { session_id } = req.params;
    const { 
      payment_method,
      card_details,      // للبطاقة
      bank_details,      // للتحويل البنكي
      paypal_details     // لـ PayPal
    } = req.body;

    console.log(`💳 Processing payment for session ${session_id} via ${payment_method}`);

    // جلب الجلسة
    const session = await Session.findByPk(session_id, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'parent_id', 'full_name']
        },
        {
          model: SessionType,
          attributes: ['name', 'price', 'duration']
        }
      ]
    });

    if (!session) {
      return res.status(404).json({ 
        success: false,
        message: 'Session not found' 
      });
    }

    // التحقق من أن الجلسة تابعة للأهل
    if (session.child.parent_id !== parentId) {
      return res.status(403).json({ 
        success: false,
        message: 'You can only pay for your own child sessions' 
      });
    }

    // التحقق من أن الجلسة في حالة انتظار الدفع
    if (session.status !== 'Pending Payment') {
      return res.status(400).json({ 
        success: false,
        message: 'Session is not pending payment',
        current_status: session.status
      });
    }

    // جلب الفاتورة
    const invoice = await Invoice.findOne({
      where: { session_id: session.session_id }
    });

    if (!invoice) {
      return res.status(404).json({
        success: false,
        message: 'Invoice not found for this session'
      });
    }

    const amount = parseFloat(invoice.total_amount);

    // تطبيع اسم طريقة الدفع (تقبل underscore أو مسافات)
    const normalizedPaymentMethod = payment_method
      .replace(/_/g, ' ')  // استبدال underscore بمسافة
      .split(' ')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(' ');

    console.log(`💡 Payment method normalized: "${payment_method}" → "${normalizedPaymentMethod}"`);

    // معالجة الدفع حسب الطريقة
    let paymentResult;

    switch (normalizedPaymentMethod) {
      case 'Cash':
        paymentResult = await PaymentGateway.processCashPayment(amount, {
          session_id,
          parent_id: parentId
        });
        break;

      case 'Credit Card':
        if (!card_details) {
          return res.status(400).json({
            success: false,
            message: 'Card details are required for credit card payment'
          });
        }
        // استخدام TEST mode للتجربة
        paymentResult = await PaymentGateway.processTestCreditCardPayment(amount, {
          ...card_details,
          session_id,
          parent_id: parentId
        });
        break;

      case 'Bank Transfer':
        if (!bank_details) {
          return res.status(400).json({
            success: false,
            message: 'Bank transfer details are required'
          });
        }
        paymentResult = await PaymentGateway.processBankTransferPayment(amount, {
          ...bank_details,
          session_id,
          parent_id: parentId
        });
        break;

      case 'Paypal':
        if (!paypal_details) {
          return res.status(400).json({
            success: false,
            message: 'PayPal details are required'
          });
        }
        paymentResult = await PaymentGateway.processPayPalPayment(amount, {
          ...paypal_details,
          session_id,
          parent_id: parentId
        });
        break;

      default:
        return res.status(400).json({
          success: false,
          message: `Unsupported payment method: ${payment_method}. Use: Cash, Credit Card, Bank Transfer, or PayPal`,
          received: payment_method,
          normalized: normalizedPaymentMethod
        });
    }

    // التحقق من نجاح الدفع
    if (!paymentResult.success) {
      return res.status(400).json({
        success: false,
        message: paymentResult.message || 'Payment failed',
        error: paymentResult.error
      });
    }

    // إنشاء سجل Payment
    const payment = await Payment.create({
      invoice_id: invoice.invoice_id,
      session_id: session.session_id,
      parent_id: parentId,
      amount: amount,
      payment_method: normalizedPaymentMethod, // ⬅️ استخدام normalizedPaymentMethod
      transaction_id: paymentResult.transaction_id,
      payment_status: paymentResult.status === 'Completed' ? 'Completed' : 'Pending',
      payment_date: paymentResult.payment_date || new Date(),
      payment_details: JSON.stringify(paymentResult)
    });

    // تحديث الفاتورة
    if (paymentResult.status === 'Completed') {
      await invoice.update({
        status: 'Paid',
        paid_date: new Date()
      });
    }

    // تحديث حالة الجلسة
    const newSessionStatus = paymentResult.status === 'Completed' ? 'Confirmed' : 'Pending Payment';
    
    await session.update({
      status: newSessionStatus,
      payment_status: paymentResult.status,
      payment_method: normalizedPaymentMethod, // ⬅️ استخدام normalizedPaymentMethod
      transaction_id: paymentResult.transaction_id,
      payment_date: paymentResult.payment_date
    });

    // الرد
    res.status(200).json({
      success: true,
      message: paymentResult.message,
      payment_id: payment.payment_id,
      transaction_id: paymentResult.transaction_id,
      payment_status: paymentResult.status,
      requires_verification: paymentResult.requires_verification || false,
      session_status: newSessionStatus,
      session_details: {
        child_name: session.child.full_name,
        session_type: session.SessionType.name,
        date: session.date,
        time: session.time,
        duration: session.SessionType.duration,
        price: session.SessionType.price
      }
    });

  } catch (error) {
    console.error('Error confirming payment:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};