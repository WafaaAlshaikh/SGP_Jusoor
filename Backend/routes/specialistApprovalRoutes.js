// routes/specialistApprovalRoutes.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const specialistApprovalController = require('../controllers/specialistApprovalController');

// تحقق من أن المستخدم أخصائي
const specialistOnly = (req, res, next) => {
  if (req.user.role !== 'Specialist') {
    return res.status(403).json({ message: 'Access denied. Specialists only.' });
  }
  next();
};

// موافقة/رفض الجلسات
router.patch('/sessions/:sessionId/approve', authMiddleware, specialistOnly, specialistApprovalController.approveSession);
router.patch('/sessions/:sessionId/reject', authMiddleware, specialistOnly, specialistApprovalController.rejectSession);

// جلب جلسات بانتظار الموافقة
router.get('/pending-sessions', authMiddleware, specialistOnly, async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    
    const pendingSessions = await require('../model/Session').findAll({
      where: { 
        specialist_id: specialistId,
        status: 'Pending Approval'
      },
      include: [
        {
          model: require('../model/Child'),
          as: 'child',
          attributes: ['full_name']
        },
        {
          model: require('../model/SessionType'),
          attributes: ['name', 'duration', 'price']
        }
      ]
    });

    res.json({
      success: true,
      data: pendingSessions
    });
  } catch (error) {
    console.error('Error fetching pending sessions:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to fetch pending sessions' 
    });
  }
});

module.exports = router;