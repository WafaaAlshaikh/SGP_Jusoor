  // services/autoSchedulingService.js
  const { Session, SessionType, Specialist, SpecialistSchedule, User, Child, Institution } = require('../model');
const { Op } = require('sequelize'); 
const sequelize = require('../config/db');
  const FinancialAssessmentService = require('./financialAssessmentService');


  class AutoSchedulingService {
    static async findAvailableSessions(childId, requiredSessionNames, institutionId) {
      try {
        const scheduledSessions = [];
        const failedSessions = []; // ✅ جديد: لتتبع الجلسات الفاشلة
        
        console.log('🔍 Looking for sessions:', requiredSessionNames, 'in institution:', institutionId);
        
        for (const sessionName of requiredSessionNames) {
          const sessionType = await SessionType.findOne({
            where: {
              institution_id: institutionId,
              name: sessionName,
              approval_status: 'Approved'
            }
          });

          if (!sessionType) {
            console.log(`❌ Session type not found for name: ${sessionName}`);
            failedSessions.push({
              session_name: sessionName,
              reason: 'Session type not found in system'
            });
            continue;
          }

          console.log(`✅ Found session type: ${sessionType.name}, Specialization: ${sessionType.specialist_specialization}`);

          const specialists = await Specialist.findAll({
            where: {
              institution_id: institutionId,
              specialization: sessionType.specialist_specialization,
              approval_status: 'Approved'
            },
            include: [
              {
                model: User,
                attributes: ['user_id', 'full_name']
              }
            ]
          });

          if (specialists.length === 0) {
            console.log(`❌ No specialists found for specialization: ${sessionType.specialist_specialization}`);
            failedSessions.push({
              session_name: sessionName,
              reason: `No specialists available for ${sessionType.specialist_specialization}`
            });
            continue;
          }

          console.log(`✅ Found ${specialists.length} specialists for ${sessionName}`);

          let sessionScheduled = false;
          
          for (const specialist of specialists) {
            const availableSlot = await this.findSpecialistAvailableSlot(
              specialist.specialist_id, 
              sessionType.duration
            );

            if (availableSlot) {
              const newSession = {
                child_id: childId,
                specialist_id: specialist.specialist_id,
                specialist_name: specialist.User.full_name,
                institution_id: institutionId,
                session_type_id: sessionType.session_type_id,
                date: availableSlot.date,
                time: availableSlot.startTime,
                session_type: 'Onsite',
                status: 'Scheduled',
                is_first_booking: true,
                requested_by_parent: false
              };

              scheduledSessions.push(newSession);
              console.log(`✅ Scheduled ${sessionName} with specialist ${specialist.User.full_name} on ${availableSlot.date} at ${availableSlot.startTime}`);
              sessionScheduled = true;
              
              break;
            }
          }

          // ✅ جديد: إذا ما انعقدت الجلسة بعد تجربة كل الأخصائيين
          if (!sessionScheduled) {
            console.log(`❌ Could not schedule ${sessionName} - no available slots found`);
            failedSessions.push({
              session_name: sessionName,
              reason: 'No available time slots found for any specialist'
            });
          }
        }

        console.log(`📅 Total scheduled sessions: ${scheduledSessions.length}`);
        console.log(`❌ Failed sessions: ${failedSessions.length}`);
        
        return {
          scheduled: scheduledSessions,
          failed: failedSessions // ✅ جديد: نرجع معلومات الجلسات الفاشلة
        };
      } catch (error) {
        console.error('❌ Auto-scheduling error:', error);
        return {
        scheduled: [],
        failed: []
      };
      }
    }
  static async findSpecialistAvailableSlot(specialistId, duration) {
      const daysToCheck = 7;
      
      for (let i = 1; i <= daysToCheck; i++) {
        const targetDate = new Date();
        targetDate.setDate(targetDate.getDate() + i);
        const dayOfWeek = this.getDayName(targetDate.getDay());
        
        const schedule = await SpecialistSchedule.findOne({
          where: {
            specialist_id: specialistId,
            day_of_week: dayOfWeek
          }
        });

        if (!schedule) {
          console.log(`No schedule found for specialist ${specialistId} on ${dayOfWeek}`);
          continue;
        }

        const existingSessions = await Session.findAll({
          where: {
            specialist_id: specialistId,
            date: targetDate.toISOString().split('T')[0],
            status: {
              [Op.notIn]: ['Cancelled', 'Rejected']
            }
          },
          include: [{
            model: SessionType,
            attributes: ['duration']
          }]
        });

        const availableSlot = this.findAvailableTime(
          schedule.start_time, 
          schedule.end_time, 
          duration, 
          existingSessions
        );

        if (availableSlot) {
          return {
            date: targetDate.toISOString().split('T')[0],
            startTime: availableSlot
          };
        }
      }
      
      console.log(`No available slots found for specialist ${specialistId} in the next ${daysToCheck} days`);
      return null;
    }

    static findAvailableTime(startTime, endTime, duration, existingSessions) {
      const startMinutes = this.timeToMinutes(startTime);
      const endMinutes = this.timeToMinutes(endTime);
      const durationMinutes = duration;
      
      const busySlots = existingSessions.map(session => {
        const sessionStart = this.timeToMinutes(session.time);
        const sessionDuration = session.SessionType?.duration || 60;
        const sessionEnd = sessionStart + sessionDuration;
        
        return { start: sessionStart, end: sessionEnd };
      });

      for (let time = startMinutes; time <= endMinutes - durationMinutes; time += 30) {
        const slotEnd = time + durationMinutes;
        const isAvailable = !busySlots.some(busy => 
          (time >= busy.start && time < busy.end) ||
          (slotEnd > busy.start && slotEnd <= busy.end) ||
          (time <= busy.start && slotEnd >= busy.end)
        );

        if (isAvailable) {
          const slotTime = this.minutesToTime(time);
          return slotTime;
        }
      }
      
      return null;
    }

    static timeToMinutes(timeStr) {
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




    /**
     * Find and schedule sessions for a child with financial assistance
     */
    static async scheduleSessionsWithFinancialAssistance(childId, institutionId, financialRequest = null) {
      try {
        console.log(`🤖 Starting auto-scheduling for child ${childId} with financial assistance`);
        
        // Get child information
        const child = await Child.findByPk(childId, {
          include: [{
            model: require('../model/Diagnosis'),
            as: 'Diagnosis',
            attributes: ['name']
          }]
        });
        
        if (!child) {
          throw new Error('Child not found');
        }
        
        // Determine required session types based on child's condition
        const requiredSessionNames = await this.determineRequiredSessions(child, institutionId);
        
        if (requiredSessionNames.length === 0) {
          console.log('No required sessions found for child');
          return { success: false, message: 'No matching session types found' };
        }
        
        console.log(`📋 Required sessions: ${requiredSessionNames.join(', ')}`);
        
        // Get financial details
        let discountPercentage = 0;
        let financialAssistanceRequestId = null;
        
        if (financialRequest) {
          discountPercentage = financialRequest.approved_discount_percentage || 
                              financialRequest.requested_discount_percentage || 0;
          financialAssistanceRequestId = financialRequest.request_id;
        }
        
        // Find available slots and specialists for each session type
        const scheduledSessions = [];
        const failedSessions = [];
        
        for (const sessionName of requiredSessionNames) {
          const sessionResult = await this.scheduleSingleSession(
            childId,
            institutionId,
            sessionName,
            discountPercentage,
            financialAssistanceRequestId
          );
          
          if (sessionResult.success) {
            scheduledSessions.push(sessionResult.session);
          } else {
            failedSessions.push({
              session_name: sessionName,
              reason: sessionResult.reason
            });
          }
        }
        
        // Send notifications
        await this.sendSchedulingNotifications(
          childId,
          scheduledSessions.length,
          discountPercentage,
          financialAssistanceRequestId
        );
        
        return {
          success: true,
          scheduled_sessions: scheduledSessions,
          failed_sessions: failedSessions,
          financial_assistance_applied: discountPercentage > 0,
          discount_percentage: discountPercentage,
          total_sessions_scheduled: scheduledSessions.length,
          total_sessions_failed: failedSessions.length
        };
        
      } catch (error) {
        console.error('❌ Error in auto-scheduling:', error);
        return {
          success: false,
          error: error.message
        };
      }
    }

    /**
     * Schedule a single session
     */
    static async scheduleSingleSession(childId, institutionId, sessionName, discountPercentage, financialRequestId) {
      try {
        // Find session type
        const sessionType = await SessionType.findOne({
          where: {
            institution_id: institutionId,
            name: sessionName,
            approval_status: 'Approved'
          }
        });
        
        if (!sessionType) {
          return { success: false, reason: 'Session type not found' };
        }
        
        // Find available specialists
        const specialists = await Specialist.findAll({
          where: {
            institution_id: institutionId,
            specialization: sessionType.specialist_specialization,
            approval_status: 'Approved',
            is_active: true
          },
          include: [{
            model: require('../model/User'),
            attributes: ['full_name']
          }]
        });
        
        if (specialists.length === 0) {
          return { success: false, reason: 'No available specialists' };
        }
        
        // Try each specialist for availability
        for (const specialist of specialists) {
          const availableSlot = await this.findAvailableSlotForSpecialist(
            specialist.specialist_id,
            sessionType.duration
          );
          
          if (availableSlot) {
  // 1️⃣ تأكد من وجود سعر الجلسة الأصلي
  const originalPrice = parseFloat(sessionType.price) || 0;

  // 2️⃣ حساب السعر النهائي بعد الخصم
  const finalPrice = originalPrice - (originalPrice * (discountPercentage || 0) / 100);

  // 3️⃣ إنشاء الجلسة
  const session = await Session.create({
    child_id: childId,
    specialist_id: specialist.specialist_id,
    institution_id: institutionId,
    session_type_id: sessionType.session_type_id,
    date: availableSlot.date,
    time: availableSlot.startTime,
    session_type: 'Onsite',
    status: 'Scheduled',
    original_price: originalPrice,
    applied_discount_percentage: discountPercentage || 0,
    final_price: finalPrice,
    financial_assistance_applied: discountPercentage > 0,
    financial_assistance_request_id: financialRequestId,
    payment_status: discountPercentage === 100 ? 'free_session' : 'pending',
    discount_reason: discountPercentage > 0 ? 'Financial assistance applied' : 'Regular pricing',
    is_first_booking: true
  });

  return {
    success: true,
    session: {
      session_id: session.session_id,
      date: session.date,
      time: session.time,
      specialist_name: specialist.User.full_name,
      session_type: sessionType.name,
      original_price: originalPrice,
      discount_percentage: discountPercentage || 0,
      final_price: finalPrice
    }
  };
}

        }
        
        return { success: false, reason: 'No available time slots' };
        
      } catch (error) {
        console.error('Error scheduling single session:', error);
        return { success: false, reason: 'Internal error' };
      }
    }
    
    /**
     * Determine required sessions based on child's condition
     */
    static async determineRequiredSessions(child, institutionId) {
      const sessionNames = [];
      
      // Use AI analysis if available
      if (child.ai_suggested_diagnosis) {
        const aiConditions = child.ai_suggested_diagnosis
          .filter(c => c.confidence > 0.4)
          .map(c => c.name);
        
        for (const condition of aiConditions) {
          const matchingSessions = await SessionType.findAll({
            where: {
              institution_id: institutionId,
              approval_status: 'Approved',
              [Op.or]: [
                { name: { [Op.like]: `%${condition}%` } },
                { specialist_specialization: { [Op.like]: `%${condition}%` } }
              ]
            },
            attributes: ['name'],
            limit: 2
          });
          
          matchingSessions.forEach(session => {
            if (!sessionNames.includes(session.name)) {
              sessionNames.push(session.name);
            }
          });
        }
      }
      
      // If no AI analysis, use diagnosis
      if (sessionNames.length === 0 && child.Diagnosis) {
        const diagnosisMap = {
          'ASD': ['Speech Therapy', 'Occupational Therapy', 'Behavioral Therapy'],
          'ADHD': ['Behavioral Therapy', 'Occupational Therapy', 'Focus Training'],
          'Down Syndrome': ['Speech Therapy', 'Physical Therapy', 'Occupational Therapy'],
          'Speech & Language Disorder': ['Speech Therapy', 'Language Therapy']
        };
        
        const defaultSessions = diagnosisMap[child.Diagnosis.name] || ['Initial Assessment'];
        
        // Check which sessions are available in the institution
        const availableSessions = await SessionType.findAll({
          where: {
            institution_id: institutionId,
            name: { [Op.in]: defaultSessions },
            approval_status: 'Approved'
          },
          attributes: ['name']
        });
        
        availableSessions.forEach(session => {
          sessionNames.push(session.name);
        });
      }
      
      // Ensure at least initial assessment
      if (sessionNames.length === 0) {
        sessionNames.push('Initial Assessment');
      }
      
      return sessionNames.slice(0, 3); // Limit to 3 sessions initially
    }
    
    /**
     * Find available time slot for a specialist
     */
    static async findAvailableSlotForSpecialist(specialistId, duration) {
      const daysToCheck = 14; // Look ahead 2 weeks
      
      for (let i = 1; i <= daysToCheck; i++) {
        const targetDate = new Date();
        targetDate.setDate(targetDate.getDate() + i);
        const dateString = targetDate.toISOString().split('T')[0];
        const dayOfWeek = this.getDayName(targetDate.getDay());
        
        // Check specialist schedule
        const schedule = await SpecialistSchedule.findOne({
          where: {
            specialist_id: specialistId,
            day_of_week: dayOfWeek
          }
        });
        
        if (!schedule) continue;
        
        // Get existing sessions for this date
        const existingSessions = await Session.findAll({
          where: {
            specialist_id: specialistId,
            date: dateString,
            status: {
              [Op.notIn]: ['Cancelled', 'Rejected', 'Completed']
            }
          }
        });
        
        // Find available time
        const availableTime = this.findAvailableTimeInSchedule(
          schedule.start_time,
          schedule.end_time,
          duration,
          existingSessions
        );
        
        if (availableTime) {
          return {
            date: dateString,
            startTime: availableTime
          };
        }
      }
      
      return null;
    }
    
    /**
     * Find available time in schedule
     */
    static findAvailableTimeInSchedule(startTime, endTime, duration, existingSessions) {
      const startMinutes = this.timeToMinutes(startTime);
      const endMinutes = this.timeToMinutes(endTime);
      const durationMinutes = duration;
      
      // Convert existing sessions to busy slots
      const busySlots = existingSessions.map(session => {
        const sessionStart = this.timeToMinutes(session.time);
        const sessionEnd = sessionStart + (session.duration || 60);
        return { start: sessionStart, end: sessionEnd };
      });
      
      // Check every 30-minute interval
      for (let time = startMinutes; time <= endMinutes - durationMinutes; time += 30) {
        const slotEnd = time + durationMinutes;
        let isAvailable = true;
        
        // Check against busy slots
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
     * Send notifications after scheduling
     */
    static async sendSchedulingNotifications(childId, sessionsCount, discountPercentage, financialRequestId) {
      try {
        // Get child and parent info
        const child = await Child.findByPk(childId, {
          include: [{
            model: require('../model/Parent'),
            attributes: ['parent_id']
          }]
        });
        
        if (!child || !child.Parent) return;
        
        const Notification = require('../model/Notification');
        let message = '';
        
        if (discountPercentage === 100) {
          message = `✅ ${sessionsCount} free therapy sessions have been scheduled for ${child.full_name} through our financial assistance program.`;
        } else if (discountPercentage > 0) {
          message = `✅ ${sessionsCount} therapy sessions have been scheduled for ${child.full_name} with ${discountPercentage}% financial assistance discount.`;
        } else {
          message = `✅ ${sessionsCount} therapy sessions have been scheduled for ${child.full_name}.`;
        }
        
        // Send to parent
        await Notification.create({
          user_id: child.Parent.parent_id,
          title: 'Sessions Scheduled',
          message: message,
          type: 'session_scheduled',
          related_id: financialRequestId || childId,
          is_read: false
        });
        
        console.log('📧 Notifications sent for scheduled sessions');
        
      } catch (error) {
        console.error('Error sending notifications:', error);
      }
    }
    
    // Utility methods
    static timeToMinutes(timeStr) {
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

  module.exports = AutoSchedulingService;