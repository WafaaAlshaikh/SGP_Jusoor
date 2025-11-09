// routes/paymentRoutes.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const paymentController = require('../controllers/paymentController');

// ⬇️ استخدم middleware المصادقة مرة واحدة فقط
router.use(authMiddleware);

// فواتير ولي الأمر
router.get('/invoices', paymentController.getParentInvoices);
router.get('/invoices/:invoiceId', paymentController.getInvoiceDetails);

// عمليات الدفع
router.get('/payment-methods', paymentController.getPaymentMethods);
router.get('/bank-details', paymentController.getBankDetails);
router.post('/create-card-token', paymentController.createCardToken);
router.post('/process-payment', paymentController.processPayment);
router.post('/refund/:sessionId', paymentController.processRefund);
router.get('/payment-history', paymentController.getPaymentHistory);
router.post('/create-checkout-session', paymentController.createCheckoutSession);

module.exports = router;