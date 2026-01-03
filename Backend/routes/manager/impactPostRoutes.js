const express = require('express');
const router = express.Router();

const authMiddleware = require('../../middleware/authMiddleware');
const impactPostsController = require('../../controllers/manager/impactPostsController');

const isManager = (req, res, next) => {
  if (req.user.role !== 'Manager') {
    return res.status(403).json({
      success: false,
      message: 'غير مصرح - يجب أن تكون مدير مؤسسة',
    });
  }
  next();
};

router.use(authMiddleware);
router.use(isManager);

router.get('/posts', impactPostsController.listImpactPosts);
router.post('/posts', impactPostsController.createImpactPost);
router.put('/posts/:postId', impactPostsController.updateImpactPost);
router.delete('/posts/:postId', impactPostsController.deleteImpactPost);

module.exports = router;
