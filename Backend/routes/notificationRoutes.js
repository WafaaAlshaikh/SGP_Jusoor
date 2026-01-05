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

module.exports = router;