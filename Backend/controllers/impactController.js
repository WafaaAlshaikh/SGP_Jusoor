const { Op } = require('sequelize');
const {
  ImpactPost,
  Donation,
  EquipmentDonation,
  Institution,
  DonationCampaign,
  EquipmentDonationCampaign,
} = require('../model');

function parseIntOrDefault(value, defaultValue) {
  const n = parseInt(String(value ?? ''), 10);
  return Number.isFinite(n) ? n : defaultValue;
}

function sanitizeMediaUrls(value) {
  if (!value) return null;
  if (Array.isArray(value)) return value.map(String).filter(Boolean).slice(0, 20);
  if (typeof value === 'string') return [value].filter(Boolean);
  return null;
}

// Public/Donor feed (requires auth): only institutions the donor interacted with (money/equipment)
exports.getDonorImpactFeed = async (req, res) => {
  try {
    const userId = req.user?.user_id;
    if (!userId) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const page = Math.max(1, parseIntOrDefault(req.query.page, 1));
    const limit = Math.min(50, Math.max(1, parseIntOrDefault(req.query.limit, 10)));
    const offset = (page - 1) * limit;

    const campaignId = req.query.campaign_id ? parseIntOrDefault(req.query.campaign_id, 0) : null;
    const equipmentCampaignId = req.query.equipment_campaign_id
      ? parseIntOrDefault(req.query.equipment_campaign_id, 0)
      : null;

    // donor institutions from both money & equipment donations
    const [moneyInstitutions, equipmentInstitutions] = await Promise.all([
      Donation.findAll({
        where: { donor_id: userId },
        attributes: ['institution_id'],
        group: ['institution_id'],
        raw: true,
      }),
      EquipmentDonation.findAll({
        where: { donor_id: userId },
        attributes: ['institution_id'],
        group: ['institution_id'],
        raw: true,
      }),
    ]);

    const institutionIds = Array.from(
      new Set([
        ...(moneyInstitutions || []).map((x) => Number(x.institution_id)),
        ...(equipmentInstitutions || []).map((x) => Number(x.institution_id)),
      ].filter((x) => Number.isFinite(x)))
    );

    if (!institutionIds.length) {
      return res.status(200).json({
        success: true,
        data: {
          items: [],
          pagination: {
            page,
            limit,
            total: 0,
            totalPages: 1,
          },
        },
      });
    }

    const where = {
      institution_id: { [Op.in]: institutionIds },
      is_published: true,
    };

    if (campaignId) where.campaign_id = campaignId;
    if (equipmentCampaignId) where.equipment_campaign_id = equipmentCampaignId;

    const { rows, count } = await ImpactPost.findAndCountAll({
      where,
      order: [['published_at', 'DESC'], ['post_id', 'DESC']],
      limit,
      offset,
      raw: true,
    });

    const instIds = [...new Set(rows.map((r) => r.institution_id).filter((x) => !!x))];
    const campaignIds = [...new Set(rows.map((r) => r.campaign_id).filter((x) => !!x))];
    const eqCampIds = [...new Set(rows.map((r) => r.equipment_campaign_id).filter((x) => !!x))];

    const [institutions, campaigns, equipmentCampaigns] = await Promise.all([
      Institution.findAll({
        where: { institution_id: { [Op.in]: instIds } },
        attributes: ['institution_id', 'name', 'city', 'location'],
        raw: true,
      }),
      campaignIds.length
        ? DonationCampaign.findAll({
            where: { campaign_id: { [Op.in]: campaignIds } },
            attributes: ['campaign_id', 'institution_id', 'name', 'status'],
            raw: true,
          })
        : [],
      eqCampIds.length
        ? EquipmentDonationCampaign.findAll({
            where: { campaign_id: { [Op.in]: eqCampIds } },
            attributes: ['campaign_id', 'institution_id', 'equipment_name', 'status', 'need_id', 'child_id'],
            raw: true,
          })
        : [],
    ]);

    const instById = new Map((institutions || []).map((x) => [Number(x.institution_id), x]));
    const campById = new Map((campaigns || []).map((x) => [Number(x.campaign_id), x]));
    const eqCampById = new Map((equipmentCampaigns || []).map((x) => [Number(x.campaign_id), x]));

    const items = rows.map((r) => {
      const inst = instById.get(Number(r.institution_id)) || null;
      const camp = r.campaign_id ? campById.get(Number(r.campaign_id)) || null : null;
      const eqCamp = r.equipment_campaign_id ? eqCampById.get(Number(r.equipment_campaign_id)) || null : null;

      return {
        post_id: r.post_id,
        institution_id: r.institution_id,
        institution: inst,
        campaign_id: r.campaign_id,
        campaign: camp,
        equipment_campaign_id: r.equipment_campaign_id,
        equipment_campaign: eqCamp,
        need_id: r.need_id,
        type: r.type,
        title: r.title,
        content: r.content,
        cover_url: r.cover_url,
        media_urls: sanitizeMediaUrls(r.media_urls),
        published_at: r.published_at,
        created_at: r.created_at,
      };
    });

    return res.status(200).json({
      success: true,
      data: {
        items,
        pagination: {
          page,
          limit,
          total: count,
          totalPages: Math.max(1, Math.ceil(count / limit)),
        },
      },
    });
  } catch (error) {
    console.error('Error fetching donor impact feed:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};
