const Session = require('../model/Session');
const Child = require('../model/Child');
const User = require('../model/User');
const Parent = require('../model/Parent');
const Specialist = require('../model/Specialist');
const Institution = require('../model/Institution');
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
module.exports = {
  getUpcomingSessionsCount,
  getChildrenCount,
  addSession,
  getProfileInfo,
  getChildrenInInstitution,
  getImminentSessions
};