// controllers/institutionReviewController.js
const InstitutionReview = require('../model/InstitutionReview');
const Institution = require('../model/Institution');
const Session = require('../model/Session');
const Child = require('../model/Child');
const { Op } = require('sequelize');
const sequelize = require("../config/db");



/**
 * إضافة مراجعة جديدة للمؤسسة
 */
const addInstitutionReview = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const parentId = req.user.user_id;
    const {
      facilities_rating,
      staff_rating,
      cleanliness_rating,
      accessibility_rating,
      review_text,
      would_recommend = true
    } = req.body;

    console.log('🏥 Adding institution review:', { institutionId, parentId });

    // 1. التحقق من وجود المؤسسة
    const institution = await Institution.findByPk(institutionId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة'
      });
    }

    // 2. التحقق من وجود زيارات سابقة للمؤسسة
    const visitCount = await Session.count({
      where: {
        institution_id: institutionId,
        status: 'Completed',
        session_type: 'Onsite'
      },
      include: [{
        model: Child,
        where: { parent_id: parentId }
      }]
    });

    if (visitCount < 1) {
      return res.status(400).json({
        success: false,
        message: 'يجب أن يكون لديك زيارات سابقة للمؤسسة لتقييمها'
      });
    }

    // 3. التحقق إذا سبق التقييم
    const existingReview = await InstitutionReview.findOne({
      where: {
        institution_id: institutionId,
        parent_id: parentId
      }
    });

    let review;
    if (existingReview) {
      // تحديث المراجعة الحالية
      review = await existingReview.update({
        facilities_rating,
        staff_rating,
        cleanliness_rating,
        accessibility_rating,
        review_text: review_text || existingReview.review_text,
        would_recommend,
        based_on_visits: visitCount,
        updated_at: new Date()
      });
    } else {
      // إضافة مراجعة جديدة
      review = await InstitutionReview.create({
        parent_id: parentId,
        institution_id: institutionId,
        facilities_rating,
        staff_rating,
        cleanliness_rating,
        accessibility_rating,
        review_text,
        would_recommend,
        based_on_visits: visitCount
      });
    }

    // 4. تحديث متوسط تقييم المؤسسة
    await updateInstitutionAverageRating(institutionId);

    res.status(existingReview ? 200 : 201).json({
      success: true,
      message: existingReview ? 'تم تحديث مراجعتك' : 'تم إضافة المراجعة بنجاح',
      data: review
    });

  } catch (error) {
    console.error('❌ Error adding institution review:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في إضافة المراجعة',
      error: error.message
    });
  }
};

/**
 * جلب مراجعات مؤسسة معينة
 */
const getInstitutionReviews = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const { page = 1, limit = 10, sort = 'newest' } = req.query;
    const offset = (page - 1) * limit;

    const order = sort === 'highest' 
      ? [['overall_rating', 'DESC']] 
      : [['created_at', 'DESC']];

    const { rows: reviews, count } = await InstitutionReview.findAndCountAll({
      where: { institution_id: institutionId },
      include: [{
        model: require('../model/User'),
        as: 'parent',
        attributes: ['full_name', 'profile_picture']
      }],
      order: order,
      limit: parseInt(limit),
      offset: offset
    });

    // حساب الإحصائيات
    const stats = await InstitutionReview.findOne({
      where: { institution_id: institutionId },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('overall_rating')), 'average_rating'],
        [sequelize.fn('COUNT', sequelize.col('institution_review_id')), 'total_reviews'],
        [sequelize.fn('SUM', sequelize.literal('CASE WHEN would_recommend = true THEN 1 ELSE 0 END')), 'recommendations'],
        [sequelize.fn('AVG', sequelize.col('facilities_rating')), 'avg_facilities'],
        [sequelize.fn('AVG', sequelize.col('staff_rating')), 'avg_staff'],
        [sequelize.fn('AVG', sequelize.col('cleanliness_rating')), 'avg_cleanliness'],
        [sequelize.fn('AVG', sequelize.col('accessibility_rating')), 'avg_accessibility']
      ],
      raw: true
    });

    res.json({
      success: true,
      data: {
        reviews: reviews.map(r => ({
          id: r.institution_review_id,
          overall_rating: r.overall_rating,
          facilities_rating: r.facilities_rating,
          staff_rating: r.staff_rating,
          cleanliness_rating: r.cleanliness_rating,
          accessibility_rating: r.accessibility_rating,
          review_text: r.review_text,
          would_recommend: r.would_recommend,
          based_on_visits: r.based_on_visits,
          date: r.created_at,
          parent_name: r.parent.full_name
        })),
        statistics: {
          average_rating: parseFloat(stats.average_rating || 0).toFixed(1),
          total_reviews: parseInt(stats.total_reviews || 0),
          recommendation_rate: stats.total_reviews ? 
            Math.round((parseInt(stats.recommendations || 0) / parseInt(stats.total_reviews)) * 100) : 0,
          category_averages: {
            facilities: parseFloat(stats.avg_facilities || 0).toFixed(1),
            staff: parseFloat(stats.avg_staff || 0).toFixed(1),
            cleanliness: parseFloat(stats.avg_cleanliness || 0).toFixed(1),
            accessibility: parseFloat(stats.avg_accessibility || 0).toFixed(1)
          }
        },
        pagination: {
          current_page: parseInt(page),
          total_pages: Math.ceil(count / limit),
          total_reviews: count
        }
      }
    });

  } catch (error) {
    console.error('Error getting institution reviews:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب المراجعات'
    });
  }
};

/**
 * جلب مراجعاتي للمؤسسات
 */
const getMyInstitutionReviews = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;

    const { rows: reviews, count } = await InstitutionReview.findAndCountAll({
      where: { parent_id: parentId },
      include: [{
        model: Institution,
        attributes: ['name', 'logo']
      }],
      order: [['created_at', 'DESC']],
      limit: parseInt(limit),
      offset: offset
    });

    res.json({
      success: true,
      data: reviews,
      count: count,
      pagination: {
        current_page: parseInt(page),
        total_pages: Math.ceil(count / limit)
      }
    });

  } catch (error) {
    console.error('Error getting my institution reviews:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب مراجعاتك'
    });
  }
};

/**
 * تحديث متوسط تقييم المؤسسة
 */
const updateInstitutionAverageRating = async (institutionId) => {
  try {
    const stats = await InstitutionReview.findOne({
      where: { institution_id: institutionId },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('overall_rating')), 'avg_rating'],
        [sequelize.fn('COUNT', sequelize.col('institution_review_id')), 'total_reviews']
      ],
      raw: true
    });

    await Institution.update({
      average_rating: parseFloat(stats.avg_rating || 0).toFixed(1),
      total_reviews: parseInt(stats.total_reviews || 0),
      last_review_update: new Date()
    }, {
      where: { institution_id: institutionId }
    });

  } catch (error) {
    console.error('Error updating institution average:', error);
  }
};

module.exports = {
  addInstitutionReview,
  getInstitutionReviews,
  getMyInstitutionReviews
};