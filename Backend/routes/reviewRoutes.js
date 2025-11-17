const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const reviewController = require('../controllers/reviewController');

// Get reviews for an institution
router.get('/institution/:institutionId', reviewController.getInstitutionReviews);

// Create a review (requires authentication)
router.post('/institution/:institutionId', authMiddleware, reviewController.createReview);

// Update a review (requires authentication)
router.put('/:reviewId', authMiddleware, reviewController.updateReview);

// Delete a review (requires authentication)
router.delete('/:reviewId', authMiddleware, reviewController.deleteReview);

// Mark review as helpful (requires authentication)
router.post('/:reviewId/helpful', authMiddleware, reviewController.markReviewHelpful);

module.exports = router;
