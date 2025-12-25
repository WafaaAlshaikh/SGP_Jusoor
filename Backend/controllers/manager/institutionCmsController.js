const {
  Institution,
  Manager,
  InstitutionPageContent,
  InstitutionNews,
  InstitutionProgram,
  InstitutionProject,
  InstitutionFAQ,
  InstitutionMedia,
} = require('../../model/index');

const { notifyInstitutionFollowers } = require('../../services/institutionFollowerNotificationService');

async function getManagerInstitutionId(managerId) {
  const manager = await Manager.findOne({
    where: { manager_id: managerId, is_active: true },
    include: [{ model: Institution, attributes: ['institution_id', 'name'] }],
  });

  if (!manager || !manager.Institution) return null;
  return manager.Institution.institution_id;
}

function parseIntOr(value, fallback) {
  const n = parseInt(String(value ?? ''), 10);
  return Number.isFinite(n) ? n : fallback;
}

// =========================
// Page Content (by key)
// =========================
exports.getPageContent = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const items = await InstitutionPageContent.findAll({
      where: { institution_id: institutionId },
      order: [['sort_order', 'ASC'], ['content_id', 'ASC']],
    });

    return res.status(200).json({ success: true, data: items });
  } catch (error) {
    console.error('getPageContent error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.upsertPageContentByKey = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const { key } = req.params;
    const { title, content, sort_order, is_active } = req.body;

    if (!key) {
      return res.status(400).json({ success: false, message: 'key is required' });
    }
    if (!content || String(content).trim().isEmpty) {
      return res.status(400).json({ success: false, message: 'content is required' });
    }

    const existing = await InstitutionPageContent.findOne({
      where: { institution_id: institutionId, key },
    });

    if (existing) {
      await existing.update({
        title: title ?? existing.title,
        content,
        sort_order: sort_order !== undefined ? parseIntOr(sort_order, existing.sort_order) : existing.sort_order,
        is_active: is_active !== undefined ? !!is_active : existing.is_active,
      });

      return res.status(200).json({ success: true, data: existing });
    }

    const created = await InstitutionPageContent.create({
      institution_id: institutionId,
      key,
      title: title ?? null,
      content,
      sort_order: sort_order !== undefined ? parseIntOr(sort_order, 0) : 0,
      is_active: is_active !== undefined ? !!is_active : true,
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    console.error('upsertPageContentByKey error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// =========================
// News
// =========================
exports.listNews = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const page = Math.max(1, parseIntOr(req.query.page, 1));
    const limit = Math.min(50, Math.max(1, parseIntOr(req.query.limit, 20)));
    const offset = (page - 1) * limit;

    const { rows, count } = await InstitutionNews.findAndCountAll({
      where: { institution_id: institutionId },
      order: [['published_at', 'DESC'], ['news_id', 'DESC']],
      limit,
      offset,
    });

    return res.status(200).json({
      success: true,
      data: {
        items: rows,
        pagination: {
          page,
          limit,
          total: count,
          totalPages: Math.max(1, Math.ceil(count / limit)),
        },
      },
    });
  } catch (error) {
    console.error('listNews error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.createNews = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const { title, summary, content, cover_image_url, published_at, is_published } = req.body;
    if (!title || String(title).trim().isEmpty) {
      return res.status(400).json({ success: false, message: 'title is required' });
    }

    const created = await InstitutionNews.create({
      institution_id: institutionId,
      title,
      summary: summary ?? null,
      content: content ?? null,
      cover_image_url: cover_image_url ?? null,
      published_at: published_at ?? new Date(),
      is_published: is_published !== undefined ? !!is_published : true,
    });

    if (created && created.is_published) {
      try {
        await notifyInstitutionFollowers({
          institutionId,
          title: `New update from ${created.institution_id}`,
          body: created.title,
          data: {
            type: 'institution_news',
            institutionId: String(institutionId),
            newsId: String(created.news_id),
            action: 'open_institution_news',
          },
          notificationType: 'institution_news',
          relatedId: created.news_id,
        });
      } catch (_) {}
    }

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    console.error('createNews error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.updateNews = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const newsId = parseIntOr(req.params.newsId, 0);
    if (!newsId) {
      return res.status(400).json({ success: false, message: 'Valid newsId is required' });
    }

    const item = await InstitutionNews.findOne({
      where: { news_id: newsId, institution_id: institutionId },
    });

    if (!item) {
      return res.status(404).json({ success: false, message: 'News not found' });
    }

    const wasPublished = !!item.is_published;

    const { title, summary, content, cover_image_url, published_at, is_published } = req.body;

    await item.update({
      title: title !== undefined ? title : item.title,
      summary: summary !== undefined ? summary : item.summary,
      content: content !== undefined ? content : item.content,
      cover_image_url: cover_image_url !== undefined ? cover_image_url : item.cover_image_url,
      published_at: published_at !== undefined ? published_at : item.published_at,
      is_published: is_published !== undefined ? !!is_published : item.is_published,
    });

    const nowPublished = !!item.is_published;
    if (!wasPublished && nowPublished) {
      try {
        await notifyInstitutionFollowers({
          institutionId,
          title: `New update from ${item.institution_id}`,
          body: item.title,
          data: {
            type: 'institution_news',
            institutionId: String(institutionId),
            newsId: String(item.news_id),
            action: 'open_institution_news',
          },
          notificationType: 'institution_news',
          relatedId: item.news_id,
        });
      } catch (_) {}
    }

    return res.status(200).json({ success: true, data: item });
  } catch (error) {
    console.error('updateNews error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.deleteNews = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const newsId = parseIntOr(req.params.newsId, 0);
    if (!newsId) {
      return res.status(400).json({ success: false, message: 'Valid newsId is required' });
    }

    const deleted = await InstitutionNews.destroy({
      where: { news_id: newsId, institution_id: institutionId },
    });

    if (!deleted) {
      return res.status(404).json({ success: false, message: 'News not found' });
    }

    return res.status(200).json({ success: true, message: 'Deleted' });
  } catch (error) {
    console.error('deleteNews error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// =========================
// Programs
// =========================
exports.listPrograms = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const items = await InstitutionProgram.findAll({
      where: { institution_id: institutionId },
      order: [['sort_order', 'ASC'], ['program_id', 'ASC']],
    });

    return res.status(200).json({ success: true, data: items });
  } catch (error) {
    console.error('listPrograms error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.createProgram = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const { title, description, icon, image_url, sort_order, is_active } = req.body;
    if (!title || String(title).trim().isEmpty) {
      return res.status(400).json({ success: false, message: 'title is required' });
    }

    const created = await InstitutionProgram.create({
      institution_id: institutionId,
      title,
      description: description ?? null,
      icon: icon ?? null,
      image_url: image_url ?? null,
      sort_order: sort_order !== undefined ? parseIntOr(sort_order, 0) : 0,
      is_active: is_active !== undefined ? !!is_active : true,
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    console.error('createProgram error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.updateProgram = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const programId = parseIntOr(req.params.programId, 0);
    if (!programId) {
      return res.status(400).json({ success: false, message: 'Valid programId is required' });
    }

    const item = await InstitutionProgram.findOne({
      where: { program_id: programId, institution_id: institutionId },
    });
    if (!item) return res.status(404).json({ success: false, message: 'Program not found' });

    const { title, description, icon, image_url, sort_order, is_active } = req.body;
    await item.update({
      title: title !== undefined ? title : item.title,
      description: description !== undefined ? description : item.description,
      icon: icon !== undefined ? icon : item.icon,
      image_url: image_url !== undefined ? image_url : item.image_url,
      sort_order: sort_order !== undefined ? parseIntOr(sort_order, item.sort_order) : item.sort_order,
      is_active: is_active !== undefined ? !!is_active : item.is_active,
    });

    return res.status(200).json({ success: true, data: item });
  } catch (error) {
    console.error('updateProgram error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.deleteProgram = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const programId = parseIntOr(req.params.programId, 0);
    if (!programId) {
      return res.status(400).json({ success: false, message: 'Valid programId is required' });
    }

    const deleted = await InstitutionProgram.destroy({
      where: { program_id: programId, institution_id: institutionId },
    });

    if (!deleted) return res.status(404).json({ success: false, message: 'Program not found' });

    return res.status(200).json({ success: true, message: 'Deleted' });
  } catch (error) {
    console.error('deleteProgram error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// =========================
// Projects
// =========================
exports.listProjects = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const items = await InstitutionProject.findAll({
      where: { institution_id: institutionId },
      order: [['sort_order', 'ASC'], ['project_id', 'ASC']],
    });

    return res.status(200).json({ success: true, data: items });
  } catch (error) {
    console.error('listProjects error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.createProject = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const { title, description, status, cover_image_url, goal_amount, raised_amount, sort_order, is_active } = req.body;
    if (!title || String(title).trim().isEmpty) {
      return res.status(400).json({ success: false, message: 'title is required' });
    }

    const created = await InstitutionProject.create({
      institution_id: institutionId,
      title,
      description: description ?? null,
      status: status ?? 'active',
      cover_image_url: cover_image_url ?? null,
      goal_amount: goal_amount ?? null,
      raised_amount: raised_amount ?? null,
      sort_order: sort_order !== undefined ? parseIntOr(sort_order, 0) : 0,
      is_active: is_active !== undefined ? !!is_active : true,
    });

    if (created && created.is_active && created.status === 'active') {
      try {
        await notifyInstitutionFollowers({
          institutionId,
          title: `New project from ${created.institution_id}`,
          body: created.title,
          data: {
            type: 'institution_project',
            institutionId: String(institutionId),
            projectId: String(created.project_id),
            action: 'open_institution_project',
          },
          notificationType: 'institution_project',
          relatedId: created.project_id,
        });
      } catch (_) {}
    }

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    console.error('createProject error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.updateProject = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const projectId = parseIntOr(req.params.projectId, 0);
    if (!projectId) {
      return res.status(400).json({ success: false, message: 'Valid projectId is required' });
    }

    const item = await InstitutionProject.findOne({
      where: { project_id: projectId, institution_id: institutionId },
    });
    if (!item) return res.status(404).json({ success: false, message: 'Project not found' });

    const wasActive = !!item.is_active;
    const wasStatusActive = item.status === 'active';

    const { title, description, status, cover_image_url, goal_amount, raised_amount, sort_order, is_active } = req.body;
    await item.update({
      title: title !== undefined ? title : item.title,
      description: description !== undefined ? description : item.description,
      status: status !== undefined ? status : item.status,
      cover_image_url: cover_image_url !== undefined ? cover_image_url : item.cover_image_url,
      goal_amount: goal_amount !== undefined ? goal_amount : item.goal_amount,
      raised_amount: raised_amount !== undefined ? raised_amount : item.raised_amount,
      sort_order: sort_order !== undefined ? parseIntOr(sort_order, item.sort_order) : item.sort_order,
      is_active: is_active !== undefined ? !!is_active : item.is_active,
    });

    const nowActive = !!item.is_active;
    const nowStatusActive = item.status === 'active';
    if ((!wasActive || !wasStatusActive) && nowActive && nowStatusActive) {
      try {
        await notifyInstitutionFollowers({
          institutionId,
          title: `Project update from ${item.institution_id}`,
          body: item.title,
          data: {
            type: 'institution_project',
            institutionId: String(institutionId),
            projectId: String(item.project_id),
            action: 'open_institution_project',
          },
          notificationType: 'institution_project',
          relatedId: item.project_id,
        });
      } catch (_) {}
    }

    return res.status(200).json({ success: true, data: item });
  } catch (error) {
    console.error('updateProject error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.deleteProject = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const projectId = parseIntOr(req.params.projectId, 0);
    if (!projectId) {
      return res.status(400).json({ success: false, message: 'Valid projectId is required' });
    }

    const deleted = await InstitutionProject.destroy({
      where: { project_id: projectId, institution_id: institutionId },
    });

    if (!deleted) return res.status(404).json({ success: false, message: 'Project not found' });

    return res.status(200).json({ success: true, message: 'Deleted' });
  } catch (error) {
    console.error('deleteProject error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// =========================
// FAQ
// =========================
exports.listFAQ = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const items = await InstitutionFAQ.findAll({
      where: { institution_id: institutionId },
      order: [['sort_order', 'ASC'], ['faq_id', 'ASC']],
    });

    return res.status(200).json({ success: true, data: items });
  } catch (error) {
    console.error('listFAQ error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.createFAQ = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const { question, answer, sort_order, is_active } = req.body;
    if (!question || String(question).trim().isEmpty) {
      return res.status(400).json({ success: false, message: 'question is required' });
    }
    if (!answer || String(answer).trim().isEmpty) {
      return res.status(400).json({ success: false, message: 'answer is required' });
    }

    const created = await InstitutionFAQ.create({
      institution_id: institutionId,
      question,
      answer,
      sort_order: sort_order !== undefined ? parseIntOr(sort_order, 0) : 0,
      is_active: is_active !== undefined ? !!is_active : true,
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    console.error('createFAQ error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.updateFAQ = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const faqId = parseIntOr(req.params.faqId, 0);
    if (!faqId) {
      return res.status(400).json({ success: false, message: 'Valid faqId is required' });
    }

    const item = await InstitutionFAQ.findOne({
      where: { faq_id: faqId, institution_id: institutionId },
    });
    if (!item) return res.status(404).json({ success: false, message: 'FAQ not found' });

    const { question, answer, sort_order, is_active } = req.body;
    await item.update({
      question: question !== undefined ? question : item.question,
      answer: answer !== undefined ? answer : item.answer,
      sort_order: sort_order !== undefined ? parseIntOr(sort_order, item.sort_order) : item.sort_order,
      is_active: is_active !== undefined ? !!is_active : item.is_active,
    });

    return res.status(200).json({ success: true, data: item });
  } catch (error) {
    console.error('updateFAQ error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.deleteFAQ = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const faqId = parseIntOr(req.params.faqId, 0);
    if (!faqId) {
      return res.status(400).json({ success: false, message: 'Valid faqId is required' });
    }

    const deleted = await InstitutionFAQ.destroy({
      where: { faq_id: faqId, institution_id: institutionId },
    });

    if (!deleted) return res.status(404).json({ success: false, message: 'FAQ not found' });

    return res.status(200).json({ success: true, message: 'Deleted' });
  } catch (error) {
    console.error('deleteFAQ error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// =========================
// Media
// =========================
exports.listMedia = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const items = await InstitutionMedia.findAll({
      where: { institution_id: institutionId },
      order: [['media_type', 'ASC'], ['sort_order', 'ASC'], ['institution_media_id', 'ASC']],
    });

    return res.status(200).json({ success: true, data: items });
  } catch (error) {
    console.error('listMedia error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.createMedia = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const { media_type, url, title, description, sort_order, is_active } = req.body;
    if (!media_type || String(media_type).trim().isEmpty) {
      return res.status(400).json({ success: false, message: 'media_type is required' });
    }
    if (!url || String(url).trim().isEmpty) {
      return res.status(400).json({ success: false, message: 'url is required' });
    }

    const created = await InstitutionMedia.create({
      institution_id: institutionId,
      media_type,
      url,
      title: title ?? null,
      description: description ?? null,
      sort_order: sort_order !== undefined ? parseIntOr(sort_order, 0) : 0,
      is_active: is_active !== undefined ? !!is_active : true,
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    console.error('createMedia error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.updateMedia = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const mediaId = parseIntOr(req.params.mediaId, 0);
    if (!mediaId) {
      return res.status(400).json({ success: false, message: 'Valid mediaId is required' });
    }

    const item = await InstitutionMedia.findOne({
      where: { institution_media_id: mediaId, institution_id: institutionId },
    });
    if (!item) return res.status(404).json({ success: false, message: 'Media not found' });

    const { media_type, url, title, description, sort_order, is_active } = req.body;
    await item.update({
      media_type: media_type !== undefined ? media_type : item.media_type,
      url: url !== undefined ? url : item.url,
      title: title !== undefined ? title : item.title,
      description: description !== undefined ? description : item.description,
      sort_order: sort_order !== undefined ? parseIntOr(sort_order, item.sort_order) : item.sort_order,
      is_active: is_active !== undefined ? !!is_active : item.is_active,
    });

    return res.status(200).json({ success: true, data: item });
  } catch (error) {
    console.error('updateMedia error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.deleteMedia = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = await getManagerInstitutionId(managerId);
    if (!institutionId) {
      return res.status(404).json({ success: false, message: 'Manager institution not found' });
    }

    const mediaId = parseIntOr(req.params.mediaId, 0);
    if (!mediaId) {
      return res.status(400).json({ success: false, message: 'Valid mediaId is required' });
    }

    const deleted = await InstitutionMedia.destroy({
      where: { institution_media_id: mediaId, institution_id: institutionId },
    });

    if (!deleted) return res.status(404).json({ success: false, message: 'Media not found' });

    return res.status(200).json({ success: true, message: 'Deleted' });
  } catch (error) {
    console.error('deleteMedia error:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};
