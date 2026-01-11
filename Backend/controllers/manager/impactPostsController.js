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

function safeJsonParse(value) {
  if (value == null) return value;
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  if (!trimmed) return value;
  try {
    return JSON.parse(trimmed);
  } catch (_) {
    return value;
  }
}

function buildFileUrl(req, relativePath) {
  const protocol = req.protocol;
  const host = req.get('host');
  return `${protocol}://${host}${relativePath}`;
}

function isVideoMime(mime) {
  return typeof mime === 'string' && mime.startsWith('video/');
}

function isImageMime(mime) {
  return typeof mime === 'string' && mime.startsWith('image/');
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

    const normalizedType = (type ?? 'update').toString().trim() || 'update';
    const normalizedTitle = title != null ? String(title).trim() : '';

    const parsedMediaUrls = sanitizeMediaUrls(safeJsonParse(media_urls));
    const parsedCoverUrl = cover_url != null && String(cover_url).trim() ? String(cover_url).trim() : null;

    let finalCoverUrl = parsedCoverUrl;
    let finalMediaUrls = parsedMediaUrls;

    if (req.file) {
      const relativePath = `/uploads/impact/${institutionId}/${req.file.filename}`;
      const uploadedUrl = buildFileUrl(req, relativePath);

      if (isVideoMime(req.file.mimetype)) {
        if (normalizedType !== 'video') {
          return res.status(400).json({ success: false, message: 'For video uploads, type must be "video"' });
        }
        finalMediaUrls = [uploadedUrl];
        if (!finalCoverUrl) finalCoverUrl = null;
      } else if (isImageMime(req.file.mimetype)) {
        if (normalizedType === 'video') {
          return res.status(400).json({ success: false, message: 'For image uploads, type cannot be "video"' });
        }
        finalCoverUrl = uploadedUrl;
        finalMediaUrls = finalMediaUrls && finalMediaUrls.length ? finalMediaUrls : [uploadedUrl];
      }
    }

    if (normalizedType === 'video') {
      const hasVideoLink = !!(finalMediaUrls && finalMediaUrls.length) || !!finalCoverUrl;
      const hasUploadedVideo = !!(req.file && isVideoMime(req.file.mimetype));
      if (!hasVideoLink && !hasUploadedVideo) {
        return res.status(400).json({ success: false, message: 'Video post requires a video file upload or a video URL' });
      }
    }

    if (!normalizedTitle) {
      return res.status(400).json({ success: false, message: 'title is required' });
    }

    const created = await ImpactPost.create({
      institution_id: institutionId,
      campaign_id: campaign_id ? parseIntOr(campaign_id, null) : null,
      equipment_campaign_id: equipment_campaign_id ? parseIntOr(equipment_campaign_id, null) : null,
      need_id: need_id ? parseIntOr(need_id, null) : null,
      type: normalizedType,
      title: normalizedTitle,
      content: content ?? null,
      cover_url: finalCoverUrl,
      media_urls: finalMediaUrls,
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

    const normalizedType = type !== undefined ? String(type).trim() : item.type;
    const normalizedTitle = title !== undefined ? String(title).trim() : item.title;

    const parsedMediaUrls = media_urls !== undefined ? sanitizeMediaUrls(safeJsonParse(media_urls)) : item.media_urls;
    const parsedCoverUrl =
      cover_url !== undefined
        ? (cover_url != null && String(cover_url).trim() ? String(cover_url).trim() : null)
        : item.cover_url;

    let finalCoverUrl = parsedCoverUrl;
    let finalMediaUrls = parsedMediaUrls;

    if (req.file) {
      const relativePath = `/uploads/impact/${institutionId}/${req.file.filename}`;
      const uploadedUrl = buildFileUrl(req, relativePath);

      if (isVideoMime(req.file.mimetype)) {
        if (normalizedType !== 'video') {
          return res.status(400).json({ success: false, message: 'For video uploads, type must be "video"' });
        }
        finalMediaUrls = [uploadedUrl];
        if (!finalCoverUrl) finalCoverUrl = null;
      } else if (isImageMime(req.file.mimetype)) {
        if (normalizedType === 'video') {
          return res.status(400).json({ success: false, message: 'For image uploads, type cannot be "video"' });
        }
        finalCoverUrl = uploadedUrl;
        finalMediaUrls = finalMediaUrls && finalMediaUrls.length ? finalMediaUrls : [uploadedUrl];
      }
    }

    if (normalizedType === 'video') {
      const hasVideoLink = !!(finalMediaUrls && finalMediaUrls.length) || !!finalCoverUrl;
      const hasUploadedVideo = !!(req.file && isVideoMime(req.file.mimetype));
      if (!hasVideoLink && !hasUploadedVideo) {
        return res.status(400).json({ success: false, message: 'Video post requires a video file upload or a video URL' });
      }
    }

    await item.update({
      type: normalizedType,
      title: normalizedTitle,
      content: content !== undefined ? content : item.content,
      cover_url: finalCoverUrl,
      media_urls: finalMediaUrls,
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
