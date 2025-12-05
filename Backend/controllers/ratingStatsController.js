// controllers/ratingStatsController.js
const SessionRating = require('../model/SessionRating');
const InstitutionReview = require('../model/InstitutionReview');
const SpecialistFeedback = require('../model/SpecialistFeedback');
const Specialist = require('../model/Specialist');
const Institution = require('../model/Institution');
const { Op } = require('sequelize');
const sequelize = require("../config/db");

/**
 * لوحة إحصائيات التقييمات للمدير
 */
const getRatingDashboard = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const userRole = req.user.role;

    if (userRole !== 'Manager') {
      return res.status(403).json({
        success: false,
        message: 'غير مصرح لك بالوصول لهذه البيانات'
      });
    }

    // الحصول على institution_id الخاص بالمدير
    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      attributes: ['institution_id']
    });

    if (!manager || !manager.institution_id) {
      return res.status(404).json({
        success: false,
        message: 'المدير غير مرتبط بمؤسسة'
      });
    }

    const institutionId = manager.institution_id;

    // 1. إحصائيات الأخصائيين
    const specialistsStats = await Specialist.findAll({
      where: { institution_id: institutionId },
      attributes: [
        'specialist_id',
        [sequelize.literal('(SELECT AVG(rating) FROM SessionRatings WHERE specialist_id = Specialist.specialist_id)'), 'avg_rating'],
        [sequelize.literal('(SELECT COUNT(*) FROM SessionRatings WHERE specialist_id = Specialist.specialist_id)'), 'total_ratings'],
        [sequelize.literal('(SELECT COUNT(*) FROM Sessions WHERE specialist_id = Specialist.specialist_id AND status = "Completed")'), 'total_sessions']
      ],
      include: [{
        model: require('../model/User'),
        attributes: ['full_name', 'profile_picture']
      }],
      order: [[sequelize.literal('avg_rating'), 'DESC']],
      limit: 10
    });

    // 2. إحصائيات التقييمات الشهرية
    const monthlyStats = await SessionRating.findAll({
      attributes: [
        [sequelize.fn('DATE_FORMAT', sequelize.col('rated_at'), '%Y-%m'), 'month'],
        [sequelize.fn('COUNT', sequelize.col('session_rating_id')), 'total_ratings'],
        [sequelize.fn('AVG', sequelize.col('rating')), 'avg_rating']
      ],
      where: {
        rated_at: {
          [Op.gte]: sequelize.literal("DATE_SUB(NOW(), INTERVAL 6 MONTH)")
        }
      },
      group: [sequelize.fn('DATE_FORMAT', sequelize.col('rated_at'), '%Y-%m')],
      order: [[sequelize.fn('DATE_FORMAT', sequelize.col('rated_at'), '%Y-%m'), 'DESC']],
      raw: true
    });

    // 3. توزيع التقييمات
    const ratingDistribution = {};
    for (let i = 1; i <= 5; i++) {
      const count = await SessionRating.count({
        where: { 
          rating: i,
          rated_at: {
            [Op.gte]: sequelize.literal("DATE_SUB(NOW(), INTERVAL 30 DAY)")
          }
        }
      });
      ratingDistribution[i] = count;
    }

    // 4. أهم نقاط التحسين
    const lowRatedSpecialists = specialistsStats
      .filter(s => parseFloat(s.dataValues.avg_rating || 0) < 3.5)
      .map(s => ({
        name: s.User.full_name,
        rating: parseFloat(s.dataValues.avg_rating || 0).toFixed(1),
        total_ratings: s.dataValues.total_ratings
      }));

    // 5. إحصائيات المؤسسة
    const institutionStats = await InstitutionReview.findOne({
      where: { institution_id: institutionId },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('overall_rating')), 'avg_rating'],
        [sequelize.fn('COUNT', sequelize.col('institution_review_id')), 'total_reviews'],
        [sequelize.fn('AVG', sequelize.col('facilities_rating')), 'avg_facilities'],
        [sequelize.fn('AVG', sequelize.col('staff_rating')), 'avg_staff']
      ],
      raw: true
    });

    res.json({
      success: true,
      data: {
        overview: {
          total_specialists: specialistsStats.length,
          average_specialist_rating: specialistsStats.length > 0 ? 
            specialistsStats.reduce((sum, s) => sum + parseFloat(s.dataValues.avg_rating || 0), 0) / specialistsStats.length : 0,
          total_monthly_ratings: monthlyStats.reduce((sum, m) => sum + parseInt(m.total_ratings), 0),
          institution_rating: parseFloat(institutionStats.avg_rating || 0).toFixed(1)
        },
        top_performers: specialistsStats
          .filter(s => parseFloat(s.dataValues.avg_rating || 0) >= 4.5)
          .slice(0, 5)
          .map(s => ({
            name: s.User.full_name,
            rating: parseFloat(s.dataValues.avg_rating || 0).toFixed(1),
            total_ratings: s.dataValues.total_ratings,
            profile_picture: s.User.profile_picture
          })),
        needs_attention: lowRatedSpecialists,
        monthly_trends: monthlyStats,
        rating_distribution: ratingDistribution,
        institution_stats: {
          average_rating: parseFloat(institutionStats.avg_rating || 0).toFixed(1),
          total_reviews: parseInt(institutionStats.total_reviews || 0),
          facilities_rating: parseFloat(institutionStats.avg_facilities || 0).toFixed(1),
          staff_rating: parseFloat(institutionStats.avg_staff || 0).toFixed(1)
        }
      }
    });

  } catch (error) {
    console.error('❌ Error getting rating dashboard:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب لوحة الإحصائيات',
      error: error.message
    });
  }
};

/**
 * تقرير مفصل عن أخصائي
 */
const getSpecialistDetailedReport = async (req, res) => {
  try {
    const { specialistId } = req.params;
    const userRole = req.user.role;

    if (userRole !== 'Manager') {
      return res.status(403).json({
        success: false,
        message: 'غير مصرح لك بالوصول لهذه البيانات'
      });
    }

    // 1. معلومات الأخصائي
    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId },
      include: [{
        model: require('../model/User'),
        attributes: ['full_name', 'email', 'phone', 'created_at']
      }]
    });

    if (!specialist) {
      return res.status(404).json({
        success: false,
        message: 'الأخصائي غير موجود'
      });
    }

    // 2. إحصائيات التقييمات
    const ratingStats = await SessionRating.findOne({
      where: { specialist_id: specialistId },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('rating')), 'avg_rating'],
        [sequelize.fn('COUNT', sequelize.col('session_rating_id')), 'total_ratings'],
        [sequelize.fn('MIN', sequelize.col('rating')), 'min_rating'],
        [sequelize.fn('MAX', sequelize.col('rating')), 'max_rating'],
        [sequelize.fn('STDDEV', sequelize.col('rating')), 'rating_std']
      ],
      raw: true
    });

    // 3. التقييمات الأخيرة
    const recentRatings = await SessionRating.findAll({
      where: { specialist_id: specialistId },
      include: [
        {
          model: require('../model/User'),
          as: 'parent',
          attributes: ['full_name']
        },
        {
          model: require('../model/Session'),
          attributes: ['date', 'session_type']
        }
      ],
      order: [['rated_at', 'DESC']],
      limit: 10
    });

    // 4. توزيع التقييمات
    const ratingDistribution = {};
    for (let i = 1; i <= 5; i++) {
      const count = await SessionRating.count({
        where: { 
          specialist_id: specialistId,
          rating: i 
        }
      });
      ratingDistribution[i] = count;
    }

    // 5. الملاحظات السرية
    const confidentialFeedbacks = await SpecialistFeedback.findAll({
      where: { specialist_id: specialistId },
      include: [{
        model: require('../model/User'),
        as: 'parent',
        attributes: ['full_name']
      }],
      order: [['submitted_at', 'DESC']],
      limit: 5
    });

    // 6. الاتجاهات الشهرية
    const monthlyTrends = await SessionRating.findAll({
      attributes: [
        [sequelize.fn('DATE_FORMAT', sequelize.col('rated_at'), '%Y-%m'), 'month'],
        [sequelize.fn('COUNT', sequelize.col('session_rating_id')), 'total_ratings'],
        [sequelize.fn('AVG', sequelize.col('rating')), 'avg_rating']
      ],
      where: { specialist_id: specialistId },
      group: [sequelize.fn('DATE_FORMAT', sequelize.col('rated_at'), '%Y-%m')],
      order: [[sequelize.fn('DATE_FORMAT', sequelize.col('rated_at'), '%Y-%m'), 'DESC']],
      limit: 6,
      raw: true
    });

    res.json({
      success: true,
      data: {
        specialist_info: {
          name: specialist.User.full_name,
          specialization: specialist.specialization,
          years_experience: specialist.years_experience,
          joined_date: specialist.User.created_at
        },
        rating_statistics: {
          average_rating: parseFloat(ratingStats.avg_rating || 0).toFixed(1),
          total_ratings: parseInt(ratingStats.total_ratings || 0),
          min_rating: ratingStats.min_rating,
          max_rating: ratingStats.max_rating,
          consistency_score: ratingStats.rating_std ? (5 - parseFloat(ratingStats.rating_std)).toFixed(2) : null
        },
        rating_distribution: ratingDistribution,
        recent_ratings: recentRatings.map(r => ({
          rating: r.rating,
          comment: r.comment,
          date: r.rated_at,
          parent_name: r.parent.full_name,
          session_date: r.Session.date
        })),
        confidential_feedbacks: confidentialFeedbacks.map(f => ({
          professionalism: f.professionalism_score,
          communication: f.communication_score,
          knowledge: f.knowledge_score,
          punctuality: f.punctuality_score,
          would_continue: f.would_continue,
          submitted_at: f.submitted_at,
          parent_name: f.parent.full_name
        })),
        monthly_trends: monthlyTrends,
        recommendations: generateRecommendations(ratingStats, confidentialFeedbacks)
      }
    });

  } catch (error) {
    console.error('Error getting specialist report:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب التقرير',
      error: error.message
    });
  }
};

/**
 * توليد توصيات بناء على البيانات
 */
const generateRecommendations = (ratingStats, feedbacks) => {
  const recommendations = [];
  const avgRating = parseFloat(ratingStats.avg_rating || 0);

  if (avgRating < 3) {
    recommendations.push({
      type: 'urgent',
      message: 'التقييم منخفض جداً، يحتاج متابعة فورية',
      action: 'مقابلة مع المدير + خطة تطوير'
    });
  } else if (avgRating < 4) {
    recommendations.push({
      type: 'warning',
      message: 'التقييم متوسط، يحتاج تحسين',
      action: 'تدريب على نقاط الضعف'
    });
  }

  // تحليل الملاحظات
  if (feedbacks.length > 0) {
    const lowScores = [];
    feedbacks.forEach(f => {
      if (f.professionalism_score < 3) lowScores.push('الاحترافية');
      if (f.communication_score < 3) lowScores.push('التواصل');
      if (f.punctuality_score < 3) lowScores.push('الالتزام بالوقت');
    });

    if (lowScores.length > 0) {
      const uniqueLowScores = [...new Set(lowScores)];
      recommendations.push({
        type: 'improvement',
        message: `نقاط تحتاج تحسين: ${uniqueLowScores.join('، ')}`,
        action: 'تدريب مخصص على هذه النقاط'
      });
    }
  }

  if (avgRating >= 4.5) {
    recommendations.push({
      type: 'reward',
      message: 'أداء متميز، يستحق المكافأة',
      action: 'مكافأة شهرية + ترقية محتملة'
    });
  }

  return recommendations;
};

module.exports = {
  getRatingDashboard,
  getSpecialistDetailedReport
};