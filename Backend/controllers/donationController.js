const {
  Donation,
  Manager,
  User,
  Institution,
  DonationCampaign,
  DonationAllocation,
  Invoice,
  Session,
  Child,
  EquipmentDonation,
  InstitutionEquipmentInventory,
  EquipmentAllocation,
  ChildEquipmentNeed,
  ImpactPost,
  DonationInvite,
  DonationInviteEvent,
} = require('../model');
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


exports.confirmDonation = async (req, res) => {
  try {
    const { session_id } = req.body;

    console.log('🔍 Confirm donation called with session:', session_id);

    if (!session_id) {
      return res.status(400).json({
        success: false,
        message: 'Session ID is required'
      });
    }

    const donation = await Donation.findOne({
      where: { stripe_session_id: session_id },
      include: [
        {
          model: Institution,
          attributes: ['institution_id', 'name', 'city', 'location', 'donation_balance']
        },
        {
          model: DonationCampaign,
          attributes: ['campaign_id', 'name', 'amount_raised'],
          required: false
        }
      ]
    });

    console.log('📦 Donation found:', donation ? donation.donation_id : 'NOT FOUND');

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: 'Donation not found. Please check the session ID or try again later.'
      });
    }

    if (donation.status === 'completed') {
      return res.status(200).json({
        success: true,
        message: 'Donation already confirmed',
        donation: {
          donation_id: donation.donation_id,
          amount: donation.amount,
          currency: donation.currency,
          status: donation.status,
          payment_status: donation.payment_status,
          payment_date: donation.payment_date,
          institution: donation.Institution,
          campaign: donation.DonationCampaign
        }
      });
    }

    let stripeSession;
    try {
      stripeSession = await stripe.checkout.sessions.retrieve(session_id, {
        expand: ['payment_intent', 'customer', 'subscription', 'invoice']
      });

      console.log('💳 Stripe session status:', stripeSession.payment_status);
    } catch (stripeError) {
      console.error('❌ Stripe error:', stripeError);
      return res.status(500).json({
        success: false,
        message: 'Failed to verify payment with Stripe. Please try again.'
      });
    }

    if (stripeSession.payment_status !== 'paid') {
      await donation.update({
        status: 'pending',
        payment_status: stripeSession.payment_status || 'unpaid'
      });

      return res.status(400).json({
        success: false,
        message: 'Payment not completed yet',
        payment_status: stripeSession.payment_status,
        donation_id: donation.donation_id
      });
    }

    const updateData = {
      status: 'completed',
      payment_status: 'paid',
      payment_date: new Date(),
      stripe_payment_intent_id:
        typeof stripeSession.payment_intent === 'string'
          ? stripeSession.payment_intent
          : stripeSession.payment_intent?.id || null,
      stripe_customer_id:
        typeof stripeSession.customer === 'string'
          ? stripeSession.customer
          : stripeSession.customer?.id || null,
      stripe_subscription_id:
        typeof stripeSession.subscription === 'string'
          ? stripeSession.subscription
          : stripeSession.subscription?.id || null,
      receipt_url: stripeSession.invoice?.receipt_url || null
    };

    await donation.update(updateData);

    const institution = await Institution.findByPk(donation.institution_id);
    if (institution) {
      const newBalance =
        parseFloat(institution.donation_balance || 0) + parseFloat(donation.amount);
      await institution.update({
        donation_balance: newBalance,
        last_donation_date: new Date()
      });
      console.log(`💰 Institution balance updated: ${newBalance} JOD`);
    }

    if (donation.campaign_id) {
      const campaign = await DonationCampaign.findByPk(donation.campaign_id);
      if (campaign) {
        const newRaised =
          parseFloat(campaign.amount_raised || 0) + parseFloat(donation.amount);
        await campaign.update({
          amount_raised: newRaised,
          last_donation_date: new Date()
        });
        console.log(`🎯 Campaign amount updated: ${newRaised} JOD`);
      }
    }

    try {
      await sendDonationSuccessNotification(donation, stripeSession);
    } catch (notifError) {
      console.error('Notification error:', notifError);
    }

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
        stripe_payment_intent_id: stripeSession.payment_intent?.id || stripeSession.payment_intent
      }
    });
  } catch (error) {
    console.error('❌ Error confirming donation:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to confirm donation. Please try again or contact support.',
      error: error.message,
      error_type: error.name,
      timestamp: new Date().toISOString()
    });
  }
};

exports.getManagerDonationImpactV2 = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institution = await getManagerInstitution(managerId);
    if (!institution) {
      return res.status(404).json({ success: false, message: 'Manager or institution not found' });
    }

    const institutionId = institution.institution_id;

    const paidDonationWhere = {
      institution_id: institutionId,
      status: 'completed',
      payment_status: 'paid',
    };

    const donationAgg = await Donation.findOne({
      where: paidDonationWhere,
      attributes: [[Donation.sequelize.fn('SUM', Donation.sequelize.col('amount')), 'total']],
      raw: true,
    });
    const totalDonationsAmount = parseFloat(donationAgg?.total || 0);

    const paidDonations = await Donation.findAll({
      where: paidDonationWhere,
      attributes: ['donation_id'],
      raw: true,
    });
    const paidDonationIds = paidDonations.map((d) => d.donation_id);

    const allocations = await DonationAllocation.findAll({
      where: {
        institution_id: institutionId,
        ...(paidDonationIds.length ? { donation_id: { [Op.in]: paidDonationIds } } : { donation_id: -1 }),
      },
      attributes: ['allocation_id', 'donation_id', 'invoice_id', 'amount_allocated', 'created_at'],
      order: [['created_at', 'DESC']],
      raw: true,
    });

    const totalAllocatedAmount = allocations.reduce(
      (sum, a) => sum + parseFloat(a.amount_allocated || 0),
      0,
    );

    const invoiceIds = [...new Set(allocations.map((a) => a.invoice_id).filter((id) => !!id))];
    let sessionsSupportedCount = 0;
    let childrenSupportedCount = 0;
    let moneyTimeline = [];

    if (invoiceIds.length) {
      const invoices = await Invoice.findAll({
        where: { invoice_id: { [Op.in]: invoiceIds } },
        attributes: ['invoice_id', 'session_id'],
        raw: true,
      });

      const sessionIds = [...new Set(invoices.map((i) => i.session_id).filter((id) => !!id))];
      sessionsSupportedCount = sessionIds.length;

      if (sessionIds.length) {
        const sessions = await Session.findAll({
          where: { session_id: { [Op.in]: sessionIds } },
          attributes: ['session_id', 'child_id', 'date', 'session_type'],
          raw: true,
        });

        const childIds = [...new Set(sessions.map((s) => s.child_id).filter((id) => !!id))];
        childrenSupportedCount = childIds.length;

        const children = childIds.length
          ? await Child.findAll({
              where: { child_id: { [Op.in]: childIds } },
              attributes: ['child_id', 'full_name'],
              raw: true,
            })
          : [];

        const childById = children.reduce((acc, c) => {
          acc[c.child_id] = c;
          return acc;
        }, {});
        const sessionById = sessions.reduce((acc, s) => {
          acc[s.session_id] = s;
          return acc;
        }, {});

        moneyTimeline = allocations.slice(0, 10).map((a) => {
          const invoice = invoices.find((i) => i.invoice_id === a.invoice_id);
          const session = invoice ? sessionById[invoice.session_id] : null;
          const child = session ? childById[session.child_id] : null;
          return {
            allocation_id: a.allocation_id,
            amount: parseFloat(a.amount_allocated || 0),
            date: a.created_at,
            child_name: child ? child.full_name : null,
            session_type: session ? session.session_type : null,
          };
        });
      }
    }

    const moneyImpact = {
      totalDonationsAmount,
      totalAllocatedAmount,
      donationBalance: parseFloat(institution.donation_balance || 0),
      sessionsSupportedCount,
      childrenSupportedCount,
      timeline: moneyTimeline,
    };

    const equipmentDonations = await EquipmentDonation.findAll({
      where: { institution_id: institutionId },
      attributes: ['equipment_donation_id', 'donor_id', 'equipment_name', 'status', 'estimated_value', 'created_at', 'actual_delivery_date'],
      order: [['created_at', 'DESC']],
      raw: true,
    });

    const equipmentDonationIds = equipmentDonations.map((d) => d.equipment_donation_id);
    const equipmentEstimatedValueTotal = equipmentDonations.reduce(
      (sum, d) => sum + (parseFloat(d.estimated_value || 0) || 0),
      0,
    );

    const inventoryItems = await InstitutionEquipmentInventory.findAll({
      where: {
        institution_id: institutionId,
        ...(equipmentDonationIds.length ? { source_donation_id: { [Op.in]: equipmentDonationIds } } : {}),
      },
      attributes: ['inventory_item_id', 'institution_id', 'equipment_name', 'category_id', 'usage_type', 'source_donation_id', 'created_at'],
      raw: true,
    });

    const inventoryItemIds = inventoryItems.map((x) => x.inventory_item_id);
    const equipmentAllocations = inventoryItemIds.length
      ? await EquipmentAllocation.findAll({
          where: { institution_id: institutionId, inventory_item_id: { [Op.in]: inventoryItemIds } },
          attributes: ['allocation_id', 'institution_id', 'inventory_item_id', 'need_id', 'child_id', 'allocation_mode', 'usage_type', 'status', 'created_at'],
          order: [['created_at', 'DESC']],
          raw: true,
        })
      : [];

    const allocationNeedIds = [...new Set(equipmentAllocations.map((a) => a.need_id).filter((x) => !!x))];
    const allocationChildIds = [...new Set(equipmentAllocations.map((a) => a.child_id).filter((x) => !!x))];

    const [needs, eqChildren] = await Promise.all([
      allocationNeedIds.length
        ? ChildEquipmentNeed.findAll({
            where: { need_id: { [Op.in]: allocationNeedIds } },
            attributes: ['need_id', 'child_id', 'equipment_name', 'equipment_type', 'severity', 'priority_score', 'status'],
            raw: true,
          })
        : [],
      allocationChildIds.length
        ? Child.findAll({
            where: { child_id: { [Op.in]: allocationChildIds } },
            attributes: ['child_id', 'full_name'],
            raw: true,
          })
        : [],
    ]);

    const needById = (needs || []).reduce((acc, n) => {
      acc[n.need_id] = n;
      return acc;
    }, {});
    const childById = (eqChildren || []).reduce((acc, c) => {
      acc[c.child_id] = c;
      return acc;
    }, {});
    const inventoryById = inventoryItems.reduce((acc, it) => {
      acc[it.inventory_item_id] = it;
      return acc;
    }, {});
    const donationById = equipmentDonations.reduce((acc, d) => {
      acc[d.equipment_donation_id] = d;
      return acc;
    }, {});

    const equipmentTimeline = [...equipmentAllocations.slice(0, 10)].map((a) => {
      const inv = inventoryById[a.inventory_item_id] || null;
      const donation = inv?.source_donation_id ? donationById[inv.source_donation_id] : null;
      const need = a.need_id ? needById[a.need_id] || null : null;
      const child = a.child_id ? childById[a.child_id] || null : null;
      return {
        allocation_id: a.allocation_id,
        status: a.status,
        date: a.created_at,
        inventory_item_id: a.inventory_item_id,
        equipment_donation_id: donation ? donation.equipment_donation_id : inv?.source_donation_id || null,
        equipment_name: inv?.equipment_name || donation?.equipment_name || null,
        need_id: a.need_id,
        need,
        child_id: a.child_id,
        child_name: child ? child.full_name : null,
      };
    });

    const equipmentImpact = {
      total_count: equipmentDonations.length,
      delivered_count: equipmentDonations.filter((d) => d.status === 'delivered').length,
      pending_count: equipmentDonations.filter((d) => ['pending', 'approved', 'scheduled'].includes(d.status)).length,
      rejected_or_cancelled_count: equipmentDonations.filter((d) => ['rejected', 'cancelled'].includes(d.status)).length,
      estimated_value_total: equipmentEstimatedValueTotal,
      inventory_items_count: inventoryItems.length,
      allocated_count: equipmentAllocations.length,
      delivered_allocation_count: equipmentAllocations.filter((a) => a.status === 'delivered').length,
      needs_supported_count: new Set(equipmentAllocations.map((a) => a.need_id).filter((x) => !!x)).size,
      children_supported_count: new Set(equipmentAllocations.map((a) => a.child_id).filter((x) => !!x)).size,
      timeline: equipmentTimeline,
    };

    const [postsTotal, postsPublished] = await Promise.all([
      ImpactPost.count({ where: { institution_id: institutionId } }),
      ImpactPost.count({ where: { institution_id: institutionId, is_published: true } }),
    ]);

    const postsStats = {
      total: postsTotal,
      published: postsPublished,
      drafts: Math.max(0, postsTotal - postsPublished),
    };

    return res.status(200).json({
      success: true,
      data: {
        institution: {
          institution_id: institutionId,
          name: institution.name,
        },
        money_impact: moneyImpact,
        equipment_impact: equipmentImpact,
        impact_posts: postsStats,
      },
    });
  } catch (error) {
    console.error('Error fetching manager donation impact v2:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch impact',
      error: error.message,
    });
  }
};

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
        status: 'active', 
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
      data: campaigns, 
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
    let donorId = null;
    let donorEmail = '';
    let donorName = '';

    if (req.user && req.user.user_id) {
      donorId = req.user.user_id;
      donorEmail = req.user.email || '';
      donorName = req.user.full_name || '';
    } else {
      const { donor_email, donor_name } = req.body;
      
      if (donor_email && donor_name) {
        donorEmail = donor_email;
        donorName = donor_name;
      }
    }

    const { 
      institution_id, 
      amount, 
      campaign_id, 
      mode, 
      currency = 'jod', 
      anonymous = false, 
      invite_code,
      platform 
    } = req.body;

    if (!institution_id || !amount) {
      return res.status(400).json({
        success: false,
        message: 'institution_id and amount are required'
      });
    }

    const parsedInstitutionId = parseInt(institution_id, 10);
    if (!Number.isFinite(parsedInstitutionId) || parsedInstitutionId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Valid institution id is required'
      });
    }

    const parsedAmount = parseFloat(amount);
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Amount must be a positive number'
      });
    }

    const MIN_DONATION = parseFloat(process.env.MIN_DONATION_AMOUNT) || 1;
    const MAX_DONATION = parseFloat(process.env.MAX_DONATION_AMOUNT) || 10000;
    
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

    const allowedCurrencies = (process.env.ALLOWED_CURRENCIES || 'usd,eur,gbp,jod').split(',');
    if (!allowedCurrencies.includes(currency.toLowerCase())) {
      return res.status(400).json({
        success: false,
        message: `Currency not supported. Allowed currencies: ${allowedCurrencies.join(', ')}`
      });
    }

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

        if (campaign.end_date && new Date(campaign.end_date) < new Date()) {
          return res.status(400).json({
            success: false,
            message: 'This campaign has ended'
          });
        }
      }
    }

    let invite = null;
    let inviteId = null;
    const inviteCodeStr = (invite_code ?? '').toString().trim();
    
    if (inviteCodeStr) {
      invite = await DonationInvite.findOne({
        where: {
          code: inviteCodeStr,
          is_active: true,
        },
        raw: true,
      });

      if (!invite) {
        return res.status(404).json({ 
          success: false, 
          message: 'Invalid invite code' 
        });
      }

      if (parseInt(invite.institution_id, 10) !== parsedInstitutionId) {
        return res.status(400).json({ 
          success: false, 
          message: 'Invite code does not match this institution' 
        });
      }

      if (invite.campaign_id && parsedCampaignId && parseInt(invite.campaign_id, 10) !== parsedCampaignId) {
        return res.status(400).json({ 
          success: false, 
          message: 'Invite code does not match this campaign' 
        });
      }

      if (invite.campaign_id && !parsedCampaignId) {
        return res.status(400).json({ 
          success: false, 
          message: 'This invite is tied to a campaign; campaign_id is required' 
        });
      }

      inviteId = invite.invite_id;
    }

    const donationMode = (mode === 'monthly' || mode === 'recurring') ? 'monthly' : 'one_time';
    
    if (donationMode === 'monthly' && parsedAmount > 1000) {
      return res.status(400).json({
        success: false,
        message: 'Maximum monthly donation amount is 1000 JOD'
      });
    }

    const metadata = {
      donor_id: donorId ? String(donorId) : 'anonymous',
      donor_email: donorEmail || '',
      donor_name: donorName || '',
      anonymous: String(anonymous === true),
      institution_id: String(parsedInstitutionId),
      institution_name: institution.name,
      campaign_id: parsedCampaignId ? String(parsedCampaignId) : '',
      campaign_name: campaign ? campaign.name : '',
      amount: String(parsedAmount),
      currency: currency.toLowerCase(),
      mode: donationMode,
      timestamp: new Date().toISOString(),
      ip_address: req.ip || req.headers['x-forwarded-for'] || req.connection.remoteAddress || '',
      user_agent: req.headers['user-agent'] || '',
      invite_code: inviteCodeStr || '',
      platform: platform || 'web',
    };

    const isMobile = 
      platform === 'mobile' || 
      req.body.platform === 'mobile' ||
      req.headers['x-platform'] === 'mobile' ||
      req.headers['user-agent']?.toLowerCase().includes('jusoormobile');

    console.log('🔍 Request details:');
    console.log('   Platform from body:', req.body.platform);
    console.log('   User-Agent:', req.headers['user-agent']);
    console.log('   X-Platform header:', req.headers['x-platform']);
    console.log('   Detected as mobile:', isMobile);

    if (isMobile) {
      console.log('📱 Creating Payment Intent for mobile...');
      
      try {
        const paymentIntent = await stripe.paymentIntents.create({
          amount: Math.round(parsedAmount * 100),
          currency: currency.toLowerCase(),
          automatic_payment_methods: {
            enabled: true,
          },
          metadata: metadata,
          description: campaign 
            ? `Donation to ${institution.name} - ${campaign.name}`
            : `Donation to ${institution.name}`,
          receipt_email: donorEmail || null,
        });

        const donation = await Donation.create({
          donor_id: donorId,
          institution_id: parsedInstitutionId,
          campaign_id: parsedCampaignId || null,
          amount: parsedAmount,
          currency: currency.toLowerCase(),
          status: 'pending',
          payment_method: 'stripe',
          stripe_payment_intent_id: paymentIntent.id,
          donation_type: donationMode,
          ip_address: metadata.ip_address,
          user_agent: metadata.user_agent,
          anonymous_donor: anonymous || !donorId,
          donor_email: donorEmail || null,
          donor_name: donorName || null,
        });

        console.log('✅ Payment Intent created successfully');
        console.log('   Payment Intent ID:', paymentIntent.id);
        console.log('   Client Secret:', paymentIntent.client_secret.substring(0, 20) + '...');

        return res.status(200).json({
          success: true,
          payment_intent_client_secret: paymentIntent.client_secret,
          payment_intent_id: paymentIntent.id,
          donation_id: donation.donation_id,
          amount: parsedAmount,
          currency: currency.toLowerCase(),
          anonymous: donation.anonymous_donor,
          message: 'Payment Intent created successfully',
          instructions: {
            for_mobile: 'Use this client_secret to initialize Stripe Payment Sheet',
            note: anonymous ? 'Your donation will be recorded as anonymous' : 'Thank you for your donation!'
          }
        });

      } catch (stripeError) {
        console.error('❌ Stripe Payment Intent error:', stripeError);
        return res.status(500).json({
          success: false,
          message: 'Failed to create payment intent',
          error: stripeError.message,
          type: stripeError.type,
        });
      }
    }

    console.log('💻 Creating Checkout Session for web...');

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
          donation_type: donationMode,
          anonymous: String(anonymous === true)
        }
      },
      unit_amount: Math.round(parsedAmount * 100),
    };

    if (donationMode === 'monthly') {
      lineItemPriceData.recurring = { 
        interval: 'month',
        interval_count: 1
      };
    }

    const sessionConfig = {
      payment_method_types: ['card'],
      line_items: [{
        price_data: lineItemPriceData,
        quantity: 1,
      }],
      mode: donationMode === 'monthly' ? 'subscription' : 'payment',
      success_url: `${process.env.FRONTEND_URL}/donations/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.FRONTEND_URL}/donations/cancel`,
      metadata: metadata,
      billing_address_collection: 'auto',
      allow_promotion_codes: true,
      expires_at: Math.floor(Date.now() / 1000) + 3600, 
      submit_type: 'donate',
      locale: 'auto',
    };

    if (donorEmail) {
      sessionConfig.customer_email = donorEmail;
    }

    if (donationMode === 'monthly') {
      sessionConfig.subscription_data = {
        metadata: metadata,
        description: `Monthly donation to ${institution.name}`
      };
    }

    try {
      const session = await stripe.checkout.sessions.create(sessionConfig);

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
        expires_at: new Date(session.expires_at * 1000),
        anonymous_donor: anonymous || !donorId,
        donor_email: donorEmail || null,
        donor_name: donorName || null,
      });

      if (inviteId) {
        try {
          await DonationInviteEvent.create({
            invite_id: inviteId,
            event_type: 'checkout_started',
            referred_user_id: donorId || null,
            donation_id: donation.donation_id,
            stripe_session_id: session.id,
            amount: parsedAmount,
            currency: currency.toLowerCase(),
            ip_address: metadata.ip_address,
            user_agent: metadata.user_agent,
            created_at: new Date(),
          });
        } catch (e) {
          console.warn('Failed to log invite checkout_started:', e.message);
        }
      }

      console.log('✅ Checkout Session created:', session.id);

      return res.status(200).json({
        success: true,
        url: session.url,
        sessionId: session.id,
        donation_id: donation.donation_id,
        anonymous: donation.anonymous_donor,
        instructions: {
          for_web: 'You will be redirected to Stripe to complete your payment',
          note: anonymous ? 'Your donation will be recorded as anonymous' : 'Thank you for your donation!'
        }
      });

    } catch (stripeError) {
      console.error('❌ Stripe Checkout Session error:', stripeError);
      return res.status(500).json({
        success: false,
        message: 'Failed to create checkout session',
        error: stripeError.message,
        type: stripeError.type,
      });
    }

  } catch (error) {
    console.error('❌ Error in createDonationCheckout:', error);
    
    let statusCode = 500;
    let errorMessage = 'Failed to create donation checkout';
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
      support_contact: 'support@jusoor.com'
    });
  }
};


exports.confirmDonationPayment = async (req, res) => {
  try {
    const { payment_intent_id, donation_id } = req.body;

    console.log('🔍 Confirming payment:', payment_intent_id);

    if (!payment_intent_id) {
      return res.status(400).json({
        success: false,
        message: 'Payment Intent ID is required'
      });
    }

    let paymentIntent;
    try {
      paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id);
    } catch (stripeError) {
      console.error('❌ Stripe error:', stripeError);
      return res.status(500).json({
        success: false,
        message: 'Failed to verify payment with Stripe',
        error: stripeError.message,
      });
    }

    console.log('💳 Payment Intent status:', paymentIntent.status);

    if (paymentIntent.status !== 'succeeded') {
      return res.status(400).json({
        success: false,
        message: 'Payment not completed yet',
        status: paymentIntent.status,
      });
    }

    let donation;
    if (donation_id) {
      donation = await Donation.findByPk(donation_id);
    } else {
      donation = await Donation.findOne({
        where: { stripe_payment_intent_id: payment_intent_id }
      });
    }

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: 'Donation not found',
      });
    }

    console.log('📦 Donation found:', donation.donation_id);

    if (donation.status === 'completed') {
      return res.status(200).json({
        success: true,
        message: 'Donation already confirmed',
        donation: {
          donation_id: donation.donation_id,
          amount: donation.amount,
          status: donation.status,
        }
      });
    }

    await donation.update({
      status: 'completed',
      payment_status: 'paid',
      payment_date: new Date(),
      receipt_url: paymentIntent.charges?.data[0]?.receipt_url || null,
    });

    const institution = await Institution.findByPk(donation.institution_id);
    if (institution) {
      const newBalance = parseFloat(institution.donation_balance || 0) + 
                        parseFloat(donation.amount);
      await institution.update({
        donation_balance: newBalance,
        last_donation_date: new Date()
      });
      console.log(`💰 Institution balance updated: ${newBalance} JOD`);
    }

    if (donation.campaign_id) {
      const campaign = await DonationCampaign.findByPk(donation.campaign_id);
      if (campaign) {
        const newRaised = parseFloat(campaign.amount_raised || 0) + 
                         parseFloat(donation.amount);
        await campaign.update({
          amount_raised: newRaised,
          last_donation_date: new Date()
        });
        console.log(`🎯 Campaign amount updated: ${newRaised} JOD`);
      }
    }

    try {
      const inviteEvents = await DonationInviteEvent.findAll({
        where: {
          donation_id: donation.donation_id,
          event_type: 'checkout_started'
        }
      });

      for (const event of inviteEvents) {
        await DonationInviteEvent.create({
          invite_id: event.invite_id,
          event_type: 'donation_completed',
          referred_user_id: event.referred_user_id,
          donation_id: donation.donation_id,
          payment_intent_id: payment_intent_id,
          amount: donation.amount,
          currency: donation.currency,
          created_at: new Date(),
        });
      }
    } catch (e) {
      console.warn('Failed to log invite donation_completed:', e.message);
    }

    console.log('✅ Payment confirmed successfully');

    return res.status(200).json({
      success: true,
      message: 'Payment confirmed successfully',
      donation: {
        donation_id: donation.donation_id,
        amount: donation.amount,
        currency: donation.currency,
        status: donation.status,
        payment_date: donation.payment_date,
        receipt_url: donation.receipt_url,
      }
    });

  } catch (error) {
    console.error('❌ Payment confirmation error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to confirm payment',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
};

exports.createAnonymousDonation = async (req, res) => {
  try {
    const { institution_id, amount, campaign_id, donor_email, donor_name, currency = 'jod' } = req.body;

    if (!institution_id || !amount) {
      return res.status(400).json({
        success: false,
        message: 'institution_id and amount are required'
      });
    }

    const institution = await Institution.findByPk(parseInt(institution_id, 10));
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    let isAnonymous = true;
    let donorId = null;
    let email = donor_email || '';
    let name = donor_name || 'Anonymous Donor';

    if (req.user && req.user.user_id) {
      donorId = req.user.user_id;
      email = req.user.email || email;
      name = req.user.full_name || name;
      isAnonymous = false;
    }

    const sessionConfig = {
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency: currency.toLowerCase(),
          product_data: {
            name: `Donation to ${institution.name}`,
            description: 'Thank you for your generous donation',
            metadata: {
              institution_id: String(institution.institution_id),
              institution_name: institution.name,
              anonymous: String(isAnonymous)
            }
          },
          unit_amount: Math.round(parseFloat(amount) * 100),
        },
        quantity: 1,
      }],
      mode: 'payment',
      success_url: `${process.env.FRONTEND_URL}/donations/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.FRONTEND_URL}/donations/cancel`,
      metadata: {
        donor_id: donorId ? String(donorId) : 'anonymous',
        donor_email: email,
        donor_name: name,
        anonymous: String(isAnonymous),
        institution_id: String(institution.institution_id),
        amount: String(amount),
        currency: currency.toLowerCase()
      },
      billing_address_collection: 'auto',
      expires_at: Math.floor(Date.now() / 1000) + 1800,
      submit_type: 'donate',
    };

    if (email) {
      sessionConfig.customer_email = email;
    }

    const session = await stripe.checkout.sessions.create(sessionConfig);

    const donation = await Donation.create({
      donor_id: donorId,
      institution_id: institution.institution_id,
      campaign_id: campaign_id || null,
      amount: parseFloat(amount),
      currency: currency.toLowerCase(),
      status: 'pending',
      stripe_session_id: session.id,
      anonymous_donor: isAnonymous,
      donor_email: email || null,
      donor_name: name || null,
    });

    return res.status(200).json({
      success: true,
      url: session.url,
      sessionId: session.id,
      donation_id: donation.donation_id,
      anonymous: isAnonymous,
      message: 'Anonymous donation checkout created successfully'
    });

  } catch (error) {
    console.error('Error creating anonymous donation:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to create anonymous donation',
      error: error.message
    });
  }
};

async function sendDonationInitiatedEmail(toEmail, data) {

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

exports.createDonation = async (req, res) => {
  try {
    const donorId = req.user ? req.user.user_id : null;
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



exports.getDonationImpact = async (req, res) => {
  try {
    const donorId = req.user.user_id;

    const donationAgg = await Donation.findOne({
      where: { donor_id: donorId },
      attributes: [
        [Donation.sequelize.fn('SUM', Donation.sequelize.col('amount')), 'total'],
      ],
      raw: true,
    });

    const totalDonationsAmount = parseFloat(donationAgg?.total || 0);

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

exports.getDonationImpactV2 = async (req, res) => {
  try {
    const donorId = req.user.user_id;

    const donationAgg = await Donation.findOne({
      where: { donor_id: donorId },
      attributes: [[Donation.sequelize.fn('SUM', Donation.sequelize.col('amount')), 'total']],
      raw: true,
    });

    const totalDonationsAmount = parseFloat(donationAgg?.total || 0);

    const donations = await Donation.findAll({
      where: { donor_id: donorId },
      attributes: ['donation_id', 'campaign_id'],
      raw: true,
    });

    let moneyImpact = {
      totalDonationsAmount,
      totalAllocatedAmount: 0,
      sessionsSupportedCount: 0,
      childrenSupportedCount: 0,
      timeline: [],
    };

    if (donations.length) {
      const donationIds = donations.map((d) => d.donation_id);

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

      if (allocations.length) {
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

        moneyImpact = {
          totalDonationsAmount,
          totalAllocatedAmount,
          sessionsSupportedCount,
          childrenSupportedCount,
          timeline,
        };
      }
    }

    const equipmentDonations = await EquipmentDonation.findAll({
      where: { donor_id: donorId },
      attributes: [
        'equipment_donation_id',
        'institution_id',
        'equipment_name',
        'status',
        'estimated_value',
        'created_at',
        'actual_delivery_date',
      ],
      order: [['created_at', 'DESC']],
      raw: true,
    });

    const equipmentDonationIds = equipmentDonations.map((d) => d.equipment_donation_id);

    const equipmentTotalCount = equipmentDonations.length;
    const equipmentDeliveredCount = equipmentDonations.filter((d) => d.status === 'delivered').length;
    const equipmentPendingCount = equipmentDonations.filter((d) => ['pending', 'approved', 'scheduled'].includes(d.status)).length;
    const equipmentRejectedOrCancelledCount = equipmentDonations.filter((d) => ['rejected', 'cancelled'].includes(d.status)).length;

    const equipmentEstimatedValueTotal = equipmentDonations.reduce(
      (sum, d) => sum + (parseFloat(d.estimated_value || 0) || 0),
      0,
    );

    let allocations = [];
    let inventoryItems = [];
    if (equipmentDonationIds.length) {
      inventoryItems = await InstitutionEquipmentInventory.findAll({
        where: {
          source_donation_id: { [Op.in]: equipmentDonationIds },
        },
        attributes: [
          'inventory_item_id',
          'institution_id',
          'equipment_name',
          'category_id',
          'usage_type',
          'source_donation_id',
          'created_at',
        ],
        raw: true,
      });

      const inventoryItemIds = inventoryItems.map((x) => x.inventory_item_id);
      if (inventoryItemIds.length) {
        allocations = await EquipmentAllocation.findAll({
          where: {
            inventory_item_id: { [Op.in]: inventoryItemIds },
          },
          attributes: [
            'allocation_id',
            'institution_id',
            'inventory_item_id',
            'need_id',
            'child_id',
            'allocation_mode',
            'usage_type',
            'status',
            'delivery_notes',
            'parent_confirmed_at',
            'created_at',
            'updated_at',
          ],
          order: [['created_at', 'DESC']],
          raw: true,
        });
      }
    }

    const inventoryById = inventoryItems.reduce((acc, it) => {
      acc[it.inventory_item_id] = it;
      return acc;
    }, {});

    const allocationNeedIds = [...new Set(allocations.map((a) => a.need_id).filter((x) => !!x))];
    const allocationChildIds = [...new Set(allocations.map((a) => a.child_id).filter((x) => !!x))];

    const [needs, children] = await Promise.all([
      allocationNeedIds.length
        ? ChildEquipmentNeed.findAll({
            where: { need_id: { [Op.in]: allocationNeedIds } },
            attributes: ['need_id', 'child_id', 'equipment_name', 'equipment_type', 'severity', 'priority_score', 'status'],
            raw: true,
          })
        : [],
      allocationChildIds.length
        ? Child.findAll({
            where: { child_id: { [Op.in]: allocationChildIds } },
            attributes: ['child_id', 'full_name'],
            raw: true,
          })
        : [],
    ]);

    const needById = (needs || []).reduce((acc, n) => {
      acc[n.need_id] = n;
      return acc;
    }, {});
    const childById2 = (children || []).reduce((acc, c) => {
      acc[c.child_id] = c;
      return acc;
    }, {});

    const allocatedCount = allocations.length;
    const deliveredAllocationCount = allocations.filter((a) => a.status === 'delivered').length;

    const needsSupportedCount = new Set(allocations.map((a) => a.need_id).filter((x) => !!x)).size;
    const childrenSupportedByEquipmentCount = new Set(allocations.map((a) => a.child_id).filter((x) => !!x)).size;

    const donationById = equipmentDonations.reduce((acc, d) => {
      acc[d.equipment_donation_id] = d;
      return acc;
    }, {});

    const donationEvents = equipmentDonations.map((d) => ({
      event_type: 'equipment_donation',
      date: d.created_at,
      institution_id: d.institution_id,
      equipment_donation_id: d.equipment_donation_id,
      equipment_name: d.equipment_name,
      status: d.status,
      estimated_value: d.estimated_value != null ? parseFloat(d.estimated_value) : null,
      delivered_at: d.actual_delivery_date || null,
    }));

    const inventoryEvents = inventoryItems.map((it) => ({
      event_type: 'inventory_added',
      date: it.created_at,
      institution_id: it.institution_id,
      inventory_item_id: it.inventory_item_id,
      equipment_name: it.equipment_name,
      source_donation_id: it.source_donation_id,
    }));

    const allocationEvents = allocations.map((a) => {
      const inv = inventoryById[a.inventory_item_id] || null;
      const donation = inv?.source_donation_id ? donationById[inv.source_donation_id] : null;
      const need = a.need_id ? needById[a.need_id] || null : null;
      const child = a.child_id ? childById2[a.child_id] || null : null;

      return {
        event_type: 'equipment_allocated',
        date: a.created_at,
        institution_id: a.institution_id,
        allocation_id: a.allocation_id,
        status: a.status,
        inventory_item_id: a.inventory_item_id,
        equipment_donation_id: donation ? donation.equipment_donation_id : inv?.source_donation_id || null,
        equipment_name: inv?.equipment_name || donation?.equipment_name || null,
        need_id: a.need_id,
        need: need,
        child_id: a.child_id,
        child_name: child ? child.full_name : null,
      };
    });

    const equipmentTimeline = [...donationEvents, ...inventoryEvents, ...allocationEvents]
      .filter((e) => !!e.date)
      .sort((a, b) => {
        const ad = new Date(a.date).getTime();
        const bd = new Date(b.date).getTime();
        return bd - ad;
      })
      .slice(0, 10);

    const equipmentImpact = {
      total_count: equipmentTotalCount,
      delivered_count: equipmentDeliveredCount,
      pending_count: equipmentPendingCount,
      rejected_or_cancelled_count: equipmentRejectedOrCancelledCount,
      estimated_value_total: equipmentEstimatedValueTotal,
      allocated_count: allocatedCount,
      delivered_allocation_count: deliveredAllocationCount,
      needs_supported_count: needsSupportedCount,
      children_supported_count: childrenSupportedByEquipmentCount,
      timeline: equipmentTimeline,
    };

    return res.status(200).json({
      success: true,
      data: {
        money_impact: moneyImpact,
        equipment_impact: equipmentImpact,
      },
    });
  } catch (error) {
    console.error('Error fetching donation impact v2:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch donation impact',
      error: error.message,
    });
  }
};

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

    const paidDonationWhere = {
      institution_id: institutionId,
      status: 'completed',
      payment_status: 'paid',
    };

    const totalDonations = await Donation.sum('amount', {
      where: paidDonationWhere,
    });

    const totalDonors = await Donation.count({
      where: paidDonationWhere,
      distinct: true,
      col: 'donor_id'
    });

    const avgDonation = await Donation.findOne({
      where: paidDonationWhere,
      attributes: [
        [sequelize.fn('AVG', sequelize.col('amount')), 'avg_amount']
      ],
      raw: true
    });

    const topDonorQuery = `
      SELECT 
        donor_id,
        SUM(amount) as total_amount,
        COUNT(donation_id) as donation_count
      FROM Donations
      WHERE institution_id = ? AND status = 'completed' AND payment_status = 'paid'
      GROUP BY donor_id
      ORDER BY total_amount DESC
      LIMIT 1
    `;
    
    const [topDonor] = await sequelize.query(topDonorQuery, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const recentDonations = await Donation.sum('amount', {
      where: {
        ...paidDonationWhere,
        date: { [Op.gte]: thirtyDaysAgo }
      }
    });

    const recentDonors = await Donation.count({
      where: {
        ...paidDonationWhere,
        date: { [Op.gte]: thirtyDaysAgo }
      },
      distinct: true,
      col: 'donor_id'
    });

    const donationDistribution = await Donation.findAll({
      where: paidDonationWhere,
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
      WHERE d.institution_id = ? AND d.status = 'completed' AND d.payment_status = 'paid'
      ORDER BY d.date DESC
      LIMIT 20
    `;
    
    const latestDonations = await sequelize.query(latestDonationsQuery, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

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
        AND d.status = 'completed' AND d.payment_status = 'paid'
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


exports.checkDonationBySession = async (req, res) => {
  try {
    const { session_id } = req.query;
    
    console.log('🔍 Checking donation status for session:', session_id);
    
    if (!session_id) {
      return res.status(400).json({
        success: false,
        message: 'Session ID is required'
      });
    }

    const donation = await Donation.findOne({
      where: { stripe_session_id: session_id },
      include: [
        {
          model: Institution,
          attributes: ['institution_id', 'name', 'city']
        },
        {
          model: DonationCampaign,
          attributes: ['campaign_id', 'name'],
          required: false
        }
      ]
    });

    console.log('📦 Donation found:', donation ? donation.donation_id : 'NOT FOUND');

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: 'Donation not found for this session'
      });
    }

    let stripeSession = null;
    if (donation.status === 'pending') {
      try {
        stripeSession = await stripe.checkout.sessions.retrieve(session_id);
      } catch (stripeError) {
        console.error('Stripe retrieval error:', stripeError.message);
      }
    }

    return res.status(200).json({
      success: true,
      donation: {
        donation_id: donation.donation_id,
        amount: donation.amount,
        currency: donation.currency,
        status: donation.status,
        payment_status: donation.payment_status,
        stripe_session_id: donation.stripe_session_id,
        stripe_payment_intent_id: donation.stripe_payment_intent_id,
        payment_date: donation.payment_date,
        institution: donation.Institution,
        campaign: donation.DonationCampaign
      },
      stripe_session: stripeSession ? {
        payment_status: stripeSession.payment_status,
        status: stripeSession.status,
        amount_total: stripeSession.amount_total,
        currency: stripeSession.currency
      } : null,
      instructions: {
        needs_confirmation: donation.status === 'pending',
        can_confirm: donation.status === 'pending',
        is_completed: donation.status === 'completed'
      }
    });

  } catch (error) {
    console.error('❌ Error checking donation by session:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to check donation status',
      error: error.message
    });
  }
};

exports.getFilteredDonationStatistics = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { 
      startDate, 
      endDate, 
      campaignId, 
      minAmount, 
      maxAmount,
      groupBy = 'day'
    } = req.query;

    const institution = await getManagerInstitution(managerId);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const institutionId = institution.institution_id;

    const whereClause = {
      institution_id: institutionId,
      status: 'completed',
      payment_status: 'paid',
    };

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

exports.debugDonations = async (req, res) => {
  try {
    console.log('🔍 Debug: Checking all donations in database...');
    
    const donations = await Donation.findAll({
      attributes: ['donation_id', 'stripe_session_id', 'status', 'amount', 'created_at'],
      order: [['donation_id', 'DESC']],
      limit: 10
    });

    console.log('📊 Last 10 donations in DB:');
    donations.forEach(d => {
      console.log(`   ID: ${d.donation_id}, Session: ${d.stripe_session_id}, Status: ${d.status}, Amount: ${d.amount}`);
    });

    return res.status(200).json({
      success: true,
      donations: donations.map(d => ({
        donation_id: d.donation_id,
        stripe_session_id: d.stripe_session_id,
        status: d.status,
        amount: d.amount,
        created_at: d.created_at
      }))
    });
  } catch (error) {
    console.error('❌ Debug error:', error);
    return res.status(500).json({ error: error.message });
  }
};

async function sendDonationSuccessNotification(donation, stripeSession) {
  try {
    console.log('📧 Sending success notification for donation:', donation.donation_id);
  } catch (error) {
    console.error('❌ Error sending notification:', error);
  }
}

exports.getDonorProfile = async (req, res) => {
  try {
    const donorId = req.user.user_id;

    console.log('🔍 Fetching donor profile for user:', donorId);

    const donor = await User.findByPk(donorId, {
      attributes: [
        'user_id',
        'full_name',
        'email',
        'phone',
        'profile_picture',
        'city',
        'region',
        'location_address',
        'created_at'
      ],
      raw: true
    });

    console.log('📋 Donor found:', donor ? 'Yes' : 'No');

    if (!donor) {
      return res.status(404).json({
        success: false,
        message: 'Donor not found'
      });
    }

    const donationStats = await Donation.findOne({
      where: { donor_id: donorId },
      attributes: [
        [sequelize.fn('COUNT', sequelize.col('donation_id')), 'total_donations'],
        [sequelize.fn('SUM', sequelize.col('amount')), 'total_amount'],
        [sequelize.fn('MAX', sequelize.col('date')), 'last_donation_date']
      ],
      raw: true
    });

    console.log('📊 Donation stats:', donationStats);

    const institutionsDonated = await Donation.findAll({
      where: { donor_id: donorId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name', 'city'],
        required: false
      }],
      attributes: ['institution_id'],
      group: ['institution_id', 'Institution.institution_id', 'Institution.name', 'Institution.city'],
      raw: true,
      nest: true
    });

    const formattedInstitutions = institutionsDonated
      .filter(item => item.Institution)
      .map(item => ({
        institution_id: item.Institution.institution_id,
        name: item.Institution.name,
        city: item.Institution.city
      }));

    const response = {
      success: true,
      data: {
        ...donor,
        stats: {
          total_donations: parseInt(donationStats?.total_donations || 0),
          total_amount: parseFloat(donationStats?.total_amount || 0),
          last_donation_date: donationStats?.last_donation_date
        },
        institutions_donated: formattedInstitutions
      }
    };

    console.log('✅ Sending donor profile response');
    return res.status(200).json(response);
    
  } catch (error) {
    console.error('❌ Error fetching donor profile:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch donor profile',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
};
module.exports = exports;
