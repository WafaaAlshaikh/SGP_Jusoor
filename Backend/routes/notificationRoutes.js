const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const notificationController = require('../controllers/notificationController');

// جميع المسارات تتطلب مصادقة
router.use(authMiddleware);

// 1. إرسال إشعار تجريبي (للتأكد من أن النظام شغال)
router.post('/test', notificationController.sendTestNotification);

// 2. إرسال إشعار إضافة طفل للأهل
router.post('/child-added', notificationController.sendChildNotification);

// 3. إرسال إشعار حجز حصة للأخصائي
router.post('/session-booked', notificationController.sendSessionNotification);

router.post('/simple-test', notificationController.sendSimpleTest);

// 5. إرسال إشعار للمدير
router.post('/manager', notificationController.sendManagerNotification);

// 6. إرسال إشعار موافقة على طفل للمدير
router.post('/child-approval', notificationController.sendChildApprovalNotification);

module.exports = router;