const express = require('express');
const router = express.Router();

const multer = require('multer');
const path = require('path');
const fs = require('fs');

const authMiddleware = require('../../middleware/authMiddleware');
const impactPostsController = require('../../controllers/manager/impactPostsController');
const { Manager, Institution } = require('../../model');

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

const resolveManagerInstitutionId = async (req, res, next) => {
  try {
    const managerId = req.user.user_id;
    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true },
      include: [{ model: Institution, attributes: ['institution_id'] }],
    });
    req.institutionId = manager?.Institution?.institution_id || null;
    return next();
  } catch (error) {
    console.error('resolveManagerInstitutionId error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

const impactMediaStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    try {
      const institutionId = req.institutionId || 'temp';
      const uploadDir = path.join(__dirname, '../../uploads/impact', String(institutionId));
      fs.mkdirSync(uploadDir, { recursive: true });
      cb(null, uploadDir);
    } catch (error) {
      cb(error);
    }
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname);
    cb(null, `impact-${uniqueSuffix}${ext}`);
  },
});

const impactMediaFileFilter = (req, file, cb) => {
  const allowed = [
    'image/jpeg',
    'image/png',
    'image/jpg',
    'image/gif',
    'video/mp4',
    'video/quicktime',
    'video/x-matroska',
    'video/webm',
  ];
  if (allowed.includes(file.mimetype)) return cb(null, true);
  return cb(new Error('Unsupported file type. Only images and videos are allowed.'), false);
};

const uploadImpactMedia = multer({
  storage: impactMediaStorage,
  fileFilter: impactMediaFileFilter,
  limits: {
    fileSize: 50 * 1024 * 1024,
    files: 1,
  },
});

router.get('/posts', impactPostsController.listImpactPosts);
router.post('/posts', resolveManagerInstitutionId, uploadImpactMedia.single('media'), impactPostsController.createImpactPost);
router.put('/posts/:postId', resolveManagerInstitutionId, uploadImpactMedia.single('media'), impactPostsController.updateImpactPost);
router.delete('/posts/:postId', impactPostsController.deleteImpactPost);

module.exports = router;
