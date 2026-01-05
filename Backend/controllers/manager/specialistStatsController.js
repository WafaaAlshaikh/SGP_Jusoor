const { Sequelize, Op } = require('sequelize');
const sequelize = require('../../config/db');
const bcrypt = require('bcryptjs');
const nodemailer = require('nodemailer');
const NotificationService = require('../../services/notificationService');
const {
  Session,
  SessionType,
  Specialist,
  User,
  Institution,
  VacationRequest,
  Manager,
  SpecialistSchedule,
  Child,
  SessionRating 
} = require('../../model/index');

// ==================== دوال مساعدة جديدة ====================

/**
 * جلب FCM Token للأخصائي من قاعدة البيانات
 * @param {number} specialistId - معرف الأخصائي
 * @returns {Promise<string|null>} - FCM Token أو null إذا لم يوجد
 */
const getSpecialistFCMToken = async (specialistId) => {
  try {
    const [tokenResult] = await sequelize.query(`
      SELECT token 
      FROM UserDeviceTokens 
      WHERE user_id = ? 
        AND is_active = 1
      ORDER BY updated_at DESC 
      LIMIT 1
    `, { replacements: [specialistId] });

    return tokenResult.length > 0 ? tokenResult[0].token : null;
  } catch (error) {
    console.error('❌ خطأ في جلب FCM Token للأخصائي:', error);
    return null;
  }
};

// 🔧 دالة مساعدة لإرسال إشعارات الجداول
const sendScheduleNotification = async (specialistToken, action, scheduleData) => {
  try {
    if (!specialistToken || specialistToken.trim() === '') {
      console.log('⚠️ لا يوجد توكن للأخصائي لإرسال إشعار الجدول');
      return;
    }

    let title, body, notificationData = {};

    switch (action) {
      case 'added':
        title = '📅 New Schedule Added';
        body = `New schedule added for ${scheduleData.day_of_week}: ${scheduleData.start_time} - ${scheduleData.end_time}`;
        notificationData = {
          type: 'schedule_change',
          action: 'added',
          day_of_week: scheduleData.day_of_week,
          start_time: scheduleData.start_time,
          end_time: scheduleData.end_time,
          schedule_id: scheduleData.schedule_id?.toString(),
          timestamp: new Date().toISOString(),
          channel: 'default_channel'  // ⬅️ أضف هذا
        };
        break;

      case 'updated':
        title = '🔄 Schedule Updated';
        body = `Schedule for ${scheduleData.day_of_week} has been updated`;
        notificationData = {
          type: 'schedule_change',
          action: 'updated',
          day_of_week: scheduleData.day_of_week,
          start_time: scheduleData.start_time || '',
          end_time: scheduleData.end_time || '',
          schedule_id: scheduleData.schedule_id?.toString(),
          timestamp: new Date().toISOString(),
          channel: 'default_channel'  // ⬅️ أضف هذا
        };
        break;

      case 'deleted':
        title = '🗑️ Schedule Deleted';
        body = `Schedule for ${scheduleData.day_of_week} has been deleted`;
        notificationData = {
          type: 'schedule_change',
          action: 'deleted',
          schedule_id: scheduleData.schedule_id?.toString(),
          timestamp: new Date().toISOString(),
          channel: 'default_channel'  // ⬅️ أضف هذا
        };
        break;

      case 'bulk_added':
        title = '📋 Multiple Schedules Added';
        body = `${scheduleData.count} schedules have been added`;
        notificationData = {
          type: 'schedule_change',
          action: 'bulk_added',
          count: scheduleData.count?.toString(),
          timestamp: new Date().toISOString(),
          channel: 'default_channel'  // ⬅️ أضف هذا
        };
        break;

      default:
        title = '📅 Schedule Modified';
        body = 'Your schedule has been modified';
        notificationData = {
          channel: 'default_channel'  // ⬅️ أضف هذا
        };
    }

    await NotificationService.sendToToken(
      specialistToken.trim(),
      title,
      body,
      notificationData
    );

    console.log(`✅ إشعار الجدول ${action} تم إرساله`);
  } catch (error) {
    console.error(`❌ خطأ في إرسال إشعار الجدول ${action}:`, error.message);
  }
};

// Helper function to send welcome email
const sendWelcomeEmail = async (email, full_name, password) => {
  try {
    // Create transporter
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: process.env.SMTP_PORT || 587,
      secure: false,
      auth: {
        user: process.env.SMTP_USER || process.env.EMAIL_USER,
        pass: process.env.SMTP_PASS || process.env.EMAIL_PASS
      },
      tls: {
        rejectUnauthorized: false
      }
    });

    // Plain text email
    const emailText = `
Hello ${full_name},

Welcome to Jusoor Specialized Centers Management System!

Your account has been successfully created as a Specialist.

Your account details:
- Email: ${email}
- Password: ${password}

We recommend changing your password immediately after logging into the system.

To access the system, please use the link below and log in using the provided email and password.

Best regards,
Jusoor System Team
`;

    // HTML email
    const emailHtml = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to Jusoor System</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f4f4f4;
        }
        .container {
            max-width: 600px;
            margin: 20px auto;
            background-color: #ffffff;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px 20px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
        }
        .content {
            padding: 30px;
        }
        .welcome {
            font-size: 20px;
            color: #2c3e50;
            margin-bottom: 20px;
        }
        .credentials {
            background-color: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            border-left: 4px solid #667eea;
        }
        .credential-item {
            margin: 10px 0;
            padding: 8px 0;
            border-bottom: 1px solid #e9ecef;
        }
        .credential-item:last-child {
            border-bottom: none;
        }
        .label {
            font-weight: bold;
            color: #495057;
            display: inline-block;
            width: 120px;
        }
        .value {
            color: #212529;
            font-family: monospace;
        }
        .password-note {
            background-color: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 5px;
            padding: 15px;
            margin: 20px 0,
            color: #856404;
        }
        .button {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
            margin: 10px 0;
            text-align: center;
        }
        .footer {
            background-color: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #6c757d;
            font-size: 14px;
            border-top: 1px solid #e9ecef;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Welcome to Jusoor System</h1>
        </div>
        
        <div class="content">
            <div class="welcome">
                🌟 Hello <strong>${full_name}</strong>,
            </div>
            
            <p>Your account as a Specialist in the Jusoor Centers Management System has been successfully created!</p>
            
            <div class="credentials">
                <div class="credential-item">
                    <span class="label">📧 Email:</span>
                    <span class="value">${email}</span>
                </div>
                <div class="credential-item">
                    <span class="label">🔑 Password:</span>
                    <span class="value">${password}</span>
                </div>
            </div>
            
            <div class="password-note">
                ⚠️ <strong>Important:</strong> We recommend changing your password immediately after logging in to protect your account.
            </div>
            
            <p>You can access the system using the link below:</p>
            
            <div style="text-align: center; margin: 30px 0;">
                <a href="http://localhost:3000/login" class="button">
                    🚪 Login to the System
                </a>
            </div>
            
            <p>If you encounter any issues, please contact your institution manager.</p>
        </div>
        
        <div class="footer">
            <p>Best regards,<br>The <strong>Jusoor</strong> System Team</p>
            <p>📧 ${process.env.SMTP_FROM || 'support@jusoor.com'}</p>
            <p>© ${new Date().getFullYear()} Jusoor System. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
`;

    // Email options
    const mailOptions = {
      from: process.env.SMTP_FROM || process.env.SMTP_USER || process.env.EMAIL_USER,
      to: email,
      subject: 'Welcome to Jusoor System – Your Account Details',
      text: emailText,
      html: emailHtml
    };

    // Send email
    const info = await transporter.sendMail(mailOptions);
    console.log('📧 Welcome email sent to:', email, 'Message ID:', info.messageId);
    return true;

  } catch (error) {
    console.error('❌ Error sending welcome email:', error);
    return false;
  }
};

// ==================== وظائف الإحصائيات الحالية (محفوظة) ====================

/**
 * @desc    Get specialists count by session type
 * @route   GET /api/manager/stats/by-session-type
 * @access  Private/Manager
 */
exports.getSpecialistsBySessionType = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // الحصول على أنواع الجلسات للمؤسسة
    const sessionTypes = await SessionType.findAll({
      where: { 
        institution_id: institutionId,
        approval_status: 'Approved'
      },
      attributes: ['session_type_id', 'name', 'category', 'specialist_specialization']
    });

    const result = [];

    for (const sessionType of sessionTypes) {
      // الحصول على الاخصائيين الذين يطابقون التخصص
      const specialists = await Specialist.findAll({
        where: {
          institution_id: institutionId,
          specialization: sessionType.specialist_specialization,
          approval_status: 'Approved'
        },
        include: [{
          model: User,
          where: { status: 'Approved' },
          attributes: ['user_id', 'full_name', 'email']
        }]
      });

      // حساب عدد الجلسات لكل أخصائي لهذا النوع
      const specialistsWithSessions = await Promise.all(
        specialists.map(async (specialist) => {
          const sessionCount = await Session.count({
            where: {
              specialist_id: specialist.specialist_id,
              session_type_id: sessionType.session_type_id,
              institution_id: institutionId
            }
          });

          return {
            specialist_id: specialist.specialist_id,
            full_name: specialist.User.full_name,
            email: specialist.User.email,
            specialization: specialist.specialization,
            session_count: sessionCount
          };
        })
      );

      result.push({
        session_type_id: sessionType.session_type_id,
        session_type_name: sessionType.name,
        category: sessionType.category,
        specialization: sessionType.specialist_specialization,
        total_specialists: specialists.length,
        specialists: specialistsWithSessions
      });
    }

    res.json({
      success: true,
      data: result,
      total_session_types: sessionTypes.length
    });

  } catch (error) {
    console.error('Error getting specialists by session type:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Get active specialists count
 * @route   GET /api/manager/stats/active-count
 * @access  Private/Manager
 */
exports.getActiveSpecialistsCount = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // حساب الأخصائيين النشطين (approved)
    const activeSpecialistsCount = await Specialist.count({
      where: {
        institution_id: institutionId,
        approval_status: 'Approved'
      },
      include: [{
        model: User,
        where: { status: 'Approved' },
        attributes: []
      }]
    });

    res.json({
      success: true,
      data: {
        institution_id: institutionId,
        active_specialists_count: activeSpecialistsCount
      }
    });

  } catch (error) {
    console.error('Error getting active specialists count:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Get vacation statistics
 * @route   GET /api/manager/stats/vacations
 * @access  Private/Manager
 */
exports.getVacationStatistics = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // الحصول على أخصائيي المؤسسة
    const institutionSpecialists = await Specialist.findAll({
      where: { institution_id: institutionId },
      attributes: ['specialist_id']
    });

    const specialistIds = institutionSpecialists.map(s => s.specialist_id);

    // تاريخ اليوم
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // 1. الأخصائيين الغائبين اليوم
    const absentToday = await VacationRequest.count({
      where: {
        specialist_id: { [Op.in]: specialistIds },
        status: 'Approved',
        start_date: { [Op.lte]: today },
        end_date: { [Op.gte]: today }
      }
    });

    // 2. إجمالي طلبات الإجازة (جميع الحالات)
    const totalVacationRequests = await VacationRequest.count({
      where: {
        specialist_id: { [Op.in]: specialistIds }
      }
    });

    // 3. طلبات الإجازة حسب الحالة
    const requestsByStatus = await VacationRequest.findAll({
      where: {
        specialist_id: { [Op.in]: specialistIds }
      },
      attributes: [
        'status',
        [Sequelize.fn('COUNT', Sequelize.col('request_id')), 'count']
      ],
      group: ['status']
    });

    const statusCounts = {};
    requestsByStatus.forEach(item => {
      statusCounts[item.status] = parseInt(item.dataValues.count);
    });

    res.json({
      success: true,
      data: {
        institution_id: institutionId,
        total_specialists: specialistIds.length,
        absent_today_count: absentToday,
        total_vacation_requests: totalVacationRequests,
        vacation_requests_by_status: statusCounts
      }
    });

  } catch (error) {
    console.error('Error getting vacation statistics:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Get average sessions per day
 * @route   GET /api/manager/stats/average-sessions
 * @access  Private/Manager
 */
exports.getAverageSessionsPerDay = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // الحصول على آخر 30 يوم
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // الحصول على الجلسات المكتملة في آخر 30 يوم
    const sessionsLast30Days = await Session.findAll({
      where: {
        institution_id: institutionId,
        status: 'Completed',
        date: {
          [Op.gte]: thirtyDaysAgo,
          [Op.lte]: new Date()
        }
      },
      attributes: ['date']
    });

    // حساب عدد الأيام الفعلية التي بها جلسات
    const daysWithSessions = [...new Set(sessionsLast30Days.map(s => {
      const date = new Date(s.date);
      return date.toISOString().split('T')[0];
    }))];
    
    let averageSessionsPerDay = 0;
    
    if (daysWithSessions.length > 0) {
      const totalSessions = sessionsLast30Days.length;
      averageSessionsPerDay = totalSessions / daysWithSessions.length;
    }

    // إحصائيات مفصلة
    const dailyStats = await Session.findAll({
      where: {
        institution_id: institutionId,
        status: 'Completed',
        date: {
          [Op.gte]: thirtyDaysAgo,
          [Op.lte]: new Date()
        }
      },
      attributes: [
        [Sequelize.fn('DATE', Sequelize.col('date')), 'day'],
        [Sequelize.fn('COUNT', Sequelize.col('session_id')), 'session_count']
      ],
      group: [Sequelize.fn('DATE', Sequelize.col('date'))],
      order: [[Sequelize.fn('DATE', Sequelize.col('date')), 'DESC']]
    });

    // تحويل النتائج إلى شكل أبسط
    const formattedDailyStats = dailyStats.map(stat => ({
      day: stat.dataValues.day,
      session_count: parseInt(stat.dataValues.session_count)
    }));

    res.json({
      success: true,
      data: {
        institution_id: institutionId,
        period_days: 30,
        total_sessions_last_30_days: sessionsLast30Days.length,
        days_with_sessions: daysWithSessions.length,
        average_sessions_per_day: Math.round(averageSessionsPerDay * 100) / 100,
        daily_statistics: formattedDailyStats
      }
    });

  } catch (error) {
    console.error('Error getting average sessions per day:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Get all specialist statistics (comprehensive)
 * @route   GET /api/manager/stats/comprehensive
 * @access  Private/Manager
 */
exports.getComprehensiveStatistics = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const institutionName = manager.Institution.name;

    // 1. عدد الأخصائيين النشطين
    const activeSpecialistsCount = await Specialist.count({
      where: {
        institution_id: institutionId,
        approval_status: 'Approved'
      },
      include: [{
        model: User,
        where: { status: 'Approved' },
        attributes: []
      }]
    });

    // 2. الأخصائيين حسب التخصص
    const specialistsBySpecialization = await Specialist.findAll({
      where: {
        institution_id: institutionId,
        approval_status: 'Approved'
      },
      include: [{
        model: User,
        where: { status: 'Approved' },
        attributes: []
      }],
      attributes: [
        'specialization',
        [Sequelize.fn('COUNT', Sequelize.col('specialist_id')), 'count']
      ],
      group: ['specialization']
    });

    // تحويل النتائج
    const formattedSpecialists = specialistsBySpecialization.map(spec => ({
      specialization: spec.specialization,
      count: parseInt(spec.dataValues.count)
    }));

    // 3. إحصائيات الجلسات
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const sessionsStats = await Session.findAll({
      where: {
        institution_id: institutionId,
        date: {
          [Op.gte]: thirtyDaysAgo,
          [Op.lte]: new Date()
        }
      },
      attributes: [
        'status',
        [Sequelize.fn('COUNT', Sequelize.col('session_id')), 'count']
      ],
      group: ['status']
    });

    const formattedSessionsStats = {};
    sessionsStats.forEach(stat => {
      formattedSessionsStats[stat.status] = parseInt(stat.dataValues.count);
    });

    // 4. أنواع الجلسات الأكثر شيوعاً - باستخدام استعلام منفصل
    const popularSessionTypes = await sequelize.query(
      `SELECT 
        st.name as session_type,
        st.category,
        COUNT(s.session_id) as count
      FROM Sessions s
      INNER JOIN SessionTypes st ON s.session_type_id = st.session_type_id
      WHERE s.institution_id = ?
        AND s.date >= ?
        AND s.date <= ?
      GROUP BY s.session_type_id, st.name, st.category
      ORDER BY count DESC
      LIMIT 5`,
      {
        replacements: [institutionId, thirtyDaysAgo, new Date()],
        type: Sequelize.QueryTypes.SELECT
      }
    );

    const formattedPopularTypes = popularSessionTypes.map(type => ({
      session_type: type.session_type,
      category: type.category,
      count: parseInt(type.count)
    }));

    // 5. إحصائيات الإجازات
    const specialistIds = await Specialist.findAll({
      where: { institution_id: institutionId },
      attributes: ['specialist_id']
    }).then(specs => specs.map(s => s.specialist_id));

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let absentToday = 0;
    let totalRequests = 0;
    let formattedVacationStats = {};

    if (specialistIds.length > 0) {
      absentToday = await VacationRequest.count({
        where: {
          specialist_id: { [Op.in]: specialistIds },
          status: 'Approved',
          start_date: { [Op.lte]: today },
          end_date: { [Op.gte]: today }
        }
      });

      totalRequests = await VacationRequest.count({
        where: { specialist_id: { [Op.in]: specialistIds } }
      });

      const vacationByStatus = await VacationRequest.findAll({
        where: { specialist_id: { [Op.in]: specialistIds } },
        attributes: [
          'status',
          [Sequelize.fn('COUNT', Sequelize.col('request_id')), 'count']
        ],
        group: ['status']
      });

      vacationByStatus.forEach(stat => {
        formattedVacationStats[stat.status] = parseInt(stat.dataValues.count);
      });
    }

    res.json({
      success: true,
      data: {
        institution: {
          id: institutionId,
          name: institutionName
        },
        active_specialists: activeSpecialistsCount,
        specialists_by_specialization: formattedSpecialists,
        sessions_last_30_days: formattedSessionsStats,
        popular_session_types: formattedPopularTypes,
        vacation_statistics: {
          absent_today: absentToday,
          total_requests: totalRequests,
          by_status: formattedVacationStats
        },
        generated_at: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('Error getting comprehensive statistics:', error);
    console.error('SQL Error:', error.sql);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
      details: error.parent ? error.parent.message : null
    });
  }
};

// ==================== وظائف إدارة الأخصائيين الجديدة ====================

/**
 * @desc    Add new specialist
 * @route   POST /api/manager/specialists
 * @access  Private/Manager
 */
exports.addSpecialist = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // Get manager institution
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const institutionName = manager.Institution.name;
    
    // New specialist data
    const {
      full_name,
      email,
      phone,
      specialization,
      years_experience,
      salary
    } = req.body;

    // Required fields validation
    if (!full_name || !email || !specialization) {
      return res.status(400).json({
        success: false,
        message: 'Full name, email, and specialization are required'
      });
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid email format'
      });
    }

    // Check if email already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email is already registered'
      });
    }

    // Generate a strong random password
    const generatePassword = () => {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
      let password = '';
      for (let i = 0; i < 12; i++) {
        password += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return password;
    };

    const generatedPassword = generatePassword();

    // Hash the password
    const hashedPassword = await bcrypt.hash(generatedPassword, 10);

    // Start DB transaction
    const transaction = await sequelize.transaction();

    try {
      console.log('🔍 Step 1: Creating user account for:', email);
      
      // 1. Create new user
      const newUser = await User.create({
        full_name,
        email,
        phone: phone || null,
        password: hashedPassword,
        role: 'Specialist',
        institution_id: institutionId,
        status: 'Approved',
        profile_picture: null
      }, { transaction });

      console.log('✅ User created with ID:', newUser.user_id);

      console.log('🔍 Step 2: Creating specialist record');
      
      // 2. Create specialist record
      const newSpecialist = await Specialist.create({
        specialist_id: newUser.user_id,
        specialization,
        years_experience: years_experience || null,
        salary: salary || null,
        institution_id: institutionId,
        approval_status: 'Approved'
      }, { transaction });

      console.log('✅ Specialist record created');

      console.log('🔍 Step 3: Sending welcome email');
      
      // 3. Send welcome email with password
      const emailSent = await sendWelcomeEmail(email, full_name, generatedPassword);
      
      if (!emailSent) {
        console.log('⚠️ Warning: Email could not be sent, but specialist was created');
      } else {
        console.log('✅ Welcome email sent successfully');
      }

      await transaction.commit();

      res.status(201).json({
        success: true,
        message: 'Specialist added successfully and password sent to their email',
        data: {
          user_id: newUser.user_id,
          full_name: newUser.full_name,
          email: newUser.email,
          phone: newUser.phone,
          specialization: newSpecialist.specialization,
          years_experience: newSpecialist.years_experience,
          salary: newSpecialist.salary,
          email_sent: emailSent,
          institution: institutionName
        },
        notes: emailSent ? 
          'Password was sent to the specialist email' : 
          'Account created but email was not sent, please inform the specialist manually'
      });

      console.log('🎉 Specialist added successfully:', newUser.full_name);

    } catch (error) {
      await transaction.rollback();
      console.error('❌ Transaction rolled back:', error);
      throw error;
    }

  } catch (error) {
    console.error('❌ Error adding specialist:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
      arabic_message: 'An error occurred while adding the specialist, please try again'
    });
  }
};


/**
 * @desc    Add new session type (إضافة نوع جلسة جديد)
 * @route   POST /api/manager/session-types
 * @access  Private/Manager
 */
exports.addSessionType = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;
    
    // بيانات نوع الجلسة الجديد
    const {
      name,
      duration,
      price,
      category,
      specialist_specialization,
      target_conditions
    } = req.body;

    // التحقق من وجود البيانات المطلوبة
    if (!name || !duration || !price || !category || !specialist_specialization) {
      return res.status(400).json({
        success: false,
        message: 'Name, duration, price, category, and specialist specialization are required'
      });
    }

    // التحقق من صحة الفئة
    const validCategories = ['Speech', 'Behavioral', 'Occupational', 'Educational'];
    if (!validCategories.includes(category)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid category. Must be one of: Speech, Behavioral, Occupational, Educational'
      });
    }

    // إنشاء نوع الجلسة الجديد
    const newSessionType = await SessionType.create({
      institution_id: institutionId,
      name,
      duration: parseInt(duration),
      price: parseFloat(price),
      category,
      specialist_specialization,
      target_conditions: target_conditions ? JSON.parse(target_conditions) : null,
      approval_status: 'Approved', // المدير يضيف مباشرة كنوع معتمد
      created_by_specialist_id: null // المدير يضيفه
    });

    res.status(201).json({
      success: true,
      message: 'Session type added successfully',
      data: {
        session_type_id: newSessionType.session_type_id,
        name: newSessionType.name,
        duration: newSessionType.duration,
        price: newSessionType.price,
        category: newSessionType.category,
        specialist_specialization: newSessionType.specialist_specialization,
        target_conditions: newSessionType.target_conditions
      }
    });

  } catch (error) {
    console.error('Error adding session type:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

exports.getAllSpecialistsSchedules = async (req, res) => {
  try {
    console.log('🎯 === START getAllSpecialistsSchedules ===');
    console.log('📝 Request received at:', new Date().toISOString());
    console.log('👤 Manager ID from token:', req.user.user_id);

    const managerId = req.user.user_id;

    console.log('🔍 Step 1: Executing SQL query');
    // استعلام مباشر
    const query = `
      SELECT 
        sp.specialist_id,
        u.full_name,
        u.email,
        u.phone,
        sp.specialization,
        sp.years_experience,
        ss.schedule_id,
        ss.day_of_week,
        ss.start_time,
        ss.end_time
      FROM Managers m
      INNER JOIN Specialists sp ON m.institution_id = sp.institution_id
      INNER JOIN Users u ON sp.specialist_id = u.user_id
      LEFT JOIN SpecialistSchedules ss ON sp.specialist_id = ss.specialist_id
      WHERE m.manager_id = ?
        AND sp.approval_status = 'Approved'
        AND u.status = 'Approved'
      ORDER BY u.full_name, 
        FIELD(ss.day_of_week, 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')
    `;

    console.log('📋 SQL Query:', query);
    console.log('🔢 Parameter (managerId):', managerId);

    const [results] = await sequelize.query(query, {
      replacements: [managerId]
    });

    console.log('📊 Step 1 Result: Found', results.length, 'rows');
    
    if (results.length === 0) {
      console.log('⚠️ No data found for manager ID:', managerId);
    } else {
      console.log('📋 Sample rows:');
      results.slice(0, 3).forEach((row, i) => {
        console.log(`   ${i+1}. ${row.full_name} - ${row.specialization}`);
      });
    }

    console.log('🔄 Step 2: Grouping results by specialist');
    // تجميع النتائج
    const specialistsMap = {};
    
    results.forEach((row, index) => {
      if (!specialistsMap[row.specialist_id]) {
        specialistsMap[row.specialist_id] = {
          specialist_id: row.specialist_id,
          full_name: row.full_name,
          email: row.email,
          phone: row.phone,
          specialization: row.specialization,
          years_experience: row.years_experience,
          schedules: []
        };
      }
      
      if (row.schedule_id) {
        specialistsMap[row.specialist_id].schedules.push({
          schedule_id: row.schedule_id,
          day_of_week: row.day_of_week,
          start_time: row.start_time,
          end_time: row.end_time
        });
      }
    });

    const specialists = Object.values(specialistsMap);
    console.log('📊 Grouped into', specialists.length, 'specialists');

    console.log('🔍 Step 3: Getting institution info');
    // الحصول على اسم المؤسسة
    const [institutionInfo] = await sequelize.query(`
      SELECT i.institution_id, i.name 
      FROM Managers m
      INNER JOIN Institutions i ON m.institution_id = i.institution_id
      WHERE m.manager_id = ?
    `, {
      replacements: [managerId]
    });

    console.log('📊 Institution info:', institutionInfo);

    console.log('✅ Step 4: Sending response');
    res.json({
      success: true,
      data: {
        institution_id: institutionInfo[0]?.institution_id || null,
        institution_name: institutionInfo[0]?.name || 'Unknown',
        total_specialists: specialists.length,
        specialists: specialists
      }
    });

    console.log('📤 Response sent with', specialists.length, 'specialists');
    console.log('🎉 === END getAllSpecialistsSchedules === Success!');

  } catch (error) {
    console.error('❌ ERROR in getAllSpecialistsSchedules:', error.message);
    console.error('🔍 Error stack:', error.stack);
    console.error('🔍 Error details:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Get specialist schedule by ID (الحصول على جدول أخصائي محدد)
 * @route   GET /api/manager/specialists/:id/schedule
 * @access  Private/Manager
 */
exports.getSpecialistSchedule = async (req, res) => {
  try {
    console.log('🎯 === START getSpecialistSchedule ===');
    console.log('📝 Request received at:', new Date().toISOString());
    console.log('👤 Manager ID from token:', req.user.user_id);
    console.log('🔗 Request params:', req.params);

    const managerId = req.user.user_id;
    const specialistId = parseInt(req.params.id); // ⬅️ تحويل إلى رقم
    
    console.log('🔢 Step 1: Parsing parameters');
    console.log('   Manager ID:', managerId);
    console.log('   Requested specialist ID:', specialistId, 'Type:', typeof specialistId);

    console.log('🔍 Step 2: Searching for manager');
    // البحث عن المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId }
    });

    console.log('📊 Step 2 Result:', manager ? 'Manager found' : 'Manager NOT found');
    if (!manager) {
      console.log('❌ ERROR: Manager not found');
      return res.status(404).json({
        success: false,
        message: 'Manager not found'
      });
    }

    console.log('🏢 Step 3: Manager found');
    console.log('   Manager ID:', manager.manager_id);
    console.log('   Institution ID:', manager.institution_id);

    console.log('🔍 Step 4: Checking if specialist belongs to same institution');
    // التحقق من أن الأخصائي تابع لنفس المؤسسة
    const specialist = await Specialist.findOne({
      where: {
        specialist_id: specialistId,
        institution_id: manager.institution_id,
        approval_status: 'Approved'
      },
      include: [
        {
          model: User,
          attributes: ['full_name', 'email', 'phone']
        }
      ]
    });

    console.log('📊 Step 4 Result:', specialist ? 'Specialist found' : 'Specialist NOT found');
    if (!specialist) {
      console.log('❌ ERROR: Specialist not found or not approved in your institution');
      console.log('   Specialist ID searched:', specialistId);
      console.log('   Institution ID required:', manager.institution_id);
      return res.status(404).json({
        success: false,
        message: 'Specialist not found or not approved in your institution'
      });
    }

    console.log('✅ Specialist found:');
    console.log('   Name:', specialist.User.full_name);
    console.log('   Email:', specialist.User.email);
    console.log('   Specialization:', specialist.specialization);

    console.log('🔍 Step 5: Fetching schedules for specialist');
    // الحصول على جداول الأخصائي
    const schedules = await SpecialistSchedule.findAll({
      where: { specialist_id: specialistId },
      attributes: ['schedule_id', 'day_of_week', 'start_time', 'end_time'],
      order: [
        [sequelize.literal("FIELD(day_of_week, 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')")]
      ]
    });

    console.log('📊 Step 5 Result: Found', schedules.length, 'schedules');
    schedules.forEach((sched, i) => {
      console.log(`   ${i+1}. ${sched.day_of_week}: ${sched.start_time} - ${sched.end_time}`);
    });

    console.log('✅ Step 6: Sending response');
    res.json({
      success: true,
      data: {
        specialist_id: specialist.specialist_id,
        full_name: specialist.User.full_name,
        email: specialist.User.email,
        phone: specialist.User.phone,
        specialization: specialist.specialization,
        years_experience: specialist.years_experience,
        schedules: schedules.map(schedule => ({
          schedule_id: schedule.schedule_id,
          day_of_week: schedule.day_of_week,
          start_time: schedule.start_time,
          end_time: schedule.end_time
        }))
      }
    });

    console.log('📤 Response sent successfully');
    console.log('🎉 === END getSpecialistSchedule === Success!');

  } catch (error) {
    console.error('❌ ERROR in getSpecialistSchedule:', error.message);
    console.error('🔍 Error stack:', error.stack);
    console.error('🔍 Error details:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Add schedule for specialist (إضافة جدول دوام لأخصائي)
 * @route   POST /api/manager/specialists/:id/schedule
 * @access  Private/Manager
 */
exports.addSpecialistSchedule = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const specialistId = req.params.id;
    const { day_of_week, start_time, end_time } = req.body; // ✅ تم التعديل: أزلنا specialist_fcm_token

    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // التحقق من أن الأخصائي تابع لنفس المؤسسة
    const specialist = await Specialist.findOne({
      where: {
        specialist_id: specialistId,
        institution_id: institutionId,
        approval_status: 'Approved'
      },
      include: [{
        model: User,
        where: { status: 'Approved' }
      }]
    });

    if (!specialist) {
      return res.status(404).json({
        success: false,
        message: 'Specialist not found or not approved'
      });
    }

    // التحقق من البيانات
    if (!day_of_week || !start_time || !end_time) {
      return res.status(400).json({
        success: false,
        message: 'Day of week, start time, and end time are required'
      });
    }

    // التحقق من صحة يوم الأسبوع
    const validDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    if (!validDays.includes(day_of_week)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid day of week'
      });
    }

    // التحقق من عدم وجود جدول مكرر في نفس اليوم
    const existingSchedule = await SpecialistSchedule.findOne({
      where: {
        specialist_id: specialistId,
        day_of_week: day_of_week
      }
    });

    if (existingSchedule) {
      return res.status(400).json({
        success: false,
        message: 'Schedule already exists for this day'
      });
    }

    // إضافة الجدول الجديد
    const newSchedule = await SpecialistSchedule.create({
      specialist_id: specialistId,
      day_of_week,
      start_time,
      end_time
    });

    // ✅ التعديل: جلب التوكن من قاعدة البيانات بدلاً من الفرونت
    const specialistToken = await getSpecialistFCMToken(specialistId);
    
    // 👇 إرسال الإشعار إذا كان في توكن
    if (specialistToken) {
      await sendScheduleNotification(
        specialistToken,
        'added',
        {
          day_of_week,
          start_time,
          end_time,
          schedule_id: newSchedule.schedule_id
        }
      ).catch(error => {
        console.log('⚠️ Schedule notification failed, but schedule was added');
      });
    }

    res.status(201).json({
      success: true,
      message: 'Schedule added successfully',
      data: {
        schedule_id: newSchedule.schedule_id,
        specialist_id: newSchedule.specialist_id,
        day_of_week: newSchedule.day_of_week,
        start_time: newSchedule.start_time,
        end_time: newSchedule.end_time
      }
    });

  } catch (error) {
    console.error('Error adding specialist schedule:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Update specialist schedule (تعديل جدول دوام أخصائي)
 * @route   PUT /api/manager/schedules/:scheduleId
 * @access  Private/Manager
 */
exports.updateSpecialistSchedule = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const scheduleId = req.params.scheduleId;
    const { day_of_week, start_time, end_time } = req.body; // ✅ تم التعديل: أزلنا specialist_fcm_token

    // التحقق من وجود بيانات للتعديل
    if (!day_of_week && !start_time && !end_time) {
      return res.status(400).json({
        success: false,
        message: 'No data provided for update'
      });
    }

    // العثور على الجدول
    const schedule = await SpecialistSchedule.findByPk(scheduleId, {
      include: [{
        model: Specialist,
        include: [{
          model: Institution,
          where: {
            institution_id: {
              [Op.in]: sequelize.literal(`(
                SELECT institution_id FROM Managers WHERE manager_id = ${managerId}
              )`)
            }
          }
        }]
      }]
    });

    if (!schedule) {
      return res.status(404).json({
        success: false,
        message: 'Schedule not found or you dont have permission'
      });
    }

    // بيانات التحديث
    const updateData = {};
    if (day_of_week) {
      const validDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      if (!validDays.includes(day_of_week)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid day of week'
        });
      }
      updateData.day_of_week = day_of_week;
    }
    if (start_time) updateData.start_time = start_time;
    if (end_time) updateData.end_time = end_time;

    const oldData = {
      day_of_week: schedule.day_of_week,
      start_time: schedule.start_time,
      end_time: schedule.end_time
    };

    // تحديث الجدول
    await schedule.update(updateData);

    // ✅ التعديل: جلب التوكن من قاعدة البيانات بدلاً من الفرونت
    const specialistToken = await getSpecialistFCMToken(schedule.specialist_id);
    
    // 👇 إرسال الإشعار إذا كان في توكن
    if (specialistToken) {
      await sendScheduleNotification(
        specialistToken,
        'updated',
        {
          day_of_week: day_of_week || oldData.day_of_week,
          start_time: start_time || oldData.start_time,
          end_time: end_time || oldData.end_time,
          schedule_id: schedule.schedule_id
        }
      ).catch(error => {
        console.log('⚠️ Schedule update notification failed, but schedule was updated');
      });
    }

    res.json({
      success: true,
      message: 'Schedule updated successfully',
      data: {
        schedule_id: schedule.schedule_id,
        specialist_id: schedule.specialist_id,
        day_of_week: schedule.day_of_week,
        start_time: schedule.start_time,
        end_time: schedule.end_time
      }
    });

  } catch (error) {
    console.error('Error updating specialist schedule:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Delete specialist schedule (حذف جدول دوام أخصائي)
 * @route   DELETE /api/manager/schedules/:scheduleId
 * @access  Private/Manager
 */
exports.deleteSpecialistSchedule = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const scheduleId = req.params.scheduleId;
    // ✅ تم التعديل: أزلنا const { specialist_fcm_token } = req.body;

    // العثور على الجدول والتحقق من الصلاحيات
    const schedule = await SpecialistSchedule.findByPk(scheduleId, {
      include: [{
        model: Specialist,
        include: [{
          model: Institution,
          where: {
            institution_id: {
              [Op.in]: sequelize.literal(`(
                SELECT institution_id FROM Managers WHERE manager_id = ${managerId}
              )`)
            }
          }
        }]
      }]
    });

    if (!schedule) {
      return res.status(404).json({
        success: false,
        message: 'Schedule not found or you dont have permission'
      });
    }

    // حفظ بيانات الجدول قبل الحذف للإشعار
    const scheduleData = {
      schedule_id: schedule.schedule_id,
      day_of_week: schedule.day_of_week
    };

    // حذف الجدول
    await schedule.destroy();

    // ✅ التعديل: جلب التوكن من قاعدة البيانات بدلاً من الفرونت
    const specialistToken = await getSpecialistFCMToken(schedule.specialist_id);
    
    // 👇 إرسال الإشعار إذا كان في توكن
    if (specialistToken) {
      await sendScheduleNotification(
        specialistToken,
        'deleted',
        scheduleData
      ).catch(error => {
        console.log('⚠️ Schedule delete notification failed, but schedule was deleted');
      });
    }

    res.json({
      success: true,
      message: 'Schedule deleted successfully'
    });

  } catch (error) {
    console.error('Error deleting specialist schedule:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Add multiple schedules for specialist (إضافة جداول متعددة لأخصائي)
 * @route   POST /api/manager/specialists/:id/schedules/bulk
 * @access  Private/Manager
 */
exports.addMultipleSchedules = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const specialistId = req.params.id;
    const { schedules } = req.body; // ✅ تم التعديل: أزلنا specialist_fcm_token

    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // التحقق من أن الأخصائي تابع لنفس المؤسسة
    const specialist = await Specialist.findOne({
      where: {
        specialist_id: specialistId,
        institution_id: institutionId,
        approval_status: 'Approved'
      }
    });

    if (!specialist) {
      return res.status(404).json({
        success: false,
        message: 'Specialist not found or not approved'
      });
    }

    if (!schedules || !Array.isArray(schedules) || schedules.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Schedules array is required'
      });
    }

    // التحقق من صحة جميع الجداول
    const validDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const errors = [];

    schedules.forEach((schedule, index) => {
      if (!schedule.day_of_week || !schedule.start_time || !schedule.end_time) {
        errors.push(`Schedule at index ${index} is missing required fields`);
      } else if (!validDays.includes(schedule.day_of_week)) {
        errors.push(`Schedule at index ${index} has invalid day_of_week`);
      }
    });

    if (errors.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid schedules data',
        errors: errors
      });
    }

    // بدء المعاملة
    const transaction = await sequelize.transaction();

    try {
      const createdSchedules = [];

      for (const scheduleData of schedules) {
        // التحقق من عدم وجود جدول مكرر في نفس اليوم
        const existingSchedule = await SpecialistSchedule.findOne({
          where: {
            specialist_id: specialistId,
            day_of_week: scheduleData.day_of_week
          },
          transaction
        });

        if (existingSchedule) {
          await transaction.rollback();
          return res.status(400).json({
            success: false,
            message: `Schedule already exists for ${scheduleData.day_of_week}`
          });
        }

        // إضافة الجدول
        const newSchedule = await SpecialistSchedule.create({
          specialist_id: specialistId,
          day_of_week: scheduleData.day_of_week,
          start_time: scheduleData.start_time,
          end_time: scheduleData.end_time
        }, { transaction });

        createdSchedules.push(newSchedule);
      }

      await transaction.commit();

      // ✅ التعديل: جلب التوكن من قاعدة البيانات بدلاً من الفرونت
      const specialistToken = await getSpecialistFCMToken(specialistId);
      
      // 👇 إرسال الإشعار إذا كان في توكن
      if (specialistToken && createdSchedules.length > 0) {
        await sendScheduleNotification(
          specialistToken,
          'bulk_added',
          {
            count: createdSchedules.length,
            first_day: createdSchedules[0].day_of_week
          }
        ).catch(error => {
          console.log('⚠️ Bulk schedule notification failed, but schedules were added');
        });
      }

      res.status(201).json({
        success: true,
        message: `${createdSchedules.length} schedules added successfully`,
        data: createdSchedules.map(schedule => ({
          schedule_id: schedule.schedule_id,
          specialist_id: schedule.specialist_id,
          day_of_week: schedule.day_of_week,
          start_time: schedule.start_time,
          end_time: schedule.end_time
        }))
      });

    } catch (error) {
      await transaction.rollback();
      throw error;
    }

  } catch (error) {
    console.error('Error adding multiple schedules:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};



// ==================== وظائف إدارة طلبات الإجازات ====================

/**
 * @desc    Get all vacation requests for institution (الحصول على جميع طلبات الإجازة)
 * @route   GET /api/manager/vacation-requests
 * @access  Private/Manager
 */
exports.getVacationRequests = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const institutionName = manager.Institution.name;

    // الحصول على جميع طلبات الإجازة للمؤسسة مع تفاصيل الأخصائي
    const vacationRequests = await VacationRequest.findAll({
      where: { institution_id: institutionId },
      include: [
        {
          model: Specialist,
          as: 'specialist', // ⬅️ أضف هذا
          include: [{
            model: User,
            attributes: ['full_name', 'email', 'phone']
          }]
        }
      ],
      order: [['start_date', 'DESC']],
      attributes: [
        'request_id',
        'specialist_id',
        'start_date',
        'end_date',
        'reason',
        'status',
        'institution_id'
      ]
    });

    // حساب الإحصائيات
    const pendingCount = vacationRequests.filter(req => req.status === 'Pending').length;
    const approvedCount = vacationRequests.filter(req => req.status === 'Approved').length;
    const rejectedCount = vacationRequests.filter(req => req.status === 'Rejected').length;

    // تحويل النتائج
    const formattedRequests = vacationRequests.map(request => ({
      request_id: request.request_id,
      specialist: {
        specialist_id: request.specialist.specialist_id, // ⬅️ استخدم request.specialist
        full_name: request.specialist.User.full_name,
        email: request.specialist.User.email,
        phone: request.specialist.User.phone,
        specialization: request.specialist.specialization
      },
      start_date: request.start_date,
      end_date: request.end_date,
      reason: request.reason,
      status: request.status,
      total_days: Math.ceil((new Date(request.end_date) - new Date(request.start_date)) / (1000 * 60 * 60 * 24)) + 1
    }));

    res.json({
      success: true,
      data: {
        institution: {
          id: institutionId,
          name: institutionName
        },
        statistics: {
          total: vacationRequests.length,
          pending: pendingCount,
          approved: approvedCount,
          rejected: rejectedCount
        },
        vacation_requests: formattedRequests
      }
    });

  } catch (error) {
    console.error('Error getting vacation requests:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Get vacation request details (الحصول على تفاصيل طلب إجازة)
 * @route   GET /api/manager/vacation-requests/:requestId
 * @access  Private/Manager
 */
exports.getVacationRequestDetails = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const requestId = req.params.requestId;

    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // الحصول على تفاصيل طلب الإجازة
    const vacationRequest = await VacationRequest.findOne({
      where: {
        request_id: requestId,
        institution_id: institutionId
      },
      include: [
        {
          model: Specialist,
          as: 'specialist', // ⬅️ أضف هذا
          include: [{
            model: User,
            attributes: ['full_name', 'email', 'phone', 'profile_picture']
          }]
        }
      ]
    });

    if (!vacationRequest) {
      return res.status(404).json({
        success: false,
        message: 'Vacation request not found or not authorized'
      });
    }

    // حساب عدد الأيام
    const startDate = new Date(vacationRequest.start_date);
    const endDate = new Date(vacationRequest.end_date);
    const totalDays = Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24)) + 1;

    res.json({
      success: true,
      data: {
        request_id: vacationRequest.request_id,
        specialist: {
          specialist_id: vacationRequest.specialist.specialist_id, // ⬅️ استخدم vacationRequest.specialist
          full_name: vacationRequest.specialist.User.full_name,
          email: vacationRequest.specialist.User.email,
          phone: vacationRequest.specialist.User.phone,
          specialization: vacationRequest.specialist.specialization,
          years_experience: vacationRequest.specialist.years_experience,
          profile_picture: vacationRequest.specialist.User.profile_picture
        },
        start_date: vacationRequest.start_date,
        end_date: vacationRequest.end_date,
        reason: vacationRequest.reason,
        status: vacationRequest.status,
        total_days: totalDays,
        institution_id: vacationRequest.institution_id
      }
    });

  } catch (error) {
    console.error('Error getting vacation request details:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Update vacation request status (تحديث حالة طلب الإجازة)
 * @route   PUT /api/manager/vacation-requests/:requestId/status
 * @access  Private/Manager
 */
exports.updateVacationRequestStatus = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const requestId = req.params.requestId;
    const { status, manager_notes } = req.body;

    // التحقق من الحالة
    const validStatuses = ['Approved', 'Rejected'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status. Must be either "Approved" or "Rejected"'
      });
    }

    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // العثور على طلب الإجازة
    const vacationRequest = await VacationRequest.findOne({
      where: {
        request_id: requestId,
        institution_id: institutionId,
        status: 'Pending' // يمكن تعديل الطلبات في حالة Pending فقط
      },
      include: [{
        model: Specialist,
        as: 'specialist', // ⬅️ أضف هذا
        include: [{
          model: User,
          attributes: ['full_name', 'email']
        }]
      }]
    });

    if (!vacationRequest) {
      return res.status(404).json({
        success: false,
        message: 'Vacation request not found, not authorized, or already processed'
      });
    }

    // تحديث حالة طلب الإجازة
    await vacationRequest.update({
      status: status
    });

    // إرسال بريد إلكتروني للأخصائي
    try {
      const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: process.env.SMTP_PORT,
        secure: false,
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS
        }
      });

      const emailSubject = status === 'Approved' 
        ? 'Your Vacation Request Has Been Approved' 
        : 'Your Vacation Request Has Been Rejected';

      const emailText = status === 'Approved'
        ? `Dear ${vacationRequest.specialist.User.full_name},\n\nYour vacation request from ${vacationRequest.start_date} to ${vacationRequest.end_date} has been approved.\n\nBest regards,\nManagement`
        : `Dear ${vacationRequest.specialist.User.full_name},\n\nYour vacation request from ${vacationRequest.start_date} to ${vacationRequest.end_date} has been rejected.\n\nReason: ${manager_notes || 'Not specified'}\n\nBest regards,\nManagement`;

      await transporter.sendMail({
        from: process.env.SMTP_FROM,
        to: vacationRequest.specialist.User.email,
        subject: emailSubject,
        text: emailText
      });

      console.log('📧 Email sent to specialist about vacation request status');
    } catch (emailError) {
      console.error('Failed to send email:', emailError);
      // لا نعيد خطأ هنا لأن العملية الرئيسية نجحت
    }

    res.json({
      success: true,
      message: `Vacation request ${status.toLowerCase()} successfully`,
      data: {
        request_id: vacationRequest.request_id,
        specialist_name: vacationRequest.specialist.User.full_name,
        start_date: vacationRequest.start_date,
        end_date: vacationRequest.end_date,
        status: status,
        manager_notes: manager_notes
      }
    });

  } catch (error) {
    console.error('Error updating vacation request status:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// ==================== وظائف إدارة أنواع الجلسات ====================

/**
 * @desc    Get pending session types (الحصول على أنواع الجلسات قيد الانتظار)
 * @route   GET /api/manager/session-types/pending
 * @access  Private/Manager
 */
exports.getPendingSessionTypes = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const institutionName = manager.Institution.name;

    // الحصول على أنواع الجلسات قيد الانتظار
    const pendingSessionTypes = await SessionType.findAll({
      where: { 
        institution_id: institutionId,
        approval_status: 'Pending'
      },
      include: [{
        model: User,
        as: 'CreatedBySpecialist',
        attributes: ['full_name', 'email']
      }],
      order: [['session_type_id', 'DESC']]
    });

    res.json({
      success: true,
      data: {
        institution: {
          id: institutionId,
          name: institutionName
        },
        total_pending: pendingSessionTypes.length,
        session_types: pendingSessionTypes.map(st => ({
          session_type_id: st.session_type_id,
          name: st.name,
          duration: st.duration,
          price: st.price,
          category: st.category,
          specialist_specialization: st.specialist_specialization,
          target_conditions: st.target_conditions,
          created_by: st.CreatedBySpecialist ? {
            full_name: st.CreatedBySpecialist.full_name,
            email: st.CreatedBySpecialist.email
          } : null,
          created_at: st.created_at
        }))
      }
    });

  } catch (error) {
    console.error('Error getting pending session types:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Update session type approval (تحديث موافقة على نوع جلسة)
 * @route   PUT /api/manager/session-types/:sessionTypeId/approval
 * @access  Private/Manager
 */
exports.updateSessionTypeApproval = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const sessionTypeId = req.params.sessionTypeId;
    const { approval_status, price } = req.body;

    // التحقق من البيانات
    if (!approval_status || (approval_status === 'Approved' && !price)) {
      return res.status(400).json({
        success: false,
        message: approval_status === 'Approved' 
          ? 'Price is required when approving a session type'
          : 'Approval status is required'
      });
    }

    // التحقق من الحالة
    const validStatuses = ['Approved', 'Rejected'];
    if (!validStatuses.includes(approval_status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status. Must be either "Approved" or "Rejected"'
      });
    }

    // التحقق من السعر إذا تمت الموافقة
    if (approval_status === 'Approved' && (isNaN(price) || price <= 0)) {
      return res.status(400).json({
        success: false,
        message: 'Price must be a positive number'
      });
    }

    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // العثور على نوع الجلسة
    const sessionType = await SessionType.findOne({
      where: {
        session_type_id: sessionTypeId,
        institution_id: institutionId,
        approval_status: 'Pending'
      },
      include: [{
        model: User,
        as: 'CreatedBySpecialist',
        attributes: ['full_name', 'email']
      }]
    });

    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'Session type not found, not authorized, or already processed'
      });
    }

    // بيانات التحديث
    const updateData = {
      approval_status: approval_status
    };

    // إذا تمت الموافقة، تحديث السعر
    if (approval_status === 'Approved') {
      updateData.price = parseFloat(price);
    }

    // تحديث نوع الجلسة
    await sessionType.update(updateData);

    // إرسال بريد إلكتروني للأخصائي الذي أنشأ النوع
    if (sessionType.CreatedBySpecialist) {
      try {
        const transporter = nodemailer.createTransport({
          host: process.env.SMTP_HOST,
          port: process.env.SMTP_PORT,
          secure: false,
          auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS
          }
        });

        const emailSubject = approval_status === 'Approved'
          ? 'Your Session Type Request Has Been Approved'
          : 'Your Session Type Request Has Been Rejected';

        const emailText = approval_status === 'Approved'
          ? `Dear ${sessionType.CreatedBySpecialist.full_name},\n\nYour session type request "${sessionType.name}" has been approved.\n\nNew Price: $${price}\n\nBest regards,\nManagement`
          : `Dear ${sessionType.CreatedBySpecialist.full_name},\n\nYour session type request "${sessionType.name}" has been rejected.\n\nBest regards,\nManagement`;

        await transporter.sendMail({
          from: process.env.SMTP_FROM,
          to: sessionType.CreatedBySpecialist.email,
          subject: emailSubject,
          text: emailText
        });

        console.log('📧 Email sent to specialist about session type status');
      } catch (emailError) {
        console.error('Failed to send email:', emailError);
      }
    }

    res.json({
      success: true,
      message: `Session type ${approval_status.toLowerCase()} successfully`,
      data: {
        session_type_id: sessionType.session_type_id,
        name: sessionType.name,
        duration: sessionType.duration,
        price: approval_status === 'Approved' ? price : sessionType.price,
        category: sessionType.category,
        approval_status: approval_status,
        specialist_specialization: sessionType.specialist_specialization
      }
    });

  } catch (error) {
    console.error('Error updating session type approval:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};


/**
 * @desc    Get all session types (الحصول على جميع أنواع الجلسات للمؤسسة)
 * @route   GET /api/manager/session-types
 * @access  Private/Manager
 */
exports.getAllSessionTypes = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const institutionName = manager.Institution.name;

    // الحصول على جميع أنواع الجلسات للمؤسسة باستثناء pending
    const sessionTypes = await SessionType.findAll({
      where: { 
        institution_id: institutionId,
        approval_status: {
          [Op.ne]: 'Pending' // لا تشمل أنواع الجلسات قيد الانتظار
        }
      },
      include: [{
        model: User,
        as: 'CreatedBySpecialist',
        attributes: ['full_name', 'email']
      }],
      order: [
        ['approval_status', 'ASC'],
        ['session_type_id', 'DESC']
      ]
    });

    // إحصائيات فقط للأنواع المعتمدة والمرفوضة
    const statistics = {
      total: sessionTypes.length,
      approved: sessionTypes.filter(st => st.approval_status === 'Approved').length,
      rejected: sessionTypes.filter(st => st.approval_status === 'Rejected').length
    };

    res.json({
      success: true,
      data: {
        institution: {
          id: institutionId,
          name: institutionName
        },
        statistics: statistics,
        session_types: sessionTypes.map(st => ({
          session_type_id: st.session_type_id,
          name: st.name,
          duration: st.duration,
          price: st.price,
          category: st.category,
          specialist_specialization: st.specialist_specialization,
          target_conditions: st.target_conditions,
          approval_status: st.approval_status,
          created_by: st.CreatedBySpecialist ? {
            full_name: st.CreatedBySpecialist.full_name,
            email: st.CreatedBySpecialist.email
          } : null,
          created_at: st.created_at,
          updated_at: st.updated_at
        }))
      }
    });

  } catch (error) {
    console.error('Error getting all session types:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};


/**
 * @desc    Edit session type (تعديل نوع جلسة)
 * @route   PUT /api/manager/session-types/:sessionTypeId
 * @access  Private/Manager
 */
exports.editSessionType = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const sessionTypeId = req.params.sessionTypeId;
    
    const {
      name,
      duration,
      price,
      category,
      specialist_specialization,
      target_conditions
    } = req.body;

    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // العثور على نوع الجلسة
    const sessionType = await SessionType.findOne({
      where: {
        session_type_id: sessionTypeId,
        institution_id: institutionId
      }
    });

    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'Session type not found or not authorized'
      });
    }

    // بيانات التحديث
    const updateData = {};
    if (name) updateData.name = name;
    if (duration) updateData.duration = parseInt(duration);
    if (price) updateData.price = parseFloat(price);
    if (category) updateData.category = category;
    if (specialist_specialization) updateData.specialist_specialization = specialist_specialization;
    if (target_conditions !== undefined) {
      updateData.target_conditions = target_conditions ? target_conditions : null;
    }

    // تحديث نوع الجلسة
    await sessionType.update(updateData);

    res.json({
      success: true,
      message: 'Session type updated successfully',
      data: {
        session_type_id: sessionType.session_type_id,
        name: sessionType.name,
        duration: sessionType.duration,
        price: sessionType.price,
        category: sessionType.category,
        specialist_specialization: sessionType.specialist_specialization,
        target_conditions: sessionType.target_conditions,
        approval_status: sessionType.approval_status
      }
    });

  } catch (error) {
    console.error('Error editing session type:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

/**
 * @desc    Soft delete session type (حذف ناعم لنوع جلسة)
 * @route   DELETE /api/manager/session-types/:sessionTypeId
 * @access  Private/Manager
 */
exports.deleteSessionType = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const sessionTypeId = req.params.sessionTypeId;

    console.log(`Attempting to delete session type ${sessionTypeId} by manager ${managerId}`);

    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // البحث عن نوع الجلسة للتأكد من وجوده
    const sessionType = await SessionType.findOne({
      where: {
        session_type_id: sessionTypeId,
        institution_id: institutionId
      }
    });

    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'Session type not found or not authorized'
      });
    }

    console.log(`Found session type: ${sessionType.name}, status: ${sessionType.approval_status }`);

    // التحقق مما إذا كان نوع الجلسة محذوفاً بالفعل
    if (sessionType.approval_status === 'Deleted') {
      return res.status(400).json({
        success: false,
        message: 'Session type is already deleted'
      });
    }

    // التحقق من وجود جلسات مستقبلية تستخدم هذا النوع
    const now = new Date();
    const today = now.toISOString().split('T')[0];
    const currentTime = now.toTimeString().split(' ')[0];
    
    const futureSessions = await Session.findAll({
      where: {
        session_type_id: sessionTypeId,
        institution_id: institutionId,
        [Op.or]: [
          // جلسات تاريخها في المستقبل
          {
            date: {
              [Op.gt]: today
            }
          },
          // جلسات تاريخها اليوم ولكن وقتها في المستقبل
          {
            date: today,
            time: {
              [Op.gt]: currentTime
            }
          }
        ],
        // الحالات التي تمنع الحذف
        status: {
          [Op.in]: ['Scheduled', 'Rescheduled', 'Confirmed', 'Pending Approval']
        }
      },
      attributes: ['session_id', 'date', 'time', 'status']
    });

    console.log(`Found ${futureSessions.length} future sessions that might block deletion`);

    // التحقق من وجود جلسات مستقبلية تمنع الحذف
    if (futureSessions.length > 0) {
      // جمع معلومات الجلسات المستقبلية
      const sessionInfo = futureSessions.map(session => ({
        id: session.session_id,
        date: session.date,
        time: session.time,
        status: session.status
      }));

      return res.status(400).json({
        success: false,
        message: 'Cannot delete session type because there are future sessions with this type.',
        blocked_by: 'There are future sessions with statuses that prevent deletion (Scheduled, Rescheduled, Confirmed, Pending Approval).',
        future_sessions_count: futureSessions.length,
        future_sessions: sessionInfo,
        allowed_action: 'You can only delete this session type if all future sessions are cancelled, completed, or have passed their scheduled time.'
      });
    }

    // تنفيذ Soft Delete - تحديث الحالة إلى Deleted
    const [updatedCount] = await SessionType.update(
      {
        approval_status : 'Deleted',
        updated_at: new Date()
      },
      {
        where: {
          session_type_id: sessionTypeId,
          institution_id: institutionId,
          approval_status : { [Op.ne]: 'Deleted' } // تحديث فقط إذا لم يكن محذوفاً بالفعل
        }
      }
    );

    console.log(`Updated ${updatedCount} session type(s) to Deleted status`);

    if (updatedCount === 0) {
      return res.status(500).json({
        success: false,
        message: 'Failed to update session type status'
      });
    }

    // جلب عدد الجلسات المرتبطة (لأغراض الإعلام)
    const allSessionsCount = await Session.count({
      where: {
        session_type_id: sessionTypeId,
        institution_id: institutionId
      }
    });

    res.json({
      success: true,
      message: 'Session type marked as deleted successfully',
      data: {
        session_type_id: sessionTypeId,
        name: sessionType.name,
        previous_status: sessionType.status,
        new_status: 'Deleted',
        affected_sessions: allSessionsCount,
        note: allSessionsCount > 0 
          ? 'Session type was marked as deleted. Existing sessions will still reference this type.' 
          : 'Session type had no associated sessions.'
      }
    });

  } catch (error) {
    console.error('Error soft deleting session type:', error);
    
    // تفصيل الخطأ بشكل أفضل
    let errorMessage = 'Server error';
    if (error.name === 'SequelizeDatabaseError') {
      errorMessage = 'Database error occurred. Please check if the status field exists.';
    } else if (error.name === 'SequelizeValidationError') {
      errorMessage = 'Validation error: ' + error.errors.map(e => e.message).join(', ');
    }
    
    res.status(500).json({
      success: false,
      message: errorMessage,
      error: error.message,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};
// ==================== وظائف عرض الأخصائيين ====================

/**
 * @desc    Get all specialists with details (نسخة SQL مباشرة)
 * @route   GET /api/manager/specialists
 * @access  Private/Manager
 */
exports.getAllSpecialists = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // استعلام SQL مباشر - أضف average_rating و total_ratings
    const query = `
      SELECT 
        s.specialist_id,
        s.specialization,
        s.years_experience,
        s.salary,
        s.approval_status,
        s.institution_id,
        s.average_rating,          -- ⬅️ أضف هذا
        s.total_ratings,          -- ⬅️ أضف هذا
        s.rating_badge,           -- ⬅️ أضف هذا (اختياري)
        u.full_name,
        u.email,
        u.phone,
        u.profile_picture,
        u.status as user_status,
        u.created_at,
        ss.schedule_id,
        ss.day_of_week,
        ss.start_time,
        ss.end_time
      FROM Managers m
      INNER JOIN Specialists s ON m.institution_id = s.institution_id
      INNER JOIN Users u ON s.specialist_id = u.user_id
      LEFT JOIN SpecialistSchedules ss ON s.specialist_id = ss.specialist_id
      WHERE m.manager_id = ?
      ORDER BY u.created_at DESC
    `;

    const [results] = await sequelize.query(query, {
      replacements: [managerId]
    });

    // الحصول على معلومات المؤسسة
    const [institutionInfo] = await sequelize.query(`
      SELECT i.institution_id, i.name 
      FROM Managers m
      INNER JOIN Institutions i ON m.institution_id = i.institution_id
      WHERE m.manager_id = ?
    `, {
      replacements: [managerId]
    });

    if (!institutionInfo || institutionInfo.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = institutionInfo[0].institution_id;
    const institutionName = institutionInfo[0].name;

    // تجميع النتائج حسب الأخصائي
    const specialistsMap = {};
    
    results.forEach(row => {
      if (!specialistsMap[row.specialist_id]) {
        specialistsMap[row.specialist_id] = {
          specialist_id: row.specialist_id,
          personal_info: {
            full_name: row.full_name,
            email: row.email,
            phone: row.phone,
            profile_picture: row.profile_picture,
            user_status: row.user_status,
            created_at: row.created_at
          },
          professional_info: {
            specialization: row.specialization,
            years_experience: row.years_experience,
            salary: row.salary,
            approval_status: row.approval_status,
            average_rating: row.average_rating || 0,     // ⬅️ تأكد من وجوده
            total_ratings: row.total_ratings || 0,       // ⬅️ تأكد من وجوده
            rating_badge: row.rating_badge || 'new'      // ⬅️ تأكد من وجوده
          },
          schedules: []
        };
      }
      
      if (row.schedule_id) {
        specialistsMap[row.specialist_id].schedules.push({
          schedule_id: row.schedule_id,
          day_of_week: row.day_of_week,
          start_time: row.start_time,
          end_time: row.end_time
        });
      }
    });

    const specialists = Object.values(specialistsMap);

    // حساب الإحصائيات
    const approvedCount = specialists.filter(s => s.professional_info.approval_status === 'Approved').length;
    const pendingCount = specialists.filter(s => s.professional_info.approval_status === 'Pending').length;
    const rejectedCount = specialists.filter(s => s.professional_info.approval_status === 'Rejected').length;
    
    // ⬅️ إحصائيات التقييمات الجديدة
    const ratingStats = {
      total_with_ratings: specialists.filter(s => s.professional_info.average_rating > 0).length,
      average_overall: specialists.reduce((sum, s) => sum + (s.professional_info.average_rating || 0), 0) / specialists.length,
      five_star_specialists: specialists.filter(s => s.professional_info.average_rating >= 4.5).length,
      new_specialists: specialists.filter(s => s.professional_info.rating_badge === 'new' || 
                                              s.professional_info.total_ratings === 0).length
    };

    // الحصول على آخر 5 أخصائيين
    const recentSpecialists = specialists
      .sort((a, b) => new Date(b.personal_info.created_at) - new Date(a.personal_info.created_at))
      .slice(0, 5);

    // ترتيب الأخصائيين حسب التقييم (الأعلى أولاً) للعرض
    const sortedByRating = [...specialists].sort((a, b) => 
      (b.professional_info.average_rating || 0) - (a.professional_info.average_rating || 0)
    );

    res.json({
      success: true,
      data: {
        institution: {
          id: institutionId,
          name: institutionName
        },
        statistics: {
          total: specialists.length,
          approved: approvedCount,
          pending: pendingCount,
          rejected: rejectedCount,
          rating_stats: ratingStats  // ⬅️ إحصائيات التقييمات الجديدة
        },
        recent_specialists: recentSpecialists.map(spec => ({
          ...spec,
          has_schedules: spec.schedules.length > 0
        })),
        top_rated_specialists: sortedByRating.slice(0, 5).map(spec => ({  // ⬅️ الأخصائيين الأعلى تقييماً
          ...spec,
          has_schedules: spec.schedules.length > 0
        })),
        all_specialists: specialists.map(spec => ({
          ...spec,
          has_schedules: spec.schedules.length > 0
        }))
      }
    });

  } catch (error) {
    console.error('Error getting all specialists:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};


/**
 * @desc    Get specialist comprehensive report with sessions, ratings, vacations, and schedules
 * @route   GET /api/manager/specialists/:id/report
 * @access  Private/Manager
 */
exports.getSpecialistComprehensiveReport = async (req, res) => {
  try {
    console.log('🎯 === START getSpecialistComprehensiveReport (SQL) ===');
    
    const managerId = req.user.user_id;
    const specialistId = parseInt(req.params.id);

    // التحقق من المدير والمؤسسة
    const [managerResult] = await sequelize.query(`
      SELECT m.manager_id, i.institution_id, i.name as institution_name
      FROM Managers m
      INNER JOIN Institutions i ON m.institution_id = i.institution_id
      WHERE m.manager_id = ?
    `, { replacements: [managerId] });

    if (!managerResult.length) {
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const institutionId = managerResult[0].institution_id;
    const institutionName = managerResult[0].institution_name;

    // معلومات الأخصائي
    const [specialistResult] = await sequelize.query(`
      SELECT 
        s.specialist_id,
        s.specialization,
        s.years_experience,
        s.salary,
        s.approval_status,
        s.average_rating,
        s.total_ratings,
        s.rating_badge,
        u.full_name,
        u.email,
        u.phone,
        u.profile_picture,
        u.status as user_status,
        u.created_at
      FROM Specialists s
      INNER JOIN Users u ON s.specialist_id = u.user_id
      WHERE s.specialist_id = ?
        AND s.institution_id = ?
    `, { replacements: [specialistId, institutionId] });

    if (!specialistResult.length) {
      return res.status(404).json({
        success: false,
        message: 'Specialist not found in your institution'
      });
    }

    const specialist = specialistResult[0];

    // الجداول
    const [schedules] = await sequelize.query(`
      SELECT schedule_id, day_of_week, start_time, end_time
      FROM SpecialistSchedules
      WHERE specialist_id = ?
      ORDER BY FIELD(day_of_week, 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')
    `, { replacements: [specialistId] });

    // الجلسات
    const [sessions] = await sequelize.query(`
      SELECT 
        session_id,
        date,
        time,
        status,
        reason,
        child_id,
        (SELECT full_name FROM Children WHERE child_id = s.child_id) as child_name,
        (SELECT name FROM SessionTypes WHERE session_type_id = s.session_type_id) as session_type
      FROM Sessions s
      WHERE specialist_id = ?
        AND institution_id = ?
      ORDER BY date DESC
    `, { replacements: [specialistId, institutionId] });

    // تحليل الجلسات
    const today = new Date().toISOString().split('T')[0];
    const sessionsByStatus = {};
    const upcomingSessions = [];
    const completedSessions = [];
    const cancelledSessions = []; // ⬅️ إضافة جلسات ملغاة

    sessions.forEach(session => {
      sessionsByStatus[session.status] = (sessionsByStatus[session.status] || 0) + 1;
      
      // الجلسات القادمة
      if (session.date >= today && ['Scheduled', 'Confirmed', 'Approved'].includes(session.status)) {
        upcomingSessions.push({
          session_id: session.session_id,
          child_name: session.child_name,
          date: session.date,
          time: session.time,
          session_type: session.session_type,
          status: session.status
        });
      }
      
      // الجلسات المكتملة
      if (session.status === 'Completed') {
        completedSessions.push({
          session_id: session.session_id,
          child_name: session.child_name,
          date: session.date,
          time: session.time,
          session_type: session.session_type
        });
      }
      
      // الجلسات الملغاة
      if (session.status === 'Cancelled') {
        cancelledSessions.push({
          session_id: session.session_id,
          child_name: session.child_name,
          date: session.date,
          reason: session.reason || 'بدون سبب'
        });
      }
    });

    // التقييمات
    const [ratings] = await sequelize.query(`
      SELECT 
        sr.session_rating_id,
        sr.rating,
        sr.rating_tag,
        sr.comment,
        sr.rated_at,
        c.full_name as child_name,
        s.date as session_date,
        st.name as session_type
      FROM SessionRatings sr
      LEFT JOIN Children c ON sr.child_id = c.child_id
      LEFT JOIN Sessions s ON sr.session_id = s.session_id
      LEFT JOIN SessionTypes st ON s.session_type_id = st.session_type_id
      WHERE sr.specialist_id = ?
      ORDER BY sr.rated_at DESC
    `, { replacements: [specialistId] });

    // حساب متوسط التقييم
    let averageRating = 0;
    const ratingDistribution = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    if (ratings.length > 0) {
      const totalRating = ratings.reduce((sum, r) => sum + r.rating, 0);
      averageRating = (totalRating / ratings.length).toFixed(1);
      ratings.forEach(r => ratingDistribution[r.rating]++);
    }

    // الإجازات - تحليل مفصل
    const [vacations] = await sequelize.query(`
      SELECT 
        request_id,
        start_date,
        end_date,
        reason,
        status,
        DATEDIFF(end_date, start_date) + 1 as total_days
      FROM VacationRequests
      WHERE specialist_id = ?
        AND institution_id = ?
      ORDER BY start_date DESC
    `, { replacements: [specialistId, institutionId] });

    const vacationStats = { approved: 0, pending: 0, rejected: 0 };
    let totalApprovedVacationDays = 0; // ⬅️ أيام الإجازة المعتمدة فقط
    const upcomingVacations = [];
    const currentVacations = []; // ⬅️ الإجازات الحالية (اليوم ضمنها)
    const pastVacations = []; // ⬅️ الإجازات الماضية

    if (vacations && vacations.length > 0) {
      vacations.forEach(vacation => {
        // إحصائيات الحالة
        if (vacation && vacation.status) {
          const statusKey = vacation.status.toLowerCase();
          vacationStats[statusKey] = (vacationStats[statusKey] || 0) + 1;
          
          // حساب أيام الإجازة المعتمدة فقط
          if (vacation.status === 'Approved' && vacation.total_days) {
            totalApprovedVacationDays += vacation.total_days;
          }
        }

        // تصنيف الإجازات حسب التواريخ
        if (vacation.end_date >= today) {
          upcomingVacations.push({
            request_id: vacation.request_id,
            start_date: vacation.start_date,
            end_date: vacation.end_date,
            reason: vacation.reason || '',
            status: vacation.status,
            total_days: vacation.total_days
          });
        }

        // الإجازات الحالية (اليوم ضمن فترة الإجازة)
        if (vacation.start_date <= today && vacation.end_date >= today) {
          currentVacations.push({
            request_id: vacation.request_id,
            start_date: vacation.start_date,
            end_date: vacation.end_date,
            reason: vacation.reason || '',
            status: vacation.status,
            total_days: vacation.total_days
          });
        }

        // الإجازات الماضية
        if (vacation.end_date < today) {
          pastVacations.push({
            request_id: vacation.request_id,
            start_date: vacation.start_date,
            end_date: vacation.end_date,
            reason: vacation.reason || '',
            status: vacation.status,
            total_days: vacation.total_days
          });
        }
      });
    }

    // ⬅️ الإجازات المعتمدة للشهر الحالي
    const [currentMonthVacations] = await sequelize.query(`
      SELECT 
        COUNT(*) as count,
        SUM(DATEDIFF(end_date, start_date) + 1) as total_days
      FROM VacationRequests
      WHERE specialist_id = ?
        AND institution_id = ?
        AND status = 'Approved'
        AND MONTH(start_date) = MONTH(NOW())
        AND YEAR(start_date) = YEAR(NOW())
    `, { replacements: [specialistId, institutionId] });

    // ⬅️ إحصائيات شهرية للجلسات
    const [monthlyStats] = await sequelize.query(`
      SELECT 
        DATE_FORMAT(date, '%Y-%m') as month,
        COUNT(*) as total_sessions,
        SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) as completed_sessions,
        SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) as cancelled_sessions
      FROM Sessions
      WHERE specialist_id = ?
        AND institution_id = ?
        AND date >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(date, '%Y-%m')
      ORDER BY month ASC
    `, { replacements: [specialistId, institutionId] });

    // ⬅️ معدل الحضور والغياب للأطفال في جلسات الأخصائي
    const [childAttendanceStats] = await sequelize.query(`
      SELECT 
        COUNT(*) as total_sessions,
        SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) as child_absent_count,
        SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) as attended_sessions,
        ROUND((SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) as attendance_rate
      FROM Sessions
      WHERE specialist_id = ?
        AND institution_id = ?
        AND date >= DATE_SUB(NOW(), INTERVAL 3 MONTH)
    `, { replacements: [specialistId, institutionId] });

    // تجميع التقرير
    const report = {
      specialist_info: {
        specialist_id: specialist.specialist_id,
        personal_info: {
          full_name: specialist.full_name,
          email: specialist.email,
          phone: specialist.phone,
          profile_picture: specialist.profile_picture,
          account_status: specialist.user_status,
          account_created: specialist.created_at
        },
        professional_info: {
          specialization: specialist.specialization,
          years_experience: specialist.years_experience,
          salary: specialist.salary,
          approval_status: specialist.approval_status,
          average_rating: specialist.average_rating,
          total_ratings: specialist.total_ratings,
          rating_badge: specialist.rating_badge
        }
      },
      institution_info: {
        institution_id: institutionId,
        institution_name: institutionName
      },
      schedules: schedules || [],
      statistics: {
        // إحصائيات الجلسات
        sessions_summary: {
          total_sessions: sessions.length || 0,
          upcoming_sessions: upcomingSessions.length || 0,
          completed_sessions: completedSessions.length || 0,
          cancelled_sessions: cancelledSessions.length || 0,
          sessions_by_status: sessionsByStatus || {}
        },
        
        // إحصائيات التقييمات
        ratings_summary: {
          total_ratings: ratings.length || 0,
          average_rating: averageRating,
          rating_distribution: ratingDistribution
        },
        
        // إحصائيات الإجازات
        vacations_summary: {
          total_requests: vacations ? vacations.length : 0,
          vacation_stats: vacationStats,
          approved_vacation_days: totalApprovedVacationDays || 0, // ⬅️ أيام الإجازة المعتمدة
          current_month_vacations: {
            count: currentMonthVacations[0]?.count || 0,
            days: currentMonthVacations[0]?.total_days || 0
          },
          current_vacations_count: currentVacations.length, // ⬅️ الإجازات الحالية (متعطل الآن)
          upcoming_vacations_count: upcomingVacations.length
        },
        
        // إحصائيات حضور الأطفال
        child_attendance: {
          total_sessions: childAttendanceStats[0]?.total_sessions || 0,
          child_absent_count: childAttendanceStats[0]?.child_absent_count || 0,
          attended_sessions: childAttendanceStats[0]?.attended_sessions || 0,
          attendance_rate: childAttendanceStats[0]?.attendance_rate || 0
        }
      },
      
      // تفاصيل
      upcoming_sessions: upcomingSessions.slice(0, 10) || [],
      recent_completed_sessions: completedSessions.slice(0, 10) || [],
      recent_cancelled_sessions: cancelledSessions.slice(0, 10) || [],
      
      // معلومات الإجازات
      current_vacations: currentVacations, // ⬅️ إذا كان متوقف حالياً
      upcoming_vacations: upcomingVacations.slice(0, 5) || [], // ⬅️ آخر 5 إجازات قادمة
      recent_vacations: pastVacations.slice(0, 5) || [], // ⬅️ آخر 5 إجازات ماضية
      
      recent_ratings: ratings ? ratings.slice(0, 10) : [],
      monthly_analytics: monthlyStats || [],
      generated_at: new Date().toISOString()
    };

    res.json({
      success: true,
      message: 'Specialist comprehensive report retrieved successfully',
      data: report
    });

    console.log('🎉 === END getSpecialistComprehensiveReport (SQL) === Success!');

  } catch (error) {
    console.error('❌ ERROR in getSpecialistComprehensiveReport:', error.message);
    console.error('🔍 Error stack:', error.stack);
    res.status(500).json({
      success: false,
      message: 'Server error while generating specialist report',
      error: error.message
    });
  }
};


/**
 * @desc    Archive specialist (تحويل أخصائي إلى حالة مؤرشف)
 * @route   PUT /api/manager/specialists/:id/archive
 * @access  Private/Manager
 */
exports.archiveSpecialist = async (req, res) => {
  try {
    console.log('🎯 === START archiveSpecialist ===');
    
    const managerId = req.user.user_id;
    const specialistId = parseInt(req.params.id);
    const { forceArchive = false } = req.body;

    console.log('🔢 Parameters:');
    console.log('   Manager ID:', managerId);
    console.log('   Specialist ID:', specialistId);
    console.log('   Force Archive:', forceArchive);

    // 1. التحقق من المدير والمؤسسة
    const [managerResult] = await sequelize.query(`
      SELECT m.manager_id, i.institution_id, i.name as institution_name
      FROM Managers m
      INNER JOIN Institutions i ON m.institution_id = i.institution_id
      WHERE m.manager_id = ?
    `, { replacements: [managerId] });

    if (!managerResult.length) {
      console.log('❌ Manager not found');
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const institutionId = managerResult[0].institution_id;

    // 2. التحقق من وجود الأخصائي
    const [specialistResult] = await sequelize.query(`
      SELECT 
        s.specialist_id,
        s.approval_status,
        u.full_name,
        u.email
      FROM Specialists s
      INNER JOIN Users u ON s.specialist_id = u.user_id
      WHERE s.specialist_id = ?
        AND s.institution_id = ?
        AND s.approval_status != 'archived'
    `, { replacements: [specialistId, institutionId] });

    if (!specialistResult.length) {
      console.log('❌ Specialist not found or already archived');
      return res.status(404).json({
        success: false,
        message: 'Specialist not found, not in your institution, or already archived'
      });
    }

    const specialistName = specialistResult[0].full_name;
    console.log('✅ Specialist found:', specialistName);

    // 3. التحقق من الجلسات المستقبلية
    const today = new Date().toISOString().split('T')[0];
    
    const [upcomingSessions] = await sequelize.query(`
      SELECT 
        s.session_id,
        s.date,
        s.time,
        s.status,
        s.child_id,
        c.full_name as child_name,
        u.user_id as parent_id,
        u.full_name as parent_name,
        u.email as parent_email
      FROM Sessions s
      LEFT JOIN Children c ON s.child_id = c.child_id
      LEFT JOIN Users u ON c.parent_id = u.user_id  -- ⬅️ تصحيح الـ JOIN
      WHERE s.specialist_id = ?
        AND s.institution_id = ?
        AND s.date >= ?
        AND s.status IN ('Scheduled', 'Pending Approval', 'Delete Requested', 'Rescheduled', 'Pending Manager Approval', 'Confirmed', 'Approved', 'Pending Specialist Approval')
      ORDER BY s.date ASC
    `, { replacements: [specialistId, institutionId, today] });

    console.log('📊 Found', upcomingSessions.length, 'upcoming sessions');

    // 4. إذا كان هناك جلسات مستقبلية ولم يتم اختيار forceArchive
    if (upcomingSessions.length > 0 && !forceArchive) {
      console.log('⚠️ Specialist has upcoming sessions');
      
      // تجميع معلومات الجلسات لعرضها للمدير
      const sessionsInfo = upcomingSessions.slice(0, 10).map(session => ({
        session_id: session.session_id,
        date: session.date,
        time: session.time,
        status: session.status,
        child_name: session.child_name,
        parent_name: session.parent_name
      }));

      return res.status(400).json({
        success: false,
        message: 'Cannot archive specialist. There are upcoming sessions.',
        requires_confirmation: true,
        data: {
          specialist_id: specialistId,
          specialist_name: specialistName,
          upcoming_sessions_count: upcomingSessions.length,
          upcoming_sessions: sessionsInfo,
          warning: 'Archiving this specialist will cancel all upcoming sessions. Are you sure?',
          suggested_action: 'Use forceArchive: true to archive and cancel all sessions automatically'
        }
      });
    }

    // 5. بدء معاملة DB
    const transaction = await sequelize.transaction();
    
    try {
      // 5.1 إذا كانت هناك جلسات مستقبلية وتم اختيار forceArchive
      if (upcomingSessions.length > 0) {
        console.log('🔄 Cancelling upcoming sessions...');
        
        // تحويل جميع الجلسات المستقبلية إلى Cancelled
        await sequelize.query(`
          UPDATE Sessions 
          SET 
            status = 'Cancelled',
            reason = CONCAT('Session cancelled because specialist was archived. ', COALESCE(reason, ''))
          WHERE specialist_id = ?
            AND institution_id = ?
            AND date >= ?
            AND status IN ('Scheduled', 'Pending Approval', 'Delete Requested', 'Rescheduled', 'Pending Manager Approval', 'Confirmed', 'Approved', 'Pending Specialist Approval')
        `, {
          replacements: [
            specialistId, 
            institutionId, 
            today
          ],
          transaction
        });

        console.log(`✅ Cancelled ${upcomingSessions.length} upcoming sessions`);
      }

      // 5.2 إلغاء تنشيط الحساب في جدول Users
      console.log('🔄 Deactivating user account...');
      await sequelize.query(`
        UPDATE Users 
        SET status = 'Canceled'
        WHERE user_id = ?
      `, {
        replacements: [specialistId],
        transaction
      });

      // 5.3 تحديث حالة الأخصائي إلى archived
      console.log('🔄 Archiving specialist...');
      await sequelize.query(`
        UPDATE Specialists 
        SET 
          approval_status = 'Archived'
          
        WHERE specialist_id = ?
      `, {
        replacements: [specialistId],
        transaction
      });

      // 5.4 (اختياري) إلغاء جدول الأخصائي
      console.log('🔄 Removing specialist schedule...');
      await sequelize.query(`
        DELETE FROM SpecialistSchedules 
        WHERE specialist_id = ?
      `, {
        replacements: [specialistId],
        transaction
      });

      // // 5.5 (اختياري) إضافة سجل في جدول المديريات
      // console.log('📝 Adding archive log...');
      // await sequelize.query(`
      //   INSERT INTO SpecialistArchiveLog 
      //   (specialist_id, archived_by_manager_id, institution_id, 
      //    archived_at, cancelled_sessions_count, notes)
      //   VALUES (?, ?, ?, NOW(), ?, ?)
      // `, {
      //   replacements: [
      //     specialistId,
      //     managerId,
      //     institutionId,
      //     upcomingSessions.length,
      //     `Archived by manager. ${upcomingSessions.length} sessions cancelled.`
      //   ],
      //   transaction
      // });

      // 6. التأكيد والمعاملة
      await transaction.commit();
      console.log('✅ Transaction committed successfully');

      // 7. إرجاع النتيجة النهائية
      const result = {
        success: true,
        message: 'Specialist archived successfully',
        data: {
          specialist_id: specialistId,
          specialist_name: specialistName,
          actions_taken: {
            account_deactivated: true,
            status_changed_to: 'Archived',
            schedule_removed: true,
            upcoming_sessions_cancelled: upcomingSessions.length,
            archive_log_created: true
          },
          archived_at: new Date().toISOString(),
          summary: {
            total_actions: 4,
            affected_sessions: upcomingSessions.length,
            notes: upcomingSessions.length > 0 
              ? `${upcomingSessions.length} upcoming sessions were automatically cancelled.`
              : 'No upcoming sessions were found.',
            recommendation: 'Notify specialist about account deactivation.'
          }
        }
      };

      res.json(result);
      console.log('🎉 === END archiveSpecialist === Success!');

    } catch (transactionError) {
      await transaction.rollback();
      console.error('❌ Transaction rolled back:', transactionError.message);
      throw transactionError;
    }

  } catch (error) {
    console.error('❌ ERROR in archiveSpecialist:', error.message);
    console.error('🔍 Error stack:', error.stack);
    res.status(500).json({
      success: false,
      message: 'Server error while archiving specialist',
      error: error.message
    });
  }
};

/**
 * @desc    Get specialist upcoming sessions (جلب الجلسات المستقبلية لأخصائي)
 * @route   GET /api/manager/specialists/:id/upcoming-sessions
 * @access  Private/Manager
 */
exports.getSpecialistUpcomingSessions = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const specialistId = parseInt(req.params.id);

    // التحقق من المدير
    const [managerResult] = await sequelize.query(`
      SELECT m.institution_id
      FROM Managers m
      WHERE m.manager_id = ?
    `, { replacements: [managerId] });

    if (!managerResult.length) {
      return res.status(404).json({
        success: false,
        message: 'Manager not found'
      });
    }

    const institutionId = managerResult[0].institution_id;
    const today = new Date().toISOString().split('T')[0];

    // جلب الجلسات المستقبلية - تصحيح الـ JOIN
    const [sessions] = await sequelize.query(`
      SELECT 
        s.session_id,
        s.date,
        s.time,
        s.status,
        s.reason,
        c.full_name as child_name,
        c.child_id,
        u.full_name as parent_name,
        u.email as parent_email,
        u.phone as parent_phone,
        st.name as session_type,
        st.duration,
        st.price
      FROM Sessions s
      LEFT JOIN Children c ON s.child_id = c.child_id
      LEFT JOIN Users u ON c.parent_id = u.user_id  -- ⬅️ تصحيح: JOIN مع Users بدلاً من Parents
      LEFT JOIN SessionTypes st ON s.session_type_id = st.session_type_id
      WHERE s.specialist_id = ?
        AND s.institution_id = ?
        AND s.date >= ?
        AND s.status NOT IN ('Cancelled', 'Completed', 'Rejected')
      ORDER BY s.date ASC, s.time ASC
    `, { replacements: [specialistId, institutionId, today] });

    // معلومات الأخصائي
    const [specialistInfo] = await sequelize.query(`
      SELECT 
        s.specialist_id,
        u.full_name,
        s.approval_status
      FROM Specialists s
      INNER JOIN Users u ON s.specialist_id = u.user_id
      WHERE s.specialist_id = ?
        AND s.institution_id = ?
    `, { replacements: [specialistId, institutionId] });

    res.json({
      success: true,
      data: {
        specialist: specialistInfo[0] || null,
        upcoming_sessions: {
          total: sessions.length,
          sessions: sessions
        },
        check_date: today,
        can_archive: sessions.length === 0
      }
    });

  } catch (error) {
    console.error('Error getting specialist upcoming sessions:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};
/**
 * @desc    Get specialist details (نسخة SQL مباشرة)
 * @route   GET /api/manager/specialists/:specialistId
 * @access  Private/Manager
 */
exports.getSpecialistDetails = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const specialistId = req.params.specialistId;

    // استعلام SQL مباشر
    const query = `
      SELECT 
        s.specialist_id,
        s.specialization,
        s.years_experience,
        s.salary,
        s.approval_status,
        u.full_name,
        u.email,
        u.phone,
        u.profile_picture,
        u.status as user_status,
        u.created_at,
        ss.schedule_id,
        ss.day_of_week,
        ss.start_time,
        ss.end_time
      FROM Managers m
      INNER JOIN Specialists s ON m.institution_id = s.institution_id
      INNER JOIN Users u ON s.specialist_id = u.user_id
      LEFT JOIN SpecialistSchedules ss ON s.specialist_id = ss.specialist_id
      WHERE m.manager_id = ?
        AND s.specialist_id = ?
      ORDER BY FIELD(ss.day_of_week, 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')
    `;

    const [results] = await sequelize.query(query, {
      replacements: [managerId, specialistId]
    });

    if (results.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Specialist not found or not authorized'
      });
    }

    // تجميع النتائج
    const specialist = {
      specialist_id: results[0].specialist_id,
      personal_info: {
        full_name: results[0].full_name,
        email: results[0].email,
        phone: results[0].phone,
        profile_picture: results[0].profile_picture,
        user_status: results[0].user_status,
        created_at: results[0].created_at
      },
      professional_info: {
        specialization: results[0].specialization,
        years_experience: results[0].years_experience,
        salary: results[0].salary,
        approval_status: results[0].approval_status
      },
      schedules: results
        .filter(row => row.schedule_id)
        .map(row => ({
          schedule_id: row.schedule_id,
          day_of_week: row.day_of_week,
          start_time: row.start_time,
          end_time: row.end_time
        }))
    };

    // الحصول على إحصائيات الجلسات
    const sessionStatsQuery = `
      SELECT 
        status,
        COUNT(session_id) as count
      FROM Sessions
      WHERE specialist_id = ?
        AND institution_id = (SELECT institution_id FROM Managers WHERE manager_id = ?)
      GROUP BY status
    `;

    const [sessionStats] = await sequelize.query(sessionStatsQuery, {
      replacements: [specialistId, managerId]
    });

    const totalSessions = sessionStats.reduce((sum, stat) => sum + parseInt(stat.count), 0);
    const sessionStatsObj = sessionStats.reduce((acc, stat) => {
      acc[stat.status] = parseInt(stat.count);
      return acc;
    }, {});

    res.json({
      success: true,
      data: {
        ...specialist,
        statistics: {
          total_sessions: totalSessions,
          session_stats: sessionStatsObj,
          average_rating: 0
        }
      }
    });

  } catch (error) {
    console.error('Error getting specialist details:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};


/**
 * @desc    Update specialist salary (تعديل راتب الأخصائي)
 * @route   PUT /api/manager/specialists/:id/salary
 * @access  Private/Manager
 */
exports.updateSpecialistSalary = async (req, res) => {
  try {
    console.log("🎯 === START updateSpecialistSalary ===");

    const managerId = req.user.user_id;
    const specialistId = parseInt(req.params.id);
    const { salary } = req.body;

    if (!salary || salary <= 0) {
      return res.status(400).json({
        success: false,
        message: "Invalid salary amount"
      });
    }

    // 1. التحقق من المدير ومؤسسته
    const [managerResult] = await sequelize.query(`
      SELECT m.manager_id, i.institution_id
      FROM Managers m
      INNER JOIN Institutions i 
        ON m.institution_id = i.institution_id
      WHERE m.manager_id = ?
    `, { replacements: [managerId] });

    if (!managerResult.length) {
      return res.status(404).json({
        success: false,
        message: "Manager or institution not found"
      });
    }

    const institutionId = managerResult[0].institution_id;

    // 2. التحقق من وجود الأخصائي في نفس المؤسسة
    const [specialistResult] = await sequelize.query(`
      SELECT specialist_id, salary, 
             (SELECT full_name FROM Users WHERE user_id = s.specialist_id) as full_name
      FROM Specialists s
      WHERE specialist_id = ?
        AND institution_id = ?
    `, { replacements: [specialistId, institutionId] });

    if (!specialistResult.length) {
      return res.status(404).json({
        success: false,
        message: "Specialist not found in your institution"
      });
    }

    const oldSalary = specialistResult[0].salary;
    const specialistName = specialistResult[0].full_name;

    // 3. تنفيذ التحديث في معاملة Transaction
    const transaction = await sequelize.transaction();
    try {

      // تحديث الراتب
      await sequelize.query(`
        UPDATE Specialists
        SET salary = ?
        WHERE specialist_id = ?
      `, {
        replacements: [salary, specialistId],
        transaction
      });

      // (اختياري) إضافة Log في جدول جديد (لو عندك)
      // await sequelize.query(`
      //   INSERT INTO SalaryHistory 
      //   (specialist_id, old_salary, new_salary, updated_by, updated_at)
      //   VALUES (?, ?, ?, ?, NOW())
      // `, {
      //   replacements: [specialistId, oldSalary, salary, managerId],
      //   transaction
      // });

      await transaction.commit();
      console.log("✅ Salary updated successfully");

      return res.json({
        success: true,
        message: "Specialist salary updated successfully",
        data: {
          specialist_id: specialistId,
          specialist_name: specialistName,
          old_salary: oldSalary,
          new_salary: salary
        }
      });

    } catch (err) {
      await transaction.rollback();
      console.error("❌ Transaction rolled back:", err.message);
      return res.status(500).json({
        success: false,
        message: "Failed to update salary",
        error: err.message
      });
    }

  } catch (error) {
    console.error("❌ ERROR in updateSpecialistSalary:", error.message);
    return res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message
    });
  }
};
