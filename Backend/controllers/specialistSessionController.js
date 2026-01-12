const Session = require('../model/Session');
  const User = require('../model/User');
  const Child = require('../model/Child');
  const Institution = require('../model/Institution');
  const SessionType = require('../model/SessionType');
  const Notification = require('../model/Notification');
  const { Op } = require('sequelize');
  const ZoomMeeting = require('../model/ZoomMeeting');
  const { createZoomMeeting } = require('../services/zoomService');
  const { createInvoiceForSession } = require('./sessionBookingController');
  const NotificationService = require('../services/notificationService');

exports.getAllSessionsForSpecialist = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    const sessions = await Session.findAll({
      where: { 
        specialist_id: specialistId,
        is_visible: true
      },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id', 'photo'] 
        },
        { 
          model: Institution, 
          as: 'institution',
          attributes: ['institution_id', 'name'] 
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'duration', 'category']
        }
      ],
      attributes: [
        'session_id', 
        'date', 
        'time', 
        'status',
        'session_type',
        'session_type_id', 
        'child_id', 
        'institution_id',
        'delete_request',
        'delete_status',
        'requested_by_parent',
        'is_pending',
        'original_session_id',
        'reason'
      ],
      order: [['date', 'ASC'], ['time', 'ASC']]
    });

    res.status(200).json(sessions);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error retrieving sessions' });
  }
};

exports.requestDeleteSession = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const specialistId = req.user.user_id;

    const session = await Session.findOne({ 
      where: { session_id: id, specialist_id: specialistId },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id', 'photo'] 
        }
      ]
    });
    
    if (!session) {
      return res.status(404).json({ message: 'Session not found' });
    }

    await Session.update(
      {
        status: 'Cancelled',
        is_visible: false, 
        reason: reason || 'Cancelled by specialist'
      },
      {
        where: { session_id: id, specialist_id: specialistId }
      }
    );

    if (session.child && session.child.parent_id) {
      await Notification.create({
        user_id: session.child.parent_id,
        title: 'Session Cancelled',
        message: `The session for ${session.child.full_name} scheduled on ${session.date} at ${session.time} has been cancelled. ${reason ? `Reason: ${reason}` : ''}`,
        type: 'session_cancelled',
        related_id: session.session_id,
        is_read: false
      });

      try {
        const UserDeviceToken = require('../model/UserDeviceToken');
        const parentTokens = await UserDeviceToken.findAll({
          where: { 
            user_id: session.child.parent_id, 
            is_active: true 
          },
          attributes: ['token']
        });

        for (const tokenData of parentTokens) {
          const fcmToken = tokenData.token;
          if (fcmToken && fcmToken.trim() !== '') {
            await NotificationService.sendSessionUpdated(
              fcmToken,
              session.child.full_name,
              session.date,
              session.time,
              null,
              null, 
              session.session_id,
              'cancelled'
            );
            console.log(`✅ FCM cancellation notification sent to parent for child ${session.child.full_name}`);
          }
        }
      } catch (fcmError) {
        console.error(`❌ Error sending FCM cancellation notification: ${fcmError.message}`);
      }
    }

    res.status(200).json({ 
      message: 'Session cancelled successfully and parent notified',
      reason: reason || 'No reason provided'
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error cancelling session' });
  }
};

exports.requestSessionUpdate = async (req, res) => {
  try {
    const { id } = req.params;
    const { date, time, status, session_type, reason } = req.body;
    const specialistId = req.user.user_id;

    const session = await Session.findOne({
      where: { session_id: id, specialist_id: specialistId },
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id', 'photo']
        }
      ]
    });

    if (!session) return res.status(404).json({ message: 'Session not found' });

    const immediateStatuses = ['Completed', 'Absent'];
    
    if (immediateStatuses.includes(status)) {
      await Session.update(
        {
          status: status,
          is_pending: false,
          reason: reason || null,
          ...(status === 'Completed' && { completed_at: new Date() })
        },
        {
          where: { session_id: id, specialist_id: specialistId }
        }
      );

      if (session.child && session.child.parent_id) {
        try {
          const UserDeviceToken = require('../model/UserDeviceToken');
          const parentTokens = await UserDeviceToken.findAll({
            where: { 
              user_id: session.child.parent_id, 
              is_active: true 
            },
            attributes: ['token']
          });

          for (const tokenData of parentTokens) {
            const fcmToken = tokenData.token;
            if (fcmToken && fcmToken.trim() !== '') {
              await NotificationService.sendSessionUpdated(
                fcmToken,
                session.child.full_name,
                session.date,
                session.time,
                null, 
                null, 
                session.session_id,
                status.toLowerCase()
              );
              console.log(`✅ FCM ${status} notification sent to parent for child ${session.child.full_name}`);
            }
          }
        } catch (fcmError) {
          console.error(`❌ Error sending FCM ${status} notification: ${fcmError.message}`);
        }
      }

      return res.status(200).json({
        message: `Session marked as ${status} successfully.`,
        reason: reason || 'No reason provided',
        updatedImmediately: true
      });
    }

    await Session.update(
      {
        status: 'Pending Approval',
        is_pending: true,
        reason: reason || null
      },
      {
        where: { session_id: id, specialist_id: specialistId }
      }
    );

    const newSession = await Session.create({
      child_id: session.child_id,
      specialist_id: session.specialist_id,
      institution_id: session.institution_id,
      session_type_id: session.session_type_id,
      date: date || session.date,
      time: time || session.time,
      status: 'Rescheduled',
      session_type: session_type || session.session_type,
      is_pending: true,
      is_visible: false,
      original_session_id: session.session_id,
      reason: reason || 'Rescheduled from original session',
      final_price: session.final_price
    });

    if (session.child && session.child.parent_id) {
      try {
        const UserDeviceToken = require('../model/UserDeviceToken');
        const parentTokens = await UserDeviceToken.findAll({
          where: { 
            user_id: session.child.parent_id, 
            is_active: true 
          },
          attributes: ['token']
        });

        for (const tokenData of parentTokens) {
          const fcmToken = tokenData.token;
          if (fcmToken && fcmToken.trim() !== '') {
            await NotificationService.sendSessionUpdated(
              fcmToken,
              session.child.full_name,
              session.date,
              session.time,
              date || session.date,
              time || session.time,
              session.session_id,
              'updated'
            );
            console.log(`✅ FCM update request sent to parent for child ${session.child.full_name}`);
          }
        }
      } catch (fcmError) {
        console.error(`❌ Error sending FCM update notification: ${fcmError.message}`);
      }
    }

    res.status(200).json({
      message: 'Session rescheduling requested. Waiting for parent approval.',
      reason: reason || 'No reason provided',
      originalSessionUpdated: true
    });

  } catch (err) {
    console.error('Request session update error:', err);
    res.status(500).json({ message: 'Server error requesting session update' });
  }
};


  exports.approvePendingSession = async (req, res) => {
    try {
      const { id } = req.params;  
      const { approve } = req.body;

      const originalSession = await Session.findOne({ 
        where: { session_id: id } 
      });
      
      if (!originalSession) return res.status(404).json({ message: 'Session not found' });

      const newSession = await Session.findOne({
        where: { original_session_id: id, is_pending: true }
      });

      if (approve) {
        if (newSession) {
          await Session.update(
            { 
              status: 'Scheduled',
              is_pending: false,
              is_visible: true
            }, 
            { 
              where: { session_id: newSession.session_id } 
            }
          );
        }

        await Session.update(
          { 
            status: 'Rescheduled - Approved',
            is_visible: false, 
            is_pending: false
          }, 
          { 
            where: { session_id: id } 
          }
        );

      } else {
        await Session.update(
          { 
            status: 'Scheduled',
            is_pending: false,
            is_visible: true
          }, 
          { 
            where: { session_id: id } 
          }
        );

        if (newSession) {
          await newSession.destroy();
        }
      }

      res.status(200).json({ 
        message: approve ? 'Session rescheduling approved' : 'Session rescheduling rejected'
      });

    } catch (err) {
      console.error('Approve pending session error:', err);
      res.status(500).json({ message: 'Server error approving/rejecting session' });
    }
  };


  exports.completeTodaySessions = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todaySessions = await Session.findAll({
      where: {
        specialist_id: specialistId,
        date: today,
        status: {
          [Op.in]: ['Scheduled', 'Confirmed', 'Pending Approval']
        }
      },
      include: [
        { 
          model: Child, 
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id', 'photo']
        }
      ]
    });

    const result = await Session.update(
      { status: 'Completed' },
      {
        where: {
          specialist_id: specialistId,
          date: today,
          status: {
            [Op.in]: ['Scheduled', 'Confirmed', 'Pending Approval']
          }
        }
      }
    );

    const updatedCount = result[0];

    for (const session of todaySessions) {
      if (session.child && session.child.parent_id) {
        await Notification.create({
          user_id: session.child.parent_id,
          title: 'Session Completed',
          message: `${session.child.full_name} session has been completed successfully.`,
          type: 'session_completed',
          related_id: session.session_id,
          is_read: false
        });

        try {
          const UserDeviceToken = require('../model/UserDeviceToken');
          const parentTokens = await UserDeviceToken.findAll({
            where: { 
              user_id: session.child.parent_id, 
              is_active: true 
            },
            attributes: ['token']
          });

          for (const tokenData of parentTokens) {
            const fcmToken = tokenData.token;
            if (fcmToken && fcmToken.trim() !== '') {
              await NotificationService.sendSessionUpdated(
                fcmToken,
                session.child.full_name,
                session.date,
                session.time,
                null, 
                null, 
                session.session_id,
                'completed'
              );
              console.log(`✅ FCM completion notification sent to parent for child ${session.child.full_name}`);
            }
          }
        } catch (fcmError) {
          console.error(`❌ Error sending FCM completion notification: ${fcmError.message}`);
        }
      }
    }

    res.status(200).json({
      message: `Completed ${updatedCount} sessions for today`,
      updatedCount: updatedCount
    });
  } catch (err) {
    console.error('Complete today sessions error:', err);
    res.status(500).json({ message: 'Server error completing today sessions' });
  }
};


  exports.getUpcomingSessions = async (req, res) => {
    try {
      const specialistId = req.user.user_id;
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const nextWeek = new Date();
      nextWeek.setDate(today.getDate() + 7);
      nextWeek.setHours(23, 59, 59, 999);

      const sessions = await Session.findAll({
        where: {
          specialist_id: specialistId,
          date: {
            [Op.between]: [today, nextWeek]
          },
          status: 'Scheduled',
          is_visible: true 
        },
        include: [
          { 
            model: Child, 
            as: 'child',
            attributes: ['child_id', 'full_name', 'photo'] 
          },
          { 
            model: Institution, 
            as: 'institution',
            attributes: ['institution_id', 'name'] 
          },
          {
            model: SessionType,
            attributes: ['session_type_id', 'name', 'duration', 'category']
          }
        ],
        attributes: [
          'session_id', 
          'date', 
          'time', 
          'status',
          'session_type',
          'session_type_id'
        ],
        order: [['date', 'ASC'], ['time', 'ASC']]
      });

      res.status(200).json(sessions);
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: 'Server error retrieving upcoming sessions' });
    }
  };


  exports.getMonthlyReport = async (req, res) => {
    try {
      const specialistId = req.user.user_id;
      const { month, year } = req.query;
      
      const targetMonth = month || new Date().getMonth() + 1;
      const targetYear = year || new Date().getFullYear();

      const startDate = new Date(targetYear, targetMonth - 1, 1);
      const endDate = new Date(targetYear, targetMonth, 0);
      endDate.setHours(23, 59, 59, 999);

      const sessions = await Session.findAll({
        where: {
          specialist_id: specialistId,
          date: {
            [Op.between]: [startDate, endDate]
          },
          is_visible: true 
        },
        attributes: [
          'session_id', 
          'date', 
          'status',
          'session_type'
        ]
      });

      const totalSessions = sessions.length;
      const completedSessions = sessions.filter(s => s.status === 'Completed').length;
      const cancelledSessions = sessions.filter(s => s.status === 'Cancelled').length;
      const onlineSessions = sessions.filter(s => s.session_type === 'Online').length;
      const onsiteSessions = sessions.filter(s => s.session_type === 'Onsite').length;

      const report = {
        month: targetMonth,
        year: targetYear,
        totalSessions,
        completedSessions,
        cancelledSessions,
        onlineSessions,
        onsiteSessions,
        completionRate: totalSessions > 0 ? (completedSessions / totalSessions * 100).toFixed(2) : 0
      };

      res.status(200).json(report);
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: 'Server error generating monthly report' });
    }
  };


  exports.setSessionReminders = async (req, res) => {
    try {
      const specialistId = req.user.user_id;
      const { reminderTime } = req.body;

      res.status(200).json({
        message: 'Reminders set successfully',
        reminderTime: reminderTime
      });
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: 'Server error setting reminders' });
    }
  };


  exports.joinZoomSession = async (req, res) => {
    try {
      const { id } = req.params;
      const specialistId = req.user.user_id;

      const session = await Session.findOne({
        where: {
          session_id: id,
          specialist_id: specialistId,
          session_type: 'Online'
        },
        include: [
          {
            model: Child,
            as: 'child',
            attributes: ['child_id', 'full_name', 'parent_id', 'photo']
          }
        ]
      });

      if (!session) {
        return res.status(404).json({ message: 'Online session not found' });
      }

      let zoomMeeting = await ZoomMeeting.findOne({ where: { session_id: id } });

      if (!zoomMeeting) {
        const startTime = `${session.date}T${session.time}:00`;
        const meetingData = await createZoomMeeting(`Session ${session.child.full_name}`, startTime);

        zoomMeeting = await ZoomMeeting.create({
          session_id: session.session_id,
          meeting_id: meetingData.id,
          join_url: meetingData.join_url,
          start_time: meetingData.start_time,
          topic: meetingData.topic
        });

        if (session.child && session.child.parent_id) {
          await Notification.create({
            user_id: session.child.parent_id,
            title: 'Zoom session created',
            message: `A Zoom meeting for ${session.child.full_name}'s session has been created. Join here: ${meetingData.join_url}`,
            type: 'session_update',
            related_id: session.session_id,
            is_read: false
          });
        }
      }

      return res.status(200).json({
        message: 'Zoom meeting retrieved successfully',
        meeting: {
          meetingId: zoomMeeting.meeting_id,
          joinUrl: zoomMeeting.join_url,
          startTime: zoomMeeting.start_time,
          topic: zoomMeeting.topic
        }
      });
    } catch (err) {
      console.error('Zoom session error:', err.response?.data || err.message);
      return res.status(500).json({ message: 'Server error creating/retrieving Zoom meeting' });
    }
  };


  exports.getPendingSessionsForParent = async (req, res) => {
    try {
      const parentId = req.user.user_id;
      const pendingSessions = await Session.findAll({
        where: {
          is_pending: true,
          is_visible: true
        },
        include: [
          {
            model: Child,
            as: 'child',
            attributes: ['child_id', 'full_name', 'parent_id', 'photo'],
            where: { parent_id: parentId }
          },
          {
            model: SessionType,
            attributes: ['session_type_id', 'name', 'duration', 'category']
          }
        ]
      });

      res.status(200).json(pendingSessions);
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: 'Server error retrieving pending sessions' });
    }
  };


  exports.getNewPendingSessionsForParent = async (req, res) => {
    try {
      const parentId = req.user.user_id;
      
      const pendingSessions = await Session.findAll({
        where: {
          status: 'Pending Approval',
          parent_approved: null,
          is_pending: true
        },
        include: [
          {
            model: Child,
            as: 'child',
            attributes: ['child_id', 'full_name', 'parent_id', 'photo']
          },
          {
            model: User,
            as: 'specialist',
            attributes: ['user_id', 'full_name', 'profile_picture']
          },
          {
            model: Institution,
            as: 'institution',
            attributes: ['institution_id', 'name']
          },
          {
            model: SessionType,
            attributes: ['session_type_id', 'name', 'duration', 'price', 'category']
          }
        ],
        order: [['date', 'ASC'], ['time', 'ASC']]
      });

      res.status(200).json({
        success: true,
        message: 'تم جلب الجلسات المعلقة بنجاح',
        data: pendingSessions,
        count: pendingSessions.length
      });
    } catch (err) {
      console.error('Error in getNewPendingSessionsForParent:', err);
      res.status(500).json({
        success: false,
        message: 'خطأ في جلب الجلسات المعلقة',
        error: err.message
      });
    }
  };


  exports.approveNewSession = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { session_id } = req.params;
    const { approve } = req.body;

    const session = await Session.findOne({
      where: {
        session_id,
        status: 'Pending Approval',
        parent_approved: null
      },
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id', 'photo'],
          where: { parent_id: parentId }
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
        message: 'Session not found or already processed'
      });
    }

    if (approve) {
      await session.update({
        status: 'Scheduled',
        parent_approved: true,
        is_pending: false,
        is_paid: false,
        payment_status: 'Pending'
      });

      let invoiceId = null;
      try {
        const child = session.child;
        const invoice = await createInvoiceForSession(session, child);
        invoiceId = invoice.invoice_id;
      } catch (invoiceError) {
        console.error('⚠️ Failed to create invoice for specialist-created session:', invoiceError);
      }

      if (session.specialist_id) {
        try {
          const UserDeviceToken = require('../model/UserDeviceToken');
          const specialistTokens = await UserDeviceToken.findAll({
            where: { 
              user_id: session.specialist_id, 
              is_active: true 
            },
            attributes: ['token']
          });

          for (const tokenData of specialistTokens) {
            const fcmToken = tokenData.token;
            if (fcmToken && fcmToken.trim() !== '') {
              await NotificationService.sendToToken(
                fcmToken,
                '✅ Session Approved',
                `Parent approved session for ${session.child.full_name} on ${session.date} at ${session.time}`,
                {
                  type: 'session_approved',
                  childId: session.child_id.toString(),
                  childName: session.child.full_name,
                  sessionId: session.session_id.toString(),
                  date: session.date,
                  time: session.time,
                  action: 'view_session',
                  channel: 'session_channel'
                }
              );
              console.log(`✅ FCM approval notification sent to specialist for child ${session.child.full_name}`);
            }
          }
        } catch (fcmError) {
          console.error(`❌ Error sending FCM approval notification to specialist: ${fcmError.message}`);
        }
      }

      res.status(200).json({
        success: true,
        message: 'Session approved successfully',
        data: {
          session_id: session.session_id,
          status: 'Scheduled',
          invoice_id: invoiceId
        }
      });
    } else {
      await session.update({
        status: 'Rejected',
        parent_approved: false,
        is_pending: false,
        is_visible: false
      });

      if (session.specialist_id) {
        try {
          const UserDeviceToken = require('../model/UserDeviceToken');
          const specialistTokens = await UserDeviceToken.findAll({
            where: { 
              user_id: session.specialist_id, 
              is_active: true 
            },
            attributes: ['token']
          });

          for (const tokenData of specialistTokens) {
            const fcmToken = tokenData.token;
            if (fcmToken && fcmToken.trim() !== '') {
              await NotificationService.sendToToken(
                fcmToken,
                '❌ Session Rejected',
                `Parent rejected session for ${session.child.full_name} on ${session.date} at ${session.time}`,
                {
                  type: 'session_rejected',
                  childId: session.child_id.toString(),
                  childName: session.child.full_name,
                  sessionId: session.session_id.toString(),
                  date: session.date,
                  time: session.time,
                  action: 'view_session',
                  channel: 'session_channel'
                }
              );
              console.log(`✅ FCM rejection notification sent to specialist for child ${session.child.full_name}`);
            }
          }
        } catch (fcmError) {
          console.error(`❌ Error sending FCM rejection notification to specialist: ${fcmError.message}`);
        }
      }

      res.status(200).json({
        success: true,
        message: 'Session rejected successfully',
        data: {
          session_id: session.session_id,
          status: 'Rejected'
        }
      });
    }

  } catch (err) {
    console.error('Error in approveNewSession:', err);
    res.status(500).json({
      success: false,
      message: 'Error processing approval',
      error: err.message
    });
  }
};


  exports.getQuickStats = async (req, res) => {
    try {
      const specialistId = req.user.user_id;
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      const todaySessions = await Session.count({
        where: {
          specialist_id: specialistId,
          date: today,
          is_visible: true
        }
      });

      const weekStart = new Date(today);
      weekStart.setDate(weekStart.getDate() - weekStart.getDay());
      
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 6);
      weekEnd.setHours(23, 59, 59, 999);

      const weekSessions = await Session.count({
        where: {
          specialist_id: specialistId,
          date: {
            [Op.between]: [weekStart, weekEnd]
          },
          is_visible: true
        }
      });

      const pendingSessions = await Session.count({
        where: {
          specialist_id: specialistId,
          status: 'Pending Approval',
          is_visible: true
        }
      });

      const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
      const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);
      monthEnd.setHours(23, 59, 59, 999);

      const completedThisMonth = await Session.count({
        where: {
          specialist_id: specialistId,
          status: 'Completed',
          date: {
            [Op.between]: [monthStart, monthEnd]
          },
          is_visible: true
        }
      });

      const stats = {
        todaySessions,
        weekSessions,
        pendingSessions,
        completedThisMonth
      };

      res.status(200).json(stats);
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: 'Server error getting quick stats' });
    }
  };

  exports.getDeleteRequestedSessions = async (req, res) => {
    try {
      const specialistId = req.user.user_id;

      const deleteRequestedSessions = await Session.findAll({
        where: { 
          specialist_id: specialistId,
          status: 'Cancelled',
          is_visible: false
        },
        include: [
          { 
            model: Child, 
            as: 'child',
            attributes: ['child_id', 'full_name', 'parent_id', 'photo'] 
          },
          { 
            model: Institution, 
            as: 'institution',
            attributes: ['institution_id', 'name'] 
          },
          {
            model: SessionType,
            attributes: ['session_type_id', 'name', 'duration', 'category']
          }
        ],
        attributes: [ 
          'session_id', 
          'date', 
          'time', 
          'status',
          'session_type',
          'delete_request',
          'delete_status',
          'reason'
        ],
        order: [['date', 'ASC'], ['time', 'ASC']]
      });

      res.status(200).json({
        message: 'Delete  sessions retrieved successfully',
        count: deleteRequestedSessions.length,
        sessions: deleteRequestedSessions
      });
    } catch (err) {
      console.error('Get delete  sessions error:', err);
      res.status(500).json({ message: 'Server error retrieving delete  sessions' });
    }
  };


  exports.getPendingUpdateRequests = async (req, res) => {
    try {
      const specialistId = req.user.user_id;

      const pendingSessions = await Session.findAll({
        where: {
          specialist_id: specialistId,
          is_pending: true,
          is_visible: false,
          original_session_id: { [Op.not]: null }
        },
        include: [
          { 
            model: Child, 
            as: 'child',
            attributes: ['child_id', 'full_name', 'parent_id', 'photo'] 
          },
          { 
            model: Institution, 
            as: 'institution',
            attributes: ['institution_id', 'name'] 
          },
          {
            model: SessionType,
            attributes: ['session_type_id', 'name', 'duration', 'category']
          }
        ],
        order: [['session_id', 'DESC']]
      });

      const sessionsWithOriginalData = await Promise.all(
        pendingSessions.map(async (session) => {
          const originalSession = await Session.findOne({
            where: { session_id: session.original_session_id },
            include: [
              { 
                model: Child, 
                as: 'child',
                attributes: ['child_id', 'full_name', 'parent_id', 'photo'] 
              },
              { 
                model: Institution, 
                as: 'institution',
                attributes: ['institution_id', 'name'] 
              }
            ],
            attributes: ['session_id', 'date', 'time', 'status', 'session_type']
          });

          console.log('🔍 Session Debug:');
          console.log('  - Modified Session ID:', session.session_id);
          console.log('  - Original Session ID:', session.original_session_id);
          console.log('  - Found Original:', !!originalSession);
          if (originalSession) {
            console.log('  - Original Date:', originalSession.date);
            console.log('  - Original Time:', originalSession.time);
          }

          return {
            session_id: session.session_id,
            child: session.child,
            institution: session.institution,
            SessionType: session.SessionType,
            date: session.date,           
            time: session.time,         
            status: session.status,
            session_type: session.session_type,
            is_pending: session.is_pending,
            reason: session.reason,
            original_session_id: session.original_session_id,
            
            originalSession: originalSession ? {
              session_id: originalSession.session_id,
              date: originalSession.date,     
              time: originalSession.time,     
              status: originalSession.status,
              session_type: originalSession.session_type,
              child: originalSession.child,
              institution: originalSession.institution
            } : null
          };
        })
      );

      console.log(`✅ Found ${sessionsWithOriginalData.length} pending sessions with original data`);
      
      res.status(200).json(sessionsWithOriginalData);
    } catch (err) {
      console.error('Get pending update requests error:', err);
      res.status(500).json({ message: 'Server error retrieving pending update requests' });
    }
  };