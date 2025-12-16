// services/autoApprovalService.js
const { 
  Child, 
  ChildRegistrationRequest, 
  Specialist, 
  SessionType, 
  Session, 
  Notification, 
  SpecialistSchedule, 
  Institution, 
  Parent, 
  User,
  Manager,
  Diagnosis
} = require('../model');
const sequelize = require('../config/db');
const { Op,Sequelize } = require('sequelize');
class AutoApprovalService {
  
  /**
   * التحقق من طلبات التسجيل الجديدة واتخاذ القرار تلقائياً
   */
static async processPendingRegistrationRequests() {
  console.log('🔄 بدء معالجة طلبات التسجيل المعلقة تلقائياً...');
  
  try {
    // جلب فقط 3 طلبات في كل مرة لمنع التحميل الزائد
    const pendingRequests = await ChildRegistrationRequest.findAll({
      where: { 
        status: 'Pending',
        requested_at: {
          [Op.lt]: new Date(Date.now() - 5 * 60 * 1000) // فقط الطلبات الأقدم من 5 دقائق
        }
      },
      include: [
        {
          model: Child,
          attributes: ['child_id', 'full_name', 'date_of_birth', 'gender', 'city', 'address', 
                       'diagnosis_id', 'suspected_condition', 'symptoms_description', 'risk_level'],
          required: true
        },
        {
          model: Institution,
          attributes: ['institution_id', 'name', 'auto_approval_enabled', 'capacity']
        }
      ],
      order: [['requested_at', 'ASC']],
      limit: 3 // معالجة 3 طلبات فقط في المرة الواحدة
    });

    console.log(`📋 عدد الطلبات المعلقة للفحص: ${pendingRequests.length}`);

    const results = {
      approved: [],
      rejected: [],
      pending_manager_review: []
    };

    // معالجة كل طلب بشكل منفصل مع معالجة الأخطاء
    for (const request of pendingRequests) {
      try {
        console.log(`⚡ معالجة الطلب ${request.request_id}...`);

        // 🚫 إذا كان الطلب مرتبطاً بطلب مساعدة مالية، لا نقوم بالموافقة التلقائية
        // بل نتركه للمراجعة اليدوية من المدير
        if (request.financial_assistance_request_id) {
          console.log(`💰 الطلب ${request.request_id} مرتبط بطلب مساعدة مالية (${request.financial_assistance_request_id})، سيتم تحويله لمراجعة المدير فقط.`);
          results.pending_manager_review.push({
            request_id: request.request_id,
            child_name: request.Child.full_name,
            reason: 'مرتبط بطلب مساعدة مالية - يحتاج مراجعة مدير'
          });
          continue;
        }
        
        const decision = await this.evaluateRegistrationRequest(request);
        
        switch (decision.status) {
          case 'Approved':
            await this.approveAndScheduleAutomatically(request, decision);
            results.approved.push({
              request_id: request.request_id,
              child_name: request.Child.full_name,
              reason: decision.reason
            });
            break;
            
          case 'Rejected':
            await this.rejectAutomatically(request, decision);
            results.rejected.push({
              request_id: request.request_id,
              child_name: request.Child.full_name,
              reason: decision.reason
            });
            break;
            
          default:
            results.pending_manager_review.push({
              request_id: request.request_id,
              child_name: request.Child.full_name,
              reason: 'بحاجة لمراجعة يدوية من المدير'
            });
        }
        
        console.log(`✅ اكتملت معالجة الطلب ${request.request_id}`);
        
      } catch (requestError) {
        console.error(`❌ خطأ في معالجة الطلب ${request.request_id}:`, requestError.message);
        // تابع مع الطلب التالي
        continue;
      }
    }

    console.log('✅ نتائج المعالجة التلقائية:', {
      approved: results.approved.length,
      rejected: results.rejected.length,
      needs_manager: results.pending_manager_review.length
    });

    return results;

  } catch (error) {
    console.error('❌ خطأ رئيسي في معالجة الطلبات تلقائياً:', error);
    throw error;
  }
}

  /**
   * تقييم طلب التسجيل بناءً على قواعد محددة
   */
  static async evaluateRegistrationRequest(request) {
    const evaluation = {
      status: 'Pending',
      reason: '',
      score: 0,
      checks: {},
      financial_factors: {}
    };

    // 🔍 التحقق 1: اكتمال بيانات الطفل
    evaluation.checks.childDataComplete = this.checkChildDataCompleteness(request.Child);
    evaluation.score += evaluation.checks.childDataComplete ? 20 : 0;

    // 🔍 التحقق 2: توفر تشخيص أو تحليل أعراض
    evaluation.checks.hasDiagnosisOrSymptoms = this.checkMedicalInformation(request.Child);
    evaluation.score += evaluation.checks.hasDiagnosisOrSymptoms ? 15 : 0;

    // 🔍 التحقق 3: تحليل المخاطر
    evaluation.checks.riskLevel = await this.assessRiskLevel(request.Child);
    evaluation.score += evaluation.checks.riskLevel === 'Low' ? 25 : 
                        evaluation.checks.riskLevel === 'Medium' ? 15 : 5;

    // 🔍 التحقق 4: توفر مواعيد في المؤسسة
    evaluation.checks.hasAvailableSlots = await this.checkInstitutionAvailability(
      request.institution_id,
      request.Child
    );
    evaluation.score += evaluation.checks.hasAvailableSlots ? 30 : 0;

    // 🔍 التحقق 5: تاريخ الأهل مع المؤسسة (إذا كانوا عملاء سابقين)
    evaluation.checks.parentHistory = await this.checkParentHistory(
      request.requested_by_parent_id,
      request.institution_id
    );
    evaluation.score += evaluation.checks.parentHistory.goodHistory ? 10 : 0;

    // 🔍 التحقق 6: السعة الاستيعابية للمؤسسة
    evaluation.checks.institutionCapacity = await this.checkInstitutionCapacity(request.institution_id);
    evaluation.score += evaluation.checks.institutionCapacity ? 10 : -10;

    

    // 📊 اتخاذ القرار بناءً على النتيجة
    if (evaluation.score >= 70) {
      evaluation.status = 'Approved';
      evaluation.reason = 'الطلب يستوفي جميع معايير الموافقة التلقائية';
    } else if (evaluation.score <= 30) {
      evaluation.status = 'Rejected';
      evaluation.reason = 'الطلب لا يستوفي الحد الأدنى من المتطلبات';
    } else {
      evaluation.status = 'Pending';
      evaluation.reason = 'الطلب بحاجة لمراجعة من المدير';
    }

    console.log(`📊 تقييم طلب ${request.request_id}: ${evaluation.score}/100 - ${evaluation.status}`);
    return evaluation;
  }

  /**
   * الموافقة التلقائية والحجز الذكي
   */
// services/autoApprovalService.js - إضافة مهلات و logs
static async approveAndScheduleAutomatically(request, decision) {
    console.log(`⏱️ بدء الموافقة التلقائية للطلب ${request.request_id}`);
    
    // 🔥 تصحيح: استخدام Sequelize مباشرة
    const transaction = await sequelize.transaction({
      isolationLevel: Sequelize.Transaction.ISOLATION_LEVELS.READ_COMMITTED,
      timeout: 30000
    });

    try {
      console.log(`✅ الموافقة التلقائية على طلب ${request.request_id}`);

      // 1️⃣ تحديث حالة الطلب
      await ChildRegistrationRequest.update(
        {
          status: 'Approved',
          reviewed_at: new Date(),
          notes: `تمت الموافقة تلقائياً: ${decision.reason}`
        },
        {
          where: { request_id: request.request_id },
          transaction
        }
      );

      // 2️⃣ تحديث حالة الطفل
      await Child.update(
        {
          registration_status: 'Approved',
          current_institution_id: request.institution_id
        },
        {
          where: { child_id: request.child_id },
          transaction
        }
      );

      // 3️⃣ البحث عن أخصائي General متاح
      const generalSpecialist = await this.findAvailableGeneralSpecialist(
        request.institution_id,
        request.Child
      );

      if (!generalSpecialist) {
        console.log('⚠️ لا يوجد أخصائي General متاح، سيتم إخطار المدير');
        await Notification.create({
          user_id: await this.getInstitutionManagerId(request.institution_id),
          title: 'تحذير: لا يوجد أخصائي متاح',
          message: `تمت الموافقة على طلب ${request.Child.full_name} ولكن لا يوجد أخصائي General متاح. يرجى تعيين أخصائي يدوياً.`,
          type: 'specialist_needed',
          related_id: request.request_id,
          is_read: false
        }, { transaction });
      } else {
        console.log(`✅ وجد أخصائي: ${generalSpecialist.User.full_name}`);
        
        // 4️⃣ البحث عن موعد متاح
        const availableSlot = await this.findNextAvailableSlot(
          generalSpecialist.specialist_id,
          60 // مدة الجلسة
        );

        if (availableSlot) {
          // 5️⃣ إنشاء جلسة Initial Assessment
          const initialAssessmentSession = await this.createInitialAssessmentSession(
            request.child_id,
            generalSpecialist.specialist_id,
            request.institution_id,
            availableSlot,
            transaction
          );

          // 6️⃣ إرسال إشعارات
          await this.sendApprovalNotifications(
            request,
            generalSpecialist,
            initialAssessmentSession,
            transaction
          );

          console.log(`✅ تم حجز جلسة التقييم الأولي: ${availableSlot.date} ${availableSlot.startTime}`);

        } else {
          console.log('⚠️ لا يوجد مواعيد متاحة، سيتم إخطار المدير');
          await Notification.create({
            user_id: await this.getInstitutionManagerId(request.institution_id),
            title: 'تحذير: لا يوجد مواعيد متاحة',
            message: `تمت الموافقة على طلب ${request.Child.full_name} ولكن لا يوجد مواعيد متاحة للأخصائي. يرجى التدخل يدوياً.`,
            type: 'scheduling_needed',
            related_id: request.request_id,
            is_read: false
          }, { transaction });
        }
      }

      await transaction.commit();
      console.log(`✅ اكتملت عملية الموافقة والحجز للطلب ${request.request_id}`);

    } catch (error) {
      console.error(`❌ خطأ في الموافقة التلقائية للطلب ${request.request_id}:`, error);
      
      // محاولة rollback بأمان
      try {
        await transaction.rollback();
        console.log(`🔄 تم التراجع عن التداول للطلب ${request.request_id}`);
      } catch (rollbackError) {
        console.error(`❌ خطأ في التراجع عن التداول:`, rollbackError);
      }
      
      throw error;
    }
  }

// تحديث دالة createInitialAssessmentSession
static async createInitialAssessmentSession(childId, specialistId, institutionId, slot, transaction = null) {
  console.log(`🔍 البحث عن نوع الجلسة للمؤسسة ${institutionId}`);
  
  const options = transaction ? { transaction } : {};
  
  const initialAssessmentType = await SessionType.findOne({
    where: {
      institution_id: institutionId,
      name: { [Op.like]: '%Initial Assessment%' }
    },
    ...options
  });

  const sessionTypeId = initialAssessmentType ? 
    initialAssessmentType.session_type_id : 
    await this.getDefaultSessionTypeId(institutionId);

  const originalPrice = initialAssessmentType ? parseFloat(initialAssessmentType.price) || 0 : 0;
  const finalPrice = originalPrice;

  console.log(`📝 إنشاء جلسة جديدة: ${slot.date} ${slot.startTime}`);
  
  const createOptions = {
    child_id: childId,
    specialist_id: specialistId,
    institution_id: institutionId,
    session_type_id: sessionTypeId,
    date: slot.date,
    time: `${slot.startTime}:00`,
    duration: 60,
    session_type: 'Onsite',
    status: 'Pending Approval',
    is_first_booking: true,
    is_initial_assessment: true,
    parent_notes: 'جلسة التقييم الأولي - تم الحجز تلقائياً بعد الموافقة على التسجيل',
    original_price: originalPrice,
    final_price: finalPrice,
    applied_discount_percentage: 0,
    payment_status: 'Pending',
    financial_assistance_applied: false,
    is_paid: false
  };

  if (transaction) {
    return await Session.create(createOptions, { transaction });
  } else {
    return await Session.create(createOptions);
  }
}

// تحديث دالة sendApprovalNotifications
static async sendApprovalNotifications(request, specialist, session, transaction = null) {
  const options = transaction ? { transaction } : {};
  
  console.log(`📨 إرسال إشعارات للطلب ${request.request_id}`);
  
  // 1. إشعار الأهل
  await Notification.create({
    user_id: request.requested_by_parent_id,
    title: 'تمت الموافقة على التسجيل وحجز الجلسة الأولى',
    message: `مبروك! تمت الموافقة على تسجيل ${request.Child.full_name} في ${request.Institution.name}. 
              تم حجز جلسة التقييم الأولي مع ${specialist.User.full_name} في ${session.date} الساعة ${session.time}.`,
    type: 'registration_approved',
    related_id: request.request_id,
    is_read: false
  }, options);

  // 2. إشعار الأخصائي
  await Notification.create({
    user_id: specialist.specialist_id,
    title: 'جلسة تقييم أولي جديدة',
    message: `لديك جلسة تقييم أولي مع ${request.Child.full_name} في ${session.date} الساعة ${session.time}. 
              الطفل: ${request.Child.age} سنوات، ${request.Child.gender}.`,
    type: 'new_session',
    related_id: session.session_id,
    is_read: false
  }, options);

  // 3. إشعار المدير
  const managerId = await this.getInstitutionManagerId(request.institution_id);
  if (managerId) {
    await Notification.create({
      user_id: managerId,
      title: 'تمت الموافقة التلقائية على تسجيل جديد',
      message: `تمت الموافقة تلقائياً على تسجيل ${request.Child.full_name}. 
                تم حجز جلسة مع ${specialist.User.full_name} في ${session.date}.`,
      type: 'auto_approval_notification',
      related_id: request.request_id,
      is_read: false
    }, options);
  }
}

  /**
   * الرفض التلقائي
   */
  static async rejectAutomatically(request, decision) {
    try {
      console.log(`❌ الرفض التلقائي لطلب ${request.request_id}`);

      await ChildRegistrationRequest.update(
        {
          status: 'Rejected',
          reviewed_at: new Date(),
          notes: `تم الرفض تلقائياً: ${decision.reason}`
        },
        { where: { request_id: request.request_id } }
      );

      await Child.update(
        { registration_status: 'Rejected' },
        { where: { child_id: request.child_id } }
      );

      // إشعار الأهل
      await Notification.create({
        user_id: request.requested_by_parent_id,
        title: 'تم رفض طلب التسجيل',
        message: `عذراً، تم رفض طلب تسجيل ${request.Child.full_name} في ${request.Institution.name}. السبب: ${decision.reason}`,
        type: 'registration_rejected',
        related_id: request.request_id,
        is_read: false
      });

    } catch (error) {
      console.error('❌ خطأ في الرفض التلقائي:', error);
      throw error;
    }
  }

  // ==================== دوال مساعدة ====================

  static checkChildDataCompleteness(child) {
    const requiredFields = ['full_name', 'date_of_birth', 'gender'];
    const hasRequired = requiredFields.every(field => child[field]);
    
    const recommendedFields = ['city', 'address', 'medical_history'];
    const hasRecommended = recommendedFields.some(field => child[field]);
    
    return hasRequired && hasRecommended;
  }

  static checkMedicalInformation(child) {
    return !!(
      child.diagnosis_id ||
      child.suspected_condition ||
      child.symptoms_description ||
      child.ai_suggested_diagnosis
    );
  }

  static async assessRiskLevel(child) {
    if (child.risk_level) {
      return child.risk_level;
    }
    
    // تحليل بسيط بناءً على الأعراض
    if (child.symptoms_description) {
      const highRiskKeywords = ['emergency', 'urgent', 'severe', 'critical', 'danger'];
      const text = child.symptoms_description.toLowerCase();
      
      if (highRiskKeywords.some(keyword => text.includes(keyword))) {
        return 'High';
      }
    }
    
    return 'Medium';
  }

  static async checkInstitutionAvailability(institutionId, child) {
    try {
      // البحث عن أخصائي General متاح في المؤسسة
      const generalSpecialist = await Specialist.findOne({
        where: {
          institution_id: institutionId,
          specialization: { [Op.like]: '%General%' },
          approval_status: 'Approved'
        }
      });

      if (!generalSpecialist) {
        console.log('⚠️ لا يوجد أخصائي General في المؤسسة');
        return false;
      }

      // التحقق من وجود جدول للمختص
      const hasSchedule = await SpecialistSchedule.findOne({
        where: { specialist_id: generalSpecialist.specialist_id }
      });

      if (!hasSchedule) {
        console.log('⚠️ الأخصائي ليس لديه جدول عمل');
        return false;
      }

      // البحث عن موعد متاح خلال الأسبوعين القادمين
      const availableSlot = await this.findNextAvailableSlot(generalSpecialist.specialist_id, 60);
      return !!availableSlot;

    } catch (error) {
      console.error('❌ خطأ في التحقق من توفر المؤسسة:', error);
      return false;
    }
  }

  static async findAvailableGeneralSpecialist(institutionId, child) {
    console.log(`🔍 البحث عن أخصائي General للمؤسسة ${institutionId}`);

    try {
      const generalSpecialists = await Specialist.findAll({
        where: {
          institution_id: institutionId,
          specialization: { [Op.like]: '%General%' },
          approval_status: 'Approved'
        },
        include: [
          {
            model: User,
            attributes: ['user_id', 'full_name', 'email'],
            required: true
          }
        ],
        attributes: ['specialist_id', 'specialization', 'years_experience', 'average_rating'],
        limit: 5,
        logging: console.log
      });

      console.log(`📊 وجد ${generalSpecialists.length} أخصائي General`);

      if (generalSpecialists.length === 0) {
        console.log('⚠️ لا يوجد أخصائي General في المؤسسة');
        return null;
      }

      // نبدأ بأول أخصائي ونحاول إيجاد من لديه جدول عمل
      for (const specialist of generalSpecialists) {
        const hasSchedule = await SpecialistSchedule.findOne({
          where: { specialist_id: specialist.specialist_id },
          limit: 1
        });

        if (!hasSchedule) {
          console.log(`⚠️ الأخصائي ${specialist.User.full_name} ليس لديه جدول`);
          continue;
        }

        // محاولة العثور على موعد سريع (اليوم وغد فقط)
        const quickSlot = await this.findQuickAvailableSlot(specialist.specialist_id, 60);

        if (quickSlot) {
          console.log(`✅ وجد موعد سريع للأخصائي ${specialist.User.full_name}: ${quickSlot.date}`);
          return specialist;
        }

        // حتى لو لم يوجد quickSlot، نرجّع هذا الأخصائي
        // ليتم لاحقاً البحث عن أقرب موعد متاح عبر findNextAvailableSlot
        console.log(`⚠️ لا يوجد موعد سريع للأخصائي ${specialist.User.full_name}، سيتم البحث عن أقرب موعد متاح لاحقاً`);
        return specialist;
      }

      // إذا لم يكن لأي من المختصين جدول عمل، نرجع null
      console.log('⚠️ لا يوجد أي أخصائي General لديه جدول عمل فعّال');
      return null;

    } catch (error) {
      console.error('❌ خطأ في البحث عن أخصائي:', error);
      return null;
    }
  }

  static async findQuickAvailableSlot(specialistId, durationMinutes) {
    // البحث في اليوم وغد فقط عن أقرب موعد متاح
    for (let i = 1; i <= 2; i++) {
      const targetDate = new Date();
      targetDate.setDate(targetDate.getDate() + i);
      const dateString = targetDate.toISOString().split('T')[0];
      const dayOfWeek = this.getDayName(targetDate.getDay());

      const schedule = await SpecialistSchedule.findOne({
        where: {
          specialist_id: specialistId,
          day_of_week: dayOfWeek
        }
      });

      if (!schedule) continue;

      // جلب الجلسات فقط لهذا اليوم المحدد
      const existingSessions = await Session.findAll({
        where: {
          specialist_id: specialistId,
          date: dateString,
          status: {
            [Op.notIn]: ['Cancelled', 'Rejected', 'Completed']
          }
        },
        attributes: ['time', 'duration'],
        limit: 10
      });

      const availableTime = this.findAvailableTimeInSchedule(
        schedule.start_time,
        schedule.end_time,
        durationMinutes,
        existingSessions
      );

      if (availableTime) {
        return {
          date: dateString,
          startTime: availableTime,
          dayOfWeek: dayOfWeek
        };
      }
    }

    return null;
  }

  static async findNextAvailableSlot(specialistId, durationMinutes) {
    const daysToCheck = 14; // البحث خلال أسبوعين
    
    for (let i = 1; i <= daysToCheck; i++) {
      const targetDate = new Date();
      targetDate.setDate(targetDate.getDate() + i);
      const dateString = targetDate.toISOString().split('T')[0];
      const dayOfWeek = this.getDayName(targetDate.getDay());
      
      // 1. التحقق من وجود جدول في هذا اليوم
      const schedule = await SpecialistSchedule.findOne({
        where: {
          specialist_id: specialistId,
          day_of_week: dayOfWeek
        }
      });

      if (!schedule) continue;

      // 2. الحصول على الجلسات المجدولة لهذا اليوم
      const existingSessions = await Session.findAll({
        where: {
          specialist_id: specialistId,
          date: dateString,
          status: {
            [Op.notIn]: ['Cancelled', 'Rejected', 'Completed']
          }
        }
      });

      // 3. البحث عن وقت متاح
      const availableTime = this.findAvailableTimeInSchedule(
        schedule.start_time,
        schedule.end_time,
        durationMinutes,
        existingSessions
      );

      if (availableTime) {
        return {
          date: dateString,
          startTime: availableTime,
          dayOfWeek: dayOfWeek
        };
      }
    }
    
    return null;
  }

  static findAvailableTimeInSchedule(startTime, endTime, durationMinutes, existingSessions) {
    const startMinutes = this.timeToMinutes(startTime);
    const endMinutes = this.timeToMinutes(endTime);
    const durationMinutesInt = parseInt(durationMinutes);
    
    // تحويل الجلسات الحالية إلى فترات مشغولة
    const busySlots = [];
    existingSessions.forEach(session => {
      const sessionStart = this.timeToMinutes(session.time);
      const sessionDuration = session.duration || 60;
      const sessionEnd = sessionStart + sessionDuration;
      busySlots.push({ start: sessionStart, end: sessionEnd });
    });

    // البحث عن فتحة متاحة كل 30 دقيقة
    for (let time = startMinutes; time <= endMinutes - durationMinutesInt; time += 30) {
      const slotEnd = time + durationMinutesInt;
      let isAvailable = true;
      
      // التحقق من التداخل مع الجلسات المشغولة
      for (const busy of busySlots) {
        if (time < busy.end && slotEnd > busy.start) {
          isAvailable = false;
          break;
        }
      }
      
      if (isAvailable) {
        return this.minutesToTime(time);
      }
    }
    
    return null;
  }

  /**
   * وظيفة جديدة: معالجة طلب واحد فقط
   */
  static async processSingleRequest(requestId) {
    try {
      console.log(`🎯 معالجة طلب واحد: ${requestId}`);
      
      const request = await ChildRegistrationRequest.findOne({
        where: { request_id: requestId, status: 'Pending' },
        include: [
          {
            model: Child,
            include: [
              {
                model: Parent,
                include: [{ model: User, attributes: ['full_name', 'email', 'phone'] }]
              },
              {
                model: Diagnosis,
                as: 'Diagnosis',
                attributes: ['name']
              }
            ]
          },
          {
            model: Institution,
            attributes: ['institution_id', 'name', 'auto_approval_enabled']
          }
        ]
      });

      if (!request) {
        console.log(`❌ الطلب ${requestId} غير موجود أو تمت معالجته مسبقاً`);
        return { success: false, message: 'Request not found or already processed' };
      }

      // 🚫 إذا كان الطلب مرتبطاً بطلب مساعدة مالية، لا تتم معالجته تلقائياً
      if (request.financial_assistance_request_id) {
        console.log(`💰 الطلب ${requestId} مرتبط بطلب مساعدة مالية (${request.financial_assistance_request_id})، لن يتم تنفيذ الموافقة التلقائية.`);
        return {
          success: true,
          status: 'Pending',
          request_id: request.request_id,
          reason: 'مرتبط بطلب مساعدة مالية - يحتاج مراجعة مدير'
        };
      }

      const decision = await this.evaluateRegistrationRequest(request);
      let result;
      
      switch (decision.status) {
        case 'Approved':
          await this.approveAndScheduleAutomatically(request, decision);
          result = { 
            success: true, 
            status: 'Approved',
            request_id: request.request_id,
            reason: decision.reason
          };
          break;
          
        case 'Rejected':
          await this.rejectAutomatically(request, decision);
          result = { 
            success: true, 
            status: 'Rejected',
            request_id: request.request_id,
            reason: decision.reason
          };
          break;
          
        default:
          result = { 
            success: true, 
            status: 'Pending',
            request_id: request.request_id,
            reason: 'Needs manual review by manager'
          };
      }

      console.log(`✅ اكتملت معالجة الطلب ${requestId}: ${result.status}`);
      return result;

    } catch (error) {
      console.error(`❌ خطأ في معالجة الطلب ${requestId}:`, error);
      return { 
        success: false, 
        request_id: requestId,
        error: error.message 
      };
    }
  }

  static async checkParentHistory(parentId, institutionId) {
    // التحقق من تاريخ الأهل مع المؤسسة
    const previousChildren = await Child.count({
      where: {
        parent_id: parentId,
        current_institution_id: institutionId,
        registration_status: 'Approved'
      }
    });

    const previousRequests = await ChildRegistrationRequest.count({
      where: {
        requested_by_parent_id: parentId,
        institution_id: institutionId,
        status: 'Rejected'
      }
    });

    return {
      hasPreviousChildren: previousChildren > 0,
      previousRejections: previousRequests,
      goodHistory: previousChildren > 0 && previousRequests === 0
    };
  }

  static async checkInstitutionCapacity(institutionId) {
    // حساب عدد الأطفال المسجلين حالياً
    const currentChildren = await Child.count({
      where: {
        current_institution_id: institutionId,
        registration_status: 'Approved'
      }
    });

    // يمكن إضافة منطق أكثر تعقيداً هنا
    // مثلاً: التحقق من سعة المؤسسة من جدول المؤسسات
    const institution = await Institution.findByPk(institutionId);
    const maxCapacity = institution.capacity || 100; // قيمة افتراضية
    
    return currentChildren < maxCapacity * 0.9; // 90% من السعة
  }

  static async getDefaultSessionTypeId(institutionId) {
    const defaultType = await SessionType.findOne({
      where: {
        institution_id: institutionId,
        category: 'Assessment'
      }
    });
    
    return defaultType ? defaultType.session_type_id : 1;
  }

  static async getInstitutionManagerId(institutionId) {
    const manager = await Manager.findOne({
      where: { institution_id: institutionId, is_active: true },
      attributes: ['manager_id']
    });
    
    return manager ? manager.manager_id : null;
  }

  // ==================== دوال تحويل الوقت ====================

  static timeToMinutes(timeStr) {
    if (!timeStr) return 0;
    const [hours, minutes] = timeStr.split(':').map(Number);
    return hours * 60 + minutes;
  }

  static minutesToTime(totalMinutes) {
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
  }

  static getDayName(dayIndex) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[dayIndex];
  }
}

module.exports = AutoApprovalService;