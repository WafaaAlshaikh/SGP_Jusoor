// services/autoSchedulingService.js
const { Session, SessionType, Specialist, SpecialistSchedule, User, Child, Institution } = require('../model');
const { Op } = require('sequelize');

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
}

module.exports = AutoSchedulingService;