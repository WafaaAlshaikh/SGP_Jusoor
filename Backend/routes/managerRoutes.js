const express = require('express');
const router = express.Router();
const managerController = require('../controllers/managerController');
const authMiddleware = require('../middleware/authMiddleware');

// 🔒 السماح فقط للمديرين
const managerOnly = (req, res, next) => {
  if (req.user.role !== 'Manager') {
    return res.status(403).json({ message: 'Access denied' });
  }
  next();
};

// ✅ جلب أنواع الجلسات المعلقة للموافقة
router.get(
  '/pending-session-types',
  authMiddleware,
  managerOnly,
  managerController.getPendingSessionTypes
);

// ✅ الموافقة على نوع جلسة
router.post(
  '/approve-session-type/:session_type_id',
  authMiddleware,
  managerOnly,
  managerController.approveSessionType
);

// ✅ رفض نوع جلسة
router.post(
  '/reject-session-type/:session_type_id',
  authMiddleware,
  managerOnly,
  managerController.rejectSessionType
);

module.exports = router;

