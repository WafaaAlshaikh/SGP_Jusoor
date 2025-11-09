// controllers/paymentController.js
const Payment = require('../model/Payment');
const Invoice = require('../model/Invoice');
const Session = require('../model/Session');
const PaymentGateway = require('../services/paymentGateway');
const { Op } = require('sequelize');
const Stripe = require('stripe');
require('dotenv').config();
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);


exports.processPayment = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { invoice_id, payment_method, card_token, payment_details } = req.body;

    console.log(`💳 Processing payment: invoice_id=${invoice_id}, parent_id=${parentId}, method=${payment_method}`);

    // أولاً: تحقق من وجود الفاتورة بدون شروط
    const invoiceCheck = await Invoice.findByPk(invoice_id);
    
    if (!invoiceCheck) {
      console.log(`❌ Invoice ${invoice_id} not found in database`);
      return res.status(404).json({ 
        success: false, 
        message: `Invoice ${invoice_id} does not exist` 
      });
    }

    console.log(`📄 Invoice found: id=${invoiceCheck.invoice_id}, status=${invoiceCheck.status}, parent_id=${invoiceCheck.parent_id}`);

    // ثانياً: تحقق من الحالة
    if (invoiceCheck.status === 'Paid') {
      console.log(`⚠️ Invoice ${invoice_id} is already paid`);
      return res.status(400).json({ 
        success: false, 
        message: 'Invoice is already paid' 
      });
    }

    // ثالثاً: تحقق من parent_id
    if (invoiceCheck.parent_id !== parentId) {
      console.log(`❌ Parent ID mismatch: invoice.parent_id=${invoiceCheck.parent_id}, user.parent_id=${parentId}`);
      return res.status(403).json({ 
        success: false, 
        message: 'You do not have permission to pay this invoice' 
      });
    }

    // الآن جلب الفاتورة مع Session
    const invoice = await Invoice.findOne({
      where: {
        invoice_id,
        parent_id: parentId,
        status: { [Op.in]: ['Pending', 'Overdue', 'Draft'] } // ⬅️ إضافة Draft
      },
      include: [{
        model: Session,
        attributes: ['session_id', 'status', 'date', 'time']
      }],
      raw: true,
      nest: true
    });

    if (!invoice) {
      console.log(`❌ Invoice ${invoice_id} cannot be paid (status: ${invoiceCheck.status})`);
      return res.status(400).json({ 
        success: false, 
        message: `Invoice cannot be paid (current status: ${invoiceCheck.status})` 
      });
    }

    console.log(`✅ Invoice ready for payment: ${invoice_id}`);

    // تطبيع اسم طريقة الدفع (تقبل underscore أو مسافات)
    const normalizedPaymentMethod = payment_method
      .replace(/_/g, ' ')  // استبدال underscore بمسافة
      .split(' ')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(' ');

    console.log(`💡 Payment method normalized: "${payment_method}" → "${normalizedPaymentMethod}"`);

    let paymentResult;

    switch (normalizedPaymentMethod) {
      case 'Credit Card':
        // استخدام PaymentGateway Test Mode
        paymentResult = await PaymentGateway.processTestCreditCardPayment(invoice.total_amount, {
          card_number: payment_details?.card_number || '4242424242424242', // default test card
          card_holder: payment_details?.card_holder || 'Test User',
          session_id: invoice.session_id,
          parent_id: parentId
        });
        // تحويل الرد لصيغة متوافقة
        if (paymentResult.success) {
          paymentResult.gateway = 'Demo Mode'; // ⬅️ اختصار للحفظ في قاعدة البيانات
          paymentResult.transactionId = paymentResult.transaction_id;
          paymentResult.cleanMethod = 'Credit Card'; // ⬅️ القيمة النظيفة للـ ENUM
        }
        break;
      case 'Cash':
        paymentResult = await PaymentGateway.processCashPayment(invoice.total_amount, {
          session_id: invoice.session_id,
          parent_id: parentId
        });
        if (paymentResult.success) {
          paymentResult.gateway = 'Cash';
          paymentResult.transactionId = paymentResult.transaction_id;
          paymentResult.cleanMethod = 'Cash'; // ⬅️ القيمة النظيفة للـ ENUM
        }
        break;
      case 'Bank Transfer':
        paymentResult = await PaymentGateway.processBankTransferPayment(invoice.total_amount, {
          bank_name: payment_details?.bank_name,
          account_number: payment_details?.account_number,
          reference_number: payment_details?.reference_number,
          session_id: invoice.session_id,
          parent_id: parentId
        });
        if (paymentResult.success) {
          paymentResult.gateway = 'Bank';
          paymentResult.transactionId = paymentResult.transaction_id;
          paymentResult.cleanMethod = 'Bank Transfer'; // ⬅️ القيمة النظيفة للـ ENUM
        }
        break;
      default:
        return res.status(400).json({ 
          success: false, 
          message: `Invalid payment method: ${payment_method}. Use: cash, credit_card, or bank_transfer`,
          received: payment_method,
          normalized: normalizedPaymentMethod
        });
    }

    if (paymentResult.success) {
      const payment = await Payment.create({
        invoice_id: invoice.invoice_id,
        amount: invoice.total_amount,
        payment_method: paymentResult.cleanMethod || normalizedPaymentMethod, // ⬅️ استخدام cleanMethod
        payment_gateway: paymentResult.gateway,
        transaction_id: paymentResult.transactionId,
        status: 'Completed',
        gateway_response: JSON.stringify(paymentResult),
        payment_date: new Date()
      });

      await Invoice.update({
        status: 'Paid',
        paid_date: new Date()
      }, { where: { invoice_id: invoice.invoice_id } });

      if (invoice.Session && invoice.Session.status === 'Pending Payment') {
        await Session.update({ status: 'Confirmed' }, { where: { session_id: invoice.session_id } });
      }

      return res.status(200).json({
        success: true,
        message: 'Payment processed successfully',
        data: {
          payment_id: payment.payment_id,
          transaction_id: payment.transaction_id,
          amount: payment.amount,
          payment_date: payment.payment_date,
          session_status: 'Confirmed'
        }
      });
    } else {
      await Payment.create({
        invoice_id: invoice.invoice_id,
        amount: invoice.total_amount,
        payment_method: paymentResult.cleanMethod || normalizedPaymentMethod, // ⬅️ استخدام cleanMethod
        status: 'Failed',
        gateway_response: JSON.stringify(paymentResult),
        payment_date: new Date()
      });

      return res.status(400).json({ success: false, message: 'Payment failed', error: paymentResult.error });
    }

  } catch (error) {
    return res.status(500).json({ success: false, message: 'Payment processing failed', error: error.message });
  }
};

// 🟢 Stripe Payment
const processCreditCardPayment = async ({ amount, card_token, invoice_number }) => {
  try {
    const amountInCents = Math.round(amount * 100);
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInCents,
      currency: 'usd',
      payment_method: card_token,
      confirm: true,
      description: `Payment for invoice ${invoice_number}`
    });

    return {
      success: true,
      gateway: 'Stripe',
      transactionId: paymentIntent.id,
      message: 'Credit card payment processed successfully',
      authorization_code: paymentIntent.charges.data[0]?.id || null
    };
  } catch (error) {
    return { success: false, error: error.raw?.message || error.message, gateway: 'Stripe' };
  }
};

// 🟢 Cash Payment
const processCashPayment = async (paymentData) => {
  await new Promise(resolve => setTimeout(resolve, 1000));
  return {
    success: true,
    gateway: 'Cash Payment',
    transactionId: `CASH-${Date.now()}`,
    message: 'Cash payment registered. Please pay at the institution before the session.'
  };
};

// 🟢 Bank Transfer Payment
const processBankTransferPayment = async (paymentData) => {
  await new Promise(resolve => setTimeout(resolve, 1500));
  return {
    success: true,
    gateway: 'Bank Transfer',
    transactionId: `BANK-${Date.now()}`,
    message: 'Bank transfer initiated. Session will be confirmed once transfer is verified.',
    bank_details: {
      bank_name: 'Example Bank',
      account_name: 'Therapy Center LLC',
      account_number: '123456789',
      iban: `INV-${paymentData.invoice_number}`
    }
  };
};

// 🏦 الحصول على تفاصيل التحويل البنكي
exports.getBankDetails = async (req, res) => {
  try {
    const bankDetails = {
      bank_name: 'Jordan Islamic Bank',
      branch: 'Khalda Branch',
      account_name: 'Hope Therapy Center',
      account_number: '0123456789012',
      iban: 'JO15JIBA0000000000123456789012',
      swift_code: 'JIBAJOAM',
      currency: 'JOD'
    };

    res.status(200).json({
      success: true,
      data: bankDetails
    });
  } catch (error) {
    console.error('Error fetching bank details:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch bank details',
      error: error.message
    });
  }
};

// 📋 طرق الدفع المتاحة
exports.getPaymentMethods = async (req, res) => {
  try {
    const { invoice_id } = req.query;
    
    let invoiceAmount = 0;
    if (invoice_id) {
      const invoice = await Invoice.findOne({
        where: { invoice_id },
        attributes: ['total_amount']
      });
      invoiceAmount = invoice ? invoice.total_amount : 0;
    }

    const paymentMethods = [
      {
        id: 'credit_card',
        name: 'Credit/Debit Card',
        description: 'Pay securely with your credit or debit card',
        icon: 'credit_card',
        supported_cards: ['visa', 'mastercard', 'amex'],
        processing_fee: 0.02, // 2%
        estimated_total: invoiceAmount * 1.02,
        available: true,
        features: ['Instant confirmation', 'Secure payment', 'Digital receipt']
      },
      {
        id: 'cash',
        name: 'Cash Payment',
        description: 'Pay in cash at the institution reception',
        icon: 'payments',
        requires_physical_presence: true,
        processing_fee: 0,
        estimated_total: invoiceAmount,
        available: true,
        features: ['No extra fees', 'Pay at your convenience', 'Get physical receipt'],
        instructions: 'Visit the institution before your session to complete payment'
      },
      {
        id: 'bank_transfer',
        name: 'Bank Transfer',
        description: 'Transfer directly to our bank account',
        icon: 'account_balance',
        processing_fee: 0,
        estimated_total: invoiceAmount,
        available: true,
        features: ['Bank-level security', 'No extra fees', 'Electronic record'],
        verification_time: '24-48 hours'
      }
    ];

    res.status(200).json({
      success: true,
      data: {
        payment_methods: paymentMethods,
        invoice_amount: invoiceAmount
      }
    });
  } catch (error) {
    console.error('Error fetching payment methods:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch payment methods',
      error: error.message
    });
  }
};

// 💳 إنشاء توكن للبطاقة
exports.createCardToken = async (req, res) => {
  try {
    const { card_number, expiry_month, expiry_year, cvv, card_holder } = req.body;

    await new Promise(resolve => setTimeout(resolve, 2000));

    const token = `tok_${Math.random().toString(36).substr(2, 16)}`;

    res.status(200).json({
      success: true,
      data: {
        card_token: token,
        masked_card: `**** **** **** ${card_number.slice(-4)}`,
        card_type: getCardType(card_number)
      }
    });
  } catch (error) {
    console.error('Error creating card token:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create card token',
      error: error.message
    });
  }
};

const getCardType = (number) => {
  const cardPatterns = {
    visa: /^4[0-9]{12}(?:[0-9]{3})?$/,
    mastercard: /^5[1-5][0-9]{14}$/,
    amex: /^3[47][0-9]{13}$/
  };

  for (const [type, pattern] of Object.entries(cardPatterns)) {
    if (pattern.test(number)) return type;
  }
  return 'unknown';
};

// استرجاع المبلغ
exports.processRefund = async (req, res) => {
  try {
    const { sessionId } = req.params;
    const { refund_reason } = req.body;

    const session = await Session.findOne({
      where: { session_id: sessionId },
      include: [{
        model: Invoice,
        attributes: ['invoice_id', 'total_amount', 'status']
      }]
    });

    if (!session || !session.Invoice) {
      return res.status(404).json({ success: false, message: 'Session or invoice not found' });
    }

    if (session.Invoice.status !== 'Paid') {
      return res.status(400).json({ success: false, message: 'Invoice is not paid, cannot process refund' });
    }

    if (session.status === 'Refunded') {
      return res.status(400).json({ success: false, message: 'Refund already processed for this session' });
    }

    const refundResult = await simulateRefund({
      amount: session.Invoice.total_amount,
      original_transaction_id: 'TXN-REFERENCE'
    });

    if (refundResult.success) {
      await Invoice.update({
        status: 'Refunded',
        refund_amount: session.Invoice.total_amount,
        refund_reason: refund_reason || 'Cancelled by parent',
        refunded_at: new Date()
      }, { where: { invoice_id: session.Invoice.invoice_id } });

      await Session.update({ status: 'Refunded' }, { where: { session_id: sessionId } });

      await Payment.create({
        invoice_id: session.Invoice.invoice_id,
        amount: -session.Invoice.total_amount,
        payment_method: 'Refund',
        status: 'Completed',
        transaction_id: refundResult.refundId,
        gateway_response: JSON.stringify(refundResult)
      });

      res.status(200).json({
        success: true,
        message: 'Refund processed successfully',
        data: {
          refund_amount: session.Invoice.total_amount,
          refund_id: refundResult.refundId,
          session_status: 'Refunded'
        }
      });
    } else {
      res.status(400).json({ success: false, message: 'Refund failed', error: refundResult.error });
    }

  } catch (error) {
    console.error('❌ Refund processing error:', error);
    res.status(500).json({ success: false, message: 'Failed to process refund', error: error.message });
  }
};

const simulateRefund = async (refundData) => {
  await new Promise(resolve => setTimeout(resolve, 2000));
  const isSuccess = Math.random() < 0.95;

  if (isSuccess) {
    return {
      success: true,
      refundId: `REF-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      message: 'Refund processed successfully'
    };
  } else {
    return { success: false, error: 'Refund processing failed' };
  }
};

// سجل المدفوعات
exports.getPaymentHistory = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { page = 1, limit = 10 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const payments = await Payment.findAll({
      attributes: ['payment_id', 'amount', 'payment_method', 'status', 'payment_date', 'invoice_id'],
      order: [['payment_date', 'DESC']],
      offset,
      limit: parseInt(limit),
      raw: true
    });

    const processedPayments = await Promise.all(
      payments.map(async (payment) => {
        const invoice = await Invoice.findOne({
          where: { invoice_id: payment.invoice_id, parent_id: parentId },
          attributes: ['invoice_number', 'total_amount', 'session_id'],
          raw: true
        });
        if (!invoice) return null;

        const session = await Session.findByPk(invoice.session_id, {
          include: [
            { model: require('../model/SessionType'), attributes: ['name'] },
            { model: require('../model/Child'), as: 'child', attributes: ['full_name'] }
          ],
          raw: true,
          nest: true
        });

        return {
          payment_id: payment.payment_id,
          amount: payment.amount,
          payment_method: payment.payment_method,
          status: payment.status,
          payment_date: payment.payment_date,
          invoice: { invoice_number: invoice.invoice_number, total_amount: invoice.total_amount },
          session: session
        };
      })
    );

    const filteredPayments = processedPayments.filter(p => p !== null);
    const totalPayments = await Payment.count();

    res.status(200).json({
      success: true,
      data: filteredPayments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalPayments,
        pages: Math.ceil(totalPayments / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('❌ Error fetching payment history:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch payment history', error: error.message });
  }
};

// جلب فواتير ولي الأمر
exports.getParentInvoices = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    
    const invoices = await Invoice.findAll({
      where: { parent_id: parentId },
      include: [
        {
          model: Session,
          attributes: ['session_id', 'date', 'time', 'session_type', 'status'],
          include: [
            { model: require('../model/Child'), as: 'child', attributes: ['full_name'] },
            { model: require('../model/SessionType'), attributes: ['name', 'duration'] }
          ]
        }
      ],
      order: [['due_date', 'ASC']]
    });

    res.status(200).json({ success: true, data: invoices });
  } catch (error) {
    console.error('Error fetching invoices:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch invoices', error: error.message });
  }
};

// جلب تفاصيل فاتورة محددة
exports.getInvoiceDetails = async (req, res) => {
  try {
    const { invoiceId } = req.params;
    const parentId = req.user.user_id;

    const invoice = await Invoice.findOne({
      where: { invoice_id: invoiceId, parent_id: parentId },
      include: [
        {
          model: Session,
          include: [
            { model: require('../model/Child'), as: 'child', attributes: ['full_name', 'age'] },
            { model: require('../model/SessionType'), attributes: ['name', 'duration', 'price'] },
            { model: require('../model/Specialist'), attributes: ['name', 'specialization'] }
          ]
        }
      ]
    });

    if (!invoice) return res.status(404).json({ success: false, message: 'Invoice not found' });

    res.status(200).json({ success: true, data: invoice });
  } catch (error) {
    console.error('Error fetching invoice details:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch invoice details', error: error.message });
  }
};


exports.createCheckoutSession = async (req, res) => {
  try {
    const { amount, invoice_number, currency = 'usd' } = req.body;

    if (!amount || !invoice_number) {
      return res.status(400).json({ success: false, message: 'Amount and invoice_number are required' });
    }

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency,
          product_data: { name: `Invoice ${invoice_number}` },
          unit_amount: Math.round(amount * 100),
        },
        quantity: 1,
      }],
      mode: 'payment',
      success_url: `http://localhost:3000/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `http://localhost:3000/cancel`,
    });

    res.status(200).json({ success: true, url: session.url, sessionId: session.id });

  } catch (error) {
    console.error('Error creating checkout session:', error);
    res.status(500).json({ success: false, message: 'Failed to create checkout session', error: error.message });
  }
};
