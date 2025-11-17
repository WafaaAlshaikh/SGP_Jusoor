const { Sequelize, Op } = require('sequelize');
const sequelize = require('../config/db');
const User = require('../model/User');
const Institution = require('../model/Institution');
const Child = require('../model/Child');
const Session = require('../model/Session');

exports.getDashboardStats = async (req, res) => {
  try {
    console.log('📈 جلب إحصائيات الـ Dashboard للـ Admin');

    const usersStats = await User.findAll({
      attributes: [
        'role',
        [Sequelize.fn('COUNT', Sequelize.col('user_id')), 'count']
      ],
      group: ['role'],
      raw: true
    });

    const institutionsStats = await Institution.findAll({
      attributes: [
        [Sequelize.fn('COUNT', Sequelize.col('institution_id')), 'total'],
        [Sequelize.fn('SUM', Sequelize.literal('CASE WHEN approval_status = "Approved" THEN 1 ELSE 0 END')), 'approved'],
        [Sequelize.fn('SUM', Sequelize.literal('CASE WHEN approval_status = "Pending" THEN 1 ELSE 0 END')), 'pending']
      ],
      raw: true
    });

    const childrenStats = await Child.findAll({
      attributes: [
        [Sequelize.fn('COUNT', Sequelize.col('child_id')), 'total'],
        [Sequelize.fn('SUM', Sequelize.literal('CASE WHEN registration_status = "Approved" THEN 1 ELSE 0 END')), 'registered'],
        [Sequelize.fn('SUM', Sequelize.literal('CASE WHEN registration_status = "Pending" THEN 1 ELSE 0 END')), 'pending']
      ],
      where: { deleted_at: null },
      raw: true
    });

    const currentMonth = new Date().getMonth() + 1;
    const currentYear = new Date().getFullYear();
    
    const sessionsStats = await Session.findAll({
      attributes: [
        [Sequelize.fn('COUNT', Sequelize.col('session_id')), 'total_sessions'],
        [Sequelize.fn('SUM', Sequelize.literal('CASE WHEN status = "Completed" THEN 1 ELSE 0 END')), 'completed_sessions'],
        [Sequelize.fn('SUM', Sequelize.literal('CASE WHEN status = "Pending" THEN 1 ELSE 0 END')), 'pending_sessions']
      ],
      where: {
        [Op.and]: [
          Sequelize.where(Sequelize.fn('MONTH', Sequelize.col('date')), currentMonth),
          Sequelize.where(Sequelize.fn('YEAR', Sequelize.col('date')), currentYear)
        ]
      },
      raw: true
    });

    const stats = {
      users: {
        total: usersStats.reduce((sum, item) => sum + parseInt(item.count), 0),
        byRole: usersStats.reduce((acc, item) => {
          acc[item.role] = parseInt(item.count);
          return acc;
        }, {})
      },
      institutions: {
        total: parseInt(institutionsStats[0]?.total || 0),
        approved: parseInt(institutionsStats[0]?.approved || 0),
        pending: parseInt(institutionsStats[0]?.pending || 0)
      },
      children: {
        total: parseInt(childrenStats[0]?.total || 0),
        registered: parseInt(childrenStats[0]?.registered || 0),
        pending: parseInt(childrenStats[0]?.pending || 0)
      },
      sessions: {
        total: parseInt(sessionsStats[0]?.total_sessions || 0),
        completed: parseInt(sessionsStats[0]?.completed_sessions || 0),
        pending: parseInt(sessionsStats[0]?.pending_sessions || 0)
      }
    };

    res.status(200).json({
      success: true,
      message: 'تم جلب إحصائيات الـ Dashboard بنجاح',
      data: stats,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ خطأ في جلب إحصائيات الـ Dashboard:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في جلب الإحصائيات',
      error: error.message
    });
  }
};

exports.getInstitutions = async (req, res) => {
  try {
    const { page = 1, limit = 10, status, search } = req.query;
    const offset = (page - 1) * limit;

    let whereClause = {};

    if (status && status !== 'all') {
      whereClause.approval_status = status;
    }

    if (search) {
      whereClause.name = { [Op.like]: `%${search}%` };
    }

    const institutions = await Institution.findAndCountAll({
      where: whereClause,
      attributes: [
        'institution_id',
        'name',
        'description',
        'city',
        'region',
        'approval_status',
        'rating',
        'created_at'
      ],
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['created_at', 'DESC']]
    });

    res.status(200).json({
      success: true,
      data: institutions.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: institutions.count,
        totalPages: Math.ceil(institutions.count / limit)
      }
    });

  } catch (error) {
    console.error('❌ خطأ في جلب المؤسسات:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في جلب المؤسسات',
      error: error.message
    });
  }
};

exports.getPendingInstitutions = async (req, res) => {
  try {
    const institutions = await Institution.findAll({
      where: { approval_status: 'Pending' },
      attributes: [
        'institution_id',
        'name',
        'description',
        'city',
        'region',
        'created_at'
      ],
      order: [['created_at', 'ASC']]
    });

    res.status(200).json({
      success: true,
      data: institutions,
      count: institutions.length
    });

  } catch (error) {
    console.error('❌ خطأ في جلب المؤسسات المعلقة:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في جلب المؤسسات المعلقة',
      error: error.message
    });
  }
};

exports.approveInstitution = async (req, res) => {
  try {
    const { id } = req.params;

    const institution = await Institution.findByPk(id);
    
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة'
      });
    }

    await institution.update({
      approval_status: 'Approved',
      updated_at: new Date()
    });

    res.status(200).json({
      success: true,
      message: 'تم الموافقة على المؤسسة بنجاح',
      data: {
        institution_id: institution.institution_id,
        name: institution.name,
        status: institution.approval_status
      }
    });

  } catch (error) {
    console.error('❌ خطأ في الموافقة على المؤسسة:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في الموافقة على المؤسسة',
      error: error.message
    });
  }
};

exports.rejectInstitution = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    const institution = await Institution.findByPk(id);
    
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة'
      });
    }

    await institution.update({
      approval_status: 'Rejected',
      rejection_reason: reason,
      updated_at: new Date()
    });

    res.status(200).json({
      success: true,
      message: 'تم رفض المؤسسة بنجاح',
      data: {
        institution_id: institution.institution_id,
        name: institution.name,
        status: institution.approval_status
      }
    });

  } catch (error) {
    console.error('❌ خطأ في رفض المؤسسة:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في رفض المؤسسة',
      error: error.message
    });
  }
};

exports.suspendInstitution = async (req, res) => {
  try {
    const { id } = req.params;

    const institution = await Institution.findByPk(id);
    
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة'
      });
    }

    await institution.update({
      approval_status: 'Suspended',
      updated_at: new Date()
    });

    res.status(200).json({
      success: true,
      message: 'تم تعليق المؤسسة بنجاح',
      data: {
        institution_id: institution.institution_id,
        name: institution.name,
        status: institution.approval_status
      }
    });

  } catch (error) {
    console.error('❌ خطأ في تعليق المؤسسة:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في تعليق المؤسسة',
      error: error.message
    });
  }
};

exports.activateInstitution = async (req, res) => {
  try {
    const { id } = req.params;

    const institution = await Institution.findByPk(id);
    
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة'
      });
    }

    await institution.update({
      approval_status: 'Approved',
      updated_at: new Date()
    });

    res.status(200).json({
      success: true,
      message: 'تم تفعيل المؤسسة بنجاح',
      data: {
        institution_id: institution.institution_id,
        name: institution.name,
        status: institution.approval_status
      }
    });

  } catch (error) {
    console.error('❌ خطأ في تفعيل المؤسسة:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في تفعيل المؤسسة',
      error: error.message
    });
  }
};

exports.getUsers = async (req, res) => {
  try {
    const { page = 1, limit = 10, role, status, search } = req.query;
    const offset = (page - 1) * limit;

    let whereClause = {};

    if (role && role !== 'all') {
      whereClause.role = role;
    }

    if (status && status !== 'all') {
      whereClause.status = status;
    }

    if (search) {
      whereClause[Op.or] = [
        { full_name: { [Op.like]: `%${search}%` } },
        { email: { [Op.like]: `%${search}%` } }
      ];
    }

    const users = await User.findAndCountAll({
      where: whereClause,
      attributes: [
        'user_id',
        'full_name',
        'email',
        'phone',
        'role',
        'status',
        'created_at'
      ],
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['created_at', 'DESC']]
    });

    res.status(200).json({
      success: true,
      data: users.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: users.count,
        totalPages: Math.ceil(users.count / limit)
      }
    });

  } catch (error) {
    console.error('❌ خطأ في جلب المستخدمين:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في جلب المستخدمين',
      error: error.message
    });
  }
};

exports.getPendingUsers = async (req, res) => {
  try {
    const users = await User.findAll({
      where: { status: 'Pending' },
      attributes: [
        'user_id',
        'full_name',
        'email',
        'phone',
        'role',
        'created_at'
      ],
      order: [['created_at', 'ASC']]
    });

    res.status(200).json({
      success: true,
      data: users,
      count: users.length
    });

  } catch (error) {
    console.error('❌ خطأ في جلب المستخدمين المعلقة:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في جلب المستخدمين المعلقة',
      error: error.message
    });
  }
};

exports.approveUser = async (req, res) => {
  try {
    const { id } = req.params;

    const user = await User.findByPk(id);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    await user.update({
      status: 'Approved',
      updated_at: new Date()
    });

    res.status(200).json({
      success: true,
      message: 'تم الموافقة على المستخدم بنجاح',
      data: {
        user_id: user.user_id,
        name: user.full_name,
        status: user.status
      }
    });

  } catch (error) {
    console.error('❌ خطأ في الموافقة على المستخدم:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في الموافقة على المستخدم',
      error: error.message
    });
  }
};

exports.suspendUser = async (req, res) => {
  try {
    const { id } = req.params;

    const user = await User.findByPk(id);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    await user.update({
      status: 'Suspended',
      updated_at: new Date()
    });

    res.status(200).json({
      success: true,
      message: 'تم تعليق المستخدم بنجاح',
      data: {
        user_id: user.user_id,
        name: user.full_name,
        status: user.status
      }
    });

  } catch (error) {
    console.error('❌ خطأ في تعليق المستخدم:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في تعليق المستخدم',
      error: error.message
    });
  }
};

exports.getGeneralStatistics = async (req, res) => {
  try {
    res.status(200).json({
      success: true,
      message: 'الإحصائيات العامة',
      data: {
        // إحصائيات إضافية يمكن إضافتها لاحقاً
      }
    });

  } catch (error) {
    console.error('❌ خطأ في جلب الإحصائيات العامة:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في جلب الإحصائيات العامة',
      error: error.message
    });
  }
};

exports.getSystemHealth = async (req, res) => {
  try {
    const dbStatus = await sequelize.authenticate()
      .then(() => 'connected')
      .catch(() => 'disconnected');

    const systemInfo = {
      database: dbStatus,
      server_time: new Date().toISOString(),
      node_version: process.version,
      platform: process.platform,
      memory_usage: process.memoryUsage(),
      uptime: process.uptime()
    };

    res.status(200).json({
      success: true,
      message: 'صحة النظام',
      data: systemInfo
    });

  } catch (error) {
    console.error('❌ خطأ في فحص صحة النظام:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في فحص صحة النظام',
      error: error.message
    });
  }
};

exports.generateReports = async (req, res) => {
  try {
    const { type, startDate, endDate } = req.query;

    res.status(200).json({
      success: true,
      message: 'تم توليد التقرير',
      data: {
        type: type || 'general',
        period: {
          start: startDate,
          end: endDate
        },
        // إضافة بيانات التقرير لاحقاً
      }
    });

  } catch (error) {
    console.error('❌ خطأ في توليد التقرير:', error);
    res.status(500).json({
      success: false,
      message: 'فشل في توليد التقرير',
      error: error.message
    });
  }
};

module.exports = exports;