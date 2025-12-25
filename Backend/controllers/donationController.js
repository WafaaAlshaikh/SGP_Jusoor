const { Donation,Manager, Institution, DonationCampaign, DonationAllocation, Invoice, Session, Child } = require('../model');
const Stripe = require('stripe');
require('dotenv').config();
const sequelize = require('../config/db');
const { Op } = require('sequelize');
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

async function getManagerInstitution(managerId) {
  const manager = await Manager.findOne({
    where: {
      manager_id: managerId,
      is_active: true
    },
    include: [{
      model: Institution,
      attributes: ['institution_id', 'name']
    }]
  });

  if (!manager || !manager.Institution) {
    return null;
  }

  return manager.Institution;
}

// ✅ أضف هذه الدالة إلى donationController.js

// ==================== NEW: Confirm Donation ====================
exports.confirmDonation = async (req, res) => {
  try {
    const { session_id } = req.body;
    
    if (!session_id) {
      return res.status(400).json({
        success: false,
        message: 'Session ID is required'
      });
    }

    // 1. البحث عن التبرع
    const donation = await Donation.findOne({
      where: { stripe_session_id: session_id },
      include: [
        {
          model: Institution,
          attributes: ['institution_id', 'name', 'city', 'location']
        },
        {
          model: DonationCampaign,
          attributes: ['campaign_id', 'name'],
          required: false
        }
      ]
    });

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: 'Donation not found'
      });
    }

    // 2. التحقق من Stripe
    let stripeSession;
    try {
      stripeSession = await stripe.checkout.sessions.retrieve(session_id);
    } catch (stripeError) {
      console.error('Stripe error:', stripeError);
      return res.status(500).json({
        success: false,
        message: 'Failed to verify payment with Stripe'
      });
    }

    // 3. التحقق من حالة الدفع
    if (stripeSession.payment_status !== 'paid') {
      return res.status(400).json({
        success: false,
        message: 'Payment not completed',
        payment_status: stripeSession.payment_status
      });
    }

    // 4. تحديث التبرع (إذا لم يتم تحديثه بواسطة webhook)
    if (donation.status !== 'completed') {
      await donation.update({
        status: 'completed',
        payment_status: 'paid',
        payment_date: new Date(),
        stripe_payment_intent_id: stripeSession.payment_intent,
        stripe_customer_id: stripeSession.customer,
      });

      // تحديث رصيد المؤسسة
      const institution = await Institution.findByPk(donation.institution_id);
      if (institution) {
        const newBalance = parseFloat(institution.donation_balance || 0) + 
                         parseFloat(donation.amount);
        await institution.update({ donation_balance: newBalance });
      }

      // تحديث رصيد الحملة
      if (donation.campaign_id) {
        const campaign = await DonationCampaign.findByPk(donation.campaign_id);
        if (campaign) {
          const newRaised = parseFloat(campaign.amount_raised || 0) + 
                          parseFloat(donation.amount);
          await campaign.update({ amount_raised: newRaised });
        }
      }
    }

    // 5. إرجاع النتيجة
    return res.status(200).json({
      success: true,
      message: 'Donation confirmed successfully',
      donation: {
        donation_id: donation.donation_id,
        amount: donation.amount,
        currency: donation.currency,
        status: donation.status,
        payment_status: donation.payment_status,
        payment_date: donation.payment_date,
        institution: donation.Institution,
        campaign: donation.DonationCampaign,
        receipt_url: stripeSession.invoice?.receipt_url || null,
      }
    });

  } catch (error) {
    console.error('Error confirming donation:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to confirm donation',
      error: error.message
    });
  }
};
// Get list of institutions available for donation
exports.getDonationInstitutions = async (req, res) => {
  try {
    const institutions = await Institution.findAll({
      attributes: ['institution_id', 'name', 'city', 'location']
    });

    return res.status(200).json({
      success: true,
      institutions
    });
  } catch (error) {
    console.error('Error fetching institutions for donation:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// في donationController.js
exports.getInstitutionCampaignsForDonations = async (req, res) => {
  try {
    const institutionId = parseInt(req.params.institutionId, 10);

    if (!institutionId || !Number.isFinite(institutionId)) {
      return res.status(400).json({
        success: false,
        message: 'Valid institution id is required',
      });
    }

    const institution = await Institution.findByPk(institutionId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found',
      });
    }

    const campaigns = await DonationCampaign.findAll({
      where: {
        institution_id: institutionId,
        status: 'active', // إرجاع الحملات النشطة فقط
      },
      order: [['created_at', 'DESC']],
      attributes: [
        'campaign_id',
        'name',
        'description',
        'target_amount',
        'start_date',
        'end_date',
        'status',
        'created_at',
      ],
    });

    return res.status(200).json({
      success: true,
      data: campaigns, // تأكد أنك تستخدم data وليس campaigns مباشرة
    });
  } catch (error) {
    console.error('Error fetching institution campaigns for donations:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch institution campaigns',
      error: error.message,
    });
  }
};

exports.createDonationCheckout = async (req, res) => {
  try {
    // ==================== 1. التحقق من التوثيق ====================
    if (!req.user || !req.user.user_id) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required. Please login to donate.'
      });
    }

    const donorId = req.user.user_id;
    const { institution_id, amount, campaign_id, mode, currency = 'usd' } = req.body;

    // ==================== 2. التحقق من المدخلات ====================
    if (!institution_id || !amount) {
      return res.status(400).json({
        success: false,
        message: 'institution_id and amount are required'
      });
    }

    // التحقق من نوع institution_id
    const parsedInstitutionId = parseInt(institution_id, 10);
    if (!Number.isFinite(parsedInstitutionId) || parsedInstitutionId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Valid institution id is required'
      });
    }

    // التحقق من المبلغ
    const parsedAmount = parseFloat(amount);
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Amount must be a positive number'
      });
    }

    // التحقق من الحد الأدنى والأقصى للمبلغ
    const MIN_DONATION = process.env.MIN_DONATION_AMOUNT || 1;
    const MAX_DONATION = process.env.MAX_DONATION_AMOUNT || 10000;
    
    if (parsedAmount < MIN_DONATION) {
      return res.status(400).json({
        success: false,
        message: `Minimum donation amount is ${MIN_DONATION} JOD`
      });
    }
    
    if (parsedAmount > MAX_DONATION) {
      return res.status(400).json({
        success: false,
        message: `Maximum donation amount is ${MAX_DONATION} JOD`
      });
    }

    // التحقق من العملة
    const allowedCurrencies = (process.env.ALLOWED_CURRENCIES || 'usd,eur,gbp,jod').split(',');
    if (!allowedCurrencies.includes(currency.toLowerCase())) {
      return res.status(400).json({
        success: false,
        message: `Currency not supported. Allowed currencies: ${allowedCurrencies.join(', ')}`
      });
    }

    // ==================== 3. التحقق من المؤسسة ====================
    const institution = await Institution.findByPk(parsedInstitutionId, {
      attributes: ['institution_id', 'name', 'city', 'is_active', 'donation_balance']
    });

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    if (institution.is_active !== true) {
      return res.status(400).json({
        success: false,
        message: 'This institution is not currently accepting donations'
      });
    }

    // ==================== 4. التحقق من الحملة (إذا وجدت) ====================
    let campaign = null;
    let parsedCampaignId = null;

    if (campaign_id) {
      parsedCampaignId = parseInt(campaign_id, 10);
      if (Number.isFinite(parsedCampaignId) && parsedCampaignId > 0) {
        campaign = await DonationCampaign.findOne({
          where: {
            campaign_id: parsedCampaignId,
            institution_id: parsedInstitutionId,
            status: 'active'
          },
          attributes: ['campaign_id', 'name', 'description', 'target_amount', 'amount_raised', 'end_date']
        });
        
        if (!campaign) {
          return res.status(404).json({
            success: false,
            message: 'Campaign not found or not active'
          });
        }

        // التحقق من تاريخ انتهاء الحملة
        if (campaign.end_date && new Date(campaign.end_date) < new Date()) {
          return res.status(400).json({
            success: false,
            message: 'This campaign has ended'
          });
        }
      }
    }

    // ==================== 5. تحديد نوع التبرع ====================
    const donationMode = (mode === 'monthly' || mode === 'recurring') ? 'monthly' : 'one_time';
    
    // التحقق من أن التبرع الشهري لا يزيد عن حد معين
    if (donationMode === 'monthly' && parsedAmount > 1000) {
      return res.status(400).json({
        success: false,
        message: 'Maximum monthly donation amount is 1000 JOD'
      });
    }

    // ==================== 6. إعداد بيانات المنتج في Stripe ====================
    const lineItemPriceData = {
      currency: currency.toLowerCase(),
      product_data: {
        name: `Donation to ${institution.name}`,
        description: campaign 
          ? `Supporting campaign: ${campaign.name}` 
          : `General donation to ${institution.name}`,
        metadata: {
          institution_id: String(parsedInstitutionId),
          institution_name: institution.name,
          donation_type: donationMode
        }
      },
      unit_amount: Math.round(parsedAmount * 100), // تحويل إلى سنتات/قروش
    };

    // إضافة التكرار إذا كان تبرعاً شهرياً
    if (donationMode === 'monthly') {
      lineItemPriceData.recurring = { 
        interval: 'month',
        interval_count: 1
      };
    }

    // ==================== 7. إعداد الميتاداتا ====================
    const metadata = {
      donor_id: String(donorId),
      donor_email: req.user.email || '',
      donor_name: req.user.full_name || '',
      institution_id: String(parsedInstitutionId),
      institution_name: institution.name,
      campaign_id: parsedCampaignId ? String(parsedCampaignId) : '',
      campaign_name: campaign ? campaign.name : '',
      amount: String(parsedAmount),
      currency: currency.toLowerCase(),
      mode: donationMode,
      timestamp: new Date().toISOString(),
      ip_address: req.ip || req.headers['x-forwarded-for'] || req.connection.remoteAddress || '',
      user_agent: req.headers['user-agent'] || ''
    };

    // ==================== 8. إعداد طرق الدفع - الإصلاح هنا ====================
    const payment_method_types = ['card']; // فقط card مرة واحدة
    
    // إزالة الكود الذي يضيف card مرة ثانية بناءً على المنطقة
    /*
    // إضافة طرق دفع إضافية حسب المنطقة
    const country = req.headers['x-country-code'] || 'JO';
    if (country === 'JO') {
      // يمكن إضافة طرق دفع محلية للأردن
      payment_method_types.push('card'); // ❌ هذا يسبب الخطأ!
    }
    */

    // بدلاً من ذلك، يمكنك إضافة طرق دفع مختلفة حسب المنطقة:
    const country = req.headers['x-country-code'] || 'JO';
    if (country === 'US') {
      // أمريكا: نضيف afterpay_clearpay
      payment_method_types.push('afterpay_clearpay');
    } else if (country === 'EU') {
      // أوروبا: نضيف ideal, sofort
      payment_method_types.push('ideal', 'sofort');
    }
    // لاحظ: لا تضيف card مرة أخرى!

    // ==================== 9. إنشاء جلسة الدفع في Stripe ====================
    const sessionConfig = {
      payment_method_types: payment_method_types,
      line_items: [
        {
          price_data: lineItemPriceData,
          quantity: 1,
        },
      ],
      mode: donationMode === 'monthly' ? 'subscription' : 'payment',
      success_url: `${process.env.FRONTEND_URL}/donations/success?session_id={CHECKOUT_SESSION_ID}&institution_id=${parsedInstitutionId}&amount=${parsedAmount}`,
      cancel_url: `${process.env.FRONTEND_URL}/donations/cancel?institution_id=${parsedInstitutionId}`,
      metadata: metadata,
      customer_email: req.user.email,
      billing_address_collection: 'auto',
      allow_promotion_codes: true,
      expires_at: Math.floor(Date.now() / 1000) + 3600, // تنتهي بعد ساعة
      submit_type: 'donate',
      locale: 'auto',
      payment_intent_data: {
        description: `Donation to ${institution.name}`,
        metadata: metadata
      }
    };

    // إعدادات إضافية للتبرعات الشهرية
    if (donationMode === 'monthly') {
      sessionConfig.subscription_data = {
        metadata: metadata,
        description: `Monthly donation to ${institution.name}`
      };
    }

    const session = await stripe.checkout.sessions.create(sessionConfig);

    // ==================== 10. حفظ التبرع في قاعدة البيانات ====================
    const donation = await Donation.create({
      donor_id: donorId,
      institution_id: parsedInstitutionId,
      campaign_id: parsedCampaignId || null,
      amount: parsedAmount,
      currency: currency.toLowerCase(),
      status: 'pending',
      payment_method: 'stripe',
      stripe_session_id: session.id,
      stripe_payment_intent_id: session.payment_intent || null,
      donation_type: donationMode,
      ip_address: metadata.ip_address,
      user_agent: metadata.user_agent,
      expires_at: new Date(session.expires_at * 1000)
    });

    // ==================== 11. إرجاع النتيجة ====================
    return res.status(200).json({
      success: true,
      url: session.url,
      sessionId: session.id,
      payment_intent_id: session.payment_intent || null,
      donation_id: donation.donation_id,
      amount: parsedAmount,
      currency: currency.toLowerCase(),
      mode: donationMode,
      institution_name: institution.name,
      campaign_name: campaign ? campaign.name : null,
      expires_at: session.expires_at,
      message: 'Checkout session created successfully',
      instructions: {
        complete_payment: 'You will be redirected to Stripe to complete your payment',
        timeout: 'This session will expire in 1 hour',
        receipt: 'You will receive a receipt via email after successful payment',
        support: 'Contact support if you encounter any issues'
      }
    });

  } catch (error) {
    console.error('Error creating donation checkout session:', error);
    
    // ==================== معالجة الأخطاء المحددة ====================
    let statusCode = 500;
    let errorMessage = 'Failed to create donation checkout session';
    let errorDetails = {};

    if (error.type === 'StripeInvalidRequestError') {
      statusCode = 400;
      errorMessage = 'Invalid payment request. Please check your information.';
      errorDetails = {
        param: error.param,
        code: error.code,
        type: error.type
      };
    } else if (error.code === 'resource_missing') {
      statusCode = 400;
      errorMessage = 'Payment information is incomplete.';
    } else if (error.code === 'rate_limit') {
      statusCode = 429;
      errorMessage = 'Too many requests. Please try again later.';
    } else if (error.name === 'SequelizeValidationError') {
      statusCode = 400;
      errorMessage = 'Validation error in donation data';
      errorDetails = {
        errors: error.errors.map(e => ({
          field: e.path,
          message: e.message
        }))
      };
    } else if (error.name === 'SequelizeDatabaseError') {
      statusCode = 500;
      errorMessage = 'Database error occurred';
    }

    return res.status(statusCode).json({
      success: false,
      message: errorMessage,
      error: error.message,
      error_type: error.type || error.name,
      details: errorDetails,
      timestamp: new Date().toISOString(),
      support_contact: 'support@example.com'
    });
  }
};

// ==================== دالة مساعدة لإرسال الإيميل ====================
async function sendDonationInitiatedEmail(toEmail, data) {
  // تنفيذ إرسال الإيميل
  // يمكن استخدام nodemailer أو أي خدمة أخرى
  console.log('Sending donation initiated email to:', toEmail);
  console.log('Donation data:', data);
  
  // مثال باستخدام nodemailer:
  /*
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT,
    secure: false,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    }
  });

  await transporter.sendMail({
    from: process.env.SMTP_FROM,
    to: toEmail,
    subject: `Donation Initiated - ${data.institution_name}`,
    html: `
      <h2>Thank you for your donation!</h2>
      <p>Dear ${data.donor_name},</p>
      <p>You have initiated a donation of ${data.amount} ${data.currency} to ${data.institution_name}.</p>
      ${data.campaign_name ? `<p>Campaign: ${data.campaign_name}</p>` : ''}
      <p>Donation Type: ${data.mode === 'monthly' ? 'Monthly Recurring' : 'One-time'}</p>
      <p>Donation ID: #${data.donation_id}</p>
      <p><a href="${data.checkout_url}">Click here to complete your payment</a></p>
      <p>This link will expire in 1 hour.</p>
      <p>If you didn't initiate this donation, please contact support immediately.</p>
      <br>
      <p>Best regards,<br>Jusoor Team</p>
    `
  });
  */
}

// Create a new donation for an institution
exports.createDonation = async (req, res) => {
  try {
    const donorId = req.user ? req.user.user_id : null; // optional auth
    const { institution_id, amount, campaign_id } = req.body;

    if (!institution_id || !amount) {
      return res.status(400).json({
        success: false,
        message: 'institution_id and amount are required'
      });
    }

    const institution = await Institution.findByPk(institution_id);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    const parsedAmount = parseFloat(amount);
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Amount must be a positive number'
      });
    }

    const donation = await Donation.create({
      donor_id: donorId || 0,
      institution_id,
      campaign_id: campaign_id || null,
      amount: parsedAmount
    });

    // زيادة رصيد التبرعات للمؤسسة بهذا المبلغ
    const currentBalance = parseFloat(institution.donation_balance || 0);
    const newBalance = currentBalance + parsedAmount;
    await institution.update({ donation_balance: newBalance });

    return res.status(201).json({
      success: true,
      message: 'Donation created successfully',
      donation_id: donation.donation_id
    });
  } catch (error) {
    console.error('Error creating donation:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};



// Get aggregated donation impact for the current donor: sessions/children supported
exports.getDonationImpact = async (req, res) => {
  try {
    const donorId = req.user.user_id;

    // Aggregate total donations for this donor
    const donationAgg = await Donation.findOne({
      where: { donor_id: donorId },
      attributes: [
        [Donation.sequelize.fn('SUM', Donation.sequelize.col('amount')), 'total'],
      ],
      raw: true,
    });

    const totalDonationsAmount = parseFloat(donationAgg?.total || 0);

    // Get all donations for this donor
    const donations = await Donation.findAll({
      where: { donor_id: donorId },
      attributes: ['donation_id', 'campaign_id'],
      raw: true,
    });

    if (!donations.length) {
      return res.status(200).json({
        success: true,
        data: {
          totalDonationsAmount: 0,
          totalAllocatedAmount: 0,
          sessionsSupportedCount: 0,
          childrenSupportedCount: 0,
          timeline: [],
        },
      });
    }

    const donationIds = donations.map((d) => d.donation_id);

    // Find allocations tied to these donations
    const allocations = await DonationAllocation.findAll({
      where: {
        donation_id: {
          [Op.in]: donationIds,
        },
      },
      attributes: ['allocation_id', 'donation_id', 'invoice_id', 'amount_allocated', 'created_at'],
      order: [['created_at', 'DESC']],
      raw: true,
    });

    if (!allocations.length) {
      return res.status(200).json({
        success: true,
        data: {
          totalDonationsAmount,
          totalAllocatedAmount: 0,
          sessionsSupportedCount: 0,
          childrenSupportedCount: 0,
          timeline: [],
        },
      });
    }

    const totalAllocatedAmount = allocations.reduce(
      (sum, a) => sum + parseFloat(a.amount_allocated || 0),
      0,
    );

    const invoiceIds = [...new Set(allocations.map((a) => a.invoice_id).filter((id) => !!id))];

    let sessionsSupportedCount = 0;
    let childrenSupportedCount = 0;
    let timeline = [];

    if (invoiceIds.length > 0) {
      const invoices = await Invoice.findAll({
        where: {
          invoice_id: {
            [Op.in]: invoiceIds,
          },
        },
        attributes: ['invoice_id', 'session_id'],
        raw: true,
      });

      const sessionIds = [...new Set(invoices.map((i) => i.session_id).filter((id) => !!id))];

      if (sessionIds.length > 0) {
        sessionsSupportedCount = sessionIds.length;

        const sessions = await Session.findAll({
          where: {
            session_id: {
              [Op.in]: sessionIds,
            },
          },
          attributes: ['session_id', 'child_id', 'date', 'session_type'],
          raw: true,
        });

        const childIds = [...new Set(sessions.map((s) => s.child_id).filter((id) => !!id))];
        childrenSupportedCount = childIds.length;

        const children = await Child.findAll({
          where: {
            child_id: {
              [Op.in]: childIds,
            },
          },
          attributes: ['child_id', 'full_name'],
          raw: true,
        });

        const childById = children.reduce((acc, c) => {
          acc[c.child_id] = c;
          return acc;
        }, {});

        const sessionById = sessions.reduce((acc, s) => {
          acc[s.session_id] = s;
          return acc;
        }, {});

        // Build a small timeline (last 10 allocations)
        const allocationsForTimeline = allocations.slice(0, 10);

        timeline = allocationsForTimeline.map((a) => {
          const invoice = invoices.find((i) => i.invoice_id === a.invoice_id);
          const session = invoice ? sessionById[invoice.session_id] : null;
          const child = session ? childById[session.child_id] : null;
          const donation = donations.find((d) => d.donation_id === a.donation_id);

          return {
            allocation_id: a.allocation_id,
            amount: parseFloat(a.amount_allocated || 0),
            date: a.created_at,
            child_name: child ? child.full_name : null,
            session_type: session ? session.session_type : null,
            campaign_id: donation ? donation.campaign_id : null,
          };
        });
      }
    }

    return res.status(200).json({
      success: true,
      data: {
        totalDonationsAmount,
        totalAllocatedAmount,
        sessionsSupportedCount,
        childrenSupportedCount,
        timeline,
      },
    });
  } catch (error) {
    console.error('Error fetching donation impact:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch donation impact',
      error: error.message,
    });
  }
};

// Confirm donation after returning from Stripe Checkout using session_id
exports.confirmDonationFromStripe = async (req, res) => {
  try {
    const donorId = req.user.user_id;
    const { session_id } = req.body;

    if (!session_id) {
      return res.status(400).json({
        success: false,
        message: 'session_id is required',
      });
    }

    const session = await stripe.checkout.sessions.retrieve(session_id);

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'Checkout session not found',
      });
    }

    if (session.payment_status !== 'paid') {
      return res.status(400).json({
        success: false,
        message: `Payment not completed (status: ${session.payment_status})`,
      });
    }

    const md = session.metadata || {};
    const institutionId = parseInt(md.institution_id || '0', 10);
    const campaignId = md.campaign_id ? parseInt(md.campaign_id, 10) : null;
    const amountFromMetadata = md.amount ? parseFloat(md.amount) : null;

    if (!institutionId || !Number.isFinite(institutionId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or missing institution in session metadata',
      });
    }

    // Basic safety check: donor from token should match metadata if present
    if (md.donor_id && String(donorId) !== String(md.donor_id)) {
      return res.status(403).json({
        success: false,
        message: 'This donation session does not belong to the current user',
      });
    }

    const institution = await Institution.findByPk(institutionId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found',
      });
    }

    const amount =
      amountFromMetadata && Number.isFinite(amountFromMetadata)
        ? amountFromMetadata
        : session.amount_total
        ? session.amount_total / 100
        : 0;

    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid donation amount from session',
      });
    }

    const donation = await Donation.create({
      donor_id: donorId,
      institution_id: institutionId,
      campaign_id: campaignId || null,
      amount,
    });

    const currentBalance = parseFloat(institution.donation_balance || 0);
    const newBalance = currentBalance + amount;
    await institution.update({ donation_balance: newBalance });

    return res.status(201).json({
      success: true,
      message: 'Donation confirmed and recorded successfully',
      donation_id: donation.donation_id,
    });
  } catch (error) {
    console.error('Error confirming donation from Stripe:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to confirm donation',
      error: error.message,
    });
  }
};

// Get donation history for the current donor
exports.getDonationHistory = async (req, res) => {
  try {
    const donorId = req.user.user_id;
    const { page = 1, limit = 10 } = req.query;
    const pageNum = parseInt(page, 10) || 1;
    const limitNum = parseInt(limit, 10) || 10;
    const offset = (pageNum - 1) * limitNum;

    const donations = await Donation.findAll({
      where: { donor_id: donorId },
      order: [['date', 'DESC']],
      offset,
      limit: limitNum,
      raw: true,
    });

    const enriched = await Promise.all(
      donations.map(async (d) => {
        const institution = await Institution.findByPk(d.institution_id, {
          attributes: ['institution_id', 'name', 'city'],
        });

        let campaign = null;
        if (d.campaign_id) {
          campaign = await DonationCampaign.findByPk(d.campaign_id, {
            attributes: ['campaign_id', 'name', 'status'],
          });
        }

        return {
          donation_id: d.donation_id,
          amount: parseFloat(d.amount || 0),
          date: d.date,
          institution: institution
            ? {
                institution_id: institution.institution_id,
                name: institution.name,
                city: institution.city,
              }
            : null,
          campaign: campaign
            ? {
                campaign_id: campaign.campaign_id,
                name: campaign.name,
                status: campaign.status,
              }
            : null,
        };
      })
    );

    const total = await Donation.count({ where: { donor_id: donorId } });

    return res.status(200).json({
      success: true,
      data: enriched,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('Error fetching donation history:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch donation history',
      error: error.message,
    });
  }
};

// Get comprehensive donation statistics for manager's institution
// Get comprehensive donation statistics for manager's institution
exports.getDonationStatistics = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const institution = await getManagerInstitution(managerId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const institutionId = institution.institution_id;

    // 1. إحصائيات أساسية
    const totalDonations = await Donation.sum('amount', {
      where: { institution_id: institutionId }
    });

    const totalDonors = await Donation.count({
      where: { institution_id: institutionId },
      distinct: true,
      col: 'donor_id'
    });

    // 2. متوسط التبرع
    const avgDonation = await Donation.findOne({
      where: { institution_id: institutionId },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('amount')), 'avg_amount']
      ],
      raw: true
    });

    // 3. أعلى متبرع
    const topDonorQuery = `
      SELECT 
        donor_id,
        SUM(amount) as total_amount,
        COUNT(donation_id) as donation_count
      FROM Donations
      WHERE institution_id = ?
      GROUP BY donor_id
      ORDER BY total_amount DESC
      LIMIT 1
    `;
    
    const [topDonor] = await sequelize.query(topDonorQuery, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    // 4. إحصائيات زمنية (آخر 30 يوم)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const recentDonations = await Donation.sum('amount', {
      where: {
        institution_id: institutionId,
        date: { [Op.gte]: thirtyDaysAgo }
      }
    });

    const recentDonors = await Donation.count({
      where: {
        institution_id: institutionId,
        date: { [Op.gte]: thirtyDaysAgo }
      },
      distinct: true,
      col: 'donor_id'
    });

    // 5. توزيع التبرعات حسب المبلغ (للعروض المرئية)
    const donationDistribution = await Donation.findAll({
      where: { institution_id: institutionId },
      attributes: [
        [sequelize.literal(`
          CASE 
            WHEN amount <= 10 THEN '0-10 JOD'
            WHEN amount <= 50 THEN '11-50 JOD'
            WHEN amount <= 100 THEN '51-100 JOD'
            WHEN amount <= 500 THEN '101-500 JOD'
            ELSE '500+ JOD'
          END
        `), 'range'],
        [sequelize.fn('COUNT', sequelize.col('donation_id')), 'count'],
        [sequelize.fn('SUM', sequelize.col('amount')), 'total']
      ],
      group: [sequelize.literal(`
        CASE 
          WHEN amount <= 10 THEN '0-10 JOD'
          WHEN amount <= 50 THEN '11-50 JOD'
          WHEN amount <= 100 THEN '51-100 JOD'
          WHEN amount <= 500 THEN '101-500 JOD'
          ELSE '500+ JOD'
        END
      `)],
      raw: true
    });

    // 6. أحدث التبرعات (للعرض في القائمة)
    const latestDonationsQuery = `
      SELECT 
        d.donation_id,
        d.amount,
        d.date,
        d.donor_id,
        d.campaign_id,
        u.user_id as id,
        u.full_name as name,
        u.email,
        u.phone,
        u.profile_picture,
        dc.name as campaign_name
      FROM Donations d
      LEFT JOIN Users u ON d.donor_id = u.user_id
      LEFT JOIN DonationCampaigns dc ON d.campaign_id = dc.campaign_id
      WHERE d.institution_id = ?
      ORDER BY d.date DESC
      LIMIT 20
    `;
    
    const latestDonations = await sequelize.query(latestDonationsQuery, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    // 7. تبرعات حسب الحملات
    const donationsByCampaignQuery = `
      SELECT 
        d.campaign_id,
        SUM(d.amount) as total_amount,
        COUNT(d.donation_id) as donation_count,
        dc.name as campaign_name,
        dc.status as campaign_status
      FROM Donations d
      LEFT JOIN DonationCampaigns dc ON d.campaign_id = dc.campaign_id
      WHERE d.institution_id = ? 
        AND d.campaign_id IS NOT NULL
      GROUP BY d.campaign_id, dc.name, dc.status
    `;
    
    const donationsByCampaign = await sequelize.query(donationsByCampaignQuery, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          totalDonations: parseFloat(totalDonations || 0),
          totalDonors: totalDonors || 0,
          avgDonation: parseFloat(avgDonation?.avg_amount || 0),
          recent30Days: {
            amount: parseFloat(recentDonations || 0),
            donors: recentDonors || 0
          }
        },
        topDonor: topDonor ? {
          donor_id: topDonor.donor_id,
          total_amount: parseFloat(topDonor.total_amount || 0),
          donation_count: parseInt(topDonor.donation_count || 0)
        } : null,
        distribution: donationDistribution.map(item => ({
          range: item.range,
          count: parseInt(item.count || 0),
          total: parseFloat(item.total || 0),
          percentage: totalDonations > 0 ? 
            (parseFloat(item.total) / totalDonations * 100).toFixed(1) : 0
        })),
        byCampaign: donationsByCampaign.map(item => ({
          campaign_id: item.campaign_id,
          campaign_name: item.campaign_name,
          campaign_status: item.campaign_status,
          total_amount: parseFloat(item.total_amount || 0),
          donation_count: parseInt(item.donation_count || 0)
        })),
        latestDonations: latestDonations.map(donation => ({
          donation_id: donation.donation_id,
          amount: parseFloat(donation.amount || 0),
          date: donation.date,
          donor: {
            id: donation.id,
            name: donation.name || 'Anonymous',
            email: donation.email,
            phone: donation.phone,
            profile_picture: donation.profile_picture
          },
          campaign: donation.campaign_id ? {
            id: donation.campaign_id,
            name: donation.campaign_name
          } : null
        }))
      
      }
    });

  } catch (error) {
    console.error('Error in getDonationStatistics:', error);
    return res.status(500).json({
      success: false,
      message: 'Error fetching donation statistics',
      error: error.message
    });
  }
};

// Get filtered donation statistics
exports.getFilteredDonationStatistics = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { 
      startDate, 
      endDate, 
      campaignId, 
      minAmount, 
      maxAmount,
      groupBy = 'day' // day, week, month, year
    } = req.query;

    const institution = await getManagerInstitution(managerId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const institutionId = institution.institution_id;

    // بناء where clause
    const whereClause = { institution_id: institutionId };

    if (startDate) {
      whereClause.date = { ...whereClause.date, [Op.gte]: new Date(startDate) };
    }
    if (endDate) {
      whereClause.date = { ...whereClause.date, [Op.lte]: new Date(endDate) };
    }
    if (campaignId) {
      whereClause.campaign_id = parseInt(campaignId);
    }
    if (minAmount) {
      whereClause.amount = { ...whereClause.amount, [Op.gte]: parseFloat(minAmount) };
    }
    if (maxAmount) {
      whereClause.amount = { ...whereClause.amount, [Op.lte]: parseFloat(maxAmount) };
    }

    // تحديد GROUP BY بناءً على groupBy
    let groupByClause;
    switch (groupBy) {
      case 'day':
        groupByClause = [sequelize.fn('DATE', sequelize.col('date'))];
        break;
      case 'week':
        groupByClause = [
          sequelize.fn('YEAR', sequelize.col('date')),
          sequelize.fn('WEEK', sequelize.col('date'))
        ];
        break;
      case 'month':
        groupByClause = [
          sequelize.fn('YEAR', sequelize.col('date')),
          sequelize.fn('MONTH', sequelize.col('date'))
        ];
        break;
      case 'year':
        groupByClause = [sequelize.fn('YEAR', sequelize.col('date'))];
        break;
      default:
        groupByClause = [sequelize.fn('DATE', sequelize.col('date'))];
    }

    // إحصائيات حسب التاريخ
    const timeSeriesStats = await Donation.findAll({
      where: whereClause,
      attributes: [
        ...groupByClause,
        [sequelize.fn('SUM', sequelize.col('amount')), 'total_amount'],
        [sequelize.fn('COUNT', sequelize.col('donation_id')), 'donation_count'],
        [sequelize.fn('COUNT', sequelize.fn('DISTINCT', sequelize.col('donor_id'))), 'donor_count'],
        [sequelize.fn('AVG', sequelize.col('amount')), 'avg_amount']
      ],
      group: groupByClause,
      order: [[groupByClause[0], 'ASC']],
      raw: true
    });

    // إحصائيات إضافية
    const totalStats = await Donation.findOne({
      where: whereClause,
      attributes: [
        [sequelize.fn('SUM', sequelize.col('amount')), 'total_amount'],
        [sequelize.fn('COUNT', sequelize.col('donation_id')), 'donation_count'],
        [sequelize.fn('COUNT', sequelize.fn('DISTINCT', sequelize.col('donor_id'))), 'donor_count'],
        [sequelize.fn('AVG', sequelize.col('amount')), 'avg_amount'],
        [sequelize.fn('MAX', sequelize.col('amount')), 'max_amount'],
        [sequelize.fn('MIN', sequelize.col('amount')), 'min_amount']
      ],
      raw: true
    });

    // أعلى 10 متبرعين في الفترة
    const topDonors = await Donation.findAll({
      where: whereClause,
      attributes: [
        'donor_id',
        [sequelize.fn('SUM', sequelize.col('amount')), 'total_amount'],
        [sequelize.fn('COUNT', sequelize.col('donation_id')), 'donation_count'],
        [sequelize.fn('MAX', sequelize.col('date')), 'last_donation_date']
      ],
      group: ['donor_id'],
      order: [[sequelize.literal('total_amount'), 'DESC']],
      limit: 10,
      raw: true
    });

    // الحصول على أسماء المتبرعين
    const donorIds = topDonors.map(d => d.donor_id).filter(id => id > 0);
    let donorsInfo = {};
    if (donorIds.length > 0) {
      const donors = await User.findAll({
        where: { user_id: { [Op.in]: donorIds } },
        attributes: ['user_id', 'full_name', 'email'],
        raw: true
      });
      donors.forEach(d => {
        donorsInfo[d.user_id] = d;
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        filters: {
          startDate,
          endDate,
          campaignId,
          minAmount,
          maxAmount,
          groupBy
        },
        summary: {
          total_amount: parseFloat(totalStats?.total_amount || 0),
          donation_count: parseInt(totalStats?.donation_count || 0),
          donor_count: parseInt(totalStats?.donor_count || 0),
          avg_amount: parseFloat(totalStats?.avg_amount || 0),
          max_amount: parseFloat(totalStats?.max_amount || 0),
          min_amount: parseFloat(totalStats?.min_amount || 0)
        },
        timeSeries: timeSeriesStats.map(stat => ({
          period: groupBy === 'day' 
            ? stat['DATE(date)']
            : groupBy === 'month'
              ? `${stat['YEAR(date)']}-${String(stat['MONTH(date)']).padStart(2, '0')}`
              : groupBy === 'year'
                ? stat['YEAR(date)']
                : `${stat['YEAR(date)']}-W${String(stat['WEEK(date)']).padStart(2, '0')}`,
          total_amount: parseFloat(stat.total_amount || 0),
          donation_count: parseInt(stat.donation_count || 0),
          donor_count: parseInt(stat.donor_count || 0),
          avg_amount: parseFloat(stat.avg_amount || 0)
        })),
        topDonors: topDonors.map(donor => ({
          donor_id: donor.donor_id,
          donor_info: donorsInfo[donor.donor_id] || { name: 'Anonymous' },
          total_amount: parseFloat(donor.total_amount || 0),
          donation_count: parseInt(donor.donation_count || 0),
          last_donation_date: donor.last_donation_date
        }))
      }
    });

  } catch (error) {
    console.error('Error in getFilteredDonationStatistics:', error);
    return res.status(500).json({
      success: false,
      message: 'Error fetching filtered donation statistics',
      error: error.message
    });
  }
};
