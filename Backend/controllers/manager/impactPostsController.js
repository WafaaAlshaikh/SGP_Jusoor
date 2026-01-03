const { Op } = require('sequelize');
const { ImpactPost, Institution, Manager } = require('../../model');

async function getManagerInstitutionId(managerId) {
  const manager = await Manager.findOne({
    where: { manager_id: managerId, is_active: true },
    include: [{ model: Institution, attributes: ['institution_id'] }],
  });

  if (!manager || !manager.Institution) return null;
  return manager.Institution.institution_id;
}

function parseIntOr(value, fallback) {
  const n = parseInt(String(value ?? ''), 10);
  return Number.isFinite(n) ? n : fallback;
}

function sanitizeMediaUrls(value) {
  if (!value) return null;
  if (Array.isArray(value)) return value.map(String).filter(Boolean).slice(0, 20);
  if (typeof value === 'string') return [value].filter(Boolean);
  return null;
}

exports.listImpactPosts = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const page = Math.max(1, parseIntOr(req.query.page, 1));
    const limit = Math.min(50, Math.max(1, parseIntOr(req.query.limit, 20)));
    const offset = (page - 1) * limit;

    const where = { institution_id: institutionId };

    const type = (req.query.type ?? '').toString().trim();
    if (type) where.type = type;

    const { rows, count } = await ImpactPost.findAndCountAll({
      where,
      order: [['published_at', 'DESC'], ['post_id', 'DESC']],
      limit,
      offset,
    });

    const items = rows.map((x) => {
      const obj = x.toJSON ? x.toJSON() : x;
      return {
        ...obj,
        media_urls: sanitizeMediaUrls(obj.media_urls),
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
    console.error('listImpactPosts error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.createImpactPost = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const {
      type = 'update',
      title,
      content,
      cover_url,
      media_urls,
      is_published = true,
      published_at,
      campaign_id,
      equipment_campaign_id,
      need_id,
    } = req.body;

    if (!title || !String(title).trim()) {
      return res.status(400).json({ success: false, message: 'title is required' });
    }

    const created = await ImpactPost.create({
      institution_id: institutionId,
      campaign_id: campaign_id ? parseIntOr(campaign_id, null) : null,
      equipment_campaign_id: equipment_campaign_id ? parseIntOr(equipment_campaign_id, null) : null,
      need_id: need_id ? parseIntOr(need_id, null) : null,
      type,
      title,
      content: content ?? null,
      cover_url: cover_url ?? null,
      media_urls: media_urls ?? null,
      is_published: is_published !== undefined ? !!is_published : true,
      published_at: published_at ?? new Date(),
      created_by_user_id: managerId,
      created_at: new Date(),
      updated_at: new Date(),
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    console.error('createImpactPost error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.updateImpactPost = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const postId = parseIntOr(req.params.postId, 0);
    if (!postId) {
      return res.status(400).json({ success: false, message: 'Valid postId is required' });
    }

    const item = await ImpactPost.findOne({
      where: { post_id: postId, institution_id: institutionId },
    });

    if (!item) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }

    const {
      type,
      title,
      content,
      cover_url,
      media_urls,
      is_published,
      published_at,
      campaign_id,
      equipment_campaign_id,
      need_id,
    } = req.body;

    await item.update({
      type: type !== undefined ? type : item.type,
      title: title !== undefined ? title : item.title,
      content: content !== undefined ? content : item.content,
      cover_url: cover_url !== undefined ? cover_url : item.cover_url,
      media_urls: media_urls !== undefined ? media_urls : item.media_urls,
      is_published: is_published !== undefined ? !!is_published : item.is_published,
      published_at: published_at !== undefined ? published_at : item.published_at,
      campaign_id: campaign_id !== undefined ? (campaign_id ? parseIntOr(campaign_id, null) : null) : item.campaign_id,
      equipment_campaign_id:
        equipment_campaign_id !== undefined
          ? (equipment_campaign_id ? parseIntOr(equipment_campaign_id, null) : null)
          : item.equipment_campaign_id,
      need_id: need_id !== undefined ? (need_id ? parseIntOr(need_id, null) : null) : item.need_id,
      updated_at: new Date(),
    });

    return res.status(200).json({ success: true, data: item });
  } catch (error) {
    console.error('updateImpactPost error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.deleteImpactPost = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const postId = parseIntOr(req.params.postId, 0);
    if (!postId) {
      return res.status(400).json({ success: false, message: 'Valid postId is required' });
    }

    const item = await ImpactPost.findOne({
      where: { post_id: postId, institution_id: institutionId },
    });

    if (!item) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }

    await item.destroy();
    return res.status(200).json({ success: true, message: 'Deleted' });
  } catch (error) {
    console.error('deleteImpactPost error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};
