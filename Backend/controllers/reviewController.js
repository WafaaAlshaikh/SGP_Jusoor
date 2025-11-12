const Review = require('../model/Review');
const ReviewHelpful = require('../model/ReviewHelpful');
const sequelize = require('../config/db');

// Get all reviews for an institution
exports.getInstitutionReviews = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const { sort = 'recent', limit = 20, offset = 0 } = req.query;

    let orderClause;
    switch (sort) {
      case 'helpful':
        orderClause = [['helpful_count', 'DESC']];
        break;
      case 'rating_high':
        orderClause = [['rating', 'DESC']];
        break;
      case 'rating_low':
        orderClause = [['rating', 'ASC']];
        break;
      case 'recent':
      default:
        orderClause = [['created_at', 'DESC']];
    }

    const reviews = await sequelize.query(`
      SELECT 
        r.review_id,
        r.rating,
        r.title,
        r.comment,
        r.staff_rating,
        r.facilities_rating,
        r.services_rating,
        r.value_rating,
        r.helpful_count,
        r.not_helpful_count,
        r.images,
        r.verified_visit,
        r.created_at,
        u.full_name as user_name,
        u.profile_picture as user_avatar
      FROM Reviews r
      JOIN Users u ON r.user_id = u.user_id
      WHERE r.institution_id = ? AND r.status = 'approved'
      ORDER BY ${sort === 'helpful' ? 'r.helpful_count DESC' : sort === 'rating_high' ? 'r.rating DESC' : sort === 'rating_low' ? 'r.rating ASC' : 'r.created_at DESC'}
      LIMIT ? OFFSET ?
    `, {
      replacements: [parseInt(institutionId), parseInt(limit), parseInt(offset)],
      type: sequelize.QueryTypes.SELECT
    });

    // Get rating statistics
    const stats = await sequelize.query(`
      SELECT 
        COUNT(*) as total_reviews,
        AVG(rating) as average_rating,
        AVG(staff_rating) as avg_staff,
        AVG(facilities_rating) as avg_facilities,
        AVG(services_rating) as avg_services,
        AVG(value_rating) as avg_value,
        SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as five_star,
        SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as four_star,
        SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as three_star,
        SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as two_star,
        SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as one_star
      FROM Reviews
      WHERE institution_id = ? AND status = 'approved'
    `, {
      replacements: [parseInt(institutionId)],
      type: sequelize.QueryTypes.SELECT
    });

    res.status(200).json({
      success: true,
      reviews,
      statistics: stats[0],
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        total: parseInt(stats[0].total_reviews)
      }
    });
  } catch (error) {
    console.error('Error fetching reviews:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Create a new review
exports.createReview = async (req, res) => {
  try {
    const userId = req.user.user_id; // ✅ تغيير من userId إلى user_id
    const { institutionId } = req.params;
    const {
      rating,
      title,
      comment,
      staff_rating,
      facilities_rating,
      services_rating,
      value_rating,
      images
    } = req.body;

    // Validation
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be between 1 and 5'
      });
    }

    // Check if user already reviewed this institution
    const existingReview = await Review.findOne({
      where: {
        institution_id: institutionId,
        user_id: userId
      }
    });

    if (existingReview) {
      return res.status(400).json({
        success: false,
        message: 'You have already reviewed this institution. You can update your existing review.'
      });
    }

    // Check if user had a session at this institution (for verified badge)
    const hasSession = await sequelize.query(`
      SELECT COUNT(*) as count
      FROM Sessions s
      JOIN Children c ON s.child_id = c.child_id
      WHERE c.parent_id = ? AND c.current_institution_id = ?
    `, {
      replacements: [userId, institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    const verifiedVisit = hasSession[0].count > 0;

    // Create review
    const newReview = await Review.create({
      institution_id: institutionId,
      user_id: userId,
      rating,
      title,
      comment,
      staff_rating,
      facilities_rating,
      services_rating,
      value_rating,
      images: images ? JSON.stringify(images) : null,
      verified_visit: verifiedVisit,
      status: 'approved' // Auto-approve for now
    });

    // Update institution average rating
    await updateInstitutionRating(institutionId);

    res.status(201).json({
      success: true,
      message: 'Review created successfully',
      review: newReview
    });
  } catch (error) {
    console.error('Error creating review:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Update a review
exports.updateReview = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { reviewId } = req.params;
    const {
      rating,
      title,
      comment,
      staff_rating,
      facilities_rating,
      services_rating,
      value_rating,
      images
    } = req.body;

    const review = await Review.findOne({
      where: { review_id: reviewId, user_id: userId }
    });

    if (!review) {
      return res.status(404).json({
        success: false,
        message: 'Review not found or you do not have permission to update it'
      });
    }

    await review.update({
      rating: rating || review.rating,
      title: title !== undefined ? title : review.title,
      comment: comment !== undefined ? comment : review.comment,
      staff_rating: staff_rating !== undefined ? staff_rating : review.staff_rating,
      facilities_rating: facilities_rating !== undefined ? facilities_rating : review.facilities_rating,
      services_rating: services_rating !== undefined ? services_rating : review.services_rating,
      value_rating: value_rating !== undefined ? value_rating : review.value_rating,
      images: images ? JSON.stringify(images) : review.images,
      updated_at: new Date()
    });

    // Update institution average rating
    await updateInstitutionRating(review.institution_id);

    res.status(200).json({
      success: true,
      message: 'Review updated successfully',
      review
    });
  } catch (error) {
    console.error('Error updating review:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Delete a review
exports.deleteReview = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { reviewId } = req.params;

    const review = await Review.findOne({
      where: { review_id: reviewId, user_id: userId }
    });

    if (!review) {
      return res.status(404).json({
        success: false,
        message: 'Review not found or you do not have permission to delete it'
      });
    }

    const institutionId = review.institution_id;
    await review.destroy();

    // Update institution average rating
    await updateInstitutionRating(institutionId);

    res.status(200).json({
      success: true,
      message: 'Review deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting review:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Mark review as helpful/not helpful
exports.markReviewHelpful = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { reviewId } = req.params;
    const { isHelpful } = req.body;

    // Check if already voted
    const existingVote = await ReviewHelpful.findOne({
      where: { review_id: reviewId, user_id: userId }
    });

    if (existingVote) {
      // Update vote
      await existingVote.update({ is_helpful: isHelpful });
    } else {
      // Create new vote
      await ReviewHelpful.create({
        review_id: reviewId,
        user_id: userId,
        is_helpful: isHelpful
      });
    }

    // Update helpful counts
    const helpfulCount = await ReviewHelpful.count({
      where: { review_id: reviewId, is_helpful: true }
    });
    const notHelpfulCount = await ReviewHelpful.count({
      where: { review_id: reviewId, is_helpful: false }
    });

    await Review.update(
      {
        helpful_count: helpfulCount,
        not_helpful_count: notHelpfulCount
      },
      { where: { review_id: reviewId } }
    );

    res.status(200).json({
      success: true,
      message: 'Vote recorded successfully',
      helpful_count: helpfulCount,
      not_helpful_count: notHelpfulCount
    });
  } catch (error) {
    console.error('Error marking review helpful:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// Helper function to update institution rating
async function updateInstitutionRating(institutionId) {
  try {
    const stats = await sequelize.query(`
      SELECT AVG(rating) as avg_rating, COUNT(*) as review_count
      FROM Reviews
      WHERE institution_id = ? AND status = 'approved'
    `, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    if (stats[0]) {
      await sequelize.query(`
        UPDATE Institutions
        SET rating = ?, review_count = ?
        WHERE institution_id = ?
      `, {
        replacements: [
          parseFloat(stats[0].avg_rating || 0).toFixed(1),
          parseInt(stats[0].review_count || 0),
          institutionId
        ]
      });
    }
  } catch (error) {
    console.error('Error updating institution rating:', error);
  }
}

module.exports = exports;
