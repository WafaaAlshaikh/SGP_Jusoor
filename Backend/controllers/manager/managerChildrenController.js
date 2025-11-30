const Child = require('../../model/Child');
const Parent = require('../../model/Parent');
const User = require('../../model/User');
const Diagnosis = require('../../model/Diagnosis');
const Institution = require('../../model/Institution');
const ChildRegistrationRequest = require('../../model/ChildRegistrationRequest');
const Session = require('../../model/Session');
const Evaluation = require('../../model/Evaluation');
const Specialist = require('../../model/Specialist');
const SessionType = require('../../model/SessionType');
const { Op } = require('sequelize');
const sequelize = require('../../config/db');
const TeamService = require('../../services/teamService');

// ================= GET ALL CHILDREN IN MANAGER'S INSTITUTION =================
exports.getInstitutionChildren = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const Manager = require('../../model/Manager');
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
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة أو المدير غير نشط'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const {
      search = '',
      registration_status,
      gender,
      diagnosis,
      sort = 'name',
      order = 'asc',
      page = '1',
      limit = '20'
    } = req.query;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const pageLimit = Math.max(1, parseInt(limit, 10) || 20);
    const offset = (pageNum - 1) * pageLimit;

    let whereClause = {
      current_institution_id: institutionId,
      deleted_at: null
    };

    if (search && search.trim() !== '') {
      whereClause[Op.or] = [
        { full_name: { [Op.like]: `%${search.trim()}%` } },
        { child_identifier: { [Op.like]: `%${search.trim()}%` } }
      ];
    }

    if (gender && (gender === 'Male' || gender === 'Female')) {
      whereClause.gender = gender;
    }

    if (registration_status && registration_status !== 'All') {
      whereClause.registration_status = registration_status;
    }

    // include clauses
    let include = [
      {
        model: Parent,
        include: [{
          model: User,
          attributes: ['user_id', 'full_name', 'email', 'phone']
        }]
      },
      {
        model: Diagnosis,
        attributes: ['diagnosis_id', 'name'],
        as: 'Diagnosis'
      },
      {
        model: Institution,
        as: 'currentInstitution',
        attributes: ['institution_id', 'name'],
        required: false
      }
    ];

    if (diagnosis && diagnosis !== 'All') {
      if (isNaN(parseInt(diagnosis, 10))) {
        include = [
          ...include.filter(item => item.model !== Diagnosis),
          {
            model: Diagnosis,
            attributes: ['diagnosis_id', 'name'],
            as: 'Diagnosis',
            required: true,
            where: { name: diagnosis }
          }
        ];
      } else {
        whereClause.diagnosis_id = parseInt(diagnosis, 10);
      }
    }

    let orderArray = [];
    switch (sort) {
      case 'age':
        orderArray.push(['date_of_birth', order === 'asc' ? 'ASC' : 'DESC']);
        break;
      case 'registration_date':
        orderArray.push(['created_at', order === 'asc' ? 'ASC' : 'DESC']);
        break;
      case 'last_session':
        orderArray.push(['created_at', 'DESC']);
        break;
      default:
        orderArray.push(['full_name', order === 'asc' ? 'ASC' : 'DESC']);
    }

    const { count, rows: children } = await Child.findAndCountAll({
      where: whereClause,
      include,
      offset,
      limit: pageLimit,
      order: orderArray,
      distinct: true
    });

    const processedChildren = await Promise.all(
      children.map(async (child) => {
        const childData = child.get({ plain: true });

        const age = calculateAge(childData.date_of_birth);

        const lastSession = await Session.findOne({
          where: { child_id: childData.child_id },
          order: [['date', 'DESC']],
          limit: 1,
          attributes: ['session_id', 'date', 'status']
        });

        const sessionCount = await Session.count({
          where: { child_id: childData.child_id }
        });

        const specialistsCountResult = await Session.findAll({
          where: { child_id: childData.child_id },
          attributes: [[sequelize.fn('DISTINCT', sequelize.col('specialist_id')), 'specialist_id']],
          raw: true
        });
        const specialistsCount = specialistsCountResult.length;

        const avgEvaluation = await Evaluation.findOne({
          where: { child_id: childData.child_id },
          attributes: [[sequelize.fn('AVG', sequelize.col('progress_score')), 'avg_progress']],
          raw: true
        });

        return {
          id: childData.child_id,
          full_name: childData.full_name,
          date_of_birth: childData.date_of_birth,
          gender: childData.gender,
          age: age,
          photo: childData.photo || '',
          child_identifier: childData.child_identifier,
          
          diagnosis: childData.Diagnosis ? {
            id: childData.Diagnosis.diagnosis_id,
            name: childData.Diagnosis.name
          } : null,
          
          parent: childData.Parent ? {
            id: childData.Parent.parent_id,
            name: childData.Parent.User.full_name,
            email: childData.Parent.User.email,
            phone: childData.Parent.User.phone
          } : null,
          
          institution: childData.currentInstitution ? {
            id: childData.currentInstitution.institution_id,
            name: childData.currentInstitution.name
          } : null,
          
          registration_status: childData.registration_status || 'Not Registered',
          
          statistics: {
            total_sessions: sessionCount,
            total_specialists: specialistsCount,
            average_progress: avgEvaluation?.avg_progress ? parseFloat(avgEvaluation.avg_progress).toFixed(1) : 0,
            last_session: lastSession ? {
              date: lastSession.date,
              status: lastSession.status
            } : null,
            performance_category: categorizeChildPerformance(sessionCount, avgEvaluation?.avg_progress)
          },
          
          city: childData.city,
          address: childData.address,
          school_info: childData.school_info,
          created_at: childData.created_at
        };
      })
    );

    res.status(200).json({
      success: true,
      data: processedChildren,
      meta: {
        page: pageNum,
        limit: pageLimit,
        total: count,
        total_pages: Math.ceil(count / pageLimit),
        institution: {
          id: institutionId,
          name: manager.Institution.name
        }
      }
    });

  } catch (error) {
    console.error('Error in getInstitutionChildren:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب بيانات الأطفال',
      error: error.message
    });
  }
};

// ================= GET PENDING REGISTRATION REQUESTS =================
exports.getPendingRegistrationRequests = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const Manager = require('../../model/Manager');
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
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة أو المدير غير نشط'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const {
      search = '',
      page = '1',
      limit = '20'
    } = req.query;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const pageLimit = Math.max(1, parseInt(limit, 10) || 20);
    const offset = (pageNum - 1) * pageLimit;

    let whereClause = {
      institution_id: institutionId,
      status: 'Pending'
    };

    if (search && search.trim() !== '') {
      whereClause[Op.or] = [
        { '$Child.full_name$': { [Op.like]: `%${search.trim()}%` } },
        { '$Parent.User.full_name$': { [Op.like]: `%${search.trim()}%` } }
      ];
    }

    const { count, rows: requests } = await ChildRegistrationRequest.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: Child,
          attributes: ['child_id', 'full_name', 'date_of_birth', 'gender', 'photo'],
          include: [
            {
              model: Diagnosis,
              attributes: ['diagnosis_id', 'name'],
              as: 'Diagnosis'
            },
            {
              model: Parent,
              include: [{
                model: User,
                attributes: ['user_id', 'full_name', 'email', 'phone']
              }]
            }
          ]
        },
        {
          model: Institution,
          attributes: ['institution_id', 'name']
        },
        {
          model: User,
          as: 'assignedManager',
          attributes: ['user_id', 'full_name'],
          required: false
        }
      ],
      offset,
      limit: pageLimit,
      order: [['requested_at', 'DESC']],
      distinct: true
    });

    const processedRequests = requests.map(request => {
      const requestData = request.get({ plain: true });
      
      const childAge = calculateAge(requestData.Child.date_of_birth);

      return {
        request_id: requestData.request_id,
        child: {
          id: requestData.Child.child_id,
          full_name: requestData.Child.full_name,
          date_of_birth: requestData.Child.date_of_birth,
          age: childAge,
          gender: requestData.Child.gender,
          photo: requestData.Child.photo || '',
          diagnosis: requestData.Child.Diagnosis ? {
            id: requestData.Child.Diagnosis.diagnosis_id,
            name: requestData.Child.Diagnosis.name
          } : null
        },
        parent: requestData.Child.Parent ? {
          id: requestData.Child.Parent.parent_id,
          name: requestData.Child.Parent.User.full_name,
          email: requestData.Child.Parent.User.email,
          phone: requestData.Child.Parent.User.phone
        } : null,
        institution: {
          id: requestData.Institution.institution_id,
          name: requestData.Institution.name
        },
        status: requestData.status,
        requested_at: requestData.requested_at,
        notes: requestData.notes,
        assigned_manager: requestData.assignedManager ? {
          id: requestData.assignedManager.user_id,
          name: requestData.assignedManager.full_name
        } : null
      };
    });

    res.status(200).json({
      success: true,
      data: processedRequests,
      meta: {
        page: pageNum,
        limit: pageLimit,
        total: count,
        total_pages: Math.ceil(count / pageLimit),
        institution: {
          id: institutionId,
          name: manager.Institution.name
        }
      }
    });

  } catch (error) {
    console.error('Error in getPendingRegistrationRequests:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب طلبات التسجيل المعلقة',
      error: error.message
    });
  }
};

// ================= APPROVE REGISTRATION REQUEST =================
exports.approveRegistrationRequest = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { request_id } = req.params;
    const { notes } = req.body;

    const Manager = require('../../model/Manager');
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
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة أو المدير غير نشط'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const registrationRequest = await ChildRegistrationRequest.findOne({
      where: {
        request_id,
        institution_id: institutionId,
        status: 'Pending'
      },
      include: [
        {
          model: Child,
          include: [{
            model: Parent,
            include: [{
              model: User,
              attributes: ['user_id', 'full_name', 'email']
            }]
          }]
        }
      ]
    });

    if (!registrationRequest) {
      return res.status(404).json({
        success: false,
        message: 'طلب التسجيل غير موجود أو تمت معالجته مسبقاً'
      });
    }

    await registrationRequest.update({
      status: 'Approved',
      reviewed_by_manager_id: managerId,
      reviewed_at: new Date(),
      manager_notes: notes || null
    });

    await Child.update({
      registration_status: 'Approved',
      current_institution_id: institutionId
    }, {
      where: { child_id: registrationRequest.child_id }
    });

    await TeamService.createInitialTeamForChild(registrationRequest.child_id, institutionId);


    const Notification = require('../../model/Notification');
    await Notification.create({
      user_id: registrationRequest.Child.Parent.parent_id,
      title: 'تمت الموافقة على طلب التسجيل',
      message: `تمت الموافقة على طلب تسجيل طفلك ${registrationRequest.Child.full_name} في مؤسسة ${manager.Institution.name}. ${notes ? `ملاحظات المدير: ${notes}` : ''}`,
      type: 'registration_approved',
      related_id: registrationRequest.request_id,
      is_read: false
    });

    res.status(200).json({
      success: true,
      message: 'تمت الموافقة على طلب التسجيل بنجاح',
      data: {
        request_id: registrationRequest.request_id,
        child_name: registrationRequest.Child.full_name,
        institution_name: manager.Institution.name,
        status: 'Approved',
        approved_at: new Date()
      }
    });

  } catch (error) {
    console.error('Error in approveRegistrationRequest:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في الموافقة على طلب التسجيل',
      error: error.message
    });
  }
};

// ================= REJECT REGISTRATION REQUEST =================
exports.rejectRegistrationRequest = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { request_id } = req.params;
    const { reason } = req.body;

    if (!reason) {
      return res.status(400).json({
        success: false,
        message: 'يرجى تقديم سبب الرفض'
      });
    }

    const Manager = require('../../model/Manager');
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
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة أو المدير غير نشط'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const registrationRequest = await ChildRegistrationRequest.findOne({
      where: {
        request_id,
        institution_id: institutionId,
        status: 'Pending'
      },
      include: [
        {
          model: Child,
          include: [{
            model: Parent,
            include: [{
              model: User,
              attributes: ['user_id', 'full_name', 'email']
            }]
          }]
        }
      ]
    });

    if (!registrationRequest) {
      return res.status(404).json({
        success: false,
        message: 'طلب التسجيل غير موجود أو تمت معالجته مسبقاً'
      });
    }

    await registrationRequest.update({
      status: 'Rejected',
      reviewed_by_manager_id: managerId,
      reviewed_at: new Date(),
      manager_notes: reason
    });

    await Child.update({
      registration_status: 'Rejected'
    }, {
      where: { child_id: registrationRequest.child_id }
    });

    const Notification = require('../../model/Notification');
    await Notification.create({
      user_id: registrationRequest.Child.Parent.parent_id,
      title: 'تم رفض طلب التسجيل',
      message: `تم رفض طلب تسجيل طفلك ${registrationRequest.Child.full_name} في مؤسسة ${manager.Institution.name}. السبب: ${reason}`,
      type: 'registration_rejected',
      related_id: registrationRequest.request_id,
      is_read: false
    });

    res.status(200).json({
      success: true,
      message: 'تم رفض طلب التسجيل بنجاح',
      data: {
        request_id: registrationRequest.request_id,
        child_name: registrationRequest.Child.full_name,
        institution_name: manager.Institution.name,
        status: 'Rejected',
        rejected_at: new Date(),
        reason: reason
      }
    });

  } catch (error) {
    console.error('Error in rejectRegistrationRequest:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في رفض طلب التسجيل',
      error: error.message
    });
  }
};

// ================= GET CHILD DETAILS =================
exports.getChildDetails = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { child_id } = req.params;

    const Manager = require('../../model/Manager');
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
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة أو المدير غير نشط'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const child = await Child.findOne({
      where: {
        child_id,
        current_institution_id: institutionId,
        deleted_at: null
      },
      include: [
        {
          model: Parent,
          include: [{
            model: User,
            attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture']
          }]
        },
        {
          model: Diagnosis,
          attributes: ['diagnosis_id', 'name', 'description'],
          as: 'Diagnosis'
        },
        {
          model: Institution,
          as: 'currentInstitution',
          attributes: ['institution_id', 'name', 'city']
        }
      ]
    });

    if (!child) {
      return res.status(404).json({
        success: false,
        message: 'الطفل غير موجود أو لا ينتمي إلى هذه المؤسسة'
      });
    }

    const sessions = await Session.findAll({
      where: { child_id },
      include: [
        {
          model: SessionType,
          attributes: ['name', 'duration', 'price']
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['full_name']
        }
      ],
      order: [['date', 'DESC']],
      limit: 10
    });

    const evaluations = await Evaluation.findAll({
      where: { child_id },
      include: [
        {
          model: User,
          as: 'specialist',
          attributes: ['full_name']
        }
      ],
      order: [['created_at', 'DESC']],
      limit: 5
    });

    const age = calculateAge(child.date_of_birth);

    const totalSessions = await Session.count({ where: { child_id } });
    const completedSessions = await Session.count({ 
      where: { 
        child_id, 
        status: 'Completed' 
      } 
    });

    res.status(200).json({
      success: true,
      data: {
        child: {
          id: child.child_id,
          full_name: child.full_name,
          date_of_birth: child.date_of_birth,
          age: age,
          gender: child.gender,
          photo: child.photo || '',
          child_identifier: child.child_identifier,
          city: child.city,
          address: child.address,
          school_info: child.school_info,
          medical_history: child.medical_history,
          registration_status: child.registration_status,
          created_at: child.created_at
        },
        diagnosis: child.Diagnosis ? {
          id: child.Diagnosis.diagnosis_id,
          name: child.Diagnosis.name,
          description: child.Diagnosis.description
        } : null,
        parent: child.Parent ? {
          id: child.Parent.parent_id,
          name: child.Parent.User.full_name,
          email: child.Parent.User.email,
          phone: child.Parent.User.phone,
          profile_picture: child.Parent.User.profile_picture
        } : null,
        institution: child.currentInstitution ? {
          id: child.currentInstitution.institution_id,
          name: child.currentInstitution.name,
          city: child.currentInstitution.city
        } : null,
        statistics: {
          total_sessions: totalSessions,
          completed_sessions: completedSessions,
          completion_rate: totalSessions > 0 ? Math.round((completedSessions / totalSessions) * 100) : 0
        },
        recent_sessions: sessions,
        recent_evaluations: evaluations
      }
    });

  } catch (error) {
    console.error('Error in getChildDetails:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب بيانات الطفل',
      error: error.message
    });
  }
};

// ================= GET CHILDREN STATISTICS =================
exports.getChildrenStatistics = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const Manager = require('../../model/Manager');
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
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة أو المدير غير نشط'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const totalChildren = await Child.count({
      where: {
        current_institution_id: institutionId,
        deleted_at: null
      }
    });

    const childrenByStatus = await Child.findAll({
      where: {
        current_institution_id: institutionId,
        deleted_at: null
      },
      attributes: [
        'registration_status',
        [sequelize.fn('COUNT', sequelize.col('child_id')), 'count']
      ],
      group: ['registration_status'],
      raw: true
    });

    const childrenByGender = await Child.findAll({
      where: {
        current_institution_id: institutionId,
        deleted_at: null
      },
      attributes: [
        'gender',
        [sequelize.fn('COUNT', sequelize.col('child_id')), 'count']
      ],
      group: ['gender'],
      raw: true
    });

    const pendingRequests = await ChildRegistrationRequest.count({
      where: {
        institution_id: institutionId,
        status: 'Pending'
      }
    });

    const currentMonth = new Date();
    const firstDayOfMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
    const lastDayOfMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0);

    const monthlySessions = await Session.count({
      where: {
        institution_id: institutionId,
        date: {
          [Op.between]: [firstDayOfMonth, lastDayOfMonth]
        }
      }
    });

    res.status(200).json({
      success: true,
      data: {
        institution: {
          id: institutionId,
          name: manager.Institution.name
        },
        statistics: {
          total_children: totalChildren,
          by_registration_status: childrenByStatus.reduce((acc, item) => {
            acc[item.registration_status] = parseInt(item.count);
            return acc;
          }, {}),
          by_gender: childrenByGender.reduce((acc, item) => {
            acc[item.gender] = parseInt(item.count);
            return acc;
          }, {}),
          pending_registration_requests: pendingRequests,
          monthly_sessions: monthlySessions
        }
      }
    });

  } catch (error) {
    console.error('Error in getChildrenStatistics:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب الإحصائيات',
      error: error.message
    });
  }
};


// ================= GET ADVANCED CHILD STATISTICS =================
exports.getAdvancedChildStatistics = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { child_id } = req.params;

    const Manager = require('../../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة أو المدير غير نشط'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const child = await Child.findOne({
      where: {
        child_id,
        current_institution_id: institutionId,
        deleted_at: null
      },
      attributes: ['child_id', 'full_name']
    });

    if (!child) {
      return res.status(404).json({
        success: false,
        message: 'الطفل غير موجود أو لا ينتمي إلى هذه المؤسسة'
      });
    }

    const sessionStats = await Session.findAll({
      where: { child_id },
      attributes: [
        'status',
        [sequelize.fn('COUNT', sequelize.col('session_id')), 'count']
      ],
      group: ['status'],
      raw: true
    });

    const durationStats = await Session.findOne({
      where: { child_id },
      include: [{
        model: SessionType,
        attributes: []
      }],
      attributes: [
        [sequelize.fn('SUM', sequelize.col('SessionType.duration')), 'total_duration']
      ],
      raw: true
    });

    const priceStats = await Session.findOne({
      where: { child_id },
      include: [{
        model: SessionType,
        attributes: []
      }],
      attributes: [
        [sequelize.fn('AVG', sequelize.col('SessionType.price')), 'avg_price']
      ],
      raw: true
    });

    const evaluations = await Evaluation.findAll({
      where: { child_id },
      include: [{
        model: User,
        as: 'specialistUser',
        attributes: ['full_name', 'user_id']
      }],
      order: [['created_at', 'ASC']]
    });

    const specialistStats = await Evaluation.findAll({
      where: { child_id },
      attributes: [
        'specialist_id',
        [sequelize.fn('COUNT', sequelize.col('evaluation_id')), 'evaluation_count'],
        [sequelize.fn('AVG', sequelize.col('progress_score')), 'avg_progress']
      ],
      group: ['specialist_id'],
      raw: true
    });

    const specialistIds = specialistStats.map(stat => stat.specialist_id);
    const specialistsInfo = specialistIds.length > 0 ? await User.findAll({
      where: { user_id: { [Op.in]: specialistIds } },
      include: [{
        model: Specialist,
        attributes: ['specialization']
      }],
      attributes: ['user_id', 'full_name'],
      raw: true
    }) : [];

    const attendancePattern = await Session.findAll({
      where: { child_id },
      attributes: [
        [sequelize.fn('DATE', sequelize.col('date')), 'session_date'],
        'status',
        [sequelize.fn('COUNT', sequelize.col('session_id')), 'daily_sessions']
      ],
      group: ['session_date', 'status'],
      order: [['session_date', 'DESC']],
      limit: 30,
      raw: true
    });

    const sessionTypeEffectiveness = await Session.findAll({
      where: { child_id },
      attributes: [
        'session_type_id',
        [sequelize.fn('COUNT', sequelize.col('session_id')), 'session_count']
      ],
      group: ['session_type_id'],
      raw: true
    });

    const sessionTypeIds = sessionTypeEffectiveness.map(st => st.session_type_id);
    const sessionTypesInfo = sessionTypeIds.length > 0 ? await SessionType.findAll({
      where: { session_type_id: { [Op.in]: sessionTypeIds } },
      attributes: ['session_type_id', 'name', 'category', 'duration'],
      raw: true
    }) : [];

    const monthlyProgress = await Evaluation.findAll({
      where: { child_id },
      attributes: [
        [sequelize.fn('YEAR', sequelize.col('created_at')), 'year'],
        [sequelize.fn('MONTH', sequelize.col('created_at')), 'month'],
        [sequelize.fn('AVG', sequelize.col('progress_score')), 'avg_progress'],
        [sequelize.fn('COUNT', sequelize.col('evaluation_id')), 'evaluation_count']
      ],
      group: ['year', 'month'],
      order: [['year', 'ASC'], ['month', 'ASC']],
      raw: true
    });

    const treatmentDiversity = await Session.findOne({
      where: { child_id },
      attributes: [
        [sequelize.fn('COUNT', sequelize.col('session_id')), 'total_sessions'],
        [sequelize.fn('COUNT', sequelize.fn('DISTINCT', sequelize.col('session_type_id'))), 'unique_session_types'],
        [sequelize.fn('COUNT', sequelize.fn('DISTINCT', sequelize.col('specialist_id'))), 'unique_specialists']
      ],
      raw: true
    });

    const commitmentMetrics = await Session.findOne({
      where: { child_id },
      attributes: [
        [sequelize.fn('COUNT', sequelize.col('session_id')), 'total_scheduled'],
        [sequelize.fn('SUM', sequelize.literal("CASE WHEN status = 'Completed' THEN 1 ELSE 0 END")), 'completed'],
        [sequelize.fn('SUM', sequelize.literal("CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END")), 'cancelled'],
        [sequelize.fn('SUM', sequelize.literal("CASE WHEN status = 'No Show' THEN 1 ELSE 0 END")), 'no_show']
      ],
      raw: true
    });

    const costEffectiveness = await Session.findOne({
      where: { 
        child_id,
        status: 'Completed'
      },
      include: [{
        model: SessionType,
        attributes: []
      }],
      attributes: [
        [sequelize.fn('SUM', sequelize.col('SessionType.price')), 'total_spent'],
        [sequelize.fn('AVG', sequelize.col('SessionType.price')), 'avg_session_cost'],
        [sequelize.fn('COUNT', sequelize.col('Session.session_id')), 'sessions_count']
      ],
      raw: true
    });

    const strengthWeaknessAnalysis = await Evaluation.findAll({
      where: { child_id },
      attributes: [
        'evaluation_type',
        [sequelize.fn('AVG', sequelize.col('progress_score')), 'avg_score'],
        [sequelize.fn('COUNT', sequelize.col('evaluation_id')), 'assessment_count']
      ],
      group: ['evaluation_type'],
      order: [['avg_score', 'DESC']],
      raw: true
    });

    const processedSessionStats = sessionStats.map(stat => ({
      status: stat.status,
      count: parseInt(stat.count),
      total_duration: durationStats?.total_duration || 0,
      avg_price: priceStats?.avg_price || 0
    }));

    const processedSpecialistStats = specialistStats.map(stat => {
      const specialistInfo = specialistsInfo.find(s => s.user_id === stat.specialist_id);
      return {
        specialist_name: specialistInfo?.full_name || 'غير معروف',
        specialization: specialistInfo?.Specialist?.specialization || 'غير محدد',
        evaluation_count: parseInt(stat.evaluation_count),
        average_progress: parseFloat(stat.avg_progress) || 0
      };
    });

    const processedSessionTypeEffectiveness = sessionTypeEffectiveness.map(st => {
      const sessionTypeInfo = sessionTypesInfo.find(sti => sti.session_type_id === st.session_type_id);
      return {
        session_type: sessionTypeInfo?.name || 'غير معروف',
        category: sessionTypeInfo?.category || 'غير محدد',
        session_count: parseInt(st.session_count),
        effectiveness_score: calculateSessionTypeEffectiveness(st, evaluations)
      };
    });

    res.status(200).json({
      success: true,
      data: {
        child: {
          id: child.child_id,
          name: child.full_name
        },
        statistics: {
          session_analytics: {
            by_status: processedSessionStats,
            total_sessions: processedSessionStats.reduce((sum, stat) => sum + stat.count, 0),
            total_duration: durationStats?.total_duration || 0,
            commitment_rate: commitmentMetrics ? 
              (parseInt(commitmentMetrics.completed || 0) / parseInt(commitmentMetrics.total_scheduled || 1)) * 100 : 0
          },

          progress_analytics: {
            monthly_trend: monthlyProgress,
            current_avg_progress: evaluations.length > 0 ? 
              evaluations.reduce((sum, ev) => sum + (ev.progress_score || 0), 0) / evaluations.length : 0,
            progress_consistency: calculateProgressConsistency(evaluations),
            strength_weakness: strengthWeaknessAnalysis
          },

          team_analytics: {
            specialists: processedSpecialistStats,
            treatment_diversity: {
              unique_session_types: treatmentDiversity?.unique_session_types || 0,
              unique_specialists: treatmentDiversity?.unique_specialists || 0,
              total_sessions: treatmentDiversity?.total_sessions || 0
            }
          },

          financial_analytics: {
            total_investment: costEffectiveness?.total_spent || 0,
            average_session_cost: costEffectiveness?.avg_session_cost || 0,
            cost_per_progress_point: costEffectiveness?.total_spent / (evaluations.reduce((sum, ev) => sum + (ev.progress_score || 0), 0) || 1),
            sessions_count: costEffectiveness?.sessions_count || 0
          },

          kpis: {
            attendance_rate: calculateAttendanceRate(attendancePattern),
            progress_velocity: calculateProgressVelocity(evaluations),
            treatment_adherence: calculateTreatmentAdherence(commitmentMetrics),
            specialist_effectiveness: calculateSpecialistEffectiveness(processedSpecialistStats)
          },
          pattern_analytics: {
            attendance_pattern: analyzeAttendancePattern(attendancePattern),
            session_type_effectiveness: processedSessionTypeEffectiveness,
            best_performing_days: analyzeBestPerformingDays(attendancePattern, evaluations)
          }
        }
      }
    });

  } catch (error) {
    console.error('Error in getAdvancedChildStatistics:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب الإحصائيات المتقدمة',
      error: error.message
    });
  }
};

// ================= GET CHILD MULTIDISCIPLINARY TEAM INSIGHTS =================
exports.getChildMultidisciplinaryInsights = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { child_id } = req.params;

    const Manager = require('../../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة أو المدير غير نشط'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const child = await Child.findOne({
      where: {
        child_id,
        current_institution_id: institutionId,
        deleted_at: null
      },
      include: [
        {
          model: Diagnosis,
          attributes: ['name', 'description'],
          as: 'Diagnosis'
        },
        {
          model: Parent,
          include: [{
            model: User,
            attributes: ['full_name', 'phone', 'email']
          }]
        }
      ]
    });

    if (!child) {
      return res.status(404).json({
        success: false,
        message: 'الطفل غير موجود أو لا ينتمي إلى هذه المؤسسة'
      });
    }

    const specialistsData = await getChildSpecialistsData(child_id, institutionId);
    
    const allEvaluations = await getConsolidatedEvaluations(child_id);
    
    const teamAnalysis = analyzeMultidisciplinaryTeam(specialistsData, allEvaluations);
    
    const decisions = generateTeamBasedDecisions(teamAnalysis, child);
    
    const actionPlan = createComprehensiveActionPlan(teamAnalysis, decisions, child);

    res.status(200).json({
      success: true,
      data: {
        child: {
          id: child.child_id,
          full_name: child.full_name,
          age: calculateAge(child.date_of_birth),
          diagnosis: child.Diagnosis,
          parent: child.Parent ? {
            name: child.Parent.User.full_name,
            contact: child.Parent.User.phone
          } : null
        },
        multidisciplinary_team: specialistsData,
        consolidated_evaluations: allEvaluations,
        team_analysis: teamAnalysis,
        decisions_recommendations: decisions,
        comprehensive_action_plan: actionPlan,
        report_generated_at: new Date(),
        data_sources: {
          specialists_count: specialistsData.length,
          evaluations_count: allEvaluations.raw_evaluations.length,
          sessions_count: teamAnalysis.total_sessions,
          time_period: teamAnalysis.analysis_period
        }
      }
    });

  } catch (error) {
    console.error('Error in getChildMultidisciplinaryInsights:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في تحليل بيانات الفريق متعدد التخصصات',
      error: error.message
    });
  }
};

// ================= دوال مساعدة =================

const calculateAge = (dateOfBirth) => {
  if (!dateOfBirth) return 0;
  const birthDate = new Date(dateOfBirth);
  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  return age;
};

const categorizeChildPerformance = (sessionCount, avgProgress) => {
  if (sessionCount === 0) return 'غير محدد';
  
  const progress = avgProgress || 0;
  
  if (progress >= 80 && sessionCount >= 10) return 'ممتاز';
  if (progress >= 60 && sessionCount >= 5) return 'جيد جداً';
  if (progress >= 40) return 'جيد';
  if (progress >= 20) return 'مقبول';
  return 'بحاجة للتحسين';
};

const calculateProgressConsistency = (evaluations) => {
  if (evaluations.length < 2) return 0;
  
  const scores = evaluations.map(e => e.progress_score).filter(score => score != null);
  const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
  const variance = scores.reduce((a, b) => a + Math.pow(b - avg, 2), 0) / scores.length;
  
  return Math.max(0, 100 - (Math.sqrt(variance) * 10));
};

const calculateAttendanceRate = (attendancePattern) => {
  const totalSessions = attendancePattern.reduce((sum, day) => sum + parseInt(day.daily_sessions), 0);
  const completedSessions = attendancePattern
    .filter(day => day.status === 'Completed')
    .reduce((sum, day) => sum + parseInt(day.daily_sessions), 0);
  
  return totalSessions > 0 ? (completedSessions / totalSessions) * 100 : 0;
};

const calculateProgressVelocity = (evaluations) => {
  if (evaluations.length < 2) return 0;
  
  const sortedEvals = evaluations.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  const firstScore = sortedEvals[0].progress_score || 0;
  const lastScore = sortedEvals[sortedEvals.length - 1].progress_score || 0;
  const timeDiff = (new Date(sortedEvals[sortedEvals.length - 1].created_at) - new Date(sortedEvals[0].created_at)) / (1000 * 60 * 60 * 30);
  
  return timeDiff > 0 ? (lastScore - firstScore) / timeDiff : 0;
};

const calculateTreatmentAdherence = (commitmentMetrics) => {
  if (!commitmentMetrics) return 0;
  
  const total = parseInt(commitmentMetrics.total_scheduled);
  const completed = parseInt(commitmentMetrics.completed);
  
  return total > 0 ? (completed / total) * 100 : 0;
};

const calculateSpecialistEffectiveness = (specialistStats) => {
  if (specialistStats.length === 0) return 0;
  
  const totalEffectiveness = specialistStats.reduce((sum, spec) => {
    return sum + (spec.average_progress || 0);
  }, 0);
  
  return totalEffectiveness / specialistStats.length;
};

const calculateSessionTypeEffectiveness = (sessionType, evaluations) => {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  const relevantEvals = evaluations.filter(ev => 
    new Date(ev.created_at) > thirtyDaysAgo
  );
  
  if (relevantEvals.length === 0) return 0;
  
  const progressSum = relevantEvals.reduce((sum, ev) => sum + (ev.progress_score || 0), 0);
  return progressSum / relevantEvals.length;
};

const analyzeAttendancePattern = (attendancePattern) => {
  const pattern = {
    best_days: [],
    consistent_days: [],
    problematic_days: []
  };
  
  const dayAnalysis = {};
  
  attendancePattern.forEach(day => {
    const date = new Date(day.session_date);
    const dayName = date.toLocaleDateString('ar-SA', { weekday: 'long' });
    
    if (!dayAnalysis[dayName]) {
      dayAnalysis[dayName] = { total: 0, completed: 0 };
    }
    
    dayAnalysis[dayName].total += parseInt(day.daily_sessions);
    if (day.status === 'Completed') {
      dayAnalysis[dayName].completed += parseInt(day.daily_sessions);
    }
  });
  
  Object.entries(dayAnalysis).forEach(([day, stats]) => {
    const rate = stats.total > 0 ? (stats.completed / stats.total) * 100 : 0;
    
    if (rate >= 80) pattern.best_days.push(day);
    else if (rate >= 60) pattern.consistent_days.push(day);
    else pattern.problematic_days.push(day);
  });
  
  return pattern;
};

const analyzeBestPerformingDays = (attendancePattern, evaluations) => {
  const dayPerformance = {};
  
  attendancePattern.forEach(day => {
    const date = new Date(day.session_date);
    const dayName = date.toLocaleDateString('ar-SA', { weekday: 'long' });
    
    const nearbyEvals = evaluations.filter(ev => {
      const evalDate = new Date(ev.created_at);
      const diffTime = Math.abs(evalDate - date);
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      return diffDays <= 3;
    });
    
    if (!dayPerformance[dayName]) {
      dayPerformance[dayName] = { total_score: 0, count: 0 };
    }
    
    nearbyEvals.forEach(ev => {
      dayPerformance[dayName].total_score += ev.progress_score || 0;
      dayPerformance[dayName].count++;
    });
  });
  
  const performanceArray = Object.entries(dayPerformance).map(([day, stats]) => ({
    day,
    average_performance: stats.count > 0 ? stats.total_score / stats.count : 0,
    assessment_count: stats.count
  }));
  
  return performanceArray.sort((a, b) => b.average_performance - a.average_performance);
};

// ================= دوال الفريق متعدد التخصصات =================

const getChildSpecialistsData = async (childId, institutionId) => {
  const sessions = await Session.findAll({
    where: { child_id: childId },
    include: [{
      model: User,
      as: 'specialist',
      attributes: ['user_id', 'full_name', 'profile_picture']
    }],
    attributes: ['specialist_id'],
    group: ['specialist_id'],
    raw: true
  });

  const specialistIds = sessions.map(s => s.specialist_id).filter(id => id);

  if (specialistIds.length === 0) {
    return [];
  }

  const specialists = await User.findAll({
    where: { user_id: { [Op.in]: specialistIds } },
    include: [{
      model: Specialist,
      attributes: ['specialization', 'years_experience']
    }],
    attributes: ['user_id', 'full_name', 'profile_picture'],
    raw: true
  });

  return await Promise.all(
    specialists.map(async (specialist) => {
      const sessions = await Session.findAll({
        where: {
          child_id: childId,
          specialist_id: specialist.user_id
        },
        include: [{
          model: SessionType,
          attributes: ['name', 'category']
        }],
        order: [['date', 'ASC']]
      });

      const evaluations = await Evaluation.findAll({
        where: {
          child_id: childId,
          specialist_id: specialist.user_id
        },
        order: [['created_at', 'ASC']]
      });

      const performanceMetrics = calculateSpecialistPerformanceMetrics(sessions, evaluations);

      return {
        specialist_id: specialist.user_id,
        personal_info: {
          name: specialist.full_name,
          profile_picture: specialist.profile_picture || '',
          specialization: specialist['Specialist.specialization'] || 'غير محدد',
          experience: specialist['Specialist.years_experience'] || 0,
        //   qualifications: specialist['Specialist.qualifications'] || 'غير محدد'
        },
        engagement: {
          total_sessions: sessions.length,
          completed_sessions: sessions.filter(s => s.status === 'Completed').length,
          first_session: sessions.length > 0 ? sessions[0].date : null,
          last_session: sessions.length > 0 ? sessions[sessions.length - 1].date : null,
          session_categories: [...new Set(sessions.map(s => s.SessionType?.category))].filter(Boolean),
          attendance_rate: sessions.length > 0 ? 
            (sessions.filter(s => s.status === 'Completed').length / sessions.length) * 100 : 0
        },
        performance: performanceMetrics,
        evaluations_summary: {
          total: evaluations.length,
          types: [...new Set(evaluations.map(e => e.evaluation_type))],
          average_score: evaluations.length > 0 ? 
            evaluations.reduce((sum, e) => sum + (e.progress_score || 0), 0) / evaluations.length : 0,
          trend: calculateProgressTrend(evaluations),
          last_evaluation: evaluations.length > 0 ? evaluations[evaluations.length - 1].created_at : null
        }
      };
    })
  );
};

const calculateProgressTrend = (evaluations) => {
  if (evaluations.length < 2) return 'stable';
  
  const sortedEvals = evaluations.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  const firstScore = sortedEvals[0].progress_score || 0;
  const lastScore = sortedEvals[sortedEvals.length - 1].progress_score || 0;
  
  if (lastScore > firstScore + 10) return 'improving';
  if (lastScore < firstScore - 10) return 'declining';
  return 'stable';
};

const calculateConsistencyScore = (evaluations) => {
  if (evaluations.length < 2) return 100;
  
  const scores = evaluations.map(e => e.progress_score).filter(score => score != null);
  const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
  const variance = scores.reduce((a, b) => a + Math.pow(b - avg, 2), 0) / scores.length;
  
  return Math.max(0, 100 - (Math.sqrt(variance) * 5));
};

const calculateRecommendationRating = (effectivenessScore, consistencyScore) => {
  const overallScore = (effectivenessScore * 0.7 + consistencyScore * 0.3);
  
  if (overallScore >= 80) return 'ممتاز';
  if (overallScore >= 60) return 'جيد';
  if (overallScore >= 40) return 'مقبول';
  return 'بحاجة للتحسين';
};

const calculateEvaluationConsistency = (evaluations) => {
  return calculateConsistencyScore(evaluations);
};

const calculateSpecialistPerformanceMetrics = (sessions, evaluations) => {
  const completedSessions = sessions.filter(s => s.status === 'Completed').length;
  const totalSessions = sessions.length;
  
  const attendanceRate = totalSessions > 0 ? (completedSessions / totalSessions) * 100 : 0;
  
  const progressScores = evaluations.map(e => e.progress_score).filter(score => score != null);
  const avgProgress = progressScores.length > 0 ? 
    progressScores.reduce((a, b) => a + b, 0) / progressScores.length : 0;

  const effectivenessScore = calculateEffectivenessScore(attendanceRate, avgProgress, evaluations.length);
  const consistencyScore = calculateConsistencyScore(evaluations);

  return {
    attendance_rate: attendanceRate,
    average_progress: avgProgress,
    effectiveness_score: effectivenessScore,
    consistency_score: consistencyScore,
    session_completion_rate: attendanceRate,
    progress_velocity: calculateProgressVelocity(evaluations),
    recommendation_rating: calculateRecommendationRating(effectivenessScore, consistencyScore)
  };
};

const calculateEffectivenessScore = (attendanceRate, avgProgress, evaluationCount) => {
  const attendanceWeight = 0.3;
  const progressWeight = 0.5;
  const consistencyWeight = 0.2;
  
  const normalizedAttendance = Math.min(attendanceRate, 100) / 100;
  const normalizedProgress = Math.min(avgProgress, 100) / 100;
  const evaluationFactor = Math.min(evaluationCount / 5, 1);
  
  return (normalizedAttendance * attendanceWeight + 
          normalizedProgress * progressWeight + 
          evaluationFactor * consistencyWeight) * 100;
};

const getConsolidatedEvaluations = async (childId) => {
  const evaluations = await Evaluation.findAll({
    where: { child_id: childId },
    order: [['created_at', 'ASC']],
    raw: true
  });

  const specialistIds = [...new Set(evaluations.map(ev => ev.specialist_id))];
  
  let specialistsInfo = [];
  if (specialistIds.length > 0) {
    specialistsInfo = await User.findAll({
      where: { user_id: { [Op.in]: specialistIds } },
      include: [{
        model: Specialist,
        attributes: ['specialization'],
        as: 'Specialist'
      }],
      attributes: ['user_id', 'full_name'],
      raw: true
    });
  }

  const processedEvaluations = evaluations.map(ev => {
    const specialistInfo = specialistsInfo.find(s => s.user_id === ev.specialist_id);
    return {
      ...ev,
      specialist: {
        name: specialistInfo?.full_name || 'غير معروف',
        specialization: specialistInfo?.['Specialist.specialization'] || 'غير محدد'
      }
    };
  });

  const domainAnalysis = groupEvaluationsByDomain(processedEvaluations);
  const progressTimeline = createProgressTimeline(processedEvaluations);
  const strengthsWeaknesses = identifyStrengthsWeaknesses(processedEvaluations);

  return {
    raw_evaluations: processedEvaluations.map(ev => ({
      id: ev.evaluation_id,
      type: ev.evaluation_type,
      specialist: {
        name: ev.specialist.name,
        specialization: ev.specialist.specialization
      },
      score: ev.progress_score,
      notes: ev.notes,
      date: ev.created_at,
      attachments: ev.attachment ? [ev.attachment] : []
    })),
    domain_analysis: domainAnalysis,
    progress_timeline: progressTimeline,
    strengths_weaknesses: strengthsWeaknesses,
    overall_progress: calculateOverallProgress(processedEvaluations),
    consistency_score: calculateEvaluationConsistency(processedEvaluations),
    progress_milestones: identifyProgressMilestones(processedEvaluations)
  };
};

const groupEvaluationsByDomain = (evaluations) => {
  const domains = {};
  
  evaluations.forEach(ev => {
    const domain = mapEvaluationToDomain(ev.evaluation_type);
    if (!domains[domain]) {
      domains[domain] = {
        evaluations: [],
        average_score: 0,
        trend: 'stable'
      };
    }
    domains[domain].evaluations.push(ev);
  });
  
  Object.keys(domains).forEach(domain => {
    const domainEvals = domains[domain].evaluations;
    const scores = domainEvals.map(e => e.progress_score).filter(score => score != null);
    domains[domain].average_score = scores.length > 0 ? 
      scores.reduce((a, b) => a + b, 0) / scores.length : 0;
    domains[domain].trend = calculateProgressTrend(domainEvals);
    domains[domain].evaluation_count = domainEvals.length;
  });
  
  return domains;
};

const mapEvaluationToDomain = (evaluationType) => {
  const type = (evaluationType || '').toLowerCase();
  
  if (type.includes('نطق') || type.includes('speech') || type.includes('language')) {
    return 'التواصل والنطق';
  }
  if (type.includes('حركي') || type.includes('motor') || type.includes('physical')) {
    return 'المهارات الحركية';
  }
  if (type.includes('سلوك') || type.includes('behavior') || type.includes('aba')) {
    return 'السلوك';
  }
  if (type.includes('اجتماعي') || type.includes('social') || type.includes('interaction')) {
    return 'المهارات الاجتماعية';
  }
  if (type.includes('تعليم') || type.includes('academic') || type.includes('cognitive')) {
    return 'المهارات المعرفية';
  }
  
  return 'عام';
};

const createProgressTimeline = (evaluations) => {
  return evaluations.map(ev => ({
    date: ev.created_at,
    score: ev.progress_score,
    type: ev.evaluation_type,
    specialist: ev.specialist?.full_name,
    notes: ev.notes
  })).sort((a, b) => new Date(a.date) - new Date(b.date));
};

const identifyStrengthsWeaknesses = (evaluations) => {
  const domainScores = {};
  
  evaluations.forEach(ev => {
    const domain = mapEvaluationToDomain(ev.evaluation_type);
    if (!domainScores[domain]) {
      domainScores[domain] = [];
    }
    if (ev.progress_score != null) {
      domainScores[domain].push(ev.progress_score);
    }
  });
  
  const averages = {};
  Object.keys(domainScores).forEach(domain => {
    const scores = domainScores[domain];
    averages[domain] = scores.length > 0 ? scores.reduce((a, b) => a + b, 0) / scores.length : 0;
  });
  
  const sortedDomains = Object.keys(averages).sort((a, b) => averages[b] - averages[a]);
  
  return {
    strengths: sortedDomains.slice(0, 2).map(domain => ({
      domain,
      average_score: averages[domain],
      evaluation_count: domainScores[domain].length
    })),
    weaknesses: sortedDomains.slice(-2).map(domain => ({
      domain,
      average_score: averages[domain],
      evaluation_count: domainScores[domain].length
    }))
  };
};

const calculateOverallProgress = (evaluations) => {
  const scores = evaluations.map(e => e.progress_score).filter(score => score != null);
  return scores.length > 0 ? scores.reduce((a, b) => a + b, 0) / scores.length : 0;
};

const identifyProgressMilestones = (evaluations) => {
  if (evaluations.length < 2) return [];
  
  const sortedEvals = evaluations.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  const milestones = [];
  
  for (let i = 1; i < sortedEvals.length; i++) {
    const current = sortedEvals[i];
    const previous = sortedEvals[i - 1];
    const currentScore = current.progress_score || 0;
    const previousScore = previous.progress_score || 0;
    const progress = currentScore - previousScore;
    
    if (progress >= 10) {
      milestones.push({
        date: current.created_at,
        description: `قفزة تقدم كبيرة (+${progress}%)`,
        specialist: current.specialist?.full_name,
        type: current.evaluation_type
      });
    }
  }
  
  return milestones;
};

const analyzeMultidisciplinaryTeam = (specialistsData, evaluations) => {
  const analysis = {
    team_composition: analyzeTeamComposition(specialistsData),
    collaboration_patterns: analyzeCollaborationPatterns(specialistsData, evaluations.raw_evaluations),
    treatment_coordination: analyzeTreatmentCoordination(specialistsData),
    gaps_and_overlaps: identifyGapsAndOverlaps(specialistsData),
    overall_effectiveness: calculateTeamEffectiveness(specialistsData, evaluations),
    communication_quality: assessCommunicationQuality(specialistsData, evaluations),
    total_sessions: specialistsData.reduce((sum, spec) => sum + spec.engagement.total_sessions, 0),
    analysis_period: calculateAnalysisPeriod(specialistsData)
  };

  return analysis;
};

const analyzeTeamComposition = (specialistsData) => {
  const specializations = specialistsData.map(s => s.personal_info.specialization);
  const uniqueSpecializations = [...new Set(specializations)];
  
  return {
    total_specialists: specialistsData.length,
    specializations: uniqueSpecializations,
    specialists: specialistsData.map(spec => ({
      name: spec.personal_info.name,
      specialization: spec.personal_info.specialization,
      experience: spec.personal_info.experience,
      effectiveness: spec.performance.effectiveness_score
    })),
    experience_distribution: {
      junior: specialistsData.filter(s => s.personal_info.experience < 3).length,
      mid: specialistsData.filter(s => s.personal_info.experience >= 3 && s.personal_info.experience < 7).length,
      senior: specialistsData.filter(s => s.personal_info.experience >= 7).length
    }
  };
};

const analyzeCollaborationPatterns = (specialistsData, evaluations) => {
  const sessionDates = specialistsData.flatMap(spec => 
    spec.engagement.first_session ? [new Date(spec.engagement.first_session)] : []
  );
  
  let coordinationScore = 50;
  
  if (sessionDates.length > 1) {
    const dateDifferences = [];
    for (let i = 0; i < sessionDates.length - 1; i++) {
      for (let j = i + 1; j < sessionDates.length; j++) {
        const diff = Math.abs(sessionDates[i] - sessionDates[j]);
        dateDifferences.push(diff);
      }
    }
    
    const avgDifference = dateDifferences.reduce((a, b) => a + b, 0) / dateDifferences.length;
    coordinationScore = Math.max(0, 100 - (avgDifference / (7 * 24 * 60 * 60 * 1000)));
  }
  
  return {
    coordination_score: Math.min(coordinationScore, 100),
    communication_frequency: 'أسبوعي',
    shared_goals: 'متوسطة',
    interdisciplinary_sessions: []
  };
};

const analyzeTreatmentCoordination = (specialistsData) => {
  const coordinationMetrics = {
    goal_alignment: 70,
    method_consistency: 65,
    progress_synchronization: 60,
    information_sharing: 75
  };
  
  const overallCoordination = Object.values(coordinationMetrics).reduce((a, b) => a + b, 0) / Object.values(coordinationMetrics).length;
  
  return {
    ...coordinationMetrics,
    overall_coordination: overallCoordination,
    coordination_level: overallCoordination >= 80 ? 'ممتاز' : overallCoordination >= 60 ? 'جيد' : 'بحاجة للتحسين'
  };
};

const identifyGapsAndOverlaps = (specialistsData) => {
  const existingSpecializations = specialistsData.map(s => s.personal_info.specialization);
  
  const requiredSpecializations = [
    'علاج نطق',
    'علاج وظيفي',
    'علاج طبيعي',
    'تحليل سلوك',
    'تأهيل نفسي'
  ];
  
  const missingSpecializations = requiredSpecializations.filter(spec => 
    !existingSpecializations.some(existing => existing.includes(spec))
  );
  
  const specializationCount = {};
  existingSpecializations.forEach(spec => {
    specializationCount[spec] = (specializationCount[spec] || 0) + 1;
  });
  
  const overlappingSpecializations = Object.entries(specializationCount)
    .filter(([spec, count]) => count > 1)
    .map(([spec, count]) => ({ specialization: spec, count }));
  
  return {
    missing_specializations: missingSpecializations,
    overlapping_specializations: overlappingSpecializations,
    coverage_score: calculateCoverageScore(existingSpecializations, requiredSpecializations),
    main_challenges: identifyMainChallenges(missingSpecializations, overlappingSpecializations)
  };
};

const calculateCoverageScore = (existing, required) => {
  const covered = required.filter(req => existing.some(ex => ex.includes(req))).length;
  return (covered / required.length) * 100;
};

const identifyMainChallenges = (missing, overlapping) => {
  const challenges = [];
  
  if (missing.length > 0) {
    challenges.push(`نقص في التخصصات: ${missing.join(', ')}`);
  }
  
  if (overlapping.length > 0) {
    challenges.push(`تكرار في التخصصات: ${overlapping.map(o => o.specialization).join(', ')}`);
  }
  
  if (challenges.length === 0) {
    challenges.push('التكوين الفريقي متوازن وجيد');
  }
  
  return challenges;
};

const calculateTeamEffectiveness = (specialistsData, evaluations) => {
  const individualEffectiveness = specialistsData.map(s => s.performance.effectiveness_score);
  const avgEffectiveness = individualEffectiveness.reduce((a, b) => a + b, 0) / individualEffectiveness.length;
  
  const collaborationScore = analyzeCollaborationPatterns(specialistsData, evaluations.raw_evaluations).coordination_score;
  const progressScore = evaluations.overall_progress;
  
  const teamStrength = (avgEffectiveness * 0.4 + collaborationScore * 0.3 + progressScore * 0.3) / 100;
  
  return {
    team_strength: teamStrength * 100,
    collaboration_quality: collaborationScore,
    progress_achievement: progressScore,
    overall_rating: teamStrength >= 0.8 ? 'ممتاز' : teamStrength >= 0.6 ? 'جيد' : 'بحاجة للتحسين'
  };
};

const assessCommunicationQuality = (specialistsData, evaluations) => {
  return {
    frequency_score: 70,
    clarity_score: 75,
    timeliness_score: 65,
    overall_quality: 'جيد'
  };
};

const calculateAnalysisPeriod = (specialistsData) => {
  const allDates = specialistsData.flatMap(spec => [
    spec.engagement.first_session,
    spec.engagement.last_session
  ]).filter(date => date);
  
  if (allDates.length === 0) return 'غير محدد';
  
  const minDate = new Date(Math.min(...allDates.map(d => new Date(d))));
  const maxDate = new Date(Math.max(...allDates.map(d => new Date(d))));
  
  const months = (maxDate.getFullYear() - minDate.getFullYear()) * 12 + 
                 (maxDate.getMonth() - minDate.getMonth());
  
  return `${months} أشهر`;
};

const generateTeamBasedDecisions = (teamAnalysis, child) => {
  const decisions = {
    strategic_decisions: [],
    tactical_adjustments: [],
    resource_allocations: [],
    coordination_improvements: [],
    priority_actions: []
  };

  if (teamAnalysis.gaps_and_overlaps.missing_specializations.length > 0) {
    decisions.strategic_decisions.push({
      type: 'TEAM_EXPANSION',
      priority: 'HIGH',
      title: 'إضافة تخصصات علاجية مطلوبة',
      description: `الطفل يحتاج إلى متخصصين في: ${teamAnalysis.gaps_and_overlaps.missing_specializations.join(', ')}`,
      rationale: 'تحليل الفريق أظهر نقصاً في التخصصات المطلوبة لتحقيق نتائج أفضل',
      expected_impact: 'تحسين شامل في النتائج العلاجية',
      implementation_timeline: '1-2 شهر',
      responsible: 'مدير المؤسسة'
    });
  }

  teamAnalysis.team_composition.specialists.forEach(specialist => {
    if (specialist.effectiveness < 60) {
      decisions.tactical_adjustments.push({
        type: 'PERFORMANCE_IMPROVEMENT',
        priority: 'MEDIUM',
        title: `تحسين أداء ${specialist.name}`,
        description: `الأخصائي ${specialist.name} بحاجة إلى تحسين في الفعالية (${specialist.effectiveness}%)`,
        actions: [
          'مراجعة أساليب العلاج المستخدمة',
          'توفير تدريب إضافي إذا لزم الأمر',
          'زيادة التنسيق مع الأخصائيين الآخرين'
        ],
        timeline: '2-4 أسابيع',
        success_metrics: 'تحسين درجة الفعالية إلى 70% على الأقل'
      });
    }
  });

  const highPerformers = teamAnalysis.team_composition.specialists.filter(s => 
    s.effectiveness >= 75
  );
  
  if (highPerformers.length > 0) {
    decisions.resource_allocations.push({
      type: 'RESOURCE_OPTIMIZATION',
      priority: 'MEDIUM',
      title: 'تعزيز دور الأخصائيين المتميزين',
      description: `زيادة عدد الجلسات مع ${highPerformers.map(s => s.name).join(', ')}`,
      rationale: 'الأخصائيون المتميزون يحققون نتائج أفضل مع الطفل',
      expected_outcome: 'تحسين معدل التقدم بشكل أسرع'
    });
  }

  if (teamAnalysis.collaboration_patterns.coordination_score < 70) {
    decisions.coordination_improvements.push({
      type: 'COLLABORATION_ENHANCEMENT',
      priority: 'HIGH',
      title: 'تحسين التنسيق بين أعضاء الفريق',
      description: 'تنظيم اجتماعات تنسيق منتظمة بين جميع الأخصائيين',
      actions: [
        'اجتماع أسبوعي لتنسيق الخطط العلاجية',
        'مشاركة التقارير والتقييمات بين الفريق',
        'وضع خطة علاجية موحدة'
      ],
      timeline: 'فوري',
      responsible: 'مدير الحالة'
    });
  }

  decisions.priority_actions = prioritizeActions(decisions);

  return decisions;
};

const prioritizeActions = (decisions) => {
  const allActions = [
    ...decisions.strategic_decisions,
    ...decisions.tactical_adjustments,
    ...decisions.resource_allocations,
    ...decisions.coordination_improvements
  ];
  
  return allActions
    .sort((a, b) => {
      const priorityOrder = { HIGH: 3, MEDIUM: 2, LOW: 1 };
      return priorityOrder[b.priority] - priorityOrder[a.priority];
    })
    .slice(0, 5);
};

const createComprehensiveActionPlan = (teamAnalysis, decisions, child) => {
  const actionPlan = {
    overview: {
      child_name: child.full_name,
      diagnosis: child.Diagnosis?.name,
      team_strength: teamAnalysis.overall_effectiveness.team_strength,
      main_challenges: teamAnalysis.gaps_and_overlaps.main_challenges,
      primary_goals: definePrimaryGoals(teamAnalysis, child)
    },
    phases: [
      {
        phase: 'فوري (أسبوعين)',
        objectives: ['معالجة الفجوات الحرجة', 'تحسين التنسيق'],
        actions: generateImmediateActions(decisions),
        success_metrics: ['تحسين درجة التنسيق 20%', 'معالجة جميع الفجوات الحرجة']
      },
      {
        phase: 'قصير المدى (1-3 أشهر)',
        objectives: ['تحسين الأداء الفردي', 'تعزيز التعاون'],
        actions: generateShortTermActions(decisions, teamAnalysis),
        success_metrics: ['تحسين متوسط الفعالية 15%', 'زيادة جودة التواصل 25%']
      },
      {
        phase: 'متوسط المدى (3-6 أشهر)',
        objectives: ['تحقيق التكامل العلاجي', 'قياس النتائج'],
        actions: generateMediumTermActions(teamAnalysis, child),
        success_metrics: ['تحقيق 80% من الأهداف العلاجية', 'تحسين شامل في جودة الحياة']
      }
    ],
    monitoring_framework: {
      key_performance_indicators: defineKPIs(teamAnalysis),
      review_schedule: 'أسبوعي للأسبوعين الأولين، ثم شهري',
      reporting_requirements: ['تقرير تقدم أسبوعي', 'تقييم شامل شهري']
    },
    risk_management: {
      potential_risks: identifyPotentialRisks(teamAnalysis, decisions),
      mitigation_strategies: developMitigationStrategies(teamAnalysis),
      contingency_plans: createContingencyPlans(child)
    }
  };

  return actionPlan;
};

const definePrimaryGoals = (teamAnalysis, child) => {
  const goals = [
    'تحسين التنسيق بين أعضاء الفريق العلاجي',
    'معالجة الفجوات في التخصصات المطلوبة',
    'تحسين جودة التواصل والمشاركة المعلوماتية'
  ];
  
  if (teamAnalysis.overall_effectiveness.progress_achievement < 60) {
    goals.push('تحسين معدل التقدم العام للطفل');
  }
  
  if (teamAnalysis.gaps_and_overlaps.missing_specializations.length > 0) {
    goals.push('استكمال الفريق العلاجي بالتخصصات المطلوبة');
  }
  
  return goals;
};

const generateImmediateActions = (decisions) => {
  return decisions.priority_actions
    .filter(action => action.priority === 'HIGH')
    .map(action => ({
      action: action.title,
      description: action.description,
      timeline: 'أسبوعين',
      responsible: action.responsible || 'مدير الفريق'
    }));
};

const generateShortTermActions = (decisions, teamAnalysis) => {
  const actions = decisions.priority_actions
    .filter(action => action.priority === 'MEDIUM')
    .map(action => ({
      action: action.title,
      description: action.description,
      timeline: '1-3 أشهر',
      responsible: action.responsible || 'مدير الفريق'
    }));
  
  if (teamAnalysis.communication_quality.overall_quality === 'بحاجة للتحسين') {
    actions.push({
      action: 'تحسين نظام التواصل الداخلي',
      description: 'تنفيذ نظام موحد لتقارير التقدم والتقييمات',
      timeline: 'شهر',
      responsible: 'مدير المؤسسة'
    });
  }
  
  return actions;
};

const generateMediumTermActions = (teamAnalysis, child) => {
  const actions = [];
  
  if (teamAnalysis.overall_effectiveness.team_strength < 70) {
    actions.push({
      action: 'برنامج تطوير مهني للفريق',
      description: 'تدريبات متخصصة لتحسين أداء الفريق العلاجي',
      timeline: '3-6 أشهر',
      responsible: 'مدير التدريب'
    });
  }
  
  actions.push({
    action: 'تقييم شامل للنتائج',
    description: `قياس تأثير الخطة العلاجية على تقدم ${child.full_name}`,
    timeline: '6 أشهر',
    responsible: 'مدير الجودة'
  });
  
  return actions;
};

const defineKPIs = (teamAnalysis) => {
  return [
    {
      kpi: 'درجة تنسيق الفريق',
      target: '80%',
      current: `${Math.round(teamAnalysis.collaboration_patterns.coordination_score)}%`
    },
    {
      kpi: 'معدل الفعالية الفردية',
      target: '75%',
      current: `${Math.round(teamAnalysis.overall_effectiveness.team_strength)}%`
    },
    {
      kpi: 'التغطية بالتخصصات',
      target: '90%',
      current: `${Math.round(teamAnalysis.gaps_and_overlaps.coverage_score)}%`
    },
    {
      kpi: 'جودة التواصل',
      target: 'ممتاز',
      current: teamAnalysis.communication_quality.overall_quality
    }
  ];
};

const identifyPotentialRisks = (teamAnalysis, decisions) => {
  const risks = [];
  
  if (teamAnalysis.gaps_and_overlaps.missing_specializations.length > 0) {
    risks.push({
      risk: 'عدم توفر التخصصات المطلوبة',
      probability: 'مرتفعة',
      impact: 'كبير',
      description: 'قد يؤثر على جودة النتائج العلاجية'
    });
  }
  
  if (teamAnalysis.overall_effectiveness.team_strength < 60) {
    risks.push({
      risk: 'ضعف أداء الفريق',
      probability: 'متوسطة',
      impact: 'كبير',
      description: 'قد يؤدي إلى تباطؤ في تقدم الطفل'
    });
  }
  
  return risks;
};

const developMitigationStrategies = (teamAnalysis) => {
  const strategies = [];
  
  if (teamAnalysis.gaps_and_overlaps.missing_specializations.length > 0) {
    strategies.push({
      strategy: 'التعاون مع أخصائيين خارجيين',
      description: 'إشراك أخصائيين من خارج المؤسسة للتخصصات الناقصة',
      timeline: 'شهر'
    });
  }
  
  if (teamAnalysis.collaboration_patterns.coordination_score < 70) {
    strategies.push({
      strategy: 'تعيين منسق للحالة',
      description: 'تعيين شخص مسؤول عن تنسيق العمل بين جميع الأخصائيين',
      timeline: 'فوري'
    });
  }
  
  return strategies;
};

const createContingencyPlans = (child) => {
  return [
    {
      scenario: 'عدم استجابة الطفل للعلاج الحالي',
      plan: 'مراجعة شاملة للخطة العلاجية وإشراك استشاري متخصص',
      trigger: 'عدم تحقيق تقدم ملحوظ خلال 3 أشهر'
    },
    {
      scenario: 'انسحاب أخصائي رئيسي من الفريق',
      plan: 'التواصل مع أخصائي بديل وتدريب سريع على حالة الطفل',
      trigger: 'إشعار بالانسحاب من أي أخصائي رئيسي'
    }
  ];
};

module.exports = exports;