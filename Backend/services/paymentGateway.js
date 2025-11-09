// services/paymentGateway.js
// نظام معالجة الدفع بالطرق المختلفة

require('dotenv').config();

const stripe = require('stripe')(process.env.STRIPE_TEST_KEY);

class PaymentGateway {
  
  // ================= 1. CASH PAYMENT =================
  static async processCashPayment(amount, transactionDetails) {
    try {
      console.log('💵 Processing cash payment:', { amount, ...transactionDetails });
      
      // للدفع النقدي، نقبله مباشرة
      return {
        success: true,
        method: 'Cash',
        transaction_id: `CASH-${Date.now()}`,
        amount: amount,
        status: 'Completed',
        message: 'Cash payment recorded successfully',
        payment_date: new Date()
      };
    } catch (error) {
      console.error('❌ Cash payment error:', error);
      return {
        success: false,
        message: 'Failed to process cash payment',
        error: error.message
      };
    }
  }

  // ================= 2. CREDIT CARD PAYMENT (Stripe) =================
  static async processCreditCardPayment(amount, cardDetails) {
    try {
      console.log('💳 Processing credit card payment via Stripe:', { amount });

      // إنشاء Payment Intent على Stripe
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(amount * 100), // Stripe يستخدم cents
        currency: 'usd',
        payment_method_types: ['card'],
        description: cardDetails.description || 'Session Payment',
        metadata: {
          session_id: cardDetails.session_id,
          parent_id: cardDetails.parent_id
        }
      });

      // إذا كان هناك payment_method_id، نؤكد الدفع مباشرة
      if (cardDetails.payment_method_id) {
        const confirmedPayment = await stripe.paymentIntents.confirm(
          paymentIntent.id,
          { payment_method: cardDetails.payment_method_id }
        );

        return {
          success: confirmedPayment.status === 'succeeded',
          method: 'Credit Card',
          transaction_id: confirmedPayment.id,
          amount: amount,
          status: confirmedPayment.status === 'succeeded' ? 'Completed' : 'Pending',
          stripe_payment_intent: confirmedPayment,
          message: 'Credit card payment processed successfully',
          payment_date: new Date()
        };
      }

      // إرجاع client_secret للواجهة الأمامية لإتمام الدفع
      return {
        success: true,
        method: 'Credit Card',
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        amount: amount,
        status: 'Pending',
        message: 'Payment intent created - waiting for card confirmation',
        requires_action: true
      };

    } catch (error) {
      console.error('❌ Credit card payment error:', error);
      return {
        success: false,
        message: 'Failed to process credit card payment',
        error: error.message
      };
    }
  }

  // ================= 2.1. TEST CREDIT CARD PAYMENT (DEMO MODE) =================
  // للتجربة بدون Stripe حقيقي - Demo Mode فقط
  static async processTestCreditCardPayment(amount, cardDetails) {
    try {
      console.log('💳 [DEMO MODE] Processing TEST credit card payment:', { amount });

      // أرقام بطاقات تجريبية - Demo Mode
      const testCards = {
        '4242424242424242': { valid: true, name: 'Visa Success', bank: 'Demo Bank' },
        '4000000000000002': { valid: false, name: 'Visa Declined', bank: 'Demo Bank' },
        '5555555555554444': { valid: true, name: 'Mastercard Success', bank: 'Demo Bank' },
        '378282246310005': { valid: true, name: 'American Express', bank: 'Demo Bank' }
      };

      const cardNumber = cardDetails.card_number?.replace(/\s/g, '');
      const testCard = testCards[cardNumber];

      // إذا لم تكن بطاقة تجريبية معروفة
      if (!testCard) {
        return {
          success: false,
          message: '🧪 Demo Mode: استخدم بطاقة تجريبية للاختبار',
          error: 'هذا demo mode - استخدم إحدى البطاقات التالية:\n✅ 4242 4242 4242 4242 (نجاح)\n❌ 4000 0000 0000 0002 (رفض)\n✅ 5555 5555 5555 4444 (Mastercard)',
          demo_mode: true,
          available_test_cards: [
            { number: '4242424242424242', result: 'Success ✅' },
            { number: '4000000000000002', result: 'Declined ❌' },
            { number: '5555555555554444', result: 'Success ✅' }
          ]
        };
      }

      // إذا كانت بطاقة مرفوضة
      if (!testCard.valid) {
        return {
          success: false,
          message: '❌ البطاقة مرفوضة (Demo Mode)',
          error: 'Card declined in test mode',
          demo_mode: true
        };
      }

      // نجاح الدفع
      return {
        success: true,
        method: 'Credit Card (Demo)',
        transaction_id: `DEMO-CARD-${Date.now()}`,
        amount: amount,
        status: 'Completed',
        card_type: testCard.name,
        card_bank: testCard.bank,
        last_4_digits: cardNumber.slice(-4),
        message: `✅ تم الدفع بنجاح (Demo Mode) - ${testCard.name}`,
        payment_date: new Date(),
        demo_mode: true,
        note: '🧪 هذا دفع تجريبي - لا يتم تحصيل أموال حقيقية'
      };

    } catch (error) {
      console.error('❌ Test credit card payment error:', error);
      return {
        success: false,
        message: 'فشل معالجة الدفع التجريبي',
        error: error.message,
        demo_mode: true
      };
    }
  }

  // ================= 3. BANK TRANSFER PAYMENT =================
  static async processBankTransferPayment(amount, transferDetails) {
    try {
      console.log('🏦 Processing bank transfer payment:', { amount, ...transferDetails });

      // للتحويل البنكي، نسجله كـ Pending ويحتاج تأكيد من المدير
      return {
        success: true,
        method: 'Bank Transfer',
        transaction_id: transferDetails.reference_number || `BANK-${Date.now()}`,
        amount: amount,
        status: 'Pending Verification', // يحتاج تأكيد
        bank_name: transferDetails.bank_name,
        account_number: transferDetails.account_number,
        message: 'Bank transfer recorded - pending verification',
        payment_date: new Date(),
        requires_verification: true
      };
    } catch (error) {
      console.error('❌ Bank transfer payment error:', error);
      return {
        success: false,
        message: 'Failed to process bank transfer',
        error: error.message
      };
    }
  }

  // ================= 4. PAYPAL PAYMENT (Sandbox) =================
  static async processPayPalPayment(amount, paypalDetails) {
    try {
      console.log('🅿️ Processing PayPal payment (sandbox):', { amount });

      // للتجربة - PayPal Sandbox
      // في الواقع تحتاج PayPal SDK
      
      return {
        success: true,
        method: 'PayPal',
        transaction_id: paypalDetails.order_id || `PAYPAL-${Date.now()}`,
        amount: amount,
        status: 'Completed',
        payer_email: paypalDetails.payer_email,
        message: 'PayPal payment processed successfully (sandbox)',
        payment_date: new Date()
      };

    } catch (error) {
      console.error('❌ PayPal payment error:', error);
      return {
        success: false,
        message: 'Failed to process PayPal payment',
        error: error.message
      };
    }
  }

  // ================= VERIFY BANK TRANSFER (للمدير) =================
  static async verifyBankTransfer(paymentId, isApproved, notes) {
    try {
      console.log(`${isApproved ? '✅' : '❌'} Verifying bank transfer:`, paymentId);

      return {
        success: true,
        payment_id: paymentId,
        status: isApproved ? 'Completed' : 'Rejected',
        verified_at: new Date(),
        verification_notes: notes,
        message: isApproved ? 'Bank transfer verified successfully' : 'Bank transfer rejected'
      };

    } catch (error) {
      console.error('❌ Bank transfer verification error:', error);
      return {
        success: false,
        message: 'Failed to verify bank transfer',
        error: error.message
      };
    }
  }

  // ================= GET PAYMENT METHOD INFO =================
  static getPaymentMethodInfo(method) {
    const methods = {
      'Cash': {
        name: 'Cash Payment',
        name_ar: 'دفع نقدي',
        icon: '💵',
        requires_verification: false,
        instant: true
      },
      'Credit Card': {
        name: 'Credit/Debit Card',
        name_ar: 'بطاقة ائتمان',
        icon: '💳',
        requires_verification: false,
        instant: true
      },
      'Bank Transfer': {
        name: 'Bank Transfer',
        name_ar: 'تحويل بنكي',
        icon: '🏦',
        requires_verification: true,
        instant: false
      },
      'PayPal': {
        name: 'PayPal',
        name_ar: 'باي بال',
        icon: '🅿️',
        requires_verification: false,
        instant: true
      }
    };

    return methods[method] || {
      name: method,
      name_ar: method,
      icon: '💰',
      requires_verification: false,
      instant: false
    };
  }
}

module.exports = PaymentGateway;
