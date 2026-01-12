const { Op, Sequelize } = require('sequelize');
const sequelize = require('../../config/db');
const nodemailer = require('nodemailer');
const bcrypt = require('bcryptjs');

const Manager = require('../../model/Manager');
const Institution = require('../../model/Institution');
const SpecialistRegistrationRequest = require('../../model/SpecialistRegistrationRequest');
const SpecialistInterview = require('../../model/SpecialistInterview');
const User = require('../../model/User');
const Specialist = require('../../model/Specialist');
const Notification = require('../../model/Notification');

// ==================== Helper function for sending emails ====================

const sendInterviewEmail = async (email, full_name, interviewData) => {
  try {
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: process.env.SMTP_PORT,
      secure: false,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
      },
      tls: {
        rejectUnauthorized: false
      }
    });

    const interviewDate = new Date(interviewData.interview_date);
    const formattedDate = interviewDate.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
    
    const formattedTime = interviewDate.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });

    let locationInfo = '';
    if (interviewData.interview_type === 'Online') {
      locationInfo = `
        <p><strong>Meeting Link:</strong> ${interviewData.meeting_link}</p>
        <p><strong>Note:</strong> The interview will be conducted online</p>
      `;
    } else {
      locationInfo = `
        <p><strong>Interview Location:</strong> ${interviewData.location}</p>
        <p><strong>Note:</strong> Please arrive 15 minutes before the scheduled time</p>
      `;
    }

    const emailHtml = `
<!DOCTYPE html>
<html dir="ltr" lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Job Interview Invitation - Jusoor</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.8;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f8f9fa;
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
            background: linear-gradient(135deg, #4A90E2 0%, #357ABD 100%);
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
        .greeting {
            font-size: 22px;
            color: #2c3e50;
            margin-bottom: 20px;
            text-align: center;
        }
        .interview-details {
            background-color: #f0f7ff;
            border-radius: 8px;
            padding: 25px;
            margin: 25px 0;
            border-left: 5px solid #4A90E2;
        }
        .detail-item {
            margin: 15px 0;
            padding: 10px 0;
            border-bottom: 1px solid #d1e3ff;
        }
        .detail-item:last-child {
            border-bottom: none;
        }
        .label {
            font-weight: bold;
            color: #2c3e50;
            display: inline-block;
            width: 150px;
        }
        .value {
            color: #1a365d;
        }
        .instructions {
            background-color: #fff8e1;
            border: 1px solid #ffd54f;
            border-radius: 5px;
            padding: 20px;
            margin: 25px 0;
        }
        .instructions h3 {
            color: #ff8f00;
            margin-top: 0;
        }
        .footer {
            background-color: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 14px;
            border-top: 1px solid #e9ecef;
        }
        .button {
            display: inline-block;
            background: linear-gradient(135deg, #4A90E2 0%, #357ABD 100%);
            color: white;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
            margin: 15px 5px;
        }
        .note {
            color: #d32f2f;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📅 Job Interview Invitation</h1>
        </div>
        
        <div class="content">
            <div class="greeting">
                👋 Hello ${full_name},
            </div>
            
            <p>We are pleased to inform you that a job interview has been scheduled for you to join our team at Jusoor Center.</p>
            
            <div class="interview-details">
                <div class="detail-item">
                    <span class="label">📅 Date:</span>
                    <span class="value">${formattedDate}</span>
                </div>
                <div class="detail-item">
                    <span class="label">⏰ Time:</span>
                    <span class="value">${formattedTime}</span>
                </div>
                <div class="detail-item">
                    <span class="label">📍 Interview Type:</span>
                    <span class="value">${interviewData.interview_type === 'Online' ? 'Remote' : 'On-site'}</span>
                </div>
                ${locationInfo}
                <div class="detail-item">
                    <span class="label">📝 Notes:</span>
                    <span class="value">${interviewData.notes || 'No additional notes'}</span>
                </div>
            </div>
            
            <div class="instructions">
                <h3>📋 Important Instructions:</h3>
                <ol>
                    <li>Please ensure you are present 10 minutes before the scheduled time</li>
                    <li>Bring a copy of your resume</li>
                    <li>Bring certified copies of your certificates and experience documents</li>
                    <li>Ensure internet connection is ready in case of remote interview</li>
                </ol>
                <p class="note">Note: If unable to attend, please notify us at least 24 hours before the appointment.</p>
            </div>
            
            <p>We look forward to meeting you and wish you the best of luck.</p>
            
            <div style="text-align: center; margin: 30px 0;">
                <p>For any inquiries, feel free to contact us.</p>
            </div>
        </div>
        
        <div class="footer">
            <p>Best regards,</p>
            <p><strong>Jusoor Center Management Team</strong></p>
            <p>📧 ${process.env.SMTP_FROM || 'info@jusoor.com'}</p>
            <p>📞 +1234567890</p>
            <p>© ${new Date().getFullYear()} Jusoor Center. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
    `;

    const mailOptions = {
      from: process.env.SMTP_FROM,
      to: email,
      subject: 'Job Interview Invitation - Jusoor Center',
      html: emailHtml
    };

    await transporter.sendMail(mailOptions);
    console.log(`📧 Interview email sent to: ${email}`);
    return true;
  } catch (error) {
    console.error('❌ Error sending interview email:', error);
    return false;
  }
};

const sendApprovalEmail = async (email, full_name, institutionName, password) => {
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

    const emailHtml = `
<!DOCTYPE html>
<html dir="ltr" lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Congratulations! Your Application Has Been Approved - Jusoor</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, sans-serif; line-height: 1.8; color: #333; margin: 0; padding: 0; background-color: #f8f9fa; }
        .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #28a745 0%, #218838 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 28px; }
        .content { padding: 30px; }
        .congrats { font-size: 24px; color: #28a745; text-align: center; margin-bottom: 20px; }
        .credentials { background: #e8f5e9; border-radius: 8px; padding: 20px; margin: 20px 0; }
        .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; border-top: 1px solid #ddd; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎉 Congratulations! Your Application Has Been Approved</h1>
        </div>
        <div class="content">
            <div class="congrats">Congratulations ${full_name}!</div>
            <p>Your application to join the specialist team at <strong>${institutionName}</strong> has been approved.</p>
            <div class="credentials">
                <p><strong>Temporary Password:</strong> ${password}</p>
                <p><strong>Tip:</strong> Please change your password after logging in.</p>
            </div>
            <p>You can now log in to the system and start using your account.</p>
        </div>
        <div class="footer">
            <p>Best regards,<br>${institutionName} Management Team</p>
        </div>
    </div>
</body>
</html>
    `;

    await transporter.sendMail({
      from: process.env.SMTP_FROM,
      to: email,
      subject: 'Congratulations! Your Application Has Been Approved - Jusoor',
      html: emailHtml
    });
    
    console.log(`📧 Approval email sent to: ${email}`);
    return true;
  } catch (error) {
    console.error('❌ Error sending approval email:', error);
    return false;
  }
};

// ==================== GET EMPLOYMENT REQUESTS ====================
exports.getEmploymentRequests = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const query = `
      SELECT 
        sr.request_id,
        sr.specialization,
        sr.years_experience,
        sr.cv_url,
        sr.status as request_status,
        sr.requested_at,
        sr.reviewed_at,
        u.user_id,
        u.full_name,
        u.email,
        u.phone,
        u.profile_picture,
        si.interview_id,
        si.interview_date,
        si.interview_type,
        si.status as interview_status
      FROM SpecialistRegistrationRequests sr
      INNER JOIN Managers m ON sr.institution_id = m.institution_id
      INNER JOIN Users u ON sr.user_id = u.user_id
      LEFT JOIN SpecialistInterviews si ON sr.request_id = si.request_id
      WHERE m.manager_id = ?
      ORDER BY sr.requested_at DESC
    `;

    const [results] = await sequelize.query(query, {
      replacements: [managerId]
    });

    if (!results || results.length === 0) {
      return res.json({
        success: true,
        data: {
          institution: {},
          total_requests: 0,
          by_status: { pending: 0, interview: 0, approved: 0, rejected: 0 },
          requests: []
        }
      });
    }

    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    const formattedRequests = results.map(row => ({
      request_id: row.request_id,
      specialist: {
        user_id: row.user_id,
        full_name: row.full_name,
        email: row.email,
        phone: row.phone,
        profile_picture: row.profile_picture
      },
      professional_info: {
        specialization: row.specialization,
        years_experience: row.years_experience,
        cv_url: row.cv_url
      },
      request_info: {
        status: row.request_status,
        requested_at: row.requested_at,
        reviewed_at: row.reviewed_at
      },
      interview: row.interview_id ? {
        interview_id: row.interview_id,
        interview_date: row.interview_date,
        interview_type: row.interview_type,
        status: row.interview_status
      } : null
    }));

    res.json({
      success: true,
      data: {
        institution: manager?.Institution ? {
          id: manager.Institution.institution_id,
          name: manager.Institution.name
        } : {},
        total_requests: results.length,
        by_status: {
          pending: results.filter(r => r.request_status === 'Pending').length,
          interview: results.filter(r => r.request_status === 'Interview').length,
          approved: results.filter(r => r.request_status === 'Approved').length,
          rejected: results.filter(r => r.request_status === 'Rejected').length
        },
        requests: formattedRequests
      }
    });

  } catch (error) {
    console.error('Error getting employment requests:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// ==================== GET EMPLOYMENT REQUEST DETAILS ====================
exports.getEmploymentRequestDetails = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const requestId = req.params.request_id;

    const [managerResult] = await sequelize.query(`
      SELECT m.manager_id, i.institution_id
      FROM Managers m
      INNER JOIN Institutions i ON m.institution_id = i.institution_id
      WHERE m.manager_id = ?
    `, { replacements: [managerId] });

    if (!managerResult.length) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    const institutionId = managerResult[0].institution_id;

    const query = `
      SELECT 
        -- Employment request information
        sr.request_id,
        sr.specialization,
        sr.years_experience,
        sr.cv_url,
        sr.status as request_status,
        sr.requested_at,
        sr.reviewed_at,
        sr.reviewed_by,
        
        -- User information (Specialist)
        u.user_id,
        u.full_name,
        u.email,
        u.phone,
        u.profile_picture,
        u.created_at as account_created,
        
        -- Interview information (if exists)
        si.interview_id,
        si.interview_date,
        si.interview_type,
        si.location,
        si.meeting_link,
        si.notes as interview_notes,
        si.status as interview_status,
        si.created_by_manager_id,
        
        -- Manager who reviewed (if exists)
        ru.full_name as reviewed_by_name,
        ru.email as reviewed_by_email
        
      FROM SpecialistRegistrationRequests sr
      
      -- JOIN with User (Specialist)
      INNER JOIN Users u ON sr.user_id = u.user_id
      
      -- LEFT JOIN with Interview (may not exist)
      LEFT JOIN SpecialistInterviews si ON sr.request_id = si.request_id
      
      -- LEFT JOIN with reviewing manager (may not exist)
      LEFT JOIN Users ru ON sr.reviewed_by = ru.user_id
      
      WHERE sr.request_id = ?
        AND sr.institution_id = ?
    `;

    const [results] = await sequelize.query(query, {
      replacements: [requestId, institutionId]
    });

    if (!results.length) {
      return res.status(404).json({
        success: false,
        message: 'Employment request not found'
      });
    }

    const requestData = results[0];

    const responseData = {
      request_id: requestData.request_id,
      specialist: {
        user_id: requestData.user_id,
        full_name: requestData.full_name,
        email: requestData.email,
        phone: requestData.phone,
        profile_picture: requestData.profile_picture,
        account_created: requestData.account_created
      },
      application: {
        specialization: requestData.specialization,
        years_experience: requestData.years_experience,
        cv_url: requestData.cv_url,
        status: requestData.request_status,
        requested_at: requestData.requested_at,
        reviewed_at: requestData.reviewed_at,
        reviewed_by: requestData.reviewed_by,
        reviewed_by_name: requestData.reviewed_by_name
      }
    };

    if (requestData.interview_id) {
      responseData.interview = {
        interview_id: requestData.interview_id,
        interview_date: requestData.interview_date,
        interview_type: requestData.interview_type,
        location: requestData.location,
        meeting_link: requestData.meeting_link,
        notes: requestData.interview_notes,
        status: requestData.interview_status,
        created_by_manager_id: requestData.created_by_manager_id
      };
    }

    responseData.can_schedule_interview = requestData.request_status === 'Pending';
    responseData.can_approve = requestData.request_status === 'Interview' && 
                               requestData.interview_status === 'Completed';

    const [otherApplications] = await sequelize.query(`
      SELECT COUNT(*) as count
      FROM SpecialistRegistrationRequests
      WHERE user_id = ?
        AND institution_id != ?
        AND status IN ('Pending', 'Interview')
    `, { replacements: [requestData.user_id, institutionId] });

    responseData.other_applications = otherApplications[0]?.count || 0;

    const [institutionInfo] = await sequelize.query(`
      SELECT name, location, contact_info
      FROM Institutions
      WHERE institution_id = ?
    `, { replacements: [institutionId] });

    if (institutionInfo.length) {
      responseData.institution = institutionInfo[0];
    }

    res.json({
      success: true,
      data: responseData
    });

  } catch (error) {
    console.error('Error getting employment request details:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// ==================== SCHEDULE INTERVIEW ====================
exports.scheduleInterview = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const managerId = req.user.user_id;
    const requestId = req.params.request_id;
    const {
      interview_type,
      interview_date,
      location,
      meeting_link,
      notes
    } = req.body;

    if (!interview_type || !interview_date) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Interview type and date are required'
      });
    }

    if (interview_type === 'Online' && !meeting_link) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Meeting link is required for online interviews'
      });
    }

    if (interview_type === 'Onsite' && !location) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Location is required for onsite interviews'
      });
    }

    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }],
      transaction
    });

    if (!manager || !manager.Institution) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const request = await SpecialistRegistrationRequest.findOne({
      where: {
        request_id: requestId,
        institution_id: institutionId,
        status: 'Pending'
      },
      include: [{
        model: User,
        as: 'User',
        attributes: ['full_name', 'email']
      }],
      transaction
    });

    if (!request) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Request not found or not in pending status'
      });
    }

    const existingInterview = await SpecialistInterview.findOne({
      where: { request_id: requestId },
      transaction
    });

    if (existingInterview) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Interview already scheduled for this request'
      });
    }

    const interview = await SpecialistInterview.create({
      request_id: requestId,
      interview_type,
      interview_date: new Date(interview_date),
      location: location || null,
      meeting_link: meeting_link || null,
      notes: notes || null,
      created_by_manager_id: managerId,
      status: 'Scheduled'
    }, { transaction });

    await request.update({
      status: 'Interview',
      reviewed_by: managerId,
      reviewed_at: new Date()
    }, { transaction });

    const emailSent = await sendInterviewEmail(
      request.User.email,
      request.User.full_name,
      {
        interview_type,
        interview_date: new Date(interview_date),
        location,
        meeting_link,
        notes
      }
    );

    await transaction.commit();

    res.status(201).json({
      success: true,
      message: 'Interview scheduled successfully',
      data: {
        interview_id: interview.interview_id,
        request_id: request.request_id,
        specialist_name: request.User.full_name,
        interview_type: interview.interview_type,
        interview_date: interview.interview_date,
        email_sent: emailSent,
        next_step: 'After interview completion, you can approve the request'
      }
    });

  } catch (error) {
    await transaction.rollback();
    console.error('Error scheduling interview:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// ==================== APPROVE EMPLOYMENT REQUEST ====================
exports.checkRequestStatus = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const requestId = req.params.request_id;

    const query = `
      SELECT 
        sr.request_id,
        sr.status as request_status,
        sr.institution_id,
        si.interview_id,
        si.status as interview_status,
        si.interview_date,
        u.full_name,
        u.email,
        i.name as institution_name
      FROM SpecialistRegistrationRequests sr
      LEFT JOIN SpecialistInterviews si ON sr.request_id = si.request_id
      INNER JOIN Users u ON sr.user_id = u.user_id
      INNER JOIN Institutions i ON sr.institution_id = i.institution_id
      INNER JOIN Managers m ON sr.institution_id = m.institution_id
      WHERE sr.request_id = ?
        AND m.manager_id = ?
    `;

    const [results] = await sequelize.query(query, {
      replacements: [requestId, managerId]
    });

    if (!results.length) {
      return res.status(404).json({
        success: false,
        message: 'Request not found or you are not authorized'
      });
    }

    const request = results[0];

    res.json({
      success: true,
      data: {
        request_id: request.request_id,
        request_status: request.request_status,
        interview_status: request.interview_status,
        interview_id: request.interview_id,
        interview_date: request.interview_date,
        specialist_name: request.full_name,
        specialist_email: request.email,
        institution: request.institution_name,
        can_approve: request.request_status === 'Interview' && 
                     request.interview_status === 'Completed',
        issues: {
          missing_interview: !request.interview_id,
          wrong_request_status: request.request_status !== 'Interview',
          interview_not_completed: request.interview_status !== 'Completed'
        }
      }
    });

  } catch (error) {
    console.error('Error checking request status:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};
exports.approveEmploymentRequest = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const managerId = req.user.user_id;
    const requestId = req.params.request_id;
    const { salary } = req.body;

    console.log('🔍 Approving request:', { requestId, salary });

    const [managerResult] = await sequelize.query(`
      SELECT i.institution_id, i.name as institution_name
      FROM Managers m
      INNER JOIN Institutions i ON m.institution_id = i.institution_id
      WHERE m.manager_id = ?
    `, { 
      replacements: [managerId],
      transaction 
    });

    if (!managerResult.length) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const institutionId = managerResult[0].institution_id;
    const institutionName = managerResult[0].institution_name;

    const [requestResult] = await sequelize.query(`
      SELECT 
        sr.user_id,
        sr.specialization,
        sr.years_experience,
        u.full_name,
        u.email,
        u.phone,
        sr.status as request_status
      FROM SpecialistRegistrationRequests sr
      INNER JOIN Users u ON sr.user_id = u.user_id
      WHERE sr.request_id = ?
        AND sr.institution_id = ?
    `, { 
      replacements: [requestId, institutionId],
      transaction 
    });

    if (!requestResult.length) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Employment request not found in your institution'
      });
    }

    const request = requestResult[0];
    const userId = request.user_id;

    if (request.request_status === 'Approved') {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'This request has already been approved'
      });
    }

    if (request.request_status === 'Rejected') {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'This request has already been rejected'
      });
    }

    console.log('✅ Approving request...');

    await sequelize.query(`
      UPDATE SpecialistRegistrationRequests
      SET 
        status = 'Approved',
        reviewed_by = ?,
        reviewed_at = NOW()
      WHERE request_id = ?
    `, { 
      replacements: [managerId, requestId],
      transaction 
    });

    await sequelize.query(`
      UPDATE Users
      SET 
        institution_id = ?,
        status = 'Approved'
      WHERE user_id = ?
    `, { 
      replacements: [institutionId, userId],
      transaction 
    });

    await sequelize.query(`
      INSERT INTO Specialists (
        specialist_id,
        specialization,
        years_experience,
        institution_id,
        approval_status,
        salary,
        average_rating,
        total_ratings,
        rating_summary,
        rating_badge
      ) VALUES (?, ?, ?, ?, 'Approved', ?, 0, 0, '{}', 'new')
      ON DUPLICATE KEY UPDATE
        specialization = VALUES(specialization),
        years_experience = VALUES(years_experience),
        institution_id = VALUES(institution_id),
        approval_status = VALUES(approval_status),
        salary = VALUES(salary)
    `, { 
      replacements: [
        userId,
        request.specialization,
        request.years_experience,
        institutionId,
        salary
      ],
      transaction 
    });

    await sequelize.query(`
      UPDATE SpecialistRegistrationRequests
      SET 
        status = 'Rejected',
        reviewed_by = ?,
        reviewed_at = NOW()
      WHERE user_id = ?
        AND institution_id != ?
        AND status IN ('Pending', 'Interview')
    `, { 
      replacements: [managerId, userId, institutionId],
      transaction 
    });

    const generatedPassword = Math.random().toString(36).slice(-8) + 'A1!';
    const hashedPassword = await bcrypt.hash(generatedPassword, 10);
    
    await sequelize.query(`
      UPDATE Users
      SET password = ?
      WHERE user_id = ?
    `, { 
      replacements: [hashedPassword, userId],
      transaction 
    });

    console.log('📧 Sending approval email...');
    const emailSent = await sendApprovalEmail(
      request.email,
      request.full_name,
      institutionName,
      generatedPassword
    );

    await transaction.commit();

    console.log('🎉 Approval successful!');

    res.json({
      success: true,
      message: 'Employment request approved successfully',
      data: {
        request_id: parseInt(requestId),
        specialist: {
          id: userId,
          name: request.full_name,
          email: request.email,
          phone: request.phone,
          specialization: request.specialization,
          years_experience: request.years_experience
        },
        employment: {
          salary: salary,
          institution: institutionName,
          status: 'Approved'
        },
        credentials: {
          password_sent: generatedPassword,
          email_delivered: emailSent
        },
        next_steps: [
          'Password will be sent to the specialist\'s email',
          'The specialist can now log in',
          'The specialist will appear in the specialists list'
        ]
      }
    });

  } catch (error) {
    await transaction.rollback();
    console.error('❌ Error approving employment request:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// ==================== REJECT EMPLOYMENT REQUEST ====================
exports.rejectEmploymentRequest = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const managerId = req.user.user_id;
    const requestId = req.params.request_id;
    const { rejection_reason } = req.body;

    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }],
      transaction
    });

    if (!manager || !manager.Institution) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const request = await SpecialistRegistrationRequest.findOne({
      where: {
        request_id: requestId,
        institution_id: institutionId,
        status: { [Op.in]: ['Pending', 'Interview'] }
      },
      include: [{
        model: User,
        as: 'User',
        attributes: ['full_name', 'email']
      }],
      transaction
    });

    if (!request) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Request not found or already processed'
      });
    }

    await request.update({
      status: 'Rejected',
      reviewed_by: managerId,
      reviewed_at: new Date()
    }, { transaction });

    await SpecialistInterview.update({
      status: 'Cancelled'
    }, {
      where: { request_id: requestId },
      transaction
    });

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

      await transporter.sendMail({
        from: process.env.SMTP_FROM,
        to: request.User.email,
        subject: 'Employment Application Decision - Jusoor',
        html: `
          <div dir="ltr">
            <h2>Dear ${request.User.full_name},</h2>
            <p>We regret to inform you that your application to join our specialist team has been rejected.</p>
            ${rejection_reason ? `<p><strong>Reason:</strong> ${rejection_reason}</p>` : ''}
            <p>We wish you the best in your future career.</p>
            <p>Best regards,<br>Management Team</p>
          </div>
        `
      });
    } catch (emailError) {
      console.error('Failed to send rejection email:', emailError);
    }

    await transaction.commit();

    res.json({
      success: true,
      message: 'Employment request rejected successfully',
      data: {
        request_id: request.request_id,
        specialist_name: request.User.full_name,
        status: 'Rejected'
      }
    });

  } catch (error) {
    await transaction.rollback();
    console.error('Error rejecting employment request:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// ==================== GET ALL INTERVIEWS ====================
exports.getAllInterviews = async (req, res) => {
  try {
    const managerId = req.user.user_id;

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
        message: 'Institution not found'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const interviews = await SpecialistInterview.findAll({
      include: [{
        model: SpecialistRegistrationRequest,
        as: 'registrationRequest',
        where: { institution_id: institutionId },
        include: [{
          model: User,
          as: 'User',
          attributes: ['full_name', 'email', 'phone']
        }]
      }],
      order: [['interview_date', 'ASC']]
    });

    const formattedInterviews = interviews.map(interview => ({
      interview_id: interview.interview_id,
      specialist: {
        full_name: interview.registrationRequest.User.full_name,
        email: interview.registrationRequest.User.email,
        phone: interview.registrationRequest.User.phone
      },
      interview_details: {
        date: interview.interview_date,
        type: interview.interview_type,
        location: interview.location,
        meeting_link: interview.meeting_link,
        status: interview.status,
        created_at: interview.created_at
      },
      request_status: interview.registrationRequest.status
    }));

    res.json({
      success: true,
      data: {
        total_interviews: interviews.length,
        upcoming: interviews.filter(i => new Date(i.interview_date) > new Date()).length,
        completed: interviews.filter(i => i.status === 'Completed').length,
        cancelled: interviews.filter(i => i.status === 'Cancelled').length,
        interviews: formattedInterviews
      }
    });

  } catch (error) {
    console.error('Error getting all interviews:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// ==================== UPDATE INTERVIEW STATUS ====================
exports.updateInterviewStatus = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const managerId = req.user.user_id;
    const interviewId = req.params.interview_id;
    const { status, notes } = req.body;

    if (!['Completed', 'Cancelled'].includes(status)) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Invalid status. Must be "Completed" or "Cancelled"'
      });
    }

    const interview = await SpecialistInterview.findOne({
      where: { interview_id: interviewId },
      include: [{
        model: SpecialistRegistrationRequest,
        as: 'registrationRequest',
        include: [{
          model: Institution,
          attributes: ['institution_id']
        }]
      }],
      transaction
    });

    if (!interview) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Interview not found'
      });
    }

    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId,
        institution_id: interview.registrationRequest.institution_id
      },
      transaction
    });

    if (!manager) {
      await transaction.rollback();
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to update this interview'
      });
    }

    await interview.update({
      status: status,
      notes: notes ? `${interview.notes || ''}\n${new Date().toISOString()}: ${notes}`.trim() : interview.notes
    }, { transaction });

    await transaction.commit();

    res.json({
      success: true,
      message: `Interview marked as ${status}`,
      data: {
        interview_id: interview.interview_id,
        status: interview.status,
        updated_at: new Date()
      }
    });

  } catch (error) {
    await transaction.rollback();
    console.error('Error updating interview status:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// ==================== DELETE INTERVIEW ====================
exports.deleteInterview = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const managerId = req.user.user_id;
    const interviewId = req.params.interview_id;

    const interview = await SpecialistInterview.findOne({
      where: { interview_id: interviewId },
      include: [{
        model: SpecialistRegistrationRequest,
        as: 'registrationRequest',
        include: [{
          model: Institution,
          attributes: ['institution_id']
        }]
      }],
      transaction
    });

    if (!interview) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Interview not found'
      });
    }

    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId,
        institution_id: interview.registrationRequest.institution_id
      },
      transaction
    });

    if (!manager) {
      await transaction.rollback();
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to delete this interview'
      });
    }

    await SpecialistRegistrationRequest.update({
      status: 'Pending',
      reviewed_by: null,
      reviewed_at: null
    }, {
      where: { request_id: interview.request_id },
      transaction
    });

    await interview.destroy({ transaction });

    await transaction.commit();

    res.json({
      success: true,
      message: 'Interview deleted and request reset to pending',
      data: {
        interview_id: interviewId,
        request_id: interview.request_id
      }
    });

  } catch (error) {
    await transaction.rollback();
    console.error('Error deleting interview:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};