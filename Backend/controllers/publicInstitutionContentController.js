const { Op } = require('sequelize');
const { Institution, InstitutionMedia, InstitutionPageContent, InstitutionNews, InstitutionProgram, InstitutionProject, InstitutionFAQ } = require('../model/index');

async function getApprovedInstitutionOrNull(institutionId) {
  return Institution.findOne({
    where: {
      institution_id: institutionId,
      is_active: true,
      approval_status: 'Approved',
    },
  });
}

function parseIntOrDefault(value, defaultValue) {
  const n = parseInt(String(value ?? ''), 10);
  return Number.isFinite(n) ? n : defaultValue;
}

exports.getInstitutionContent = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const inst = await getApprovedInstitutionOrNull(institutionId);
    if (!inst) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const items = await InstitutionPageContent.findAll({
      where: {
        institution_id: institutionId,
        is_active: true,
      },
      order: [['sort_order', 'ASC'], ['content_id', 'ASC']],
    });

    return res.status(200).json({
      success: true,
      data: items,
    });
  } catch (error) {
    console.error('Error fetching institution content:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.getInstitutionNews = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const page = Math.max(1, parseIntOrDefault(req.query.page, 1));
    const limit = Math.min(50, Math.max(1, parseIntOrDefault(req.query.limit, 10)));
    const offset = (page - 1) * limit;

    const inst = await getApprovedInstitutionOrNull(institutionId);
    if (!inst) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const where = {
      institution_id: institutionId,
      is_published: true,
    };

    const { rows, count } = await InstitutionNews.findAndCountAll({
      where,
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
    console.error('Error fetching institution news:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.getInstitutionPrograms = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const inst = await getApprovedInstitutionOrNull(institutionId);
    if (!inst) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const items = await InstitutionProgram.findAll({
      where: {
        institution_id: institutionId,
        is_active: true,
      },
      order: [['sort_order', 'ASC'], ['program_id', 'ASC']],
    });

    return res.status(200).json({ success: true, data: items });
  } catch (error) {
    console.error('Error fetching institution programs:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.getInstitutionProjects = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const status = (req.query.status ?? '').toString().trim();

    const inst = await getApprovedInstitutionOrNull(institutionId);
    if (!inst) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const where = {
      institution_id: institutionId,
      is_active: true,
    };

    if (status) {
      where.status = status;
    }

    const items = await InstitutionProject.findAll({
      where,
      order: [['sort_order', 'ASC'], ['project_id', 'ASC']],
    });

    return res.status(200).json({ success: true, data: items });
  } catch (error) {
    console.error('Error fetching institution projects:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.getInstitutionFAQ = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const inst = await getApprovedInstitutionOrNull(institutionId);
    if (!inst) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const items = await InstitutionFAQ.findAll({
      where: {
        institution_id: institutionId,
        is_active: true,
      },
      order: [['sort_order', 'ASC'], ['faq_id', 'ASC']],
    });

    return res.status(200).json({ success: true, data: items });
  } catch (error) {
    console.error('Error fetching institution faq:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

exports.getInstitutionHome = async (req, res) => {
  try {
    const { institutionId } = req.params;

    const inst = await getApprovedInstitutionOrNull(institutionId);
    if (!inst) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const [content, programs, projects, faq, media, news] = await Promise.all([
      InstitutionPageContent.findAll({
        where: { institution_id: institutionId, is_active: true },
        order: [['sort_order', 'ASC'], ['content_id', 'ASC']],
      }),
      InstitutionProgram.findAll({
        where: { institution_id: institutionId, is_active: true },
        order: [['sort_order', 'ASC'], ['program_id', 'ASC']],
      }),
      InstitutionProject.findAll({
        where: { institution_id: institutionId, is_active: true },
        order: [['sort_order', 'ASC'], ['project_id', 'ASC']],
      }),
      InstitutionFAQ.findAll({
        where: { institution_id: institutionId, is_active: true },
        order: [['sort_order', 'ASC'], ['faq_id', 'ASC']],
      }),
      InstitutionMedia.findAll({
        where: { institution_id: institutionId, is_active: true },
        order: [['sort_order', 'ASC'], ['institution_media_id', 'ASC']],
      }),
      InstitutionNews.findAll({
        where: {
          institution_id: institutionId,
          is_published: true,
          published_at: { [Op.ne]: null },
        },
        order: [['published_at', 'DESC'], ['news_id', 'DESC']],
        limit: 5,
      }),
    ]);

    const cover = media.find((m) => m.media_type === 'cover');
    const logo = media.find((m) => m.media_type === 'logo');
    const introVideo = media.find((m) => m.media_type === 'video');
    const gallery = media.filter((m) => m.media_type === 'gallery');

    return res.status(200).json({
      success: true,
      data: {
        institution: {
          institution_id: inst.institution_id,
          name: inst.name,
          description: inst.description,
          city: inst.city,
          region: inst.region,
          location_address: inst.location_address,
          website: inst.website,
          contact_email: inst.contact_email,
          contact_phone: inst.contact_phone,
        },
        content,
        news,
        programs,
        projects,
        faq,
        media: {
          cover_url: cover ? cover.url : null,
          logo_url: logo ? logo.url : null,
          intro_video_url: introVideo ? introVideo.url : null,
          gallery: gallery.map((g) => ({
            id: g.institution_media_id,
            url: g.url,
            title: g.title,
            description: g.description,
            sort_order: g.sort_order,
          })),
        },
      },
    });
  } catch (error) {
    console.error('Error fetching institution home:', error);
    return res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};
