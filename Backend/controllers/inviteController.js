const { Op } = require('sequelize');
const {
  DonationInvite,
  DonationInviteEvent,
  DonationCampaign,
  Institution,
  Donation,
} = require('../model');

function parseIntOr(value, fallback) {
  const n = parseInt(String(value ?? ''), 10);
  return Number.isFinite(n) ? n : fallback;
}

function makeCode() {
  // 12 chars base36
  return Math.random().toString(36).slice(2, 8) + Math.random().toString(36).slice(2, 8);
}

async function ensureUniqueCode() {
  for (let i = 0; i < 5; i++) {
    const code = makeCode();
    const exists = await DonationInvite.findOne({ where: { code } });
    if (!exists) return code;
  }
  // fallback
  return `${Date.now().toString(36)}${makeCode()}`.slice(0, 24);
}

exports.createDonationInvite = async (req, res) => {
  try {
    const inviterUserId = req.user.user_id;

    const institutionId = parseIntOr(req.body.institution_id, null);
    const campaignId = req.body.campaign_id ? parseIntOr(req.body.campaign_id, null) : null;
    const shareMessage = req.body.share_message ? String(req.body.share_message).slice(0, 500) : null;

    if (!institutionId) {
      return res.status(400).json({ success: false, message: 'institution_id is required' });
    }

    const institution = await Institution.findByPk(institutionId, { attributes: ['institution_id', 'name'] });
    if (!institution) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    let campaign = null;
    if (campaignId) {
      campaign = await DonationCampaign.findOne({
        where: { campaign_id: campaignId, institution_id: institutionId },
        attributes: ['campaign_id', 'name', 'status'],
      });
      if (!campaign) {
        return res.status(404).json({ success: false, message: 'Campaign not found for this institution' });
      }
    }

    const code = await ensureUniqueCode();

    const invite = await DonationInvite.create({
      inviter_user_id: inviterUserId,
      institution_id: institutionId,
      campaign_id: campaignId,
      code,
      share_message: shareMessage,
      is_active: true,
      created_at: new Date(),
      updated_at: new Date(),
    });

    return res.status(201).json({
      success: true,
      data: {
        invite_id: invite.invite_id,
        code: invite.code,
        institution_id: institutionId,
        campaign_id: campaignId,
        share_message: invite.share_message,
      },
    });
  } catch (error) {
    console.error('createDonationInvite error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.resolveDonationInvite = async (req, res) => {
  try {
    const code = String(req.params.code ?? '').trim();
    if (!code) {
      return res.status(400).json({ success: false, message: 'code is required' });
    }

    const invite = await DonationInvite.findOne({ where: { code, is_active: true } });
    if (!invite) {
      return res.status(404).json({ success: false, message: 'Invite not found' });
    }

    // Log click
    await DonationInviteEvent.create({
      invite_id: invite.invite_id,
      event_type: 'click',
      referred_user_id: req.user?.user_id ?? null,
      ip_address: req.ip || req.headers['x-forwarded-for'] || req.connection.remoteAddress || '',
      user_agent: req.headers['user-agent'] || '',
      created_at: new Date(),
    });

    const [institution, campaign] = await Promise.all([
      Institution.findByPk(invite.institution_id, { attributes: ['institution_id', 'name', 'city', 'location'] }),
      invite.campaign_id
        ? DonationCampaign.findByPk(invite.campaign_id, {
            attributes: ['campaign_id', 'name', 'description', 'target_amount', 'amount_raised', 'status', 'end_date'],
          })
        : null,
    ]);

    return res.status(200).json({
      success: true,
      data: {
        code: invite.code,
        invite_id: invite.invite_id,
        institution,
        campaign,
        share_message: invite.share_message,
      },
    });
  } catch (error) {
    console.error('resolveDonationInvite error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.getMyDonationInviteStats = async (req, res) => {
  try {
    const inviterUserId = req.user.user_id;

    const invites = await DonationInvite.findAll({
      where: { inviter_user_id: inviterUserId },
      order: [['created_at', 'DESC']],
      raw: true,
    });

    const inviteIds = invites.map((x) => x.invite_id);
    const events = inviteIds.length
      ? await DonationInviteEvent.findAll({
          where: { invite_id: { [Op.in]: inviteIds } },
          attributes: ['invite_id', 'event_type', 'amount', 'currency', 'donation_id', 'created_at'],
          raw: true,
        })
      : [];

    const eventsByInvite = events.reduce((acc, e) => {
      acc[e.invite_id] = acc[e.invite_id] || [];
      acc[e.invite_id].push(e);
      return acc;
    }, {});

    const items = invites.map((inv) => {
      const evs = eventsByInvite[inv.invite_id] || [];
      const clicks = evs.filter((e) => e.event_type === 'click').length;
      const checkouts = evs.filter((e) => e.event_type === 'checkout_started').length;
      const donations = evs.filter((e) => e.event_type === 'donation_completed');
      const donatedAmount = donations.reduce((sum, d) => sum + (parseFloat(d.amount || 0) || 0), 0);

      return {
        ...inv,
        stats: {
          clicks,
          checkouts,
          donations_count: donations.length,
          donated_amount_total: donatedAmount,
        },
      };
    });

    // overall
    const totalClicks = events.filter((e) => e.event_type === 'click').length;
    const totalCheckouts = events.filter((e) => e.event_type === 'checkout_started').length;
    const totalDonations = events.filter((e) => e.event_type === 'donation_completed');
    const totalDonatedAmount = totalDonations.reduce((sum, d) => sum + (parseFloat(d.amount || 0) || 0), 0);

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          invites_count: invites.length,
          clicks: totalClicks,
          checkouts: totalCheckouts,
          donations_count: totalDonations.length,
          donated_amount_total: totalDonatedAmount,
        },
        items,
      },
    });
  } catch (error) {
    console.error('getMyDonationInviteStats error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// Internal helper used by webhook to mark a donation as completed for an invite
exports._markInviteDonationCompleted = async ({ inviteId, stripeSessionId, donationId, amount, currency }) => {
  if (!inviteId) return;

  // Try to find prior checkout event for this session
  const prior = stripeSessionId
    ? await DonationInviteEvent.findOne({
        where: { invite_id: inviteId, event_type: 'checkout_started', stripe_session_id: String(stripeSessionId) },
        order: [['event_id', 'DESC']],
      })
    : null;

  // Avoid duplicates: if we already have a completed event for this donation/session
  const exists = await DonationInviteEvent.findOne({
    where: {
      invite_id: inviteId,
      event_type: 'donation_completed',
      ...(donationId ? { donation_id: donationId } : {}),
      ...(stripeSessionId ? { stripe_session_id: String(stripeSessionId) } : {}),
    },
  });
  if (exists) return;

  await DonationInviteEvent.create({
    invite_id: inviteId,
    event_type: 'donation_completed',
    donation_id: donationId || null,
    stripe_session_id: stripeSessionId ? String(stripeSessionId) : prior?.stripe_session_id || null,
    amount: amount != null ? amount : null,
    currency: currency != null ? String(currency).toUpperCase() : null,
    created_at: new Date(),
  });
};
