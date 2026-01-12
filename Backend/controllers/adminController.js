const { Op, Sequelize } = require('sequelize');
const sequelize = require('../config/db');
const User = require('../model/User');
const Institution = require('../model/Institution');
const Specialist = require('../model/Specialist');
const Manager = require('../model/Manager');
const Parent = require('../model/Parent');
const Report = require('../model/Report');
const Donation = require('../model/Donation');
const Session = require('../model/Session');
const Child = require('../model/Child');
const SessionType = require('../model/SessionType');
const SessionRating = require('../model/SessionRating');
const AuditLog = require('../model/AuditLog');
const SystemSettings = require('../model/SystemSettings');
const Notification = require('../model/Notification');
const InstitutionReview = require('../model/InstitutionReview');
const Post = require('../model/Post');
const Comment = require('../model/Comment');
const ChildRegistrationRequest = require('../model/ChildRegistrationRequest');
const SpecialistRegistrationRequest = require('../model/SpecialistRegistrationRequest');
const AppContent = require('../model/AppContent');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

class AdminController {
  
  // ==================== DASHBOARD ====================
  async getDashboardStats(req, res) {
    try {
      const [
        totalInstitutions,
        pendingInstitutions,
        totalUsers,
        pendingSpecialists,
        pendingManagers,
        totalChildren,
        totalSessions,
        recentDonations,
        recentReports
      ] = await Promise.all([
        Institution.count(),
        Institution.count({ where: { approval_status: 'Pending' } }),
        User.count(),
        Specialist.count({ where: { approval_status: 'Pending' } }),
        User.count({ where: { role: 'Manager', status: 'Pending' } }),
        Child.count(),
        Session.count(),
        Donation.sum('amount'),
        Report.count({ where: { status: 'open' } })
      ]);

      const today = new Date();
      const lastWeek = new Date(today);
      lastWeek.setDate(today.getDate() - 7);

      const recentStats = await Promise.all([
        User.count({
          where: {
            created_at: { [Op.gte]: lastWeek }
          }
        }),
        Child.count({
          where: {
            created_at: { [Op.gte]: lastWeek }
        }
        }),
        Session.count({
          where: {
            date: { [Op.gte]: lastWeek }
          }
        })
      ]);

      res.json({
        success: true,
        data: {
          summary: {
            total_institutions: totalInstitutions,
            pending_institutions: pendingInstitutions,
            total_users: totalUsers,
            pending_approvals: pendingSpecialists + pendingManagers,
            total_children: totalChildren,
            total_sessions: totalSessions,
            total_donations: recentDonations || 0,
            open_reports: recentReports
          },
          recent_activity: {
            new_users: recentStats[0],
            new_children: recentStats[1],
            new_sessions: recentStats[2]
          }
        }
      });
    } catch (error) {
      console.error('Dashboard error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error fetching dashboard stats' 
      });
    }
  }

  async getAnalyticsOverview(req, res) {
    try {
      const rangeDays = Math.max(7, Math.min(parseInt(req.query.range_days || '30', 10), 365));

      const today = new Date();
      const start = new Date(today);
      start.setHours(0, 0, 0, 0);
      start.setDate(start.getDate() - (rangeDays - 1));

      const roleRows = await User.findAll({
        attributes: [
          'role',
          [sequelize.fn('COUNT', sequelize.col('user_id')), 'count']
        ],
        group: ['role'],
        raw: true
      });

      const normalizeRole = (r) => {
        const key = String(r || '').trim().toLowerCase();
        const map = {
          donor: 'Donor',
          manager: 'Manager',
          parent: 'Parent',
          children: 'Children',
          child: 'Children',
          specialist: 'Specialist',
          admin: 'Admon',
          admon: 'Admon'
        };
        return map[key] || (r || 'Unknown');
      };

      const roleCounts = roleRows.reduce((acc, row) => {
        const role = normalizeRole(row.role);
        const count = parseInt(row.count || '0', 10);
        acc[role] = (acc[role] || 0) + count;
        return acc;
      }, {});

      const institutionRows = await Institution.findAll({
        attributes: [
          'approval_status',
          [sequelize.fn('COUNT', sequelize.col('institution_id')), 'count']
        ],
        group: ['approval_status'],
        raw: true
      });

      const institutionStatusCounts = institutionRows.reduce((acc, row) => {
        const status = row.approval_status || 'Unknown';
        acc[status] = parseInt(row.count || '0', 10);
        return acc;
      }, {});

      const usersGrowthRows = await User.findAll({
        attributes: [
          [sequelize.fn('DATE', sequelize.col('created_at')), 'date'],
          [sequelize.fn('COUNT', sequelize.col('user_id')), 'count']
        ],
        where: {
          created_at: { [Op.gte]: start }
        },
        group: ['date'],
        order: [[sequelize.literal('date'), 'ASC']],
        raw: true
      });

      const institutionsGrowthRows = await Institution.findAll({
        attributes: [
          [sequelize.fn('DATE', sequelize.col('created_at')), 'date'],
          [sequelize.fn('COUNT', sequelize.col('institution_id')), 'count']
        ],
        where: {
          created_at: { [Op.gte]: start }
        },
        group: ['date'],
        order: [[sequelize.literal('date'), 'ASC']],
        raw: true
      });

      return res.json({
        success: true,
        data: {
          range_days: rangeDays,
          user_roles: roleCounts,
          institution_statuses: institutionStatusCounts,
          growth: {
            users: usersGrowthRows,
            institutions: institutionsGrowthRows
          }
        }
      });
    } catch (error) {
      console.error('Analytics overview error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error fetching analytics overview'
      });
    }
  }

  async getInstitutionsAnalyticsOverview(req, res) {
    try {
      const rangeDays = Math.max(7, Math.min(parseInt(req.query.range_days || '90', 10), 365));
      const limit = Math.max(3, Math.min(parseInt(req.query.limit || '10', 10), 50));

      const sessionsWeight = parseFloat(req.query.sessions_weight || '1');
      const childRequestsWeight = parseFloat(req.query.child_requests_weight || '3');
      const specialistRequestsWeight = parseFloat(req.query.specialist_requests_weight || '2');
      const ratingWeight = parseFloat(req.query.rating_weight || '5');

      const today = new Date();
      const start = new Date(today);
      start.setHours(0, 0, 0, 0);
      start.setDate(start.getDate() - (rangeDays - 1));

      const [
        institutionStatusRows,
        childRequestsRows,
        specialistRequestsRows,
        sessionsRows,
        reviewRows,
        globalAvgRatingRow,
      ] = await Promise.all([
        Institution.findAll({
          attributes: [
            'approval_status',
            [sequelize.fn('COUNT', sequelize.col('institution_id')), 'count']
          ],
          group: ['approval_status'],
          raw: true
        }),
        ChildRegistrationRequest.findAll({
          attributes: [
            'institution_id',
            [sequelize.fn('COUNT', sequelize.col('request_id')), 'count']
          ],
          where: { requested_at: { [Op.gte]: start } },
          group: ['institution_id'],
          raw: true
        }),
        SpecialistRegistrationRequest.findAll({
          attributes: [
            'institution_id',
            [sequelize.fn('COUNT', sequelize.col('request_id')), 'count']
          ],
          where: { requested_at: { [Op.gte]: start } },
          group: ['institution_id'],
          raw: true
        }),
        Session.findAll({
          attributes: [
            'institution_id',
            [sequelize.fn('COUNT', sequelize.col('session_id')), 'count']
          ],
          where: { date: { [Op.gte]: start } },
          group: ['institution_id'],
          raw: true
        }),
        InstitutionReview.findAll({
          attributes: [
            'institution_id',
            [sequelize.fn('AVG', sequelize.col('overall_rating')), 'avg_rating'],
            [sequelize.fn('COUNT', sequelize.col('institution_review_id')), 'reviews_count'],
            [sequelize.fn('SUM', sequelize.literal("CASE WHEN would_recommend = 1 THEN 1 ELSE 0 END")), 'recommend_yes']
          ],
          where: { created_at: { [Op.gte]: start } },
          group: ['institution_id'],
          raw: true
        }),
        InstitutionReview.findAll({
          attributes: [[sequelize.fn('AVG', sequelize.col('overall_rating')), 'avg_rating']],
          raw: true
        }),
      ]);

      const institutionStatusCounts = institutionStatusRows.reduce((acc, row) => {
        const status = row.approval_status || 'Unknown';
        acc[status] = parseInt(row.count || '0', 10);
        return acc;
      }, {});

      const childRequestsByInstitution = childRequestsRows.reduce((acc, row) => {
        acc[String(row.institution_id)] = parseInt(row.count || '0', 10);
        return acc;
      }, {});
      const specialistRequestsByInstitution = specialistRequestsRows.reduce((acc, row) => {
        acc[String(row.institution_id)] = parseInt(row.count || '0', 10);
        return acc;
      }, {});
      const sessionsByInstitution = sessionsRows.reduce((acc, row) => {
        acc[String(row.institution_id)] = parseInt(row.count || '0', 10);
        return acc;
      }, {});
      const reviewsByInstitution = reviewRows.reduce((acc, row) => {
        acc[String(row.institution_id)] = {
          avg_rating: parseFloat(row.avg_rating || '0') || 0,
          reviews_count: parseInt(row.reviews_count || '0', 10),
          recommend_yes: parseInt(row.recommend_yes || '0', 10)
        };
        return acc;
      }, {});

      const institutionIdsSet = new Set([
        ...Object.keys(childRequestsByInstitution),
        ...Object.keys(specialistRequestsByInstitution),
        ...Object.keys(sessionsByInstitution),
        ...Object.keys(reviewsByInstitution)
      ].filter(Boolean));

      const institutionIds = Array.from(institutionIdsSet)
        .map((v) => parseInt(v, 10))
        .filter((v) => !Number.isNaN(v));

      const institutions = await Institution.findAll({
        where: institutionIds.length ? { institution_id: { [Op.in]: institutionIds } } : undefined,
        attributes: ['institution_id', 'name', 'approval_status', 'city', 'region', 'is_active'],
        raw: true
      });

      const institutionsById = institutions.reduce((acc, inst) => {
        acc[String(inst.institution_id)] = inst;
        return acc;
      }, {});

      const rows = institutionIds.map((institutionId) => {
        const key = String(institutionId);
        const institution = institutionsById[key] || { institution_id: institutionId, name: 'Unknown' };

        const sessionsCount = sessionsByInstitution[key] || 0;
        const childRequestsCount = childRequestsByInstitution[key] || 0;
        const specialistRequestsCount = specialistRequestsByInstitution[key] || 0;
        const reviewStats = reviewsByInstitution[key] || { avg_rating: 0, reviews_count: 0, recommend_yes: 0 };

        const ratingBoost = (Math.min(5, Math.max(0, reviewStats.avg_rating)) / 5) * ratingWeight;
        const score = (sessionsCount * sessionsWeight)
          + (childRequestsCount * childRequestsWeight)
          + (specialistRequestsCount * specialistRequestsWeight)
          + ratingBoost;

        const recommendRate = reviewStats.reviews_count > 0
          ? (reviewStats.recommend_yes / reviewStats.reviews_count)
          : null;

        return {
          institution_id: institution.institution_id,
          name: institution.name,
          approval_status: institution.approval_status,
          is_active: institution.is_active,
          city: institution.city,
          region: institution.region,
          metrics: {
            sessions: sessionsCount,
            child_requests: childRequestsCount,
            specialist_requests: specialistRequestsCount,
            total_requests: childRequestsCount + specialistRequestsCount,
            reviews_count: reviewStats.reviews_count,
            avg_rating: reviewStats.avg_rating,
            recommend_rate: recommendRate
          },
          score
        };
      });

      rows.sort((a, b) => (b.score || 0) - (a.score || 0));
      const top = rows.slice(0, limit);

      const totals = {
        sessions: Object.values(sessionsByInstitution).reduce((s, v) => s + (v || 0), 0),
        child_requests: Object.values(childRequestsByInstitution).reduce((s, v) => s + (v || 0), 0),
        specialist_requests: Object.values(specialistRequestsByInstitution).reduce((s, v) => s + (v || 0), 0),
        reviews_count: Object.values(reviewsByInstitution).reduce((s, v) => s + ((v && v.reviews_count) || 0), 0)
      };
      totals.total_requests = totals.child_requests + totals.specialist_requests;
      const globalAvgRating = parseFloat(globalAvgRatingRow?.[0]?.avg_rating || '0') || 0;

      return res.json({
        success: true,
        data: {
          range_days: rangeDays,
          weights: {
            sessions: sessionsWeight,
            child_requests: childRequestsWeight,
            specialist_requests: specialistRequestsWeight,
            rating: ratingWeight
          },
          institution_statuses: institutionStatusCounts,
          totals: {
            ...totals,
            global_avg_rating: globalAvgRating
          },
          top_institutions: top
        }
      });
    } catch (error) {
      console.error('Institutions analytics overview error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error fetching institutions analytics overview'
      });
    }
  }

  async getInstitutionsAnalyticsTop(req, res) {
    try {
      const rangeDays = Math.max(7, Math.min(parseInt(req.query.range_days || '90', 10), 365));
      const limit = Math.max(1, Math.min(parseInt(req.query.limit || '10', 10), 100));

      const metricRaw = String(req.query.metric || 'score').trim().toLowerCase();
      const metric = ['score', 'child_requests', 'rating'].includes(metricRaw) ? metricRaw : 'score';

      const sessionsWeight = parseFloat(req.query.sessions_weight || '1');
      const childRequestsWeight = parseFloat(req.query.child_requests_weight || '3');
      const specialistRequestsWeight = parseFloat(req.query.specialist_requests_weight || '2');
      const ratingWeight = parseFloat(req.query.rating_weight || '5');

      const today = new Date();
      const start = new Date(today);
      start.setHours(0, 0, 0, 0);
      start.setDate(start.getDate() - (rangeDays - 1));

      const [childRequestsRows, specialistRequestsRows, sessionsRows, reviewRows] = await Promise.all([
        ChildRegistrationRequest.findAll({
          attributes: ['institution_id', [sequelize.fn('COUNT', sequelize.col('request_id')), 'count']],
          where: { requested_at: { [Op.gte]: start } },
          group: ['institution_id'],
          raw: true
        }),
        SpecialistRegistrationRequest.findAll({
          attributes: ['institution_id', [sequelize.fn('COUNT', sequelize.col('request_id')), 'count']],
          where: { requested_at: { [Op.gte]: start } },
          group: ['institution_id'],
          raw: true
        }),
        Session.findAll({
          attributes: ['institution_id', [sequelize.fn('COUNT', sequelize.col('session_id')), 'count']],
          where: { date: { [Op.gte]: start } },
          group: ['institution_id'],
          raw: true
        }),
        InstitutionReview.findAll({
          attributes: [
            'institution_id',
            [sequelize.fn('AVG', sequelize.col('overall_rating')), 'avg_rating'],
            [sequelize.fn('COUNT', sequelize.col('institution_review_id')), 'reviews_count'],
            [sequelize.fn('SUM', sequelize.literal("CASE WHEN would_recommend = 1 THEN 1 ELSE 0 END")), 'recommend_yes']
          ],
          where: { created_at: { [Op.gte]: start } },
          group: ['institution_id'],
          raw: true
        }),
      ]);

      const childRequestsByInstitution = childRequestsRows.reduce((acc, row) => {
        acc[String(row.institution_id)] = parseInt(row.count || '0', 10);
        return acc;
      }, {});
      const specialistRequestsByInstitution = specialistRequestsRows.reduce((acc, row) => {
        acc[String(row.institution_id)] = parseInt(row.count || '0', 10);
        return acc;
      }, {});
      const sessionsByInstitution = sessionsRows.reduce((acc, row) => {
        acc[String(row.institution_id)] = parseInt(row.count || '0', 10);
        return acc;
      }, {});
      const reviewsByInstitution = reviewRows.reduce((acc, row) => {
        acc[String(row.institution_id)] = {
          avg_rating: parseFloat(row.avg_rating || '0') || 0,
          reviews_count: parseInt(row.reviews_count || '0', 10),
          recommend_yes: parseInt(row.recommend_yes || '0', 10)
        };
        return acc;
      }, {});

      const institutionIdsSet = new Set([
        ...Object.keys(childRequestsByInstitution),
        ...Object.keys(specialistRequestsByInstitution),
        ...Object.keys(sessionsByInstitution),
        ...Object.keys(reviewsByInstitution)
      ].filter(Boolean));

      const institutionIds = Array.from(institutionIdsSet)
        .map((v) => parseInt(v, 10))
        .filter((v) => !Number.isNaN(v));

      const institutions = await Institution.findAll({
        where: institutionIds.length ? { institution_id: { [Op.in]: institutionIds } } : undefined,
        attributes: ['institution_id', 'name', 'approval_status', 'city', 'region', 'is_active'],
        raw: true
      });

      const institutionsById = institutions.reduce((acc, inst) => {
        acc[String(inst.institution_id)] = inst;
        return acc;
      }, {});

      const rows = institutionIds.map((institutionId) => {
        const key = String(institutionId);
        const institution = institutionsById[key] || { institution_id: institutionId, name: 'Unknown' };

        const sessionsCount = sessionsByInstitution[key] || 0;
        const childRequestsCount = childRequestsByInstitution[key] || 0;
        const specialistRequestsCount = specialistRequestsByInstitution[key] || 0;
        const reviewStats = reviewsByInstitution[key] || { avg_rating: 0, reviews_count: 0, recommend_yes: 0 };

        const ratingBoost = (Math.min(5, Math.max(0, reviewStats.avg_rating)) / 5) * ratingWeight;
        const score = (sessionsCount * sessionsWeight)
          + (childRequestsCount * childRequestsWeight)
          + (specialistRequestsCount * specialistRequestsWeight)
          + ratingBoost;

        const recommendRate = reviewStats.reviews_count > 0
          ? (reviewStats.recommend_yes / reviewStats.reviews_count)
          : null;

        return {
          institution_id: institution.institution_id,
          name: institution.name,
          approval_status: institution.approval_status,
          is_active: institution.is_active,
          city: institution.city,
          region: institution.region,
          metrics: {
            sessions: sessionsCount,
            child_requests: childRequestsCount,
            specialist_requests: specialistRequestsCount,
            total_requests: childRequestsCount + specialistRequestsCount,
            reviews_count: reviewStats.reviews_count,
            avg_rating: reviewStats.avg_rating,
            recommend_rate: recommendRate
          },
          score
        };
      });

      if (metric === 'child_requests') {
        rows.sort((a, b) => ((b.metrics?.child_requests || 0) - (a.metrics?.child_requests || 0)) || ((b.score || 0) - (a.score || 0)));
      } else if (metric === 'rating') {
        rows.sort((a, b) => ((b.metrics?.avg_rating || 0) - (a.metrics?.avg_rating || 0)) || ((b.metrics?.reviews_count || 0) - (a.metrics?.reviews_count || 0)));
      } else {
        rows.sort((a, b) => (b.score || 0) - (a.score || 0));
      }

      return res.json({
        success: true,
        data: {
          range_days: rangeDays,
          metric,
          top_institutions: rows.slice(0, limit)
        }
      });
    } catch (error) {
      console.error('Institutions analytics top error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error fetching institutions analytics top'
      });
    }
  }

  async getInstitutionsAnalyticsHistory(req, res) {
    try {
      const rangeDays = Math.max(7, Math.min(parseInt(req.query.range_days || '90', 10), 365));
      const bucket = String(req.query.bucket || 'day').toLowerCase() === 'month' ? 'month' : 'day';

      const today = new Date();
      const start = new Date(today);
      start.setHours(0, 0, 0, 0);
      start.setDate(start.getDate() - (rangeDays - 1));

      const bucketExprRequests = bucket === 'month'
        ? sequelize.fn('DATE_FORMAT', sequelize.col('requested_at'), '%Y-%m')
        : sequelize.fn('DATE', sequelize.col('requested_at'));
      const bucketExprSessions = bucket === 'month'
        ? sequelize.fn('DATE_FORMAT', sequelize.col('date'), '%Y-%m')
        : sequelize.fn('DATE', sequelize.col('date'));
      const bucketExprReviews = bucket === 'month'
        ? sequelize.fn('DATE_FORMAT', sequelize.col('created_at'), '%Y-%m')
        : sequelize.fn('DATE', sequelize.col('created_at'));

      const [childRows, specialistRows, sessionRows, reviewRows] = await Promise.all([
        ChildRegistrationRequest.findAll({
          attributes: [[bucketExprRequests, 'bucket'], [sequelize.fn('COUNT', sequelize.col('request_id')), 'count']],
          where: { requested_at: { [Op.gte]: start } },
          group: ['bucket'],
          order: [[sequelize.literal('bucket'), 'ASC']],
          raw: true
        }),
        SpecialistRegistrationRequest.findAll({
          attributes: [[bucketExprRequests, 'bucket'], [sequelize.fn('COUNT', sequelize.col('request_id')), 'count']],
          where: { requested_at: { [Op.gte]: start } },
          group: ['bucket'],
          order: [[sequelize.literal('bucket'), 'ASC']],
          raw: true
        }),
        Session.findAll({
          attributes: [[bucketExprSessions, 'bucket'], [sequelize.fn('COUNT', sequelize.col('session_id')), 'count']],
          where: { date: { [Op.gte]: start } },
          group: ['bucket'],
          order: [[sequelize.literal('bucket'), 'ASC']],
          raw: true
        }),
        InstitutionReview.findAll({
          attributes: [[bucketExprReviews, 'bucket'], [sequelize.fn('COUNT', sequelize.col('institution_review_id')), 'count']],
          where: { created_at: { [Op.gte]: start } },
          group: ['bucket'],
          order: [[sequelize.literal('bucket'), 'ASC']],
          raw: true
        })
      ]);

      return res.json({
        success: true,
        data: {
          range_days: rangeDays,
          bucket,
          series: {
            child_requests: childRows,
            specialist_requests: specialistRows,
            sessions: sessionRows,
            reviews: reviewRows
          }
        }
      });
    } catch (error) {
      console.error('Institutions analytics history error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error fetching institutions analytics history'
      });
    }
  }

  async getSystemHealth(req, res) {
    try {
      await sequelize.authenticate();
      const uptime = process.uptime();
      const mem = process.memoryUsage();

      return res.json({
        success: true,
        data: {
          status: 'healthy',
          uptime_seconds: uptime,
          memory: {
            rss_mb: Math.floor(mem.rss / 1024 / 1024),
            heap_used_mb: Math.floor(mem.heapUsed / 1024 / 1024),
            heap_total_mb: Math.floor(mem.heapTotal / 1024 / 1024)
          },
          database: 'connected',
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      return res.status(503).json({
        success: false,
        data: {
          status: 'unhealthy',
          database: 'disconnected',
          timestamp: new Date().toISOString()
        },
        message: error.message
      });
    }
  }

  // ==================== INSTITUTION MANAGEMENT ====================
  async getPendingInstitutions(req, res) {
    try {
      const { page = 1, limit = 20, search = '' } = req.query;
      const offset = (page - 1) * limit;

      const whereCondition = {
        approval_status: 'Pending'
      };

      if (search) {
        whereCondition[Op.or] = [
          { name: { [Op.like]: `%${search}%` } },
          { contact_email: { [Op.like]: `%${search}%` } },
          { contact_phone: { [Op.like]: `%${search}%` } }
        ];
      }

      const institutions = await Institution.findAndCountAll({
        where: whereCondition,
        include: [
          {
            model: Manager,
            attributes: ['manager_id', 'institution_id', 'department', 'is_active'],
            include: [
              {
                model: User,
                attributes: ['user_id', 'full_name', 'email', 'phone']
              }
            ]
          }
        ],
        limit: parseInt(limit),
        offset: parseInt(offset),
        order: [['created_at', 'DESC']]
      });

      const institutionsWithManagers = institutions.rows.map((institution) => {
        const data = institution.toJSON();
        const managers = Array.isArray(data.Managers)
          ? data.Managers.map((m) => m.User).filter(Boolean)
          : [];

        delete data.Managers;

        return {
          ...data,
          managers
        };
      });

      res.json({
        success: true,
        data: {
          institutions: institutionsWithManagers,
          total: institutions.count,
          page: parseInt(page),
          totalPages: Math.ceil(institutions.count / limit)
        }
      });
    } catch (error) {
      console.error('Get pending institutions error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error fetching institutions' 
      });
    }
  }

  async approveInstitution(req, res) {
    const transaction = await sequelize.transaction();
    
    try {
      const { institution_id } = req.params;
      const { notes } = req.body;

      const institution = await Institution.findByPk(institution_id, { transaction });
      if (!institution) {
        await transaction.rollback();
        return res.status(404).json({ 
          success: false, 
          message: 'Institution not found' 
        });
      }

      institution.approval_status = 'Approved';
      institution.is_active = true;
      institution.updated_at = new Date();
      await institution.save({ transaction });

      const manager = await User.findOne({
        where: { 
          institution_id: institution_id,
          role: 'Manager'
        },
        transaction
      });

      if (manager) {
        manager.status = 'Approved';
        await manager.save({ transaction });

        await Manager.findOrCreate({
          where: { manager_id: manager.user_id },
          defaults: {
            manager_id: manager.user_id,
            institution_id: institution_id,
            is_active: true
          },
          transaction
        });

        await Notification.create({
          user_id: manager.user_id,
          title: 'تمت الموافقة على مؤسستك',
          message: `تمت الموافقة على مؤسسة "${institution.name}" من قبل الإدارة. يمكنك الآن بدء العمل.`,
          type: 'institution_approval',
          related_id: institution_id,
          created_at: new Date()
        }, { transaction });
      }

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'institution_approval',
        target_type: 'Institution',
        target_id: institution_id,
        details: notes || 'Institution approved by admin',
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      res.json({
        success: true,
        message: 'Institution approved successfully'
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Approve institution error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error approving institution' 
      });
    }
  }

  async rejectInstitution(req, res) {
    const transaction = await sequelize.transaction();
    
    try {
      const { institution_id } = req.params;
      const { reason } = req.body;

      if (!reason) {
        return res.status(400).json({ 
          success: false, 
          message: 'Rejection reason is required' 
        });
      }

      const institution = await Institution.findByPk(institution_id, { transaction });
      if (!institution) {
        await transaction.rollback();
        return res.status(404).json({ 
          success: false, 
          message: 'Institution not found' 
        });
      }

      institution.approval_status = 'Rejected';
      institution.rejection_reason = reason;
      institution.is_active = false;
      institution.updated_at = new Date();
      await institution.save({ transaction });

      const manager = await User.findOne({
        where: { 
          institution_id: institution_id,
          role: 'Manager'
        },
        transaction
      });

      if (manager) {
        await Notification.create({
          user_id: manager.user_id,
          title: 'تم رفض مؤسستك',
          message: `تم رفض مؤسسة "${institution.name}" للأسباب التالية: ${reason}`,
          type: 'institution_rejection',
          related_id: institution_id,
          created_at: new Date()
        }, { transaction });
      }

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'institution_rejection',
        target_type: 'Institution',
        target_id: institution_id,
        details: reason,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      res.json({
        success: true,
        message: 'Institution rejected successfully'
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Reject institution error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error rejecting institution' 
      });
    }
  }

  async suspendInstitution(req, res) {
    const transaction = await sequelize.transaction();
    
    try {
      const { institution_id } = req.params;
      const { reason, duration_days } = req.body;

      const institution = await Institution.findByPk(institution_id, { transaction });
      if (!institution) {
        await transaction.rollback();
        return res.status(404).json({ 
          success: false, 
          message: 'Institution not found' 
        });
      }

      institution.approval_status = 'Suspended';
      institution.is_active = false;
      institution.rejection_reason = reason || 'Suspended by admin';
      institution.updated_at = new Date();
      await institution.save({ transaction });

      await Specialist.update(
        { approval_status: 'Archived' },
        { 
          where: { institution_id: institution_id },
          transaction 
        }
      );

      const specialists = await User.findAll({
        where: { 
          institution_id: institution_id,
          role: 'Specialist'
        },
        transaction
      });

      for (const specialist of specialists) {
        await Notification.create({
          user_id: specialist.user_id,
          title: 'تم تعليق المؤسسة',
          message: `تم تعليق مؤسسة "${institution.name}" مؤقتاً. جميع الجلسات معلقة حتى إشعار آخر.`,
          type: 'institution_suspension',
          related_id: institution_id,
          created_at: new Date()
        }, { transaction });
      }

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'institution_suspension',
        target_type: 'Institution',
        target_id: institution_id,
        details: reason || 'Institution suspended',
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      res.json({
        success: true,
        message: 'Institution suspended successfully'
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Suspend institution error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error suspending institution' 
      });
    }
  }

  // ==================== 👥 USER MANAGEMENT ====================
  async getPendingUsers(req, res) {
    try {
      const { role, page = 1, limit = 20 } = req.query;
      const offset = (page - 1) * limit;

      const whereCondition = { status: 'Pending' };
      if (role && ['Specialist', 'Manager'].includes(role)) {
        whereCondition.role = role;
      } else {
        whereCondition.role = { [Op.in]: ['Specialist', 'Manager'] };
      }

      const users = await User.findAndCountAll({
        where: whereCondition,
        include: [
          {
            model: Institution,
            as: 'institution',
            attributes: ['name', 'institution_id']
          }
        ],
        attributes: { exclude: ['password'] },
        limit: parseInt(limit),
        offset: parseInt(offset),
        order: [['created_at', 'DESC']]
      });

      res.json({
        success: true,
        data: {
          users: users.rows,
          total: users.count,
          page: parseInt(page),
          totalPages: Math.ceil(users.count / limit)
        }
      });
    } catch (error) {
      console.error('Get pending users error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error fetching pending users' 
      });
    }
  }

  async approveUser(req, res) {
    const transaction = await sequelize.transaction();
    
    try {
      const { user_id } = req.params;
      const user = await User.findByPk(user_id, { transaction });

      if (!user) {
        await transaction.rollback();
        return res.status(404).json({ 
          success: false, 
          message: 'User not found' 
        });
      }

      if (user.status !== 'Pending') {
        await transaction.rollback();
        return res.status(400).json({ 
          success: false, 
          message: 'User is not pending approval' 
        });
      }

      user.status = 'Approved';
      await user.save({ transaction });

      if (user.role === 'Specialist') {
        await Specialist.update(
          { approval_status: 'Approved' },
          { 
            where: { specialist_id: user_id },
            transaction 
          }
        );
      }

      if (user.role === 'Manager') {
        await Manager.findOrCreate({
          where: { manager_id: user.user_id },
          defaults: {
            manager_id: user.user_id,
            institution_id: user.institution_id,
            is_active: true
          },
          transaction
        });
      }

      await Notification.create({
        user_id: user.user_id,
        title: 'تمت الموافقة على حسابك',
        message: 'تمت الموافقة على حسابك من قبل الإدارة. يمكنك الآن تسجيل الدخول والبدء باستخدام التطبيق.',
        type: 'user_approval',
        related_id: user.user_id,
        created_at: new Date()
      }, { transaction });

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'user_approval',
        target_type: 'User',
        target_id: user_id,
        details: `Approved ${user.role} user`,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      res.json({
        success: true,
        message: 'User approved successfully'
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Approve user error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error approving user' 
      });
    }
  }

  async suspendUser(req, res) {
    const transaction = await sequelize.transaction();
    
    try {
      const { user_id } = req.params;
      const { reason } = req.body;

      if (!reason) {
        return res.status(400).json({ 
          success: false, 
          message: 'Suspension reason is required' 
        });
      }

      const user = await User.findByPk(user_id, { transaction });
      if (!user) {
        await transaction.rollback();
        return res.status(404).json({ 
          success: false, 
          message: 'User not found' 
        });
      }

      if (user.role === 'Admin') {
        await transaction.rollback();
        return res.status(403).json({ 
          success: false, 
          message: 'Cannot suspend admin users' 
        });
      }

      user.status = 'Canceled';
      await user.save({ transaction });

      if (user.role === 'Specialist') {
        await Specialist.update(
          { approval_status: 'Archived' },
          { 
            where: { specialist_id: user_id },
            transaction 
          }
        );

        await Session.update(
          { status: 'Cancelled' },
          { 
            where: { 
              specialist_id: user_id,
              date: { [Op.gte]: new Date() },
              status: { [Op.notIn]: ['Completed', 'Cancelled'] }
            },
            transaction 
          }
        );
      }

      await Notification.create({
        user_id: user.user_id,
        title: 'تم تعليق حسابك',
        message: `تم تعليق حسابك للأسباب التالية: ${reason}. يرجى التواصل مع الإدارة لمزيد من التفاصيل.`,
        type: 'user_suspension',
        related_id: user.user_id,
        created_at: new Date()
      }, { transaction });

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'user_suspension',
        target_type: 'User',
        target_id: user_id,
        details: reason,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      res.json({
        success: true,
        message: 'User suspended successfully'
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Suspend user error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error suspending user' 
      });
    }
  }

  // ==================== 📋 REPORT MANAGEMENT ====================
  async getAllReports(req, res) {
    try {
      const { status, priority, page = 1, limit = 20 } = req.query;
      const offset = (page - 1) * limit;

      const whereCondition = {};
      if (status) whereCondition.status = status;
      if (priority) whereCondition.priority = priority;

      const reports = await Report.findAndCountAll({
        where: whereCondition,
        include: [
          {
            model: User,
            as: 'reporter',
            attributes: ['user_id', 'full_name', 'email', 'role']
          },
          {
            model: Institution,
            as: 'ReportInstitution',
            attributes: ['institution_id', 'name']
          }
        ],
        limit: parseInt(limit),
        offset: parseInt(offset),
        order: [['created_at', 'DESC']]
      });

      res.json({
        success: true,
        data: {
          reports: reports.rows,
          total: reports.count,
          page: parseInt(page),
          totalPages: Math.ceil(reports.count / limit)
        }
      });
    } catch (error) {
      console.error('Get reports error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error fetching reports' 
      });
    }
  }

  async updateReportStatus(req, res) {
    const transaction = await sequelize.transaction();
    
    try {
      const { report_id } = req.params;
      const { status, admin_notes } = req.body;

      const report = await Report.findByPk(report_id, { transaction });
      if (!report) {
        await transaction.rollback();
        return res.status(404).json({ 
          success: false, 
          message: 'Report not found' 
        });
      }

      const oldStatus = report.status;
      report.status = status;
      report.updated_at = new Date();
      
      if (admin_notes) {
        report.description = report.description + '\n\n[Admin Note]: ' + admin_notes;
      }
      
      await report.save({ transaction });

      await Notification.create({
        user_id: report.reporter_user_id,
        title: 'تحديث حالة البلاغ',
        message: `تم تحديث حالة البلاغ #${report_id} إلى "${status}".`,
        type: 'report_update',
        related_id: report_id,
        created_at: new Date()
      }, { transaction });

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'report_resolution',
        target_type: 'Report',
        target_id: report_id,
        details: `Status changed from ${oldStatus} to ${status}`,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      res.json({
        success: true,
        message: 'Report status updated successfully'
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Update report error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error updating report' 
      });
    }
  }

  // ==================== 💰 DONATION MANAGEMENT ====================
  async getAllDonations(req, res) {
    try {
      const { start_date, end_date, institution_id, page = 1, limit = 20 } = req.query;
      const offset = (page - 1) * limit;

      const whereCondition = {};
      
      if (start_date && end_date) {
        whereCondition.date = {
          [Op.between]: [new Date(start_date), new Date(end_date)]
        };
      }
      
      if (institution_id) {
        whereCondition.institution_id = institution_id;
      }

      const donations = await Donation.findAndCountAll({
        where: whereCondition,
        include: [
          {
            model: Institution,
            attributes: ['institution_id', 'name']
          }
        ],
        limit: parseInt(limit),
        offset: parseInt(offset),
        order: [['date', 'DESC']]
      });

      const totalAmount = await Donation.sum('amount', { where: whereCondition });
      const totalCount = await Donation.count({ where: whereCondition });

      res.json({
        success: true,
        data: {
          donations: donations.rows,
          summary: {
            total_amount: totalAmount || 0,
            total_count: totalCount,
            average_donation: totalCount > 0 ? totalAmount / totalCount : 0
          },
          total: donations.count,
          page: parseInt(page),
          totalPages: Math.ceil(donations.count / limit)
        }
      });
    } catch (error) {
      console.error('Get donations error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error fetching donations' 
      });
    }
  }

  // ==================== ⚙️ SYSTEM SETTINGS ====================
  async getSettings(req, res) {
    try {
      const { category } = req.query;
      
      const whereCondition = {};
      if (category) whereCondition.category = category;

      const settings = await SystemSettings.findAll({
        where: whereCondition,
        order: [['category', 'ASC'], ['setting_key', 'ASC']]
      });

      const processedSettings = settings.map(setting => {
        let value = setting.setting_value;
        
        switch (setting.setting_type) {
          case 'number':
            value = parseFloat(value);
            break;
          case 'boolean':
            value = value === 'true' || value === '1';
            break;
          case 'json':
            try {
              value = JSON.parse(value);
            } catch {
              value = value;
            }
            break;
          case 'array':
            try {
              value = JSON.parse(value);
              if (!Array.isArray(value)) value = [value];
            } catch {
              value = [value];
            }
            break;
        }
        
        return {
          ...setting.toJSON(),
          setting_value: value
        };
      });

      res.json({
        success: true,
        data: processedSettings
      });
    } catch (error) {
      console.error('Get settings error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error fetching settings' 
      });
    }
  }

  async updateSetting(req, res) {
    const transaction = await sequelize.transaction();
    
    try {
      const { setting_id } = req.params;
      const { setting_value } = req.body;

      const setting = await SystemSettings.findByPk(setting_id, { transaction });
      if (!setting) {
        await transaction.rollback();
        return res.status(404).json({ 
          success: false, 
          message: 'Setting not found' 
        });
      }

      if (!setting.is_editable) {
        await transaction.rollback();
        return res.status(403).json({ 
          success: false, 
          message: 'This setting is not editable' 
        });
      }

      let stringValue;
      switch (setting.setting_type) {
        case 'boolean':
          stringValue = setting_value ? 'true' : 'false';
          break;
        case 'number':
          stringValue = setting_value.toString();
          break;
        case 'json':
        case 'array':
          stringValue = JSON.stringify(setting_value);
          break;
        default:
          stringValue = setting_value;
      }

      setting.setting_value = stringValue;
      setting.updated_by = req.user.user_id;
      setting.updated_at = new Date();
      await setting.save({ transaction });

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'setting_change',
        target_type: 'SystemSetting',
        target_id: setting_id,
        details: `Updated ${setting.setting_key} to ${stringValue}`,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      res.json({
        success: true,
        message: 'Setting updated successfully'
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Update setting error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error updating setting' 
      });
    }
  }

  // ==================== 📈 ADVANCED STATISTICS ====================
  async getDetailedStats(req, res) {
    try {
      const { start_date, end_date } = req.query;
      
      const dateFilter = {};
      if (start_date && end_date) {
        dateFilter[Op.between] = [new Date(start_date), new Date(end_date)];
      }

      const userStats = await User.findAll({
        attributes: [
          'role',
          [sequelize.fn('COUNT', sequelize.col('user_id')), 'count']
        ],
        group: ['role'],
        raw: true
      });

      const institutionStats = await Institution.findAll({
        attributes: [
          'approval_status',
          [sequelize.fn('COUNT', sequelize.col('institution_id')), 'count']
        ],
        group: ['approval_status'],
        raw: true
      });

      const monthlyDonations = await Donation.findAll({
        attributes: [
          [sequelize.fn('DATE_FORMAT', sequelize.col('date'), '%Y-%m'), 'month'],
          [sequelize.fn('SUM', sequelize.col('amount')), 'total']
        ],
        where: dateFilter,
        group: ['month'],
        order: [['month', 'ASC']],
        raw: true
      });

      const monthlySessions = await Session.findAll({
        attributes: [
          [sequelize.fn('DATE_FORMAT', sequelize.col('date'), '%Y-%m'), 'month'],
          [sequelize.fn('COUNT', sequelize.col('session_id')), 'count']
        ],
        where: dateFilter,
        group: ['month'],
        order: [['month', 'ASC']],
        raw: true
      });

      const topInstitutions = await Donation.findAll({
        attributes: [
          'institution_id',
          [sequelize.fn('SUM', sequelize.col('amount')), 'total_donations']
        ],
        include: [{
          model: Institution,
          attributes: ['name']
        }],
        where: dateFilter,
        group: ['institution_id'],
        order: [[sequelize.fn('SUM', sequelize.col('amount')), 'DESC']],
        limit: 10,
        raw: true
      });

      res.json({
        success: true,
        data: {
          user_statistics: userStats,
          institution_statistics: institutionStats,
          monthly_donations: monthlyDonations,
          monthly_sessions: monthlySessions,
          top_institutions: topInstitutions
        }
      });
    } catch (error) {
      console.error('Detailed stats error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error fetching detailed statistics' 
      });
    }
  }

  // ==================== 🗑️ CONTENT MODERATION ====================
  async removeContent(req, res) {
    const transaction = await sequelize.transaction();
    
    try {
      const { content_type, content_id, reason } = req.body;

      if (!content_type || !content_id || !reason) {
        return res.status(400).json({ 
          success: false, 
          message: 'Content type, ID, and reason are required' 
        });
      }

      let content;
      let user_id;

      switch (content_type) {
        case 'post':
          content = await Post.findByPk(content_id, { transaction });
          if (content) user_id = content.user_id;
          break;
        case 'comment':
          content = await Comment.findByPk(content_id, { transaction });
          if (content) user_id = content.user_id;
          break;
        case 'review':
          content = await InstitutionReview.findByPk(content_id, { transaction });
          if (content) user_id = content.parent_id;
          break;
        default:
          await transaction.rollback();
          return res.status(400).json({ 
            success: false, 
            message: 'Invalid content type' 
          });
      }

      if (!content) {
        await transaction.rollback();
        return res.status(404).json({ 
          success: false, 
          message: 'Content not found' 
        });
      }

      await content.destroy({ transaction });

      if (user_id) {
        await Notification.create({
          user_id: user_id,
          title: 'تم إزالة محتوى',
          message: `تم إزالة محتوى من نوع ${content_type} للأسباب التالية: ${reason}`,
          type: 'content_removal',
          related_id: content_id,
          created_at: new Date()
        }, { transaction });
      }

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'content_removal',
        target_type: content_type,
        target_id: content_id,
        details: reason,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      res.json({
        success: true,
        message: 'Content removed successfully'
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Remove content error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error removing content' 
      });
    }
  }

  // ==================== 📜 AUDIT LOGS ====================
  async getAuditLogs(req, res) {
    try {
      const { admin_id, action_type, start_date, end_date, page = 1, limit = 50 } = req.query;
      const offset = (page - 1) * limit;

      const whereCondition = {};
      
      if (admin_id) whereCondition.admin_id = admin_id;
      if (action_type) whereCondition.action_type = action_type;
      
      if (start_date && end_date) {
        whereCondition.created_at = {
          [Op.between]: [new Date(start_date), new Date(end_date)]
        };
      }

      const logs = await AuditLog.findAndCountAll({
        where: whereCondition,
        include: [{
          model: User,
          as: 'admin',
          attributes: ['user_id', 'full_name', 'email']
        }],
        limit: parseInt(limit),
        offset: parseInt(offset),
        order: [['created_at', 'DESC']]
      });

      res.json({
        success: true,
        data: {
          logs: logs.rows,
          total: logs.count,
          page: parseInt(page),
          totalPages: Math.ceil(logs.count / limit)
        }
      });
    } catch (error) {
      console.error('Get audit logs error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Error fetching audit logs' 
      });
    }
  }
  
  // ==================== 👥 ALL USERS MANAGEMENT ====================
async getAllUsers(req, res) {
  try {
    const { 
      page = 1, 
      limit = 20, 
      search = '',
      role = '',
      status = '',
      institution_id = ''
    } = req.query;
    
    const offset = (page - 1) * limit;

    const whereCondition = {};
    
    if (search) {
      whereCondition[Op.or] = [
        { full_name: { [Op.like]: `%${search}%` } },
        { email: { [Op.like]: `%${search}%` } },
        { phone: { [Op.like]: `%${search}%` } }
      ];
    }
    
    if (role) whereCondition.role = role;
    if (status) whereCondition.status = status;
    if (institution_id) whereCondition.institution_id = institution_id;

    const includeModels = [
      {
        model: Institution,
        as: 'institution',
        attributes: ['institution_id', 'name']
      }
    ];

    const users = await User.findAndCountAll({
      where: whereCondition,
      include: includeModels,
      attributes: { 
        exclude: ['password'] 
      },
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['created_at', 'DESC']],
      distinct: true
    });

    const stats = await User.findAll({
      attributes: [
        'role',
        [sequelize.fn('COUNT', sequelize.col('user_id')), 'count']
      ],
      group: ['role'],
      raw: true
    });

    const thisMonth = new Date();
    const firstDay = new Date(thisMonth.getFullYear(), thisMonth.getMonth(), 1);
    
    const newThisMonth = await User.count({
      where: {
        created_at: {
          [Op.gte]: firstDay
        }
      }
    });

    res.json({
      success: true,
      data: {
        users: users.rows,
        total: users.count,
        page: parseInt(page),
        totalPages: Math.ceil(users.count / limit),
        statistics: {
          by_role: stats,
          new_this_month: newThisMonth,
          total_active: await User.count({ where: { status: 'Approved' } }),
          total_pending: await User.count({ where: { status: 'Pending' } })
        }
      }
    });
  } catch (error) {
    console.error('Get all users error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching users' 
    });
  }
}

async getUserDetails(req, res) {
  try {
    const { user_id } = req.params;

    const user = await User.findByPk(user_id, {
      attributes: { exclude: ['password'] },
      include: [
        {
          model: Institution,
          as: 'institution',
          attributes: ['institution_id', 'name', 'contact_email', 'contact_phone']
        },
        {
          model: Parent,
          as: 'parent',
          attributes: ['address', 'occupation', 'financial_score', 'financial_tier'],
          required: false
        },
        {
          model: Specialist,
          as: 'specialist',
          attributes: ['specialization', 'years_experience', 'approval_status'],
          required: false
        },
        {
          model: Manager,
          as: 'manager',
          attributes: ['department', 'permissions'],
          required: false
        }
      ]
    });

    if (!user) {
      return res.status(404).json({ 
        success: false, 
        message: 'User not found' 
      });
    }

    let additionalInfo = {};
    
    if (user.role === 'Parent') {
      const childrenCount = await Child.count({ 
        where: { parent_id: user_id } 
      });
      
      const sessions = await Session.findAll({
        where: { 
          child_id: { 
            [Op.in]: sequelize.literal(
              `(SELECT child_id FROM Children WHERE parent_id = ${user_id})`
            )
          }
        },
        attributes: ['session_id', 'date', 'status', 'final_price'],
        limit: 10,
        order: [['date', 'DESC']]
      });

      additionalInfo = {
        children_count: childrenCount,
        recent_sessions: sessions
      };
    }

    if (user.role === 'Specialist') {
      const sessionsCount = await Session.count({ 
        where: { specialist_id: user_id } 
      });
      
      const completedSessions = await Session.count({
        where: { 
          specialist_id: user_id,
          status: 'Completed'
        }
      });

      const ratings = await SessionRating.findAll({
        where: { specialist_id: user_id },
        attributes: [
          [sequelize.fn('AVG', sequelize.col('rating')), 'average_rating'],
          [sequelize.fn('COUNT', sequelize.col('session_rating_id')), 'total_ratings']
        ],
        raw: true
      });

      additionalInfo = {
        sessions_count: sessionsCount,
        completed_sessions: completedSessions,
        average_rating: ratings[0]?.average_rating || 0,
        total_ratings: ratings[0]?.total_ratings || 0
      };
    }

    res.json({
      success: true,
      data: {
        user,
        additional_info: additionalInfo
      }
    });
  } catch (error) {
    console.error('Get user details error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching user details' 
    });
  }
}

async updateUserStatus(req, res) {
  const transaction = await sequelize.transaction();
  
  try {
    const { user_id } = req.params;
    const { status, reason } = req.body;

    const user = await User.findByPk(user_id, { transaction });
    if (!user) {
      await transaction.rollback();
      return res.status(404).json({ 
        success: false, 
        message: 'User not found' 
      });
    }

    if (user.role === 'Admin' && req.user.user_id !== user_id) {
      await transaction.rollback();
      return res.status(403).json({ 
        success: false, 
        message: 'Cannot modify other admin accounts' 
      });
    }

    const oldStatus = user.status;
    user.status = status;
    user.updated_at = new Date();
    await user.save({ transaction });

    if (user.role === 'Specialist') {
      const specialist = await Specialist.findByPk(user_id, { transaction });
      if (specialist) {
        if (status === 'Canceled' || status === 'Rejected') {
          specialist.approval_status = 'Archived';
        } else if (status === 'Approved') {
          specialist.approval_status = 'Approved';
        }
        await specialist.save({ transaction });
      }
    }

    if (user.role === 'Manager') {
      const manager = await Manager.findByPk(user_id, { transaction });
      if (manager) {
        manager.is_active = status === 'Approved';
        await manager.save({ transaction });
      }
    }

    await Notification.create({
      user_id: user.user_id,
      title: 'Account Status Updated',
      message: `Your account status has been changed from ${oldStatus} to ${status}. ${reason ? `Reason: ${reason}` : ''}`,
      type: 'account_status_change',
      related_id: user.user_id,
      created_at: new Date()
    }, { transaction });

    await AuditLog.create({
      admin_id: req.user.user_id,
      action_type: 'user_status_change',
      target_type: 'User',
      target_id: user_id,
      details: `Status changed from ${oldStatus} to ${status}. Reason: ${reason || 'No reason provided'}`,
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      created_at: new Date()
    }, { transaction });

    await transaction.commit();

    res.json({
      success: true,
      message: 'User status updated successfully'
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Update user status error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error updating user status' 
    });
  }
}

async deleteUser(req, res) {
  const transaction = await sequelize.transaction();
  
  try {
    const { user_id } = req.params;
    const { reason } = req.body;

    const user = await User.findByPk(user_id, { transaction });
    if (!user) {
      await transaction.rollback();
      return res.status(404).json({ 
        success: false, 
        message: 'User not found' 
      });
    }

    if (user.role === 'Admin') {
      await transaction.rollback();
      return res.status(403).json({ 
        success: false, 
        message: 'Cannot delete admin accounts' 
      });
    }

    const userData = user.toJSON();
    delete userData.password;

    await user.destroy({ transaction });

    if (user.role === 'Parent') {
      await Parent.destroy({ 
        where: { parent_id: user_id },
        transaction 
      });
    }

    if (user.role === 'Specialist') {
      await Specialist.destroy({ 
        where: { specialist_id: user_id },
        transaction 
      });
    }

    if (user.role === 'Manager') {
      await Manager.destroy({ 
        where: { manager_id: user_id },
        transaction 
      });
    }

    await AuditLog.create({
      admin_id: req.user.user_id,
      action_type: 'user_deletion',
      target_type: 'User',
      target_id: user_id,
      details: JSON.stringify({
        deleted_user: userData,
        reason: reason || 'No reason provided'
      }),
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      created_at: new Date()
    }, { transaction });

    await transaction.commit();

    res.json({
      success: true,
      message: 'User deleted successfully'
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Delete user error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error deleting user' 
    });
  }
} 

// ==================== 🏢 ALL INSTITUTIONS MANAGEMENT ====================
async getAllInstitutions(req, res) {
  try {
    const { 
      page = 1, 
      limit = 20, 
      search = '',
      status = '',
      city = '',
      region = ''
    } = req.query;
    
    const offset = (page - 1) * limit;

    const whereCondition = {};
    
    if (search) {
      whereCondition[Op.or] = [
        { name: { [Op.like]: `%${search}%` } },
        { contact_email: { [Op.like]: `%${search}%` } },
        { contact_phone: { [Op.like]: `%${search}%` } },
        { location_address: { [Op.like]: `%${search}%` } }
      ];
    }
    
    if (status) whereCondition.approval_status = status;
    if (city) whereCondition.city = city;
    if (region) whereCondition.region = region;

    const institutions = await Institution.findAndCountAll({
      where: whereCondition,
      include: [
        {
          model: Manager,
          attributes: ['manager_id', 'institution_id', 'department', 'is_active'],
          include: [
            {
              model: User,
              attributes: ['user_id', 'full_name', 'email', 'phone', 'status']
            }
          ],
          required: false
        },
        {
          model: Specialist,
          attributes: ['specialist_id', 'specialization', 'approval_status'],
          required: false
        }
      ],
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['created_at', 'DESC']],
      distinct: true
    });

    const institutionsWithManagers = institutions.rows.map((institution) => {
      const data = institution.toJSON();
      const managers = Array.isArray(data.Managers)
        ? data.Managers.map((m) => m.User).filter(Boolean)
        : [];

      delete data.Managers;

      return {
        ...data,
        managers
      };
    });

    const stats = await Institution.findAll({
      attributes: [
        'approval_status',
        [sequelize.fn('COUNT', sequelize.col('institution_id')), 'count']
      ],
      group: ['approval_status'],
      raw: true
    });

    const activeInstitutions = await Session.findAll({
      attributes: [
        'institution_id',
        [sequelize.fn('COUNT', sequelize.col('session_id')), 'sessions_count']
      ],
      where: {
        date: {
          [Op.gte]: new Date(new Date() - 30 * 24 * 60 * 60 * 1000) 
        }
      },
      group: ['institution_id'],
      order: [[sequelize.fn('COUNT', sequelize.col('session_id')), 'DESC']],
      limit: 5,
      raw: true
    });

    const activeInstitutionIds = activeInstitutions.map(inst => inst.institution_id);
    const activeInstitutionDetails = await Institution.findAll({
      where: {
        institution_id: { [Op.in]: activeInstitutionIds }
      },
      attributes: ['institution_id', 'name'],
      raw: true
    });

    const activeWithNames = activeInstitutions.map(inst => ({
      ...inst,
      name: activeInstitutionDetails.find(d => d.institution_id === inst.institution_id)?.name || 'Unknown'
    }));

    res.json({
      success: true,
      data: {
        institutions: institutionsWithManagers,
        total: institutions.count,
        page: parseInt(page),
        totalPages: Math.ceil(institutions.count / limit),
        statistics: {
          by_status: stats,
          total_active: await Institution.count({ where: { is_active: true } }),
          total_suspended: await Institution.count({ where: { approval_status: 'Suspended' } }),
          most_active: activeWithNames
        }
      }
    });
  } catch (error) {
    console.error('Get all institutions error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching institutions' 
    });
  }
}

  async getInstitutionDetails(req, res) {
    try {
      const { institution_id } = req.params;

      const institution = await Institution.findByPk(institution_id, {
        include: [
          {
            model: Manager,
            attributes: ['manager_id', 'institution_id', 'department', 'is_active'],
            include: [
              {
                model: User,
                attributes: ['user_id', 'full_name', 'email', 'phone', 'status']
              }
            ],
            required: false
          },
          {
            model: Specialist,
            attributes: ['specialist_id', 'specialization', 'approval_status'],
            include: [{
              model: User,
              as: 'user',
              attributes: ['full_name', 'email', 'phone']
            }],
            required: false
          },
          {
            model: SessionType,
            attributes: ['session_type_id', 'name', 'price', 'duration', 'approval_status'],
            required: false
          }
        ]
      });

      if (!institution) {
        return res.status(404).json({
          success: false,
          message: 'Institution not found'
        });
      }

      const stats = await Promise.all([
        Child.count({ where: { current_institution_id: institution_id } }),
        Session.count({ where: { institution_id: institution_id } }),
        Donation.sum('amount', { where: { institution_id: institution_id } }),
        InstitutionReview.findAll({
          where: { institution_id: institution_id },
          attributes: [
            [sequelize.fn('AVG', sequelize.col('overall_rating')), 'average_rating'],
            [sequelize.fn('COUNT', sequelize.col('institution_review_id')), 'total_reviews']
          ],
          raw: true
        }),
        Session.findAll({
          attributes: [
            [sequelize.fn('DATE_FORMAT', sequelize.col('date'), '%Y-%m'), 'month'],
            [sequelize.fn('COUNT', sequelize.col('session_id')), 'sessions_count']
          ],
          where: {
            institution_id: institution_id,
            date: { [Op.gte]: new Date(new Date() - 6 * 30 * 24 * 60 * 60 * 1000) }
          },
          group: ['month'],
          order: [['month', 'DESC']],
          raw: true
        })
      ]);

      const recentReviews = await InstitutionReview.findAll({
        where: { institution_id: institution_id },
        include: [{
          model: User,
          as: 'parent',
          attributes: ['full_name']
        }],
        order: [['created_at', 'DESC']],
        limit: 5
      });

      return res.json({
        success: true,
        data: {
          institution,
          statistics: {
            total_children: stats[0],
            total_sessions: stats[1],
            total_donations: stats[2] || 0,
            average_rating: stats[3][0]?.average_rating || 0,
            total_reviews: stats[3][0]?.total_reviews || 0,
            monthly_sessions: stats[4] || []
          },
          recent_reviews: recentReviews
        }
      });
    } catch (error) {
      console.error('Get institution details error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error fetching institution details'
      });
    }
  }

  async updateInstitution(req, res) {
    const transaction = await sequelize.transaction();

    try {
      const { institution_id } = req.params;
      const updateData = req.body;

      const institution = await Institution.findByPk(institution_id, { transaction });
      if (!institution) {
        await transaction.rollback();
        return res.status(404).json({
          success: false,
          message: 'Institution not found'
        });
      }

      const allowedFields = [
        'name', 'description', 'location_address', 'website',
        'contact_email', 'contact_phone', 'license_number',
        'services_offered', 'conditions_supported', 'capacity',
        'price_range', 'city', 'region', 'location_lat', 'location_lng'
      ];

      const filteredUpdate = {};
      Object.keys(updateData).forEach(key => {
        if (allowedFields.includes(key)) {
          filteredUpdate[key] = updateData[key];
        }
      });

      await institution.update(filteredUpdate, { transaction });

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'institution_update',
        target_type: 'Institution',
        target_id: institution_id,
        details: `Updated fields: ${Object.keys(filteredUpdate).join(', ')}`,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      return res.json({
        success: true,
        message: 'Institution updated successfully',
        data: institution
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Update institution error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error updating institution'
      });
    }
  }

  async createInstitution(req, res) {
    const transaction = await sequelize.transaction();

    try {
      const payload = req.body || {};

      const institutionPayload = payload.institution && typeof payload.institution === 'object'
        ? payload.institution
        : payload;
      const managerPayload = payload.manager && typeof payload.manager === 'object'
        ? payload.manager
        : null;

      const allowedFields = [
        'name', 'description', 'location_address', 'website',
        'contact_email', 'contact_phone', 'license_number',
        'services_offered', 'conditions_supported', 'capacity',
        'price_range', 'city', 'region', 'location_lat', 'location_lng',
        'is_active', 'approval_status'
      ];

      const createData = {};

      Object.keys(institutionPayload).forEach((key) => {
        if (allowedFields.includes(key)) {
          createData[key] = institutionPayload[key];
        }
      });

      createData.approval_status = 'Approved';
      createData.is_active = true;

      if (!createData.name) {
        await transaction.rollback();
        return res.status(400).json({
          success: false,
          message: 'Institution name is required'
        });
      }

      if (createData.approval_status && !['Pending', 'Approved', 'Rejected', 'Suspended'].includes(createData.approval_status)) {
        await transaction.rollback();
        return res.status(400).json({
          success: false,
          message: 'Invalid approval_status'
        });
      }

      const institution = await Institution.create({
        ...createData,
        created_at: new Date(),
        updated_at: new Date()
      }, { transaction });

      let managerUser = null;
      let generatedPassword = null;
      let credentialsEmailSent = false;

      if (managerPayload) {
        const existingUserId = managerPayload.existing_user_id ?? managerPayload.existingUserId ?? null;
        const newManager = managerPayload.new_manager ?? managerPayload.newManager ?? null;

        if (existingUserId && newManager) {
          await transaction.rollback();
          return res.status(400).json({
            success: false,
            message: 'Provide either existing_user_id or new_manager, not both'
          });
        }

        if (!existingUserId && !newManager) {
          await transaction.rollback();
          return res.status(400).json({
            success: false,
            message: 'Manager info is required (existing_user_id or new_manager)'
          });
        }

        if (existingUserId) {
          const user = await User.findByPk(existingUserId, { transaction });
          if (!user) {
            await transaction.rollback();
            return res.status(404).json({
              success: false,
              message: 'Selected manager user not found'
            });
          }

          const existingManagerRecord = await Manager.findByPk(user.user_id, { transaction });
          if (existingManagerRecord && String(existingManagerRecord.institution_id) !== String(institution.institution_id)) {
            await transaction.rollback();
            return res.status(400).json({
              success: false,
              message: 'This user is already a manager of another institution'
            });
          }

          user.role = 'Manager';
          user.institution_id = institution.institution_id;
          user.status = 'Approved';
          user.updated_at = new Date();
          await user.save({ transaction });

          await Manager.findOrCreate({
            where: { manager_id: user.user_id },
            defaults: {
              manager_id: user.user_id,
              institution_id: institution.institution_id,
              is_active: true
            },
            transaction
          });

          await Manager.update(
            { institution_id: institution.institution_id, is_active: true },
            { where: { manager_id: user.user_id }, transaction }
          );

          managerUser = user;
        }

        if (newManager) {
          const fullName = newManager.full_name ?? newManager.fullName;
          const email = newManager.email;
          const phone = newManager.phone ?? null;

          if (!fullName || !email) {
            await transaction.rollback();
            return res.status(400).json({
              success: false,
              message: 'New manager full_name and email are required'
            });
          }

          const existingUser = await User.findOne({ where: { email }, transaction });
          if (existingUser) {
            await transaction.rollback();
            return res.status(400).json({
              success: false,
              message: 'Email already registered'
            });
          }

          generatedPassword = crypto.randomBytes(8).toString('hex');
          const hashedPassword = await bcrypt.hash(generatedPassword, 10);

          const user = await User.create({
            full_name: fullName,
            email,
            password: hashedPassword,
            phone,
            role: 'Manager',
            institution_id: institution.institution_id,
            status: 'Approved',
            city: createData.city ?? null,
            region: createData.region ?? null,
            location_lat: createData.location_lat ?? null,
            location_lng: createData.location_lng ?? null,
            location_address: createData.location_address ?? null,
            created_at: new Date(),
            updated_at: new Date()
          }, { transaction });

          await Manager.create({
            manager_id: user.user_id,
            institution_id: institution.institution_id,
            department: newManager.department ?? null,
            is_active: true
          }, { transaction });

          managerUser = user;

          try {
            const nodemailer = require('nodemailer');

            const transporter = nodemailer.createTransport({
              host: process.env.SMTP_HOST || 'smtp.gmail.com',
              port: parseInt(process.env.SMTP_PORT, 10) || 587,
              secure: false,
              auth: {
                user: process.env.SMTP_USER || process.env.EMAIL_USER,
                pass: process.env.SMTP_PASS || process.env.EMAIL_PASS
              }
            });

            if (process.env.SMTP_USER || process.env.EMAIL_USER) {
              await transporter.sendMail({
                from: process.env.SMTP_FROM || `"Jusoor App" <${process.env.SMTP_USER || process.env.EMAIL_USER}>`,
                to: email,
                subject: 'Your Manager Account - Jusoor App',
                text: `Hello ${fullName},\n\nA manager account has been created for you on Jusoor App for institution: ${institution.name}.\n\nEmail: ${email}\nPassword: ${generatedPassword}\n\nPlease change your password after logging in.\n\nBest regards,\nThe Jusoor Team`
              });
              credentialsEmailSent = true;
            }
          } catch (e) {
            credentialsEmailSent = false;
          }
        }
      }

      if (managerUser) {
        await Notification.create({
          user_id: managerUser.user_id,
          title: 'تمت الموافقة على مؤسستك',
          message: `تمت الموافقة على مؤسسة "${institution.name}" من قبل الإدارة. يمكنك الآن بدء العمل.`,
          type: 'institution_approval',
          related_id: institution.institution_id,
          created_at: new Date()
        }, { transaction });
      }

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'institution_create',
        target_type: 'Institution',
        target_id: institution.institution_id,
        details: `Created institution: ${institution.name}`,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      return res.status(201).json({
        success: true,
        message: 'Institution created successfully',
        data: {
          institution,
          manager: managerUser
            ? {
                user_id: managerUser.user_id,
                full_name: managerUser.full_name,
                email: managerUser.email,
                phone: managerUser.phone,
                status: managerUser.status,
                role: managerUser.role
              }
            : null,
          credentials_email_sent: credentialsEmailSent
        }
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Create institution error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error creating institution'
      });
    }
  }

  async deleteInstitution(req, res) {
    const transaction = await sequelize.transaction();

    try {
      const { institution_id } = req.params;

      const institution = await Institution.findByPk(institution_id, { transaction });
      if (!institution) {
        await transaction.rollback();
        return res.status(404).json({
          success: false,
          message: 'Institution not found'
        });
      }

      institution.is_active = false;
      institution.approval_status = 'Suspended';
      institution.updated_at = new Date();
      await institution.save({ transaction });

      await AuditLog.create({
        admin_id: req.user.user_id,
        action_type: 'institution_delete',
        target_type: 'Institution',
        target_id: institution_id,
        details: `Archived institution: ${institution.name}`,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        created_at: new Date()
      }, { transaction });

      await transaction.commit();

      return res.json({
        success: true,
        message: 'Institution archived successfully'
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Delete institution error:', error);
      return res.status(500).json({
        success: false,
        message: 'Error deleting institution'
      });
    }
  }


// ==================== 📱 APP CONTENT MANAGEMENT ====================

async getAllContent(req, res) {
  try {
    const { 
      content_type, 
      is_active, 
      page = 1, 
      limit = 50,
      search = ''
    } = req.query;
    
    const offset = (page - 1) * limit;

    const whereCondition = {};
    
    if (content_type) whereCondition.content_type = content_type;
    if (is_active !== undefined) whereCondition.is_active = is_active === 'true';
    
    if (search) {
      whereCondition[Op.or] = [
        { title_ar: { [Op.like]: `%${search}%` } },
        { title_en: { [Op.like]: `%${search}%` } },
        { content_ar: { [Op.like]: `%${search}%` } },
        { content_en: { [Op.like]: `%${search}%` } }
      ];
    }

   const contents = await AppContent.findAndCountAll({
  where: whereCondition,
  include: [
    { model: User, as: 'creator', attributes: ['user_id', 'full_name', 'email'], required: false },
    { model: User, as: 'updater', attributes: ['user_id', 'full_name', 'email'], required: false }
  ],
  order: [['content_type', 'ASC'], ['display_order', 'ASC'], ['created_at', 'DESC']],
  limit: parseInt(limit),
  offset: parseInt(offset)
});


    res.json({
      success: true,
      data: {
        contents: contents.rows,
        total: contents.count,
        page: parseInt(page),
        totalPages: Math.ceil(contents.count / limit),
        statistics: {
          by_type: await AppContent.findAll({
            attributes: [
              'content_type',
              [sequelize.fn('COUNT', sequelize.col('content_id')), 'count']
            ],
            group: ['content_type'],
            raw: true
          }),
          total_active: await AppContent.count({ where: { is_active: true } }),
          total_inactive: await AppContent.count({ where: { is_active: false } })
        }
      }
    });
  } catch (error) {
    console.error('Get all content error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching content' 
    });
  }
}

async getContentDetails(req, res) {
  try {
    const { content_id } = req.params;

    const content = await AppContent.findByPk(content_id, {
      include: [
        {
          model: User,
          as: 'creator',
          attributes: ['user_id', 'full_name', 'email']
        },
        {
          model: User,
          as: 'updater',
          attributes: ['user_id', 'full_name', 'email']
        }
      ]
    });

    if (!content) {
      return res.status(404).json({ 
        success: false, 
        message: 'Content not found' 
      });
    }

    const auditLogs = await AuditLog.findAll({
      where: {
        target_type: 'AppContent',
        target_id: content_id
      },
      order: [['created_at', 'DESC']],
      limit: 10
    });

    res.json({
      success: true,
      data: {
        content,
        audit_logs: auditLogs,
        change_history: auditLogs.map(log => ({
          action: log.action_type,
          admin: log.admin_id,
          details: log.details,
          timestamp: log.created_at
        }))
      }
    });
  } catch (error) {
    console.error('Get content details error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching content details' 
    });
  }
}

async createContent(req, res) {
  const transaction = await sequelize.transaction();
  
  try {
    const {
      content_type,
      title_ar,
      title_en,
      content_ar,
      content_en,
      section_key,
      display_order = 0,
      is_active = true,
      icon = null,
      metadata = {}
    } = req.body;

    const normalizedMetadata = (metadata && typeof metadata === 'object') ? metadata : {};

    if (
      content_type === 'help_section' &&
      (!normalizedMetadata.visible_to ||
        (Array.isArray(normalizedMetadata.visible_to) && normalizedMetadata.visible_to.length === 0))
    ) {
      normalizedMetadata.visible_to = ['all'];
    }

    if (!content_type || !title_ar || !title_en || !content_ar || !content_en || !section_key) {
      await transaction.rollback();
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required fields' 
      });
    }

    const existingContent = await AppContent.findOne({
      where: { section_key },
      transaction
    });

    if (existingContent) {
      await transaction.rollback();
      return res.status(400).json({ 
        success: false, 
        message: 'Section key already exists' 
      });
    }

    const content = await AppContent.create({
      content_type,
      title_ar,
      title_en,
      content_ar,
      content_en,
      section_key,
      display_order,
      is_active,
      icon,
      metadata: normalizedMetadata,
      created_by: req.user.user_id,
      updated_by: req.user.user_id
    }, { transaction });

    await AuditLog.create({
      admin_id: req.user.user_id,
      action_type: 'content_create',
      target_type: 'AppContent',
      target_id: content.content_id,
      details: JSON.stringify({
        content_type,
        title_ar,
        title_en,
        section_key
      }),
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      created_at: new Date()
    }, { transaction });

    await transaction.commit();

    res.status(201).json({
      success: true,
      message: 'Content created successfully',
      data: content
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Create content error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error creating content' 
    });
  }
}

async updateContent(req, res) {
  const transaction = await sequelize.transaction();
  
  try {
    const { content_id } = req.params;
    const updateData = req.body;

    const content = await AppContent.findByPk(content_id, { transaction });
    if (!content) {
      await transaction.rollback();
      return res.status(404).json({ 
        success: false, 
        message: 'Content not found' 
      });
    }

    const oldData = content.toJSON();
    
    const allowedFields = [
      'title_ar', 'title_en', 'content_ar', 'content_en',
      'display_order', 'is_active', 'icon', 'metadata'
    ];

    const filteredUpdate = {};
    Object.keys(updateData).forEach(key => {
      if (allowedFields.includes(key)) {
        filteredUpdate[key] = updateData[key];
      }
    });

    filteredUpdate.updated_by = req.user.user_id;

    await content.update(filteredUpdate, { transaction });

    const changes = {};
    Object.keys(filteredUpdate).forEach(key => {
      if (oldData[key] !== filteredUpdate[key]) {
        changes[key] = {
          old: oldData[key],
          new: filteredUpdate[key]
        };
      }
    });

    await AuditLog.create({
      admin_id: req.user.user_id,
      action_type: 'content_update',
      target_type: 'AppContent',
      target_id: content_id,
      details: JSON.stringify(changes),
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      created_at: new Date()
    }, { transaction });

    await transaction.commit();

    res.json({
      success: true,
      message: 'Content updated successfully',
      data: content
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Update content error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error updating content' 
    });
  }
}

async deleteContent(req, res) {
  const transaction = await sequelize.transaction();
  
  try {
    const { content_id } = req.params;

    const content = await AppContent.findByPk(content_id, { transaction });
    if (!content) {
      await transaction.rollback();
      return res.status(404).json({ 
        success: false, 
        message: 'Content not found' 
      });
    }

    const backupData = content.toJSON();

    await content.destroy({ transaction });

    await AuditLog.create({
      admin_id: req.user.user_id,
      action_type: 'content_delete',
      target_type: 'AppContent',
      target_id: content_id,
      details: JSON.stringify({
        deleted_content: backupData,
        deleted_by: req.user.user_id
      }),
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      created_at: new Date()
    }, { transaction });

    await transaction.commit();

    res.json({
      success: true,
      message: 'Content deleted successfully'
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Delete content error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error deleting content' 
    });
  }
}

async reorderContent(req, res) {
  const transaction = await sequelize.transaction();
  
  try {
    const { content_type, order_updates } = req.body;

    if (!content_type || !Array.isArray(order_updates)) {
      await transaction.rollback();
      return res.status(400).json({ 
        success: false, 
        message: 'Content type and order updates array are required' 
      });
    }

    for (const update of order_updates) {
      const { content_id, display_order } = update;
      
      if (content_id && display_order !== undefined) {
        await AppContent.update(
          { display_order, updated_by: req.user.user_id },
          { 
            where: { 
              content_id,
              content_type 
            },
            transaction 
          }
        );
      }
    }

    await AuditLog.create({
      admin_id: req.user.user_id,
      action_type: 'content_reorder',
      target_type: 'AppContent',
      target_id: null,
      details: JSON.stringify({
        content_type,
        order_updates
      }),
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      created_at: new Date()
    }, { transaction });

    await transaction.commit();

    const updatedContents = await AppContent.findAll({
      where: { content_type },
      order: [['display_order', 'ASC']]
    });

    res.json({
      success: true,
      message: 'Content order updated successfully',
      data: updatedContents
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Reorder content error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error reordering content' 
    });
  }
}


async getHelpSections(req, res) {
  try {
    const language = req.query.lang || 'ar';
    const userRole = req.user?.role || 'Parent'; 

    const whereCondition = {
      content_type: 'help_section',
      is_active: true
    };

    if (userRole === 'Parent') {
      whereCondition[Op.and] = Sequelize.literal(
        `metadata IS NULL
         OR JSON_EXTRACT(metadata, '$.visible_to') IS NULL
         OR JSON_CONTAINS(metadata->'$.visible_to', '"parent"')
         OR JSON_CONTAINS(metadata->'$.visible_to', '"all"')`
      );
    }

    const sections = await AppContent.findAll({
      where: whereCondition,
      attributes: [
        'content_id',
        language === 'ar' ? 'title_ar' : 'title_en',
        language === 'ar' ? 'content_ar' : 'content_en',
        'icon',
        'display_order',
        'section_key'
      ],
      order: [['display_order', 'ASC']]
    });

    res.json({
      success: true,
      data: {
        sections,
        language
      }
    });
  } catch (error) {
    console.error('Get help sections error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching help sections' 
    });
  }
}

async getAboutContent(req, res) {
  try {
    const language = req.query.lang || 'ar';

    const contents = await AppContent.findAll({
      where: {
        content_type: 'about_section',
        is_active: true
      },
      attributes: [
        'content_id',
        language === 'ar' ? 'title_ar' : 'title_en',
        language === 'ar' ? 'content_ar' : 'content_en',
        'icon',
        'display_order'
      ],
      order: [['display_order', 'ASC']]
    });

    const privacyPolicy = await AppContent.findOne({
      where: {
        content_type: 'privacy_policy',
        is_active: true
      },
      attributes: [
        'content_id',
        language === 'ar' ? 'title_ar' : 'title_en',
        language === 'ar' ? 'content_ar' : 'content_en'
      ]
    });

    const termsOfService = await AppContent.findOne({
      where: {
        content_type: 'terms_of_service',
        is_active: true
      },
      attributes: [
        'content_id',
        language === 'ar' ? 'title_ar' : 'title_en',
        language === 'ar' ? 'content_ar' : 'content_en'
      ]
    });

    res.json({
      success: true,
      data: {
        about_sections: contents,
        privacy_policy: privacyPolicy,
        terms_of_service: termsOfService,
        app_info: {
          version: '1.2.3',
          build: '456',
          copyright: `© ${new Date().getFullYear()} Jusoor App`
        }
      }
    });
  } catch (error) {
    console.error('Get about content error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching about content' 
    });
  }
}


// ==================== 📱 APP CONTENT MANAGEMENT ====================

async batchUpdateContentStatus(req, res) {
  const transaction = await sequelize.transaction();
  
  try {
    const { content_ids, is_active, reason } = req.body;

    if (!Array.isArray(content_ids) || content_ids.length === 0) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Content IDs array is required'
      });
    }

    await AppContent.update(
      {
        is_active,
        updated_by: req.user.user_id,
        updated_at: new Date()
      },
      {
        where: {
          content_id: { [Op.in]: content_ids }
        },
        transaction
      }
    );

    await AuditLog.create({
      admin_id: req.user.user_id,
      action_type: 'content_batch_update',
      target_type: 'AppContent',
      target_id: null,
      details: JSON.stringify({
        content_ids,
        is_active,
        reason,
        updated_count: content_ids.length
      }),
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      created_at: new Date()
    }, { transaction });

    await transaction.commit();

    res.json({
      success: true,
      message: `Updated ${content_ids.length} content items successfully`
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Batch update content error:', error);
    res.status(500).json({
      success: false,
      message: 'Error batch updating content'
    });
  }
}

async getContentStatistics(req, res) {
  try {
    const statistics = await AppContent.findAll({
      attributes: [
        'content_type',
        'is_active',
        [sequelize.fn('COUNT', sequelize.col('content_id')), 'count']
      ],
      group: ['content_type', 'is_active'],
      raw: true
    });

    const totalByType = await AppContent.findAll({
      attributes: [
        'content_type',
        [sequelize.fn('COUNT', sequelize.col('content_id')), 'total']
      ],
      group: ['content_type'],
      raw: true
    });

    const recentActivity = await AppContent.findAll({
      attributes: [
        [sequelize.fn('DATE', sequelize.col('created_at')), 'date'],
        [sequelize.fn('COUNT', sequelize.col('content_id')), 'created'],
        [sequelize.fn('COUNT', sequelize.col('updated_at')), 'updated']
      ],
      where: {
        created_at: {
          [Op.gte]: new Date(new Date() - 30 * 24 * 60 * 60 * 1000)
        }
      },
      group: ['date'],
      order: [['date', 'DESC']],
      raw: true
    });

    res.json({
      success: true,
      data: {
        by_type_and_status: statistics,
        total_by_type: totalByType,
        recent_activity: recentActivity,
        summary: {
          total_content: await AppContent.count(),
          active_content: await AppContent.count({ where: { is_active: true } }),
          inactive_content: await AppContent.count({ where: { is_active: false } })
        }
      }
    });
  } catch (error) {
    console.error('Get content statistics error:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching content statistics'
    });
  }
}

async importContent(req, res) {
  const transaction = await sequelize.transaction();
  
  try {
    const { contents } = req.body;

    if (!Array.isArray(contents) || contents.length === 0) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Contents array is required'
      });
    }

    const results = {
      created: 0,
      updated: 0,
      skipped: 0,
      errors: []
    };

    for (const contentData of contents) {
      try {
        const existing = await AppContent.findOne({
          where: { section_key: contentData.section_key },
          transaction
        });

        if (existing) {
          await existing.update({
            ...contentData,
            updated_by: req.user.user_id,
            updated_at: new Date()
          }, { transaction });
          results.updated++;
        } else {
          await AppContent.create({
            ...contentData,
            created_by: req.user.user_id,
            updated_by: req.user.user_id
          }, { transaction });
          results.created++;
        }
      } catch (error) {
        results.skipped++;
        results.errors.push({
          section_key: contentData.section_key,
          error: error.message
        });
      }
    }

    await AuditLog.create({
      admin_id: req.user.user_id,
      action_type: 'content_import',
      target_type: 'AppContent',
      target_id: null,
      details: JSON.stringify(results),
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      created_at: new Date()
    }, { transaction });

    await transaction.commit();

    res.json({
      success: true,
      message: `Import completed: ${results.created} created, ${results.updated} updated, ${results.skipped} skipped`,
      data: results
    });
  } catch (error) {
    await transaction.rollback();
    console.error('Import content error:', error);
    res.status(500).json({
      success: false,
      message: 'Error importing content'
    });
  }
}

async exportContent(req, res) {
  try {
    const { content_type, is_active } = req.query;

    const whereCondition = {};
    if (content_type) whereCondition.content_type = content_type;
    if (is_active !== undefined) whereCondition.is_active = is_active === 'true';

    const contents = await AppContent.findAll({
      where: whereCondition,
      attributes: { exclude: ['created_by', 'updated_by'] },
      order: [['content_type', 'ASC'], ['display_order', 'ASC']]
    });

    const exportData = {
      exported_at: new Date().toISOString(),
      exported_by: req.user.user_id,
      total_items: contents.length,
      contents: contents.map(content => content.toJSON())
    };

    res.json({
      success: true,
      data: exportData
    });
  } catch (error) {
    console.error('Export content error:', error);
    res.status(500).json({
      success: false,
      message: 'Error exporting content'
    });
  }
}
}

module.exports = new AdminController();