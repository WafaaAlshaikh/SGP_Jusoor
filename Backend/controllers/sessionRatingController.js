// controllers/sessionRatingController.js
const SessionRating = require('../model/SessionRating');
const Session = require('../model/Session');
const Child = require('../model/Child');
const Notification = require('../model/Notification');
const { Op } = require('sequelize');
const sequelize = require("../config/db");


/**
 * تقييم جلسة معينة
 */
// في sessionRatingController.js - دالة rateSession
const rateSession = async (req, res) => {
  try {
    const { sessionId } = req.params;
    const parentId = req.user.user_id;
    const { rating, comment, rating_tag } = req.body;

    console.log('⭐ Rating session:', { sessionId, parentId, rating });

    // الجلسة متاحة بالفعل في req.session (من middleware)
    const session = req.session;

    // حفظ التقييم
    const newRating = await SessionRating.create({
      session_id: sessionId,
      parent_id: parentId,
      specialist_id: session.specialist_id,
      child_id: session.child_id,
      rating: rating,
      rating_tag: rating_tag || getRatingTag(rating),
      comment: comment || null,
      session_type: session.session_type,
      rated_at: new Date()
    });

    // تحديث متوسط تقييم الأخصائي
    await updateSpecialistAverageRating(session.specialist_id);

    // إشعار للأخصائي
    if (rating >= 4) {
      await Notification.create({
        user_id: session.specialist_id,
        title: 'تقييم جديد ممتاز',
        message: `حصلت على تقييم ${rating} نجوم من أحد أولياء الأمور`,
        type: 'rating_received',
        related_id: sessionId,
        is_read: false
      });
    }

    res.status(201).json({
      success: true,
      message: 'تم تقييم الجلسة بنجاح',
      data: newRating
    });

  } catch (error) {
    console.error('❌ Error rating session:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في تقييم الجلسة',
      error: error.message
    });
  }
};

/**
 * جلب تقييمات جلسة معينة
 */
const getSessionRatings = async (req, res) => {
  try {
    const { sessionId } = req.params;

    const ratings = await SessionRating.findAll({
      where: { session_id: sessionId },
      include: [
        {
          model: require('../model/User'),
          as: 'parent',
          attributes: ['full_name', 'profile_picture']
        }
      ],
      order: [['rated_at', 'DESC']]
    });

    res.json({
      success: true,
      data: ratings,
      count: ratings.length
    });

  } catch (error) {
    console.error('Error getting session ratings:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب التقييمات'
    });
  }
};

/**
 * جلب تقييمات أخصائي معين
 */
const getSpecialistRatings = async (req, res) => {
  try {
    const { specialistId } = req.params;
    const { page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;

    const { rows: ratings, count } = await SessionRating.findAndCountAll({
      where: { specialist_id: specialistId },
      include: [
        {
          model: require('../model/User'),
          as: 'parent',
          attributes: ['full_name', 'profile_picture']
        },
        {
          model: Session,
          attributes: ['date', 'session_type'],
          include: [{
            model: Child,
            as: 'child',  // ✅ تحديد alias
            attributes: ['full_name']
          }]
        }
      ],
      order: [['rated_at', 'DESC']],
      limit: parseInt(limit),
      offset: offset
    });

    // حساب الإحصائيات
    const stats = await SessionRating.findOne({
      where: { specialist_id: specialistId },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('rating')), 'average_rating'],
        [sequelize.fn('COUNT', sequelize.col('session_rating_id')), 'total_ratings'],
        [sequelize.fn('SUM', sequelize.literal('CASE WHEN rating = 5 THEN 1 ELSE 0 END')), 'five_star'],
        [sequelize.fn('SUM', sequelize.literal('CASE WHEN rating = 1 THEN 1 ELSE 0 END')), 'one_star']
      ],
      raw: true
    });

    res.json({
      success: true,
      data: {
        ratings: ratings.map(r => ({
          id: r.session_rating_id,
          rating: r.rating,
          rating_tag: r.rating_tag,
          comment: r.comment,
          date: r.rated_at,
          parent_name: r.parent.full_name,
          session_date: r.Session.date,
          session_type: r.Session.session_type
        })),
        statistics: {
          average_rating: parseFloat(stats.average_rating || 0).toFixed(1),
          total_ratings: parseInt(stats.total_ratings || 0),
          five_star_count: parseInt(stats.five_star || 0),
          one_star_count: parseInt(stats.one_star || 0),
          distribution: await getRatingDistribution(specialistId)
        },
        pagination: {
          current_page: parseInt(page),
          total_pages: Math.ceil(count / limit),
          total_items: count
        }
      }
    });

  } catch (error) {
    console.error('Error getting specialist ratings:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب تقييمات الأخصائي'
    });
  }
};

/**
 * جلب تقييماتي (للأهل)
 */
const getMyRatings = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;

    const { rows: ratings, count } = await SessionRating.findAndCountAll({
      where: { parent_id: parentId },
      include: [
        {
          model: require('../model/User'),
          as: 'specialist',
          attributes: ['full_name', 'profile_picture']
        },
        {
          model: Session,
          attributes: ['date', 'session_type'],
          include: [{
            model: Child,
            as: 'child',  // ✅ تحديد alias واضح
            attributes: ['full_name', 'child_id']
          }]
        }
      ],
      order: [['rated_at', 'DESC']],
      limit: parseInt(limit),
      offset: offset
    });

    res.json({
      success: true,
      data: ratings.map(rating => ({
        id: rating.session_rating_id,
        rating: rating.rating,
        rating_tag: rating.rating_tag,
        comment: rating.comment,
        rated_at: rating.rated_at,
        session_type: rating.session_type,
        specialist_name: rating.specialist?.full_name || 'غير معروف',
        specialist_avatar: rating.specialist?.profile_picture,
        session_date: rating.Session?.date,
        child_name: rating.Session?.child?.full_name,
        child_id: rating.Session?.child?.child_id
      })),
      count: count,
      pagination: {
        current_page: parseInt(page),
        total_pages: Math.ceil(count / limit)
      }
    });

  } catch (error) {
    console.error('Error getting my ratings:', error);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب تقييماتك',
      error: error.message
    });
  }
};

/**
 * تحديث متوسط تقييم الأخصائي
 */
const updateSpecialistAverageRating = async (specialistId) => {
  try {
    const stats = await SessionRating.findOne({
      where: { specialist_id: specialistId },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('rating')), 'avg_rating'],
        [sequelize.fn('COUNT', sequelize.col('session_rating_id')), 'total_ratings']
      ],
      raw: true
    });

    const Specialist = require('../model/Specialist');
    await Specialist.update({
      average_rating: parseFloat(stats.avg_rating || 0).toFixed(1),
      total_ratings: parseInt(stats.total_ratings || 0),
      last_rating_update: new Date()
    }, {
      where: { specialist_id: specialistId }
    });

  } catch (error) {
    console.error('Error updating specialist average:', error);
  }
};

/**
 * جلب توزيع التقييمات
 */
const getRatingDistribution = async (specialistId) => {
  const distribution = {};
  for (let i = 1; i <= 5; i++) {
    const count = await SessionRating.count({
      where: { 
        specialist_id: specialistId,
        rating: i 
      }
    });
    distribution[i] = count;
  }
  return distribution;
};

/**
 * تحويل الرقم إلى تاج
 */
const getRatingTag = (rating) => {
  const tags = {
    1: 'سيء',
    2: 'مقبول',
    3: 'جيد',
    4: 'جيد جداً',
    5: 'ممتاز'
  };
  return tags[rating] || 'جيد';
};

module.exports = {
  rateSession,
  getSessionRatings,
  getSpecialistRatings,
  getMyRatings
};