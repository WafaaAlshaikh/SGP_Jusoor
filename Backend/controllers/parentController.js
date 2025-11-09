const Parent = require('../model/Parent');
const Child = require('../model/Child');
const Diagnosis = require('../model/Diagnosis');
const User = require('../model/User');
const Session = require('../model/Session');
const AIRecommendation = require('../model/AIRecommendation');
const Institution = require('../model/Institution');
const ChildRegistrationRequest = require('../model/ChildRegistrationRequest');  
const { Op } = require('sequelize'); // ⬅️ تأكد من استيراد Op
const sequelize = require('../config/db'); // ⬅️⬅️⬅️ أضف هذا السطر!


// controllers/parentController.js - تحديث الداشبورد
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

    // جلب طلبات الانضمام pending
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
      children: children.map(c => ({
        id: c.child_id,
        name: c.full_name,
        condition: c.Diagnosis ? c.Diagnosis.name : 'Not diagnosed',
        image: c.photo,
        registration_status: c.registration_status,
        current_institution: c.currentInstitution ? c.currentInstitution.name : null
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

    // 1. البحث عن Parent
    const parent = await Parent.findOne({ 
      where: { parent_id: parentId } 
    });

    if (!parent) {
      return res.status(404).json({ message: 'Parent not found' });
    }

    // 2. تحديث بيانات المستخدم في جدول Users
    await User.update(
      {
        full_name,
        email,
        phone,
        profile_picture
      },
      { where: { user_id: parentId } }
    );

    // 3. تحديث بيانات الوالد في جدول Parents
    await Parent.update(
      {
        address,
        occupation
      },
      { where: { parent_id: parentId } }
    );

    // 4. جلب البيانات المحدثة
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


// إضافة هذه الدالة لملف parentController.js
const rescheduleSession = async (req, res) => {
  try {
    const { sessionId } = req.params;
    const parentId = req.user.user_id;
    const { new_date, new_time } = req.body;

    console.log('🔄 Rescheduling session:', { sessionId, parentId, new_date, new_time });

    // 1. التأكد من أن الجلسة تابعة لأطفال الأب - استخدم 'as' keyword
    const session = await Session.findOne({
      where: { session_id: sessionId },
      include: [
        {
          model: Child,
          as: 'child', // ⬅️⬅️⬅️ أضف هذا - استخدم نفس الـ alias من الموديل
          where: { parent_id: parentId },
          attributes: ['child_id']
        }
      ]
    });

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'Session not found or you do not have permission to reschedule this session'
      });
    }

    // 2. التأكد من أن الجلسة قابلة لإعادة الجدولة
    if (session.status !== 'Scheduled' && session.status !== 'Pending Approval') {
      return res.status(400).json({
        success: false,
        message: 'Cannot reschedule a session that is not in scheduled or pending status'
      });
    }

    // 3. التحقق من توفر الأخصائي في الوقت الجديد
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

    // 4. تحديث الجلسة
    await Session.update(
      {
        date: new_date,
        time: new_time,
        status: 'Pending Approval',
        rescheduled_at: new Date(),
        rescheduled_by: 'parent'
      },
      { where: { session_id: sessionId } }
    );

    // 5. جلب البيانات المحدثة - استخدم 'as' في جميع العلاقات
    const updatedSession = await Session.findByPk(sessionId, {
      include: [
        {
          model: Child,
          as: 'child', // ⬅️⬅️⬅️
          attributes: ['full_name']
        },
        {
          model: User,
          as: 'specialist', // ⬅️⬅️⬅️
          attributes: ['full_name']
        },
        {
          model: Institution,
          as: 'institution', // ⬅️⬅️⬅️
          attributes: ['name']
        }
      ]
    });

    res.status(200).json({
      success: true,
      message: 'Session rescheduled successfully, waiting for approval',
      session: {
        session_id: updatedSession.session_id,
        date: updatedSession.date,
        time: updatedSession.time,
        status: updatedSession.status,
        rescheduled_at: updatedSession.rescheduled_at,
        child: updatedSession.child ? {
          full_name: updatedSession.child.full_name
        } : null,
        specialist: updatedSession.specialist ? {
          full_name: updatedSession.specialist.full_name
        } : null,
        institution: updatedSession.institution ? {
          name: updatedSession.institution.name
        } : null
      }
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

// الحصول على تقييمات أطفال الوالد
const getChildEvaluations = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    console.log('🔍 Fetching evaluations for parent:', parentId);

    // استعلام SQL محسن
    const query = `
      SELECT 
        e.evaluation_id,
        e.evaluation_type,
        e.notes,
        e.progress_score,
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
      LIMIT 10
    `;

    const [evaluations] = await sequelize.query(query, {
      replacements: [parentId]
    });

    console.log('📊 Evaluations found:', evaluations.length);

    // معالجة البيانات
    const processedEvaluations = evaluations.map(evaluation => ({
      evaluation_id: evaluation.evaluation_id,
      evaluation_type: evaluation.evaluation_type,
      notes: evaluation.notes,
      progress_score: evaluation.progress_score,
      attachment: evaluation.attachment,
      created_at: evaluation.created_at,
      child_id: evaluation.child_id,
      child_name: evaluation.child_name,
      specialist_name: evaluation.specialist_name,
      specialization: evaluation.specialization,
      diagnosis: evaluation.diagnosis_name
    }));

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

// ⬇️⬇️⬇️ التصدير الصحيح ⬇️⬇️⬇️
module.exports = { 
  getParentDashboard,
  updateParentProfile,
  rescheduleSession,
  getChildEvaluations
};