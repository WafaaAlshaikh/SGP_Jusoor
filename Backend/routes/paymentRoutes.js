// routes/paymentRoutes.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const paymentController = require('../controllers/paymentController');
const invoiceController = require('../controllers/invoiceController');

// ⬇️ استخدم middleware المصادقة مرة واحدة فقط
router.use(authMiddleware);

// فواتير ولي الأمر
router.get('/invoices', paymentController.getParentInvoices);
router.get('/invoices/:invoiceId', paymentController.getInvoiceDetails);
router.get('/child-invoices/:childId', invoiceController.getChildInvoices);

// عمليات الدفع
router.get('/payment-methods', paymentController.getPaymentMethods);
router.get('/bank-details', paymentController.getBankDetails);
router.post('/create-card-token', paymentController.createCardToken);
router.post('/process-payment', paymentController.processPayment);
router.post('/refund/:sessionId', paymentController.processRefund);
router.get('/payment-history', paymentController.getPaymentHistory);
router.post('/create-checkout-session', paymentController.createCheckoutSession);
router.post('/session/:sessionId/process-payment', paymentController.processPayment);
router.post('/success', paymentController.processPaymentSuccess);
module.exports = router;