const Parent = require('../model/Parent');
const Child = require('../model/Child');
const Diagnosis = require('../model/Diagnosis');
const User = require('../model/User');
const Session = require('../model/Session');
const AIRecommendation = require('../model/AIRecommendation');
const Institution = require('../model/Institution');
const Notification = require('../model/Notification');
const NotificationService = require('../services/notificationService');
const ChildRegistrationRequest = require('../model/ChildRegistrationRequest');  
const { Op } = require('sequelize'); 
const sequelize = require('../config/db');
const fs = require('fs');
const path = require('path');

const uploadParentProfilePicture = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ 
        success: false,
        message: 'No image file uploaded' 
      });
    }

    const parentId = req.user.user_id;
    
    const parent = await Parent.findOne({ 
      where: { parent_id: parentId } 
    });
    
    if (!parent) {
      if (req.file && req.file.path) {
        fs.unlinkSync(req.file.path);
      }
      return res.status(404).json({ 
        success: false,
        message: 'Parent not found' 
      });
    }

    const user = await User.findOne({
      where: { user_id: parentId }
    });

    if (!user) {
      if (req.file && req.file.path) {
        fs.unlinkSync(req.file.path);
      }
      return res.status(404).json({ 
        success: false,
        message: 'User not found' 
      });
    }

    if (user.profile_picture) {
      try {
        const oldFilename = user.profile_picture.split('/').pop();
        const oldPath = path.join(__dirname, '../uploads/parents/', oldFilename);
        if (fs.existsSync(oldPath)) {
          fs.unlinkSync(oldPath);
          console.log('✅ Old parent image deleted:', oldFilename);
        }
      } catch (deleteError) {
        console.log('⚠️ Could not delete old parent image:', deleteError.message);
      }
    }

    const protocol = req.protocol;
    const host = req.get('host');
    const profilePictureUrl = `${protocol}://${host}/uploads/parents/${req.file.filename}`;

    console.log('📸 Parent profile picture URL:', profilePictureUrl);

    await User.update({
      profile_picture: profilePictureUrl,
      updated_at: new Date()
    }, {
      where: { user_id: parentId }
    });

    const updatedUser = await User.findOne({
      where: { user_id: parentId },
      attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture', 'created_at', 'updated_at']
    });

    res.json({
      success: true,
      message: 'Parent profile picture uploaded successfully',
      data: {
        profile_picture: profilePictureUrl,
        user: updatedUser
      }
    });

  } catch (error) {
    console.error('❌ Error uploading parent profile picture:', error);
    
    if (req.file && req.file.path) {
      try {
        fs.unlinkSync(req.file.path);
        console.log('Deleted uploaded file due to error');
      } catch (deleteError) {
        console.log('Could not delete file:', deleteError.message);
      }
    }
    
    res.status(500).json({ 
      success: false,
      message: 'Error uploading profile picture',
      error: error.message 
    });
  }
};

const getParentDashboard = async (req, res) => {
  try {
    const parentId = req.user.user_id; 

    const parent = await Parent.findOne({
      where: { parent_id: parentId },
      include: [
        { model: User, attributes: ['full_name', 'email', 'phone', 'profile_picture'] },
      ]
    });
    if (!parent) return res.status(404).json({ message: 'Parent not found' });

    const children = await Child.findAll({
      where: { parent_id: parentId },
      include: [
        { 
          model: Diagnosis, 
          attributes: ['name'],
          as: 'Diagnosis' 
        },
        {
          model: Institution,
          as: 'currentInstitution',
          attributes: ['name', 'institution_id']
        }
      ],
    });
    
    const childrenWithEvaluations = await Promise.all(
      children.map(async (child) => {
        const evaluations = await sequelize.query(`
          SELECT evaluation_id, evaluation_type, progress_score, notes, created_at
          FROM Evaluations
          WHERE child_id = ?
          ORDER BY created_at DESC
          LIMIT 10
        `, {
          replacements: [child.child_id],
          type: sequelize.QueryTypes.SELECT
        });
        
        return {
          ...child.toJSON(),
          evaluations
        };
      })
    );

    const pendingRegistrations = await ChildRegistrationRequest.count({
      where: { 
        requested_by_parent_id: parentId,
        status: 'Pending'
      }
    });

    const upcomingSessions = await Session.count({
      where: { 
        child_id: children.map(c => c.child_id), 
        status: ['Scheduled', 'Confirmed'] 
      }
    });

    const newAIAdviceCount = await AIRecommendation.count({
      where: { child_id: children.map(c => c.child_id) }
    });

    const notifications = [
      ...(pendingRegistrations > 0 ? [
        { 
          icon: 'pending_actions', 
          title: `You have ${pendingRegistrations} pending registration requests` 
        }
      ] : []),
      { icon: 'payment', title: 'Payment due for October sessions.' },
      { icon: 'check_circle', title: 'Evaluation report for Ali is ready.' },
    ];

    res.status(200).json({
      parent: {
        name: parent.User.full_name,
        phone: parent.User.phone,
        address: parent.address,
        email: parent.User.email,
        profile_picture: parent.User.profile_picture,
      },
      children: childrenWithEvaluations.map(c => ({
        child_id: c.child_id,
        name: c.full_name,
        condition: c.Diagnosis ? c.Diagnosis.name : 'Not diagnosed',
        image: c.photo,
        registration_status: c.registration_status,
        current_institution: c.currentInstitution ? c.currentInstitution.name : null,
        evaluations: c.evaluations || []
      })),
      summaries: {
        totalChildren: children.length,
        pendingRegistrations,
        upcomingSessions,
        newAIAdviceCount,
        notifications
      }
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

const updateParentProfile = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const {
      full_name,
      email,
      phone,
      address,
      occupation,
      profile_picture
    } = req.body;

    console.log('🔄 Updating parent profile:', { parentId, ...req.body });

    const parent = await Parent.findOne({ 
      where: { parent_id: parentId } 
    });

    if (!parent) {
      return res.status(404).json({ message: 'Parent not found' });
    }

    await User.update(
      {
        full_name,
        email,
        phone,
        profile_picture
      },
      { where: { user_id: parentId } }
    );

    await Parent.update(
      {
        address,
        occupation
      },
      { where: { parent_id: parentId } }
    );

    const updatedParent = await Parent.findOne({
      where: { parent_id: parentId },
      include: [
        { 
          model: User, 
          attributes: ['full_name', 'email', 'phone', 'profile_picture'] 
        },
      ]
    });

    res.status(200).json({ 
      success: true,
      message: 'Profile updated successfully',
      parent: {
        name: updatedParent.User.full_name,
        email: updatedParent.User.email,
        phone: updatedParent.User.phone,
        address: updatedParent.address,
        occupation: updatedParent.occupation,
        profile_picture: updatedParent.User.profile_picture
      }
    });

  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to update profile', 
      error: error.message 
    });
  }
};


const sendNotificationToSpecialist = async (specialistId, title, body, data = {}) => {
  try {
    if (!specialistId) {
      console.log('⚠️ No specialist ID provided for notification');
      return;
    }

    const [tokenResult] = await sequelize.query(`
      SELECT token 
      FROM UserDeviceTokens 
      WHERE user_id = ? 
        AND is_active = 1
      ORDER BY updated_at DESC 
      LIMIT 1
    `, { replacements: [specialistId] });

    if (!tokenResult.length || !tokenResult[0].token) {
      console.log(`⚠️ No token found for specialist ${specialistId}`);
      
      await Notification.create({
        user_id: specialistId,
        title: title,
        message: body,
        type: data.type || 'session_notification',
        related_id: data.session_id || null,
        is_read: false,
        metadata: JSON.stringify(data)
      });
      
      return;
    }

    const token = tokenResult[0].token.trim();
    
    const notificationData = {
      type: data.type || 'session_notification',
      session_id: data.session_id?.toString() || '',
      child_name: data.child_name || '',
      date: data.date || '',
      time: data.time || '',
      status: data.status || '',
      action: data.action || 'view_schedule',
      channel: 'session_channel',
      ...data
    };

    await NotificationService.sendToToken(
      token,
      title,
      body,
      notificationData
    );

    await Notification.create({
      user_id: specialistId,
      title: title,
      message: body,
      type: data.type || 'session_notification',
      related_id: data.session_id || null,
      is_read: false,
      metadata: JSON.stringify(notificationData)
    });

    console.log(`✅ Notification sent to specialist ${specialistId}: ${title}`);

  } catch (error) {
    console.error('❌ Error sending notification to specialist:', error);
  }
};

const rescheduleSession = async (req, res) => {
  try {
    const { sessionId } = req.params;
    const parentId = req.user.user_id;
    const { new_date, new_time, note } = req.body;

    console.log('🔄 Rescheduling session:', { sessionId, parentId, new_date, new_time, note });

    const session = await Session.findOne({
      where: { session_id: sessionId },
      include: [
        {
          model: Child,
          as: 'child',
          where: { parent_id: parentId },
          attributes: ['child_id', 'full_name']
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
        message: 'Session not found or you do not have permission to reschedule this session'
      });
    }

    if (session.status !== 'Scheduled' && session.status !== 'Pending Approval') {
      return res.status(400).json({
        success: false,
        message: 'Cannot reschedule a session that is not in scheduled or pending status'
      });
    }

    const oldDate = session.date;
    const oldTime = session.time;

    const conflictingSession = await Session.findOne({
      where: {
        specialist_id: session.specialist_id,
        date: new_date,
        time: new_time,
        status: ['Scheduled', 'Confirmed'],
        session_id: { [Op.ne]: sessionId }
      }
    });

    if (conflictingSession) {
      return res.status(409).json({
        success: false,
        message: 'Specialist is not available at the requested time'
      });
    }

    const SpecialistSchedule = require('../model/SpecialistSchedule');
    const targetDate = new Date(new_date);
    const dayOfWeek = targetDate.toLocaleDateString('en-US', { weekday: 'long' });

    const specialistSchedule = await SpecialistSchedule.findOne({
      where: {
        specialist_id: session.specialist_id,
        day_of_week: dayOfWeek
      }
    });

    let newStatus = 'Pending Approval';

    if (specialistSchedule) {
      const sessionTime = new_time.substring(0, 5);
      const scheduleStart = specialistSchedule.start_time.substring(0, 5);
      const scheduleEnd = specialistSchedule.end_time.substring(0, 5);

      if (sessionTime >= scheduleStart && sessionTime < scheduleEnd) {
        newStatus = 'Rescheduled';
        console.log(
          `✅ Time ${sessionTime} is within specialist working hours (${scheduleStart}-${scheduleEnd}), setting status to Rescheduled`
        );
      } else {
        console.log(
          `⚠️ Time ${sessionTime} is outside specialist working hours (${scheduleStart}-${scheduleEnd}), status remains Pending Approval`
        );
      }
    } else {
      console.log(
        `⚠️ No schedule found for specialist on ${dayOfWeek}, status remains Pending Approval`
      );
    }

    const updateData = {
      date: new_date,
      time: new_time,
      status: newStatus,
      rescheduled_at: new Date(),
      rescheduled_by: 'parent',
      old_date: oldDate, 
      old_time: oldTime  
    };

    if (note) {
      updateData.reschedule_note = note;
    }

    const autoNote = `Session rescheduled from ${oldDate} ${oldTime} to ${new_date} ${new_time}`;
    updateData.specialist_note =
      autoNote + (note ? `\nParent note: ${note}` : '');

    await Session.update(updateData, { where: { session_id: sessionId } });

    const updatedSession = await Session.findByPk(sessionId, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['full_name']
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['full_name', 'user_id']
        },
        {
          model: Institution,
          as: 'institution',
          attributes: ['name']
        }
      ]
    });

   
await sendNotificationToSpecialist(
  updatedSession.specialist.user_id,
  newStatus === 'Rescheduled' ? '📅 تم تأجيل الجلسة' : '⏳ طلب تأجيل الجلسة',
  newStatus === 'Rescheduled'
    ? `تم تأجيل جلسة ${updatedSession.child.full_name} من ${oldDate} ${oldTime} إلى ${new_date} ${new_time}`
    : `طلب تأجيل جلسة ${updatedSession.child.full_name} من ${oldDate} ${oldTime} إلى ${new_date} ${new_time} (في انتظار الموافقة)`,
  {
    type: 'session_rescheduled',
    session_id: sessionId.toString(), 
    child_id: updatedSession.child.child_id.toString(), 
    child_name: updatedSession.child.full_name, 
    old_date: oldDate,
    old_time: oldTime,
    new_date: new_date,
    new_time: new_time,
    status: newStatus,
    rescheduled_by: 'parent',
    note: note || '',
    action: 'view_session',
    channel: 'session_channel',
    notificationType: 'session_rescheduled',
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
    timestamp: new Date().toISOString()
  }
);

await Notification.create({
  user_id: session.specialist_id,
  title: newStatus === 'Rescheduled' ? 'تم تأجيل جلسة' : 'طلب تأجيل جلسة',
  message: newStatus === 'Rescheduled' 
    ? `تم تأجيل جلسة ${updatedSession.child.full_name} من ${oldDate} ${oldTime} إلى ${new_date} ${new_time}. ${note ? `ملاحظة الأهل: ${note}` : ''}`
    : `طلب تأجيل جلسة ${updatedSession.child.full_name} من ${oldDate} ${oldTime} إلى ${new_date} ${new_time}. ${note ? `ملاحظة الأهل: ${note}` : ''}`,
  type: 'session_rescheduled',
  related_id: sessionId,
  is_read: false,
  metadata: JSON.stringify({
    old_date: oldDate,
    old_time: oldTime,
    new_date: new_date,
    new_time: new_time,
    status: newStatus,
    rescheduled_by: 'parent',
    child_name: updatedSession.child.full_name,
    child_id: updatedSession.child.child_id,
    session_id: sessionId,
    notification_data: {
      type: 'session_rescheduled',
      action: 'view_session',
      channel: 'session_channel'
    }
  })
});

    try {
      await Notification.create({
        user_id: session.specialist_id,
        title: newStatus === 'Rescheduled' ? 'Session Rescheduled' : 'Session Reschedule Request',
        message: newStatus === 'Rescheduled'
          ? `Session for ${updatedSession.child.full_name} has been rescheduled from ${oldDate} ${oldTime} to ${new_date} ${new_time}. ${note ? `Parent note: ${note}` : ''}`
          : `Reschedule request for ${updatedSession.child.full_name} from ${oldDate} ${oldTime} to ${new_date} ${new_time}. ${note ? `Parent note: ${note}` : ''}`,
        type: 'session_rescheduled',
        related_id: sessionId,
        is_read: false,
        metadata: {
          old_date: oldDate,
          old_time: oldTime,
          new_date: new_date,
          new_time: new_time,
          status: newStatus,
          rescheduled_by: 'parent',
          child_name: updatedSession.child.full_name
        }
      });
      console.log('✅ Notification created for specialist about rescheduling');
    } catch (notifError) {
      console.error('❌ Error creating notification:', notifError);
    }

    res.status(200).json({
      success: true,
      message:
        newStatus === 'Rescheduled'
          ? 'Session rescheduled successfully'
          : 'Session reschedule request submitted successfully and pending approval',
      session: {
        session_id: updatedSession.session_id,
        date: updatedSession.date,
        time: updatedSession.time,
        status: updatedSession.status,
        rescheduled_at: updatedSession.rescheduled_at,
        old_date: oldDate,
        old_time: oldTime,
        specialist_note: updatedSession.specialist_note,
        child: updatedSession.child ? {
          full_name: updatedSession.child.full_name
        } : null,
        specialist: updatedSession.specialist ? {
          full_name: updatedSession.specialist.full_name,
          user_id: updatedSession.specialist.user_id
        } : null,
        institution: updatedSession.institution ? {
          name: updatedSession.institution.name
        } : null
      },
      notification_sent: true,
      schedule_info: specialistSchedule ? {
        day_of_week: dayOfWeek,
        working_hours: `${specialistSchedule.start_time.substring(0, 5)} - ${specialistSchedule.end_time.substring(0, 5)}`,
        is_within_schedule: newStatus === 'Rescheduled'
      } : null
    });

  } catch (error) {
    console.error('❌ Error rescheduling session:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to reschedule session',
      error: error.message
    });
  }
};


const getChildEvaluations = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    console.log('🔍 Fetching evaluations for parent:', parentId);

    const query = `
      SELECT 
        e.evaluation_id,
        e.evaluation_type,
        e.notes,
        CAST(e.progress_score AS DECIMAL(5,2)) as progress_score,
        e.attachment,
        e.created_at,
        c.child_id,
        c.full_name as child_name,
        u_spec.full_name as specialist_name,
        spec.specialization,
        diag.name as diagnosis_name
      FROM Evaluations e
      INNER JOIN Children c ON e.child_id = c.child_id
      INNER JOIN Specialists spec ON e.specialist_id = spec.specialist_id
      INNER JOIN Users u_spec ON spec.specialist_id = u_spec.user_id
      LEFT JOIN Diagnoses diag ON c.diagnosis_id = diag.diagnosis_id
      WHERE c.parent_id = ? AND c.deleted_at IS NULL
      ORDER BY e.created_at DESC
    `;

    const evaluations = await sequelize.query(query, {
      replacements: [parentId],
      type: sequelize.QueryTypes.SELECT
    });

    if (!Array.isArray(evaluations)) {
      console.error('❌ Evaluations is not an array:', typeof evaluations, evaluations);
      return res.status(500).json({
        success: false,
        error: 'Invalid data format from database'
      });
    }

    console.log('📊 Evaluations found:', evaluations.length);
    if (evaluations && evaluations.length > 0) {
      console.log('🔍 Sample evaluation progress_score:', {
        raw: evaluations[0].progress_score,
        type: typeof evaluations[0].progress_score,
        stringified: JSON.stringify(evaluations[0].progress_score)
      });
    }

    const processedEvaluations = evaluations.map(evaluation => {
      let progressScore = evaluation.progress_score;
      if (progressScore != null) {
        if (typeof progressScore === 'string') {
          progressScore = parseFloat(progressScore);
        } else if (typeof progressScore === 'object' && progressScore.toString) {
          progressScore = parseFloat(progressScore.toString());
        }
        if (isNaN(progressScore)) {
          progressScore = null;
        }
      }
      
      return {
        evaluation_id: evaluation.evaluation_id,
        evaluation_type: evaluation.evaluation_type,
        notes: evaluation.notes,
        progress_score: progressScore,
        attachment: evaluation.attachment,
        created_at: evaluation.created_at,
        child_id: evaluation.child_id,
        child_name: evaluation.child_name,
        specialist_name: evaluation.specialist_name,
        specialization: evaluation.specialization,
        diagnosis: evaluation.diagnosis_name
      };
    });

    res.status(200).json({
      success: true,
      data: processedEvaluations,
      count: processedEvaluations.length,
      message: 'Child evaluations retrieved successfully'
    });

  } catch (error) {
    console.error('❌ Get child evaluations error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch child evaluations: ' + error.message
    });
  }
};

module.exports = { 
  getParentDashboard,
  updateParentProfile,
  rescheduleSession,
  getChildEvaluations,
  uploadParentProfilePicture,
  sendNotificationToSpecialist 
};