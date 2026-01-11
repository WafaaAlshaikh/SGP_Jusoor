const admin = require('firebase-admin');
const sequelize = require('../config/db');
const { Op } = require('sequelize');

// 1. Initialize Firebase
try {
  const serviceAccount = require('../firebase/service-account-key.json');
  
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('✅ Firebase Admin initialized');
  }
} catch (error) {
  console.error('❌ Failed to initialize Firebase:', error.message);
  console.log('⚠️ Please make sure service-account-key.json exists in firebase/ folder');
}

// 2. Notification Service
const NotificationService = {
  // Basic function: Send notification to a single token
  // في notificationService.js، عدل دالة sendToToken:

// في notificationService.js، عدل كائن message:
async sendToToken(token, title, body, data = {}) {
  try {
    if (!token || token.trim() === '') {
      console.log('⚠️ Empty token provided');
      return { success: false, error: 'Empty token' };
    }

    // 🔥 تحويل جميع قيم data إلى strings
    const stringData = {};
    for (const [key, value] of Object.entries(data)) {
      if (value !== undefined && value !== null) {
        stringData[key] = String(value);
      } else {
        stringData[key] = '';
      }
    }

    const message = {
      token: token.trim(),
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: data.channel || 'default_channel',
          icon: '@mipmap/ic_launcher',
          color: '#2196F3',
          tag: data.type || 'general',
          sound: 'default',
          visibility: 'public',
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body
            },
            sound: 'default',
            badge: 1
          }
        }
      },
      data: {
        ...stringData,  // 🔥 استخدام البيانات المحولة إلى strings
        type: data.type || 'general',
        timestamp: new Date().toISOString(),
        title: title,
        body: body,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        channelId: data.channel || 'default_channel',
        priority: 'high',
        notificationType: data.notificationType || data.type || 'general'
      }
    };

    console.log(`📤 Sending session notification: "${title}"`);
    console.log(`📱 Token: ${token.substring(0, 20)}...`);
    console.log(`📋 Channel: ${data.channel || 'default_channel'}`);
    console.log(`👶 Child: ${data.childName || 'Unknown'}`);
    console.log(`📅 Date/Time: ${data.date || ''} ${data.time || ''}`);
    
    const response = await admin.messaging().send(message);
    console.log('✅ Session notification sent successfully');
    return { success: true, response: response };

  } catch (error) {
    console.error('❌ Error sending session notification:', error.message);
    console.error('🔍 Error details:', error);
    return { success: false, error: error.message };
  }
},

  // Notification for child registration to parents
  async sendChildAdded(parentToken, childName, childId) {
    return await this.sendToToken(
      parentToken,
      '🎓 New Child Registered',
      `${childName} has been registered in the system`,
      {
        type: 'child_added',
        childId: childId.toString(),
        childName: childName,
        action: 'view_child'
      }
    );
  },


  
  // Notification for session booking to specialist
  async sendSessionBooked(specialistToken, childName, date, time, sessionId) {
    return await this.sendToToken(
      specialistToken,
      '📅 New Session Booked',
      `Session on ${date} at ${time} for child ${childName}`,
      {
        type: 'session_booked',
        childName: childName,
        sessionDate: date,
        sessionTime: time,
        sessionId: sessionId,
        action: 'view_schedule'
      }
    );
  },

  async sendSimpleTest(token, title, body) {
    try {
      console.log('🔥 TESTING: Sending simplest possible notification');
      console.log('Token:', token.substring(0, 20) + '...');
      
      const message = {
        token: token.trim(),
        notification: {
          title: title,
          body: body,
        },
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              sound: 'default',
            },
          },
        },
        data: {
          test: 'true',
          timestamp: new Date().toISOString(),
        },
      };

      console.log('📤 Message to send:', JSON.stringify(message, null, 2));
      
      const response = await admin.messaging().send(message);
      console.log('✅ Firebase response:', response);
      return { success: true, response: response };

    } catch (error) {
      console.error('❌ Firebase error:', error.message);
      console.error('Full error:', error);
      return { success: false, error: error.message };
    }
  },


  // Notification for session update to parents
async sendSessionUpdated(parentToken, childName, originalDate, originalTime, newDate, newTime, sessionId, action) {
  let title, body;
  
  switch(action) {
    case 'updated':
      title = '🔄 Session Rescheduled';
      body = `Session for ${childName} has been rescheduled from ${originalDate} ${originalTime} to ${newDate} ${newTime}`;
      break;
    case 'cancelled':
      title = '❌ Session Cancelled';
      body = `Session for ${childName} on ${originalDate} at ${originalTime} has been cancelled`;
      break;
    case 'completed':
      title = '✅ Session Completed';
      body = `Session for ${childName} on ${originalDate} at ${originalTime} has been completed`;
      break;
    default:
      title = '📅 Session Updated';
      body = `Session for ${childName} has been updated`;
  }
  
  return await this.sendToToken(
    parentToken,
    title,
    body,
    {
      type: 'session_' + action,
      childId: sessionId.toString(),
      childName: childName,
      originalDate: originalDate,
      originalTime: originalTime,
      newDate: newDate || '',
      newTime: newTime || '',
      sessionId: sessionId,
      action: 'view_session',
      channel: 'session_channel'
    }
  );
},

// notificationService.js - add this function
async sendToUser(userId, title, body, data = {}) {
  try {
    // Get the latest active device token from database
    const [tokenResult] = await sequelize.query(`
      SELECT token 
      FROM UserDeviceTokens 
      WHERE user_id = ? 
        AND is_active = 1
      ORDER BY updated_at DESC 
      LIMIT 1
    `, { replacements: [userId] });

    if (!tokenResult.length || !tokenResult[0].token) {
      console.log(`⚠️ No device token found for user ${userId}`);
      return { success: false, error: 'No token found for user' };
    }

    const token = tokenResult[0].token.trim();
    
    // 🔥 Convert all data values to strings (FCM requirement)
    const stringData = {};
    for (const [key, value] of Object.entries(data)) {
      if (value !== undefined && value !== null) {
        stringData[key] = String(value);
      } else {
        stringData[key] = '';
      }
    }

    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: data.channel || 'default_channel',
          icon: '@mipmap/ic_launcher',
          color: '#2196F3',
          tag: data.type || 'general',
          sound: 'default',
          visibility: 'public',
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body
            },
            sound: 'default',
            badge: 1
          }
        }
      },
      data: {
        ...stringData,
        type: data.type || 'general',
        timestamp: new Date().toISOString(),
        title: title,
        body: body,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        channelId: data.channel || 'default_channel',
        priority: 'high',
        notificationType: data.notificationType || data.type || 'general'
      }
    };

    console.log(`📤 Sending notification to user ${userId}: "${title}"`);
    console.log(`📱 Token: ${token.substring(0, 20)}...`);
    
    const response = await admin.messaging().send(message);
    console.log('✅ Notification sent successfully to user');
    return { success: true, response: response };

  } catch (error) {
    console.error('❌ Error sending notification to user:', error.message);
    return { success: false, error: error.message };
  }
},

// Helper function to send notification to manager
async sendToManager(managerId, title, body, data = {}) {
  return await this.sendToUser(managerId, title, body, {
    ...data,
    type: 'manager_notification',
    channel: 'manager_channel'
  });
},

// Send child approval notification
async sendChildApprovalNotifications(
  managerId,
  childName,
  institutionName,
  childId,
  sessionDetails = null
) {
  let title, body, notificationData = {};
  
  if (sessionDetails) {
    title = '✅ Child Approved & Session Scheduled';
    body = `Auto-approval completed for ${childName} at ${institutionName}. Session scheduled with ${sessionDetails.specialistName}`;
    
    notificationData = {
      type: 'child_auto_approved_with_session',
      child_name: childName,
      institution_name: institutionName,
      child_id: childId.toString(),
      session_id: sessionDetails.sessionId?.toString(),
      specialist_name: sessionDetails.specialistName,
      session_date: sessionDetails.date,
      session_time: sessionDetails.time,
      action: 'view_child_schedule'
    };
  } else {
    title = '✅ Child Registration Approved';
    body = `Auto-approval completed for ${childName} at ${institutionName}`;
    
    notificationData = {
      type: 'child_auto_approved',
      child_name: childName,
      institution_name: institutionName,
      child_id: childId.toString(),
      action: 'view_pending_registrations'
    };
  }

  // Send notification to manager
  const managerResult = await this.sendToManager(
    managerId,
    title,
    body,
    notificationData
  );

  return {
    manager_notification: managerResult
  };
}

};



module.exports = NotificationService;