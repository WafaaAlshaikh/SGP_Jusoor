const { Op, Sequelize } = require('sequelize');
const sequelize = require('../config/db');
const { Institution, Specialist, User, Child, Session, InstitutionReview, InstitutionMedia, InstitutionNews, InstitutionProgram, InstitutionProject, SessionType } = require('../model/index');

const parseCsvList = (value) => {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  return String(value)
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);
};

const formatInstitution = (inst, media = {}) => ({
  institution_id: inst.institution_id,
  name: inst.name,
  description: inst.description,
  location: inst.location,
  location_address: inst.location_address,
  city: inst.city,
  region: inst.region,
  website: inst.website,
  contact_info: inst.contact_info,
  contact_email: inst.contact_email,
  contact_phone: inst.contact_phone,
  license_number: inst.license_number,
  established_year: inst.established_year,
  services_offered: parseCsvList(inst.services_offered),
  conditions_supported: parseCsvList(inst.conditions_supported),
  rating: parseFloat(inst.rating) || 0,
  price_range: inst.price_range,
  capacity: inst.capacity,
  available_slots: inst.available_slots,
  location_lat: inst.location_lat !== null && inst.location_lat !== undefined ? parseFloat(inst.location_lat) : null,
  location_lng: inst.location_lng !== null && inst.location_lng !== undefined ? parseFloat(inst.location_lng) : null,
  logo_url: media.logo_url ?? null,
  cover_url: media.cover_url ?? null,
});

exports.getPublicInstitutions = async (req, res) => {
  try {
    const q = (req.query.q ?? '').toString().trim();
    const city = (req.query.city ?? '').toString().trim();
    const region = (req.query.region ?? '').toString().trim();
    const minRatingRaw = (req.query.min_rating ?? '').toString().trim();
    const sortByRaw = (req.query.sort_by ?? '').toString().trim().toLowerCase();
    const sortOrderRaw = (req.query.sort_order ?? '').toString().trim().toUpperCase();

    const pageProvided = req.query.page !== undefined || req.query.limit !== undefined;
    const page = Math.max(1, parseInt((req.query.page ?? '1').toString(), 10) || 1);
    const limit = Math.min(50, Math.max(1, parseInt((req.query.limit ?? '20').toString(), 10) || 20));
    const offset = (page - 1) * limit;

    const minRating = parseFloat(minRatingRaw);

    const where = {
      is_active: true,
      approval_status: 'Approved'
    };

    if (q) {
      where[Op.or] = [
        { name: { [Op.like]: `%${q}%` } },
        { city: { [Op.like]: `%${q}%` } },
        { region: { [Op.like]: `%${q}%` } },
        { description: { [Op.like]: `%${q}%` } },
        { services_offered: { [Op.like]: `%${q}%` } },
        { conditions_supported: { [Op.like]: `%${q}%` } },
      ];
    }

    if (city) {
      where.city = city;
    }

    if (region) {
      where.region = region;
    }

    if (Number.isFinite(minRating)) {
      where.rating = { [Op.gte]: minRating };
    }

    const attributes = [
      'institution_id',
      'name',
      'description',
      'location',
      'location_address',
      'city',
      'region',
      'website',
      'contact_info',
      'contact_email',
      'contact_phone',
      'license_number',
      'established_year',
      'services_offered',
      'conditions_supported',
      'rating',
      'price_range',
      'capacity',
      'available_slots',
      'location_lat',
      'location_lng'
    ];

    const sortBy = ['name', 'rating', 'city'].includes(sortByRaw) ? sortByRaw : 'name';
    const sortOrder = ['ASC', 'DESC'].includes(sortOrderRaw) ? sortOrderRaw : 'ASC';
    const order = [[sortBy, sortOrder]];

    let institutions = [];
    let total = null;

    if (pageProvided) {
      const { rows, count } = await Institution.findAndCountAll({
        where,
        attributes,
        order,
        limit,
        offset,
      });
      institutions = rows;
      total = count;
    } else {
      institutions = await Institution.findAll({
        where,
        attributes,
        order,
      });
    }

    const institutionIds = institutions.map((i) => i.institution_id);
    const mediaByInstitutionId = {};

    if (institutionIds.length) {
      const mediaRows = await InstitutionMedia.findAll({
        where: {
          institution_id: { [Op.in]: institutionIds },
          is_active: true,
          media_type: { [Op.in]: ['logo', 'cover'] },
        },
        attributes: ['institution_media_id', 'institution_id', 'media_type', 'url', 'sort_order'],
        order: [['institution_id', 'ASC'], ['media_type', 'ASC'], ['sort_order', 'ASC'], ['institution_media_id', 'ASC']],
        raw: true,
      });

      mediaRows.forEach((m) => {
        const id = m.institution_id;
        if (!mediaByInstitutionId[id]) {
          mediaByInstitutionId[id] = { logo_url: null, cover_url: null };
        }
        if (m.media_type === 'logo' && !mediaByInstitutionId[id].logo_url) {
          mediaByInstitutionId[id].logo_url = m.url;
        }
        if (m.media_type === 'cover' && !mediaByInstitutionId[id].cover_url) {
          mediaByInstitutionId[id].cover_url = m.url;
        }
      });
    }

    const response = {
      success: true,
      data: institutions.map((inst) => formatInstitution(inst, mediaByInstitutionId[inst.institution_id]))
    };

    if (pageProvided) {
      response.pagination = {
        page,
        limit,
        total,
        totalPages: total !== null ? Math.max(1, Math.ceil(total / limit)) : 1,
      };
    }

    res.status(200).json(response);
  } catch (error) {
    console.error('Error fetching public institutions:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

exports.getPublicInstitutionTeam = async (req, res) => {
  try {
    const { institutionId } = req.params;

    const institution = await Institution.findOne({
      where: {
        institution_id: institutionId,
        is_active: true,
        approval_status: 'Approved'
      }
    });

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    const specialists = await Specialist.findAll({
      where: {
        institution_id: institutionId,
        approval_status: 'Approved'
      },
      include: [
        {
          model: User,
          attributes: ['user_id', 'full_name', 'profile_picture', 'city', 'region']
        }
      ],
      order: [['average_rating', 'DESC'], ['total_ratings', 'DESC']]
    });

    const data = specialists.map((s) => ({
      specialist_id: s.specialist_id,
      specialization: s.specialization,
      years_experience: s.years_experience,
      average_rating: s.average_rating,
      total_ratings: s.total_ratings,
      rating_badge: s.rating_badge,
      user: s.User ? {
        user_id: s.User.user_id,
        full_name: s.User.full_name,
        profile_picture: s.User.profile_picture,
        city: s.User.city,
        region: s.User.region,
      } : null,
    }));

    return res.status(200).json({
      success: true,
      data
    });
  } catch (error) {
    console.error('Error fetching institution team:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

exports.getPublicInstitutionDetails = async (req, res) => {
  try {
    const { institutionId } = req.params;

    const institution = await Institution.findOne({
      where: {
        institution_id: institutionId,
        is_active: true,
        approval_status: 'Approved'
      }
    });

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    res.status(200).json({
      success: true,
      data: formatInstitution(institution)
    });
  } catch (error) {
    console.error('Error fetching public institution details:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

exports.getPublicInstitutionHighlights = async (req, res) => {
  try {
    const { institutionId } = req.params;

    const institution = await Institution.findOne({
      where: {
        institution_id: institutionId,
        is_active: true,
        approval_status: 'Approved'
      },
      attributes: [
        'institution_id',
        'name',
        'description',
        'city',
        'region',
        'rating',
        'services_offered',
        'conditions_supported'
      ]
    });

    if (!institution) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const [
      reviewStats,
      mediaRows,
      latestNews,
      featuredPrograms,
      featuredProjectRows,
    ] = await Promise.all([
      InstitutionReview.findOne({
        where: { institution_id: institutionId },
        attributes: [
          [sequelize.fn('AVG', sequelize.col('overall_rating')), 'average_rating'],
          [sequelize.fn('COUNT', sequelize.col('institution_review_id')), 'total_reviews'],
        ],
        raw: true
      }),
      InstitutionMedia.findAll({
        where: {
          institution_id: institutionId,
          is_active: true,
          media_type: { [Op.in]: ['logo', 'cover'] },
        },
        attributes: ['institution_media_id', 'media_type', 'url', 'sort_order'],
        order: [['media_type', 'ASC'], ['sort_order', 'ASC'], ['institution_media_id', 'ASC']],
        raw: true,
      }),
      InstitutionNews.findAll({
        where: {
          institution_id: institutionId,
          is_published: true,
          published_at: { [Op.ne]: null },
        },
        attributes: ['news_id', 'title', 'summary', 'cover_image_url', 'published_at'],
        order: [['published_at', 'DESC'], ['news_id', 'DESC']],
        limit: 2,
        raw: true,
      }),
      InstitutionProgram.findAll({
        where: {
          institution_id: institutionId,
          is_active: true,
        },
        attributes: ['program_id', 'title', 'description', 'icon', 'image_url'],
        order: [['sort_order', 'ASC'], ['program_id', 'ASC']],
        limit: 2,
        raw: true,
      }),
      InstitutionProject.findAll({
        where: {
          institution_id: institutionId,
          is_active: true,
          status: 'active',
        },
        attributes: ['project_id', 'title', 'description', 'status', 'cover_image_url', 'goal_amount', 'raised_amount'],
        order: [['sort_order', 'ASC'], ['project_id', 'ASC']],
        limit: 1,
        raw: true,
      }),
    ]);

    const media = { logo_url: null, cover_url: null };
    (mediaRows || []).forEach((m) => {
      if (m.media_type === 'logo' && !media.logo_url) media.logo_url = m.url;
      if (m.media_type === 'cover' && !media.cover_url) media.cover_url = m.url;
    });

    const avgRating = reviewStats && reviewStats.average_rating ? parseFloat(reviewStats.average_rating) : 0;
    const totalReviews = reviewStats && reviewStats.total_reviews ? parseInt(reviewStats.total_reviews, 10) : 0;

    return res.status(200).json({
      success: true,
      data: {
        institution: formatInstitution(institution, media),
        snapshots: {
          average_rating: Number.isFinite(avgRating) ? Number(avgRating.toFixed(1)) : 0,
          total_reviews: totalReviews,
        },
        latest_news: latestNews || [],
        featured_programs: featuredPrograms || [],
        featured_project: (featuredProjectRows && featuredProjectRows[0]) ? featuredProjectRows[0] : null,
      }
    });
  } catch (error) {
    console.error('Error fetching public institution highlights:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

exports.getPublicInstitutionProfile = async (req, res) => {
  try {
    const { institutionId } = req.params;

    const institution = await Institution.findOne({
      where: {
        institution_id: institutionId,
        is_active: true,
        approval_status: 'Approved'
      }
    });

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    const [
      reviewStats,
      specialistStats,
      childrenCount,
      completedSessionsCount,
      mediaRows
    ] = await Promise.all([
      InstitutionReview.findOne({
        where: { institution_id: institutionId },
        attributes: [
          [sequelize.fn('AVG', sequelize.col('overall_rating')), 'average_rating'],
          [sequelize.fn('COUNT', sequelize.col('institution_review_id')), 'total_reviews'],
          [sequelize.fn('SUM', sequelize.literal('CASE WHEN would_recommend = true THEN 1 ELSE 0 END')), 'recommendations'],
          [sequelize.fn('AVG', sequelize.col('facilities_rating')), 'avg_facilities'],
          [sequelize.fn('AVG', sequelize.col('staff_rating')), 'avg_staff'],
          [sequelize.fn('AVG', sequelize.col('cleanliness_rating')), 'avg_cleanliness'],
          [sequelize.fn('AVG', sequelize.col('accessibility_rating')), 'avg_accessibility']
        ],
        raw: true
      }),
      Specialist.findAll({
        where: {
          institution_id: institutionId,
          approval_status: 'Approved'
        },
        attributes: [
          [sequelize.fn('COUNT', sequelize.col('specialist_id')), 'total_specialists'],
          [sequelize.fn('AVG', sequelize.col('years_experience')), 'avg_years_experience']
        ],
        raw: true
      }).then(rows => rows && rows[0] ? rows[0] : { total_specialists: 0, avg_years_experience: null }),
      Child.count({
        where: {
          current_institution_id: institutionId,
          deleted_at: null,
          registration_status: {
            [Op.notIn]: ['Archived', 'Inactive', 'Rejected', 'RejectedByManager', 'RejectedBySystem']
          }
        }
      }),
      Session.count({
        where: {
          institution_id: institutionId,
          status: 'Completed'
        }
      }),
      InstitutionMedia.findAll({
        where: {
          institution_id: institutionId,
          is_active: true
        },
        attributes: ['institution_media_id', 'media_type', 'url', 'title', 'description', 'sort_order'],
        order: [['media_type', 'ASC'], ['sort_order', 'ASC'], ['institution_media_id', 'ASC']],
        raw: true
      })
    ]);

    const media = {
      logo_url: null,
      cover_url: null,
      intro_video_url: null,
      gallery: []
    };

    (mediaRows || []).forEach(m => {
      if (m.media_type === 'logo' && !media.logo_url) {
        media.logo_url = m.url;
      } else if (m.media_type === 'cover' && !media.cover_url) {
        media.cover_url = m.url;
      } else if (m.media_type === 'video' && !media.intro_video_url) {
        media.intro_video_url = m.url;
      } else if (m.media_type === 'gallery') {
        media.gallery.push({
          id: m.institution_media_id,
          url: m.url,
          title: m.title,
          description: m.description,
          sort_order: m.sort_order
        });
      }
    });

    const specialtiesRaw = await Specialist.findAll({
      where: {
        institution_id: institutionId,
        approval_status: 'Approved',
        specialization: {
          [Op.ne]: null
        }
      },
      attributes: [[Sequelize.fn('DISTINCT', Sequelize.col('specialization')), 'specialization']],
      raw: true
    });

    const specialties = specialtiesRaw
      .map(r => r.specialization)
      .filter(Boolean);

    const avgRating = reviewStats && reviewStats.average_rating ? parseFloat(reviewStats.average_rating) : 0;
    const totalReviews = reviewStats && reviewStats.total_reviews ? parseInt(reviewStats.total_reviews, 10) : 0;
    const recommendations = reviewStats && reviewStats.recommendations ? parseInt(reviewStats.recommendations, 10) : 0;

    const response = {
      institution: formatInstitution(institution),
      media,
      reviews_summary: {
        average_rating: avgRating.toFixed(1),
        total_reviews: totalReviews,
        recommendation_rate: totalReviews ? Math.round((recommendations / totalReviews) * 100) : 0,
        category_averages: {
          facilities: (reviewStats && reviewStats.avg_facilities ? parseFloat(reviewStats.avg_facilities) : 0).toFixed(1),
          staff: (reviewStats && reviewStats.avg_staff ? parseFloat(reviewStats.avg_staff) : 0).toFixed(1),
          cleanliness: (reviewStats && reviewStats.avg_cleanliness ? parseFloat(reviewStats.avg_cleanliness) : 0).toFixed(1),
          accessibility: (reviewStats && reviewStats.avg_accessibility ? parseFloat(reviewStats.avg_accessibility) : 0).toFixed(1)
        }
      },
      team_summary: {
        total_specialists: parseInt(specialistStats.total_specialists || 0, 10),
        specialties,
        avg_years_experience: specialistStats.avg_years_experience !== null && specialistStats.avg_years_experience !== undefined
          ? Number(parseFloat(specialistStats.avg_years_experience).toFixed(1))
          : null
      },
      public_stats: {
        children_count: childrenCount,
        completed_sessions_count: completedSessionsCount
      }
    };

    res.status(200).json({
      success: true,
      data: response
    });
  } catch (error) {
    console.error('Error fetching public institution profile:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

exports.getInstitutionSessionTypes = async (req, res) => {
  try {
    const { institutionId } = req.params;
    
    // تحقق من وجود المؤسسة
    const institution = await Institution.findOne({
      where: {
        institution_id: institutionId,
        is_active: true,
        approval_status: 'Approved'
      }
    });

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    // جلب أنواع الجلسات النشطة والمعتمدة
    const sessionTypes = await SessionType.findAll({
      where: {
        institution_id: institutionId,
        approval_status: 'Approved'
      },
      order: [
        ['category', 'ASC'],
        ['name', 'ASC']
      ],
      attributes: [
        'session_type_id',
        'name',
        'duration',
        'price',
        'category',
        'specialist_specialization',
        'target_conditions'
      ]
    });

    // تنسيق البيانات للإرجاع
    const formattedSessionTypes = sessionTypes.map(st => ({
      session_type_id: st.session_type_id,
      name: st.name,
      duration: st.duration,
      price: parseFloat(st.price),
      category: st.category,
      specialist_specialization: st.specialist_specialization,
      target_conditions: st.target_conditions || []
    }));

    return res.status(200).json({
      success: true,
      data: formattedSessionTypes
    });
  } catch (error) {
    console.error('Error fetching institution session types:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// دالة أخرى للحصول على تفاصيل نوع جلسة محدد
exports.getSessionTypeDetails = async (req, res) => {
  try {
    const { institutionId, sessionTypeId } = req.params;
    
    // تحقق من وجود المؤسسة
    const institution = await Institution.findOne({
      where: {
        institution_id: institutionId,
        is_active: true,
        approval_status: 'Approved'
      }
    });

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    // جلب تفاصيل نوع الجلسة
    const sessionType = await SessionType.findOne({
      where: {
        session_type_id: sessionTypeId,
        institution_id: institutionId,
        approval_status: 'Approved'
      },
      include: [
        {
          model: User,
          as: 'CreatedBySpecialist',
          attributes: ['user_id', 'full_name', 'profile_picture']
        }
      ]
    });

    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'Session type not found'
      });
    }

    const response = {
      session_type_id: sessionType.session_type_id,
      name: sessionType.name,
      duration: sessionType.duration,
      price: parseFloat(sessionType.price),
      category: sessionType.category,
      specialist_specialization: sessionType.specialist_specialization,
      target_conditions: sessionType.target_conditions || [],
      created_by: sessionType.CreatedBySpecialist ? {
        user_id: sessionType.CreatedBySpecialist.user_id,
        full_name: sessionType.CreatedBySpecialist.full_name,
        profile_picture: sessionType.CreatedBySpecialist.profile_picture
      } : null
    };

    return res.status(200).json({
      success: true,
      data: response
    });
  } catch (error) {
    console.error('Error fetching session type details:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};
