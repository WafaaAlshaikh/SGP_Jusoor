// controllers/webhookController.js
const { Donation, Institution, DonationCampaign, User, DonationInvite } = require('../model');
const Stripe = require('stripe');
require('dotenv').config();

const inviteController = require('./inviteController');

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

// ==================== Handle Stripe Webhook ====================
exports.handleStripeWebhook = async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    // 1. التحقق من صحة الـ webhook
    event = stripe.webhooks.constructEvent(
      req.body, 
      sig, 
      webhookSecret
    );
    
    console.log(' Webhook verified:', event.type);

  } catch (err) {
    console.error(' Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // 2. معالجة الأحداث المختلفة
  try {
    switch (event.type) {
      // نجاح الدفع لمرة واحدة
      case 'checkout.session.completed':
        await handleCheckoutSessionCompleted(event.data.object);
        break;

      // نجاح الدفع الشهري
      case 'invoice.payment_succeeded':
        await handleInvoicePaymentSucceeded(event.data.object);
        break;

      // فشل الدفع
      case 'invoice.payment_failed':
        await handleInvoicePaymentFailed(event.data.object);
        break;

      // إلغاء الاشتراك
      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object);
        break;

      // تحديث الاشتراك
      case 'customer.subscription.updated':
        await handleSubscriptionUpdated(event.data.object);
        break;

      default:
        console.log(` Unhandled event type: ${event.type}`);
    }

    res.json({ received: true, event: event.type });

  } catch (error) {
    console.error(' Error processing webhook:', error);
    res.status(500).json({ 
      error: 'Webhook processing failed',
      message: error.message 
    });
  }
};

// ==================== معالج نجاح جلسة الدفع ====================
async function handleCheckoutSessionCompleted(session) {
  try {
    console.log(' Processing checkout.session.completed');
    console.log('   Session ID:', session.id);
    console.log('   Payment Status:', session.payment_status);

    // البحث عن التبرع
    const donation = await Donation.findOne({
      where: { stripe_session_id: session.id }
    });

    if (!donation) {
      console.error(' Donation not found for session:', session.id);
      return;
    }

    if (session.metadata && donation.anonymous_donor) {
      const updateData = {
        donor_email: session.metadata.donor_email || donation.donor_email,
        donor_name: session.metadata.donor_name || donation.donor_name,
      };

      // تحديث إذا كانت البيانات متوفرة
      if (session.metadata.donor_email || session.metadata.donor_name) {
        await donation.update(updateData);
      }
    }

    // تحديث حالة التبرع
    if (session.payment_status === 'paid') {
      await donation.update({
        status: 'completed',
        payment_status: 'paid',
        payment_date: new Date(),
        stripe_payment_intent_id: session.payment_intent,
        stripe_customer_id: session.customer,
        stripe_subscription_id: session.subscription || donation.stripe_subscription_id || null,
        receipt_url: session.invoice?.receipt_url || null,
      });

      // Invite/referral tracking (if invite_code exists)
      try {
        const inviteCode = (session.metadata?.invite_code ?? '').toString().trim();
        if (inviteCode) {
          const invite = await DonationInvite.findOne({ where: { code: inviteCode, is_active: true }, raw: true });
          if (invite?.invite_id) {
            await inviteController._markInviteDonationCompleted({
              inviteId: invite.invite_id,
              stripeSessionId: session.id,
              donationId: donation.donation_id,
              amount: donation.amount,
              currency: donation.currency,
            });
          }
        }
      } catch (e) {
        console.warn('Invite donation_completed log failed:', e.message);
      }

      // تحديث رصيد المؤسسة
      const institution = await Institution.findByPk(donation.institution_id);
      if (institution) {
        const newBalance = parseFloat(institution.donation_balance || 0) + 
                         parseFloat(donation.amount);
        await institution.update({
          donation_balance: newBalance
        });
        console.log(` Institution balance updated: ${newBalance} JOD`);
      }

      // تحديث رصيد الحملة (إن وجدت)
      if (donation.campaign_id) {
        const campaign = await DonationCampaign.findByPk(donation.campaign_id);
        if (campaign) {
          const newRaised = parseFloat(campaign.amount_raised || 0) + 
                          parseFloat(donation.amount);
          await campaign.update({
            amount_raised: newRaised
          });
          console.log(` Campaign amount updated: ${newRaised} JOD`);
        }
      }

      console.log(' Donation completed successfully:', donation.donation_id);

      // إرسال إشعار للمتبرع (اختياري)
      await sendDonationSuccessNotification(donation);

    } else {
      console.warn(' Payment not completed:', session.payment_status);
    }

  } catch (error) {
    console.error(' Error in handleCheckoutSessionCompleted:', error);
    throw error;
  }
}

// ==================== معالج نجاح الاشتراك الشهري ====================
async function handleInvoicePaymentSucceeded(invoice) {
  try {
    console.log('💰 Processing invoice.payment_succeeded');
    
    const subscriptionId = invoice.subscription;
    
    // البحث عن التبرع الشهري
    const donation = await Donation.findOne({
      where: { 
        stripe_subscription_id: subscriptionId,
        donation_type: 'monthly'
      }
    });

    if (!donation) {
      console.warn('⚠️ Recurring donation not found for subscription:', subscriptionId);
      return;
    }

    // تحديث المؤسسة والحملة
    const institution = await Institution.findByPk(donation.institution_id);
    if (institution) {
      const newBalance = parseFloat(institution.donation_balance || 0) + 
                       parseFloat(donation.amount);
      await institution.update({ donation_balance: newBalance });
    }

    if (donation.campaign_id) {
      const campaign = await DonationCampaign.findByPk(donation.campaign_id);
      if (campaign) {
        const newRaised = parseFloat(campaign.amount_raised || 0) + 
                        parseFloat(donation.amount);
        await campaign.update({ amount_raised: newRaised });
      }
    }

    console.log('✅ Monthly donation processed successfully');

  } catch (error) {
    console.error('❌ Error in handleInvoicePaymentSucceeded:', error);
  }
}

// ==================== معالج فشل الدفع ====================
async function handleInvoicePaymentFailed(invoice) {
  try {
    console.log('❌ Processing invoice.payment_failed');
    
    const subscriptionId = invoice.subscription;
    
    const donation = await Donation.findOne({
      where: { stripe_subscription_id: subscriptionId }
    });

    if (donation) {
      await donation.update({
        status: 'failed',
        payment_status: 'failed',
        payment_failure_reason: invoice.failure_reason || 'Payment failed'
      });

      console.log('❌ Donation marked as failed:', donation.donation_id);
      
      // إرسال إشعار للمتبرع (اختياري)
      await sendDonationFailureNotification(donation);
    }

  } catch (error) {
    console.error('❌ Error in handleInvoicePaymentFailed:', error);
  }
}

// ==================== معالج إلغاء الاشتراك ====================
async function handleSubscriptionDeleted(subscription) {
  try {
    console.log('🔴 Processing subscription.deleted');
    
    const donation = await Donation.findOne({
      where: { stripe_subscription_id: subscription.id }
    });

    if (donation) {
      await donation.update({
        status: 'cancelled',
        cancelled_at: new Date(),
        cancellation_reason: 'Subscription cancelled by user or expired'
      });

      console.log('✅ Subscription cancelled:', donation.donation_id);
    }

  } catch (error) {
    console.error('❌ Error in handleSubscriptionDeleted:', error);
  }
}

// ==================== معالج تحديث الاشتراك ====================
async function handleSubscriptionUpdated(subscription) {
  try {
    console.log('🔄 Processing subscription.updated');
    
    // يمكن إضافة منطق إضافي هنا لتحديث الاشتراكات
    
  } catch (error) {
    console.error('❌ Error in handleSubscriptionUpdated:', error);
  }
}

// ==================== دوال الإشعارات ====================
async function sendDonationSuccessNotification(donation) {
  try {
    // إضافة منطق الإشعارات هنا
    // مثل: إرسال بريد إلكتروني، Firebase notification، إلخ
    console.log('📧 Sending success notification for donation:', donation.donation_id);
  } catch (error) {
    console.error('❌ Error sending notification:', error);
  }
}

async function sendDonationFailureNotification(donation) {
  try {
    console.log('📧 Sending failure notification for donation:', donation.donation_id);
  } catch (error) {
    console.error('❌ Error sending notification:', error);
  }
}

module.exports = exports;