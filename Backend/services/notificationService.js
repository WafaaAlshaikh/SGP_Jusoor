const admin = require('firebase-admin');

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
  async sendToToken(token, title, body, data = {}) {
    try {
      if (!token || token.trim() === '') {
        console.log('⚠️ Empty token provided');
        return { success: false, error: 'Empty token' };
      }

      const message = {
        token: token.trim(),
        notification: {
          title: title,
          body: body
        },
        data: {
          ...data,
          type: data.type || 'general',
          timestamp: new Date().toISOString()
        }
      };

      console.log(`📤 Sending notification: "${title}"`);
      const response = await admin.messaging().send(message);
      console.log('✅ Notification sent successfully');
      return { success: true, response: response };

    } catch (error) {
      console.error('❌ Error sending notification:', error.message);
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
  }

  
};

module.exports = NotificationService;