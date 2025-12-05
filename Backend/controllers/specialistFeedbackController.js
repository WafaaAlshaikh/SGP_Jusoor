// controllers/specialistFeedbackController.js
const SpecialistFeedback = require('../model/SpecialistFeedback');
const Session = require('../model/Session');
const Child = require('../model/Child');
const { Op } = require('sequelize');
const sequelize = require("../config/db");

/**
 * إضافة ملاحظات سرية عن أخصائي
 */
const submitSpecialistFeedback = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const {
      specialist_id,
      professionalism_score,
      communication_score,
      knowledge_score,
      punctuality_score,
      strengths,
      improvements_needed,
      would_continue
    } = req.body;

    console.log('🔒 Submitting specialist feedback:', { parentId, specialist_id });

    // 1. التحقق من وجود جلسات سابقة مع الأخصائي
    const sessionCount = await Session.count({
      where: {
        specialist_id: specialist_id,
        status: 'Completed'
      },
      include: [{
        model: Child,
        where: { parent_id: parentId }
      }]
    });

    if (sessionCount < 3) {
      return res.status(400).json({
        success: false,
        message: 'يجب أن يكون لديك 3 جلسات على الأقل مع الأخصائي لتقديم ملاحظات'
      });
    }

    // 2. التحقق إذا سبق تقديم ملاحظات
    const existingFeedback = await SpecialistFeedback.findOne({
      where: {
        parent_id: parentId,
        specialist_id: specialist_id
      }
    });

    if (existingFeedback) {
      return res.status(400).json({
        success: false,
        message: 'لقد قدمت ملاحظات عن هذا الأخصائي مسبقاً'
      });
    }

    // 3. حفظ الملاحظات
    const feedback = await SpecialistFeedback.create({
      parent_id: parentId,
      specialist_id: specialist_id,
      professionalism_score,
      communication_score,
      knowledge_score,
      punctuality_score,
      strengths: strengths || null,
      improvements_needed: improvements_needed || null,
      would_continue,
      submitted_at: new Date()
    });

    res.status(201).json({
      success: true,
      message: 'تم إرسال ملاحظاتك بنجاح. ستكون مرئية للإدارة فقط.',
      data: {
        feedback_id: feedback.feedback_id,
        submitted_at: feedback.submitted_at
      }
    });

  } catch (error) {
    console.error('❌ Error submitting specialist feedback:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في إرسال الملاحظات',
      error: error.message
    });
  }
};

/**
 * جلب ملاحظات الأخصائيين (للمدير فقط)
 */
const getSpecialistFeedbacksForManager = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const userRole = req.user.role;

    // التحقق من صلاحية المدير
    if (userRole !== 'Manager') {
      return res.status(403).json({
        success: false,
        message: 'غير مصرح لك بالوصول لهذه البيانات'
      });
    }

    const { specialistId, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    const whereClause = {};
    if (specialistId) {
      whereClause.specialist_id = specialistId;
    }

    const { rows: feedbacks, count } = await SpecialistFeedback.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: require('../model/User'),
          as: 'parent',
          attributes: ['full_name', 'user_id']
        },
        {
          model: require('../model/User'),
          as: 'specialist',
          attributes: ['full_name', 'user_id']
        }
      ],
      order: [['submitted_at', 'DESC']],
      limit: parseInt(limit),
      offset: offset
    });

    // حساب الإحصائيات إذا طلب أخصائي محدد
    let statistics = null;
    if (specialistId) {
      const stats = await SpecialistFeedback.findOne({
        where: { specialist_id: specialistId },
        attributes: [
          [sequelize.fn('AVG', sequelize.col('professionalism_score')), 'avg_professionalism'],
          [sequelize.fn('AVG', sequelize.col('communication_score')), 'avg_communication'],
          [sequelize.fn('AVG', sequelize.col('knowledge_score')), 'avg_knowledge'],
          [sequelize.fn('AVG', sequelize.col('punctuality_score')), 'avg_punctuality'],
          [sequelize.fn('COUNT', sequelize.col('feedback_id')), 'total_feedbacks'],
          [sequelize.fn('SUM', sequelize.literal('CASE WHEN would_continue = true THEN 1 ELSE 0 END')), 'would_continue_count']
        ],
        raw: true
      });

      statistics = {
        averages: {
          professionalism: parseFloat(stats.avg_professionalism || 0).toFixed(1),
          communication: parseFloat(stats.avg_communication || 0).toFixed(1),
          knowledge: parseFloat(stats.avg_knowledge || 0).toFixed(1),
          punctuality: parseFloat(stats.avg_punctuality || 0).toFixed(1)
        },
        total_feedbacks: parseInt(stats.total_feedbacks || 0),
        would_continue_rate: stats.total_feedbacks ? 
          Math.round((parseInt(stats.would_continue_count || 0) / parseInt(stats.total_feedbacks)) * 100) : 0
      };
    }

    res.json({
      success: true,
      data: {
        feedbacks: feedbacks.map(f => ({
          id: f.feedback_id,
          professionalism_score: f.professionalism_score,
          communication_score: f.communication_score,
          knowledge_score: f.knowledge_score,
          punctuality_score: f.punctuality_score,
          strengths: f.strengths,
          improvements_needed: f.improvements_needed,
          would_continue: f.would_continue,
          submitted_at: f.submitted_at,
          parent_name: f.parent.full_name,
          specialist_name: f.specialist.full_name
        })),
        statistics: statistics,
        pagination: {
          current_page: parseInt(page),
          total_pages: Math.ceil(count / limit),
          total_feedbacks: count
        }
      }
    });

  } catch (error) {
    console.error('Error getting specialist feedbacks:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب الملاحظات',
      error: error.message
    });
  }
};

/**
 * جلب ملاحظاتي التي قدمتها (للأهل)
 */
const getMyFeedbacks = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;

    const { rows: feedbacks, count } = await SpecialistFeedback.findAndCountAll({
      where: { parent_id: parentId },
      include: [{
        model: require('../model/User'),
        as: 'specialist',
        attributes: ['full_name', 'profile_picture']
      }],
      order: [['submitted_at', 'DESC']],
      limit: parseInt(limit),
      offset: offset
    });

    res.json({
      success: true,
      data: feedbacks,
      count: count,
      pagination: {
        current_page: parseInt(page),
        total_pages: Math.ceil(count / limit)
      }
    });

  } catch (error) {
    console.error('Error getting my feedbacks:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب ملاحظاتك'
    });
  }
};

module.exports = {
  submitSpecialistFeedback,
  getSpecialistFeedbacksForManager,
  getMyFeedbacks
};