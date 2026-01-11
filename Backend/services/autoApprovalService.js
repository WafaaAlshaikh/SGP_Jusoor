// services/autoApprovalService.js (Complete version with additions)
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
  Diagnosis,
  AutoFinancialAidLog, 
} = require('../model');
const { Op, Sequelize } = require('sequelize');
const sequelize = require('../config/db'); 
class AutoApprovalService {
  
  /**
   * Check new registration requests and make automatic decisions
   */
  static async processPendingRegistrationRequests() {
    console.log('🔄 Starting automatic processing of pending registration requests...');
    
    try {
      // Fetch only 3 requests at a time to prevent overload
      const pendingRequests = await ChildRegistrationRequest.findAll({
        where: { 
          status: 'Pending',
          requested_at: {
            [Op.lt]: new Date(Date.now() - 5 * 60 * 1000) // Only requests older than 5 minutes
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
        limit: 3 // Process only 3 requests at a time
      });

      console.log(`📋 Number of pending requests to examine: ${pendingRequests.length}`);

      const results = {
        approved: [],
        rejected: [],
        pending_manager_review: []
      };

      // Process each request separately with error handling
      for (const request of pendingRequests) {
        try {
          console.log(`⚡ Processing request ${request.request_id}...`);

          // 🚫 If the request is linked to a financial aid request, do not auto-approve
          // Instead, leave it for manual review by the manager
          if (request.financial_assistance_request_id) {
            console.log(`💰 Request ${request.request_id} is linked to a financial aid request (${request.financial_assistance_request_id}), will be forwarded to manager review only.`);
            results.pending_manager_review.push({
              request_id: request.request_id,
              child_name: request.Child.full_name,
              reason: 'Linked to a financial aid request - needs manager review'
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
                reason: 'Needs manual review by manager'
              });
          }
          
          console.log(`✅ Completed processing request ${request.request_id}`);
          
        } catch (requestError) {
          console.error(`❌ Error processing request ${request.request_id}:`, requestError.message);
          // Continue with the next request
          continue;
        }
      }

      console.log('✅ Auto-processing results:', {
        approved: results.approved.length,
        rejected: results.rejected.length,
        needs_manager: results.pending_manager_review.length
      });

      return results;

    } catch (error) {
      console.error('❌ Main error in automatic request processing:', error);
      throw error;
    }
  }

  /**
   * Evaluate registration request based on specific rules
   */
  static async evaluateRegistrationRequest(request) {
    const evaluation = {
      status: 'Pending',
      reason: '',
      score: 0,
      checks: {},
      financial_factors: {}
    };

    // 🔍 Check 1: Child data completeness
    evaluation.checks.childDataComplete = this.checkChildDataCompleteness(request.Child);
    evaluation.score += evaluation.checks.childDataComplete ? 20 : 0;

    // 🔍 Check 2: Availability of diagnosis or symptom analysis
    evaluation.checks.hasDiagnosisOrSymptoms = this.checkMedicalInformation(request.Child);
    evaluation.score += evaluation.checks.hasDiagnosisOrSymptoms ? 15 : 0;

    // 🔍 Check 3: Risk analysis
    evaluation.checks.riskLevel = await this.assessRiskLevel(request.Child);
    evaluation.score += evaluation.checks.riskLevel === 'Low' ? 25 : 
                        evaluation.checks.riskLevel === 'Medium' ? 15 : 5;

    // 🔍 Check 4: Availability of slots at the institution
    evaluation.checks.hasAvailableSlots = await this.checkInstitutionAvailability(
      request.institution_id,
      request.Child
    );
    evaluation.score += evaluation.checks.hasAvailableSlots ? 30 : 0;

    // 🔍 Check 5: Parent history with the institution (if they were previous clients)
    evaluation.checks.parentHistory = await this.checkParentHistory(
      request.requested_by_parent_id,
      request.institution_id
    );
    evaluation.score += evaluation.checks.parentHistory.goodHistory ? 10 : 0;

    // 🔍 Check 6: Institution capacity
    evaluation.checks.institutionCapacity = await this.checkInstitutionCapacity(request.institution_id);
    evaluation.score += evaluation.checks.institutionCapacity ? 10 : -10;

    

    // 📊 Make decision based on score
    if (evaluation.score >= 70) {
      evaluation.status = 'Approved';
      evaluation.reason = 'Request meets all auto-approval criteria';
    } else if (evaluation.score <= 30) {
      evaluation.status = 'Rejected';
      evaluation.reason = 'Request does not meet minimum requirements';
    } else {
      evaluation.status = 'Pending';
      evaluation.reason = 'Request needs manager review';
    }

    console.log(`📊 Evaluation of request ${request.request_id}: ${evaluation.score}/100 - ${evaluation.status}`);
    return evaluation;
  }

  /**
   * Automatic approval and smart scheduling with financial aid
   */
  static async approveAndScheduleAutomatically(request, decision) {
    console.log(`⏱️ Starting automatic approval for request ${request.request_id}`);
    
    // 🔥 Correction: Use Sequelize directly
    const transaction = await sequelize.transaction({
      isolationLevel: Sequelize.Transaction.ISOLATION_LEVELS.READ_COMMITTED,
      timeout: 30000
    });

    try {
      console.log(`✅ Automatic approval for request ${request.request_id}`);

      // 1️⃣ Update request status
      await ChildRegistrationRequest.update(
        {
          status: 'Approved',
          reviewed_at: new Date(),
          notes: `Auto-approved: ${decision.reason}`
        },
        {
          where: { request_id: request.request_id },
          transaction
        }
      );

      // 2️⃣ Update child status
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

      // 3️⃣ Find available General specialist
      const generalSpecialist = await this.findAvailableGeneralSpecialist(
        request.institution_id,
        request.Child
      );

      if (!generalSpecialist) {
        console.log('⚠️ No available General specialist, manager will be notified');
        await Notification.create({
          user_id: await this.getInstitutionManagerId(request.institution_id),
          title: 'Warning: No available specialist',
          message: `Request for ${request.Child.full_name} was approved but no General specialist is available. Please assign a specialist manually.`,
          type: 'specialist_needed',
          related_id: request.request_id,
          is_read: false
        }, { transaction });
        
        await transaction.commit();
        return;
      }

      console.log(`✅ Found specialist: ${generalSpecialist.User.full_name}`);
      
      // 4️⃣ Find available slot
      const availableSlot = await this.findNextAvailableSlot(
        generalSpecialist.specialist_id,
        60 // Session duration
      );

      if (!availableSlot) {
        console.log('⚠️ No available slots, manager will be notified');
        await Notification.create({
          user_id: await this.getInstitutionManagerId(request.institution_id),
          title: 'Warning: No available slots',
          message: `Request for ${request.Child.full_name} was approved but no slots are available for the specialist. Please intervene manually.`,
          type: 'scheduling_needed',
          related_id: request.request_id,
          is_read: false
        }, { transaction });
        
        await transaction.commit();
        return;
      }

      // 5️⃣ Create Initial Assessment session
      const initialAssessmentSession = await this.createInitialAssessmentSession(
        request.child_id,
        generalSpecialist.specialist_id,
        request.institution_id,
        availableSlot,
        transaction
      );

      // 6️⃣ Send basic approval notifications
      await this.sendApprovalNotifications(
        request,
        generalSpecialist,
        initialAssessmentSession,
        transaction
      );

      await this.sendManagerApprovalNotification(
      request,
      generalSpecialist,
      initialAssessmentSession,
      transaction
    );

      console.log(`✅ Initial assessment session booked: ${availableSlot.date} ${availableSlot.startTime}`);

      // 🔴 NEW: Apply automatic financial aid
      setTimeout(async () => {
        try {
          const AutoFinancialAidService = require('./autoFinancialAidService');
          const aidResult = await AutoFinancialAidService.autoApplyFinancialAid(initialAssessmentSession.session_id);
          
          console.log(`💰 Auto financial aid result:`, aidResult);
          
          // Update parent notification with financial aid information
          if (aidResult && aidResult.auto_applied) {
            let updatedMessage = `✅ Registration for ${request.Child.full_name} at ${request.Institution.name} has been approved.\n`;
            
            if (aidResult.final_price === 0) {
              updatedMessage += `🎉 Initial assessment session fully funded through automatic financial aid!`;
            } else if (aidResult.discount_amount > 0) {
              updatedMessage += `💰 Automatic discount of ${aidResult.discount_percentage.toFixed(2)}% applied to the session.`;
            }
            
            await Notification.update({
              message: updatedMessage
            }, {
              where: {
                user_id: request.requested_by_parent_id,
                related_id: request.request_id,
                type: 'registration_approved'
              }
            });
          }
        } catch (aidError) {
          console.error('❌ Error applying automatic financial aid:', aidError);
        }
      }, 1000); // Delay for one second

      await transaction.commit();
      console.log(`✅ Completed approval and booking process for request ${request.request_id}`);

    } catch (error) {
      console.error(`❌ Error in automatic approval for request ${request.request_id}:`, error);
      
      // Attempt safe rollback
      try {
        await transaction.rollback();
        console.log(`🔄 Transaction rolled back for request ${request.request_id}`);
      } catch (rollbackError) {
        console.error(`❌ Error rolling back transaction:`, rollbackError);
      }
      
      throw error;
    }
  }

  /**
   * Create Initial Assessment session
   */
  static async createInitialAssessmentSession(childId, specialistId, institutionId, slot, transaction = null) {
    console.log(`🔍 Looking for session type for institution ${institutionId}`);
    
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

    console.log(`📝 Creating new session: ${slot.date} ${slot.startTime}`);
    
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
      parent_notes: 'Initial assessment session - auto-booked after registration approval',
      original_price: originalPrice,
      final_price: finalPrice,
      applied_discount_percentage: 0,
      payment_status: 'Pending',
      financial_assistance_applied: false,
      is_paid: false,
      auto_financial_assistance: false
    };

    if (transaction) {
      return await Session.create(createOptions, { transaction });
    } else {
      return await Session.create(createOptions);
    }
  }

  static async sendManagerApprovalNotification(request, specialist, session, transaction = null) {
  const options = transaction ? { transaction } : {};
  const NotificationService = require('../services/notificationService');
  
  try {
    // Get manager ID
    const managerId = await this.getInstitutionManagerId(request.institution_id);
    
    if (!managerId) {
      console.log('⚠️ No manager to send notification to');
      return;
    }

    const notificationData = {
      type: 'child_auto_approved',
      child_name: request.Child.full_name,
      institution_name: request.Institution.name,
      child_id: request.child_id.toString(),
      specialist_name: specialist.User.full_name,
      session_date: session.date,
      session_time: session.time,
      session_id: session.session_id?.toString(),
      approval_type: 'auto',
      timestamp: new Date().toISOString()
    };

    // console.log(`📨 Sending notification to manager ${managerId} about auto-approval');

    // Use notification service to send to manager
    const result = await NotificationService.sendToManager(
      managerId,
      '✅ Automatic approval of child registration',
      `Auto-approved ${request.Child.full_name} and booked session with ${specialist.User.full_name}`,
      notificationData
    );

    // Also save notification in database
    await Notification.create({
      user_id: managerId,
      title: 'Automatic approval of child registration',
      message: `Auto-approved ${request.Child.full_name} at ${request.Institution.name}. 
                Initial assessment session booked with ${specialist.User.full_name} on ${session.date} at ${session.time}.`,
      type: 'auto_approval_notification',
      related_id: request.request_id,
      metadata: JSON.stringify(notificationData),
      is_read: false
    }, options);

    console.log(`✅ Sent approval notification to manager ${managerId}`);

  } catch (error) {
    console.error('❌ Error sending notification to manager:', error);
    // Don't stop process if notification fails
  }
}

// 🔥 **NEW: Update sendApprovalNotifications function**
static async sendApprovalNotifications(request, specialist, session, transaction = null) {
  const options = transaction ? { transaction } : {};
  
  console.log(`📨 Sending notifications for request ${request.request_id}`);
  
  // 1. Parent notification
  await Notification.create({
    user_id: request.requested_by_parent_id,
    title: 'Registration approved and first session booked',
    message: `✅ Auto-approved registration for ${request.Child.full_name} at ${request.Institution.name}. 
              Initial assessment session booked with ${specialist.User.full_name} on ${session.date} at ${session.time}.`,
    type: 'registration_approved',
    related_id: request.request_id,
    is_read: false
  }, options);

  // 2. Specialist notification
  await Notification.create({
    user_id: specialist.specialist_id,
    title: 'New initial assessment session',
    message: `👶 You have an initial assessment session with ${request.Child.full_name} on ${session.date} at ${session.time}. 
              Child: ${request.Child.age} years, ${request.Child.gender}.`,
    type: 'new_session',
    related_id: session.session_id,
    is_read: false
  }, options);

  // 3. 🔥 **NEW: Send push notifications to parent and specialist**
  const NotificationService = require('../services/notificationService');
  
  // Push notification to parent
  setTimeout(async () => {
    try {
      await NotificationService.sendToUser(
        request.requested_by_parent_id,
        '✅ Registration approved',
        `Registration for ${request.Child.full_name} at ${request.Institution.name} has been approved`,
        {
          type: 'registration_approved',
          child_id: request.child_id.toString(),
          institution_id: request.institution_id.toString()
        }
      );
    } catch (error) {
      console.error('❌ Error sending push to parent:', error);
    }
  }, 1000);

  // Push notification to specialist
  setTimeout(async () => {
    try {
      await NotificationService.sendToUser(
        specialist.specialist_id,
        '📅 New initial assessment session',
        `You have a session with ${request.Child.full_name} on ${session.date}`,
        {
          type: 'new_session',
          session_id: session.session_id?.toString(),
          child_id: request.child_id.toString()
        }
      );
    } catch (error) {
      console.error('❌ Error sending push to specialist:', error);
    }
  }, 1500);
}

  /**
   * Automatic rejection
   */
  static async rejectAutomatically(request, decision) {
    try {
      console.log(`❌ Automatic rejection for request ${request.request_id}`);

      await ChildRegistrationRequest.update(
        {
          status: 'Rejected',
          reviewed_at: new Date(),
          notes: `Auto-rejected: ${decision.reason}`
        },
        { where: { request_id: request.request_id } }
      );

      await Child.update(
        { registration_status: 'Rejected' },
        { where: { child_id: request.child_id } }
      );

      // Parent notification
      await Notification.create({
        user_id: request.requested_by_parent_id,
        title: 'Registration request rejected',
        message: `Sorry, registration request for ${request.Child.full_name} at ${request.Institution.name} has been rejected. 
                  Reason: ${decision.reason}`,
        type: 'registration_rejected',
        related_id: request.request_id,
        is_read: false
      });

    } catch (error) {
      console.error('❌ Error in automatic rejection:', error);
      throw error;
    }
  }

  // ==================== Helper functions ====================

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
    
    // Simple analysis based on symptoms
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
      // Find available General specialist at the institution
      const generalSpecialist = await Specialist.findOne({
        where: {
          institution_id: institutionId,
          specialization: { [Op.like]: '%General%' },
          approval_status: 'Approved'
        }
      });

      if (!generalSpecialist) {
        console.log('⚠️ No General specialist at institution');
        return false;
      }

      // Check if specialist has a schedule
      const hasSchedule = await SpecialistSchedule.findOne({
        where: { specialist_id: generalSpecialist.specialist_id }
      });

      if (!hasSchedule) {
        console.log('⚠️ Specialist does not have a work schedule');
        return false;
      }

      // Look for available slot in the next two weeks
      const availableSlot = await this.findNextAvailableSlot(generalSpecialist.specialist_id, 60);
      return !!availableSlot;

    } catch (error) {
      console.error('❌ Error checking institution availability:', error);
      return false;
    }
  }

  static async findAvailableGeneralSpecialist(institutionId, child) {
    console.log(`🔍 Looking for General specialist for institution ${institutionId}`);

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
        limit: 5
      });

      console.log(`📊 Found ${generalSpecialists.length} General specialists`);

      if (generalSpecialists.length === 0) {
        console.log('⚠️ No General specialist at institution');
        return null;
      }

      // Start with first specialist and try to find one with work schedule
      for (const specialist of generalSpecialists) {
        const hasSchedule = await SpecialistSchedule.findOne({
          where: { specialist_id: specialist.specialist_id },
          limit: 1
        });

        if (!hasSchedule) {
          console.log(`⚠️ Specialist ${specialist.User.full_name} has no schedule`);
          continue;
        }

        // Try to find quick slot (today and tomorrow only)
        const quickSlot = await this.findQuickAvailableSlot(specialist.specialist_id, 60);

        if (quickSlot) {
          console.log(`✅ Found quick slot for specialist ${specialist.User.full_name}: ${quickSlot.date}`);
          return specialist;
        }

        // Even if no quickSlot, return this specialist
        // Later we'll search for next available slot via findNextAvailableSlot
        console.log(`⚠️ No quick slot for specialist ${specialist.User.full_name}, will search for next available slot later`);
        return specialist;
      }

      // If none of the specialists have work schedules, return null
      console.log('⚠️ No General specialist has an active work schedule');
      return null;

    } catch (error) {
      console.error('❌ Error searching for specialist:', error);
      return null;
    }
  }

  static async findQuickAvailableSlot(specialistId, durationMinutes) {
    // Search in today and tomorrow only for nearest available slot
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

      // Get sessions only for this specific day
      const existingSessions = await Session.findAll({
        where: {
          specialist_id: specialistId,
          date: dateString,
          status: {
            [Op.notIn]: ['Cancelled', 'Rejected', 'Completed']
          }
        },
        attributes: ['time', 'session_type_id'],
        include: [
          {
            model: SessionType,
            attributes: ['duration'],
            required: false
          }
        ],
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
    const daysToCheck = 14; // Search within two weeks
    
    for (let i = 1; i <= daysToCheck; i++) {
      const targetDate = new Date();
      targetDate.setDate(targetDate.getDate() + i);
      const dateString = targetDate.toISOString().split('T')[0];
      const dayOfWeek = this.getDayName(targetDate.getDay());
      
      // 1. Check if there's a schedule on this day
      const schedule = await SpecialistSchedule.findOne({
        where: {
          specialist_id: specialistId,
          day_of_week: dayOfWeek
        }
      });

      if (!schedule) continue;

      // 2. Get scheduled sessions for this day
      const existingSessions = await Session.findAll({
        where: {
          specialist_id: specialistId,
          date: dateString,
          status: {
            [Op.notIn]: ['Cancelled', 'Rejected', 'Completed']
          }
        },
        attributes: ['time', 'session_type_id'],
        include: [
          {
            model: SessionType,
            attributes: ['duration'],
            required: false
          }
        ]
      });

      // 3. Find available time
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
    
    // Convert existing sessions to busy slots
    const busySlots = [];
    existingSessions.forEach(session => {
      const sessionStart = this.timeToMinutes(session.time);
      const sessionDuration = session.SessionType?.duration || 60;
      const sessionEnd = sessionStart + sessionDuration;
      busySlots.push({ start: sessionStart, end: sessionEnd });
    });

    // Search for available slot every 30 minutes
    for (let time = startMinutes; time <= endMinutes - durationMinutesInt; time += 30) {
      const slotEnd = time + durationMinutesInt;
      let isAvailable = true;
      
      // Check overlap with busy sessions
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

  static async processSingleRequest(requestId) {
    try {
      console.log(`🎯 Processing single request: ${requestId}`);
      
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
        console.log(`❌ Request ${requestId} not found or already processed`);
        return { success: false, message: 'Request not found or already processed' };
      }

      // 🚫 If the request is linked to a financial aid request, do not process automatically
      if (request.financial_assistance_request_id) {
        console.log(`💰 Request ${requestId} is linked to a financial aid request (${request.financial_assistance_request_id}), auto-approval will not be performed.`);
        return {
          success: true,
          status: 'Pending',
          request_id: request.request_id,
          reason: 'Linked to a financial aid request - needs manager review'
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
            reason: decision.reason,
            note: 'Approved and initial assessment session booked with automatic financial aid applied'
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

      console.log(`✅ Completed processing request ${requestId}: ${result.status}`);
      return result;

    } catch (error) {
      console.error(`❌ Error processing request ${requestId}:`, error);
      return { 
        success: false, 
        request_id: requestId,
        error: error.message 
      };
    }
  }

  static async checkParentHistory(parentId, institutionId) {
    // Check parent history with institution
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
    // Count current registered children
    const currentChildren = await Child.count({
      where: {
        current_institution_id: institutionId,
        registration_status: 'Approved'
      }
    });

    // Can add more complex logic here
    // For example: Check institution capacity from institutions table
    const institution = await Institution.findByPk(institutionId);
    const maxCapacity = institution.capacity || 100; // Default value
    
    return currentChildren < maxCapacity * 0.9; // 90% of capacity
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

  // ==================== Time conversion functions ====================

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