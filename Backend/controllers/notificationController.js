const NotificationService = require('../services/notificationService');

exports.sendTestNotification = async (req, res) => {
  try {
    const { token, title, body } = req.body;

    if (!token) {
      return res.status(400).json({
        success: false,
        message: 'Token is required'
      });
    }

    const result = await NotificationService.sendToToken(
      token,
      title || 'Test Notification',
      body || 'Hello from Jusoor App!'
    );

    if (result.success) {
      res.status(200).json({
        success: true,
        message: 'Notification sent successfully'
      });
    } else {
      res.status(500).json({
        success: false,
        message: 'Failed to send notification',
        error: result.error
      });
    }

  } catch (error) {
    console.error('Error in sendTestNotification:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

exports.sendChildNotification = async (req, res) => {
  try {
    const { parent_token, child_name, child_id } = req.body;

    if (!parent_token || !child_name || !child_id) {
      return res.status(400).json({
        success: false,
        message: 'Parent token, child name and ID are required'
      });
    }

    const result = await NotificationService.sendChildAdded(
      parent_token,
      child_name,
      child_id
    );

    res.status(200).json({
      success: result.success,
      message: result.success 
        ? 'Child notification sent successfully' 
        : 'Failed to send notification',
      error: result.error
    });

  } catch (error) {
    console.error('Error in sendChildNotification:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

exports.sendSessionNotification = async (req, res) => {
  try {
    const { 
      specialist_token, 
      child_name, 
      session_date, 
      session_time, 
      session_id 
    } = req.body;

    if (!specialist_token || !child_name || !session_date || !session_time) {
      return res.status(400).json({
        success: false,
        message: 'Specialist token, child name, date and time are required'
      });
    }

    const result = await NotificationService.sendSessionBooked(
      specialist_token,
      child_name,
      session_date,
      session_time,
      session_id || 'unknown'
    );

    res.status(200).json({
      success: result.success,
      message: result.success 
        ? 'Session notification sent successfully' 
        : 'Failed to send notification',
      error: result.error
    });

  } catch (error) {
    console.error('Error in sendSessionNotification:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};