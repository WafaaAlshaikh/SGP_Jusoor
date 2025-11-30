const Specialist = require('../../model/Specialist');
const User = require('../../model/User');
const Manager = require('../../model/Manager');
const Institution = require('../../model/Institution');
const Session = require('../../model/Session');
const Evaluation = require('../../model/Evaluation');
const Child = require('../../model/Child');
const SessionType = require('../../model/SessionType');
const VacationRequest = require('../../model/VacationRequest');
const { Op } = require('sequelize');
const sequelize = require('../../config/db');

// ================= GET ALL SPECIALISTS IN INSTITUTION =================
exports.getInstitutionSpecialists = async (req, res) => {
  try {
    const managerId = req.user.user_id;

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
        message: 'Institution not found or manager not active'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const {
      search = '',
      specialization,
      approval_status,
      experience_level,
      sort = 'name',
      order = 'asc',
      page = '1',
      limit = '20'
    } = req.query;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const pageLimit = Math.max(1, parseInt(limit, 10) || 20);
    const offset = (pageNum - 1) * pageLimit;

    let whereClause = {
      institution_id: institutionId
    };

    let userWhereClause = {};

    if (search && search.trim() !== '') {
      userWhereClause[Op.or] = [
        { full_name: { [Op.like]: `%${search.trim()}%` } },
        { email: { [Op.like]: `%${search.trim()}%` } }
      ];
    }

    if (specialization && specialization !== 'All') {
      whereClause.specialization = { [Op.like]: `%${specialization}%` };
    }

    if (approval_status && approval_status !== 'All') {
      whereClause.approval_status = approval_status;
    }

    if (experience_level && experience_level !== 'All') {
      switch (experience_level) {
        case 'junior':
          whereClause.years_experience = { [Op.lt]: 3 };
          break;
        case 'mid':
          whereClause.years_experience = { [Op.between]: [3, 7] };
          break;
        case 'senior':
          whereClause.years_experience = { [Op.gt]: 7 };
          break;
      }
    }

    let orderArray = [];
    switch (sort) {
      case 'experience':
        orderArray.push(['years_experience', order === 'asc' ? 'ASC' : 'DESC']);
        break;
      case 'rating':
        orderArray.push(['rating', order === 'asc' ? 'ASC' : 'DESC']);
        break;
      case 'sessions_count':
        orderArray.push([sequelize.literal('sessions_count'), order === 'asc' ? 'ASC' : 'DESC']);
        break;
      case 'approval_date':
        orderArray.push(['approval_date', order === 'asc' ? 'ASC' : 'DESC']);
        break;
      default:
        orderArray.push([{ model: User }, 'full_name', order === 'asc' ? 'ASC' : 'DESC']);
    }

    const { count, rows: specialists } = await Specialist.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: User,
          attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture', 'created_at'],
          where: userWhereClause
        }
      ],
      offset,
      limit: pageLimit,
      order: orderArray,
      distinct: true
    });

    const specialistsWithStats = await Promise.all(
      specialists.map(async (specialist) => {
        const specialistData = specialist.get({ plain: true });

        // Session statistics
        const sessionStats = await Session.findAll({
          where: { specialist_id: specialist.specialist_id },
          attributes: [
            'status',
            [sequelize.fn('COUNT', sequelize.col('session_id')), 'count']
          ],
          group: ['status'],
          raw: true
        });

        const totalSessions = sessionStats.reduce((sum, stat) => sum + parseInt(stat.count), 0);
        const completedSessions = sessionStats.find(stat => stat.status === 'Completed')?.count || 0;

        // Evaluation statistics
        const evaluationStats = await Evaluation.findOne({
          where: { specialist_id: specialist.specialist_id },
          attributes: [
            [sequelize.fn('COUNT', sequelize.col('evaluation_id')), 'total_evaluations'],
            [sequelize.fn('AVG', sequelize.col('progress_score')), 'avg_progress_score']
          ],
          raw: true
        });

        // Unique children count
        const uniqueChildren = await Session.count({
          where: { specialist_id: specialist.specialist_id },
          distinct: true,
          col: 'child_id'
        });

        // Upcoming sessions
        const upcomingSessions = await Session.count({
          where: {
            specialist_id: specialist.specialist_id,
            date: { [Op.gte]: new Date() },
            status: 'Scheduled'
          }
        });

        // Attendance rate (last 30 days)
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        
        const recentSessions = await Session.findAll({
          where: {
            specialist_id: specialist.specialist_id,
            date: { [Op.gte]: thirtyDaysAgo }
          },
          attributes: ['status']
        });

        const recentCompleted = recentSessions.filter(s => s.status === 'Completed').length;
        const attendanceRate = recentSessions.length > 0 ? 
          (recentCompleted / recentSessions.length) * 100 : 0;

        // Vacation requests
        const pendingVacations = await VacationRequest.count({
          where: {
            specialist_id: specialist.specialist_id,
            status: 'Pending'
          }
        });

        return {
          id: specialistData.specialist_id,
          personal_info: {
            name: specialistData.User.full_name,
            email: specialistData.User.email,
            phone: specialistData.User.phone,
            profile_picture: specialistData.User.profile_picture,
            join_date: specialistData.User.created_at
          },
          professional_info: {
            specialization: specialistData.specialization,
            years_experience: specialistData.years_experience,
            qualifications: specialistData.qualifications,
            bio: specialistData.bio,
            hourly_rate: specialistData.hourly_rate,
            rating: specialistData.rating
          },
          institutional_info: {
            approval_status: specialistData.approval_status,
            approval_date: specialistData.approval_date,
            notes: specialistData.manager_notes,
            is_active: specialistData.is_active
          },
          statistics: {
            sessions: {
              total: totalSessions,
              completed: parseInt(completedSessions),
              upcoming: upcomingSessions,
              completion_rate: totalSessions > 0 ? (completedSessions / totalSessions) * 100 : 0,
              by_status: sessionStats.reduce((acc, stat) => {
                acc[stat.status] = parseInt(stat.count);
                return acc;
              }, {})
            },
            evaluations: {
              total: parseInt(evaluationStats?.total_evaluations || 0),
              average_score: parseFloat(evaluationStats?.avg_progress_score || 0).toFixed(1)
            },
            children: {
              total_unique: uniqueChildren
            },
            performance: {
              attendance_rate: parseFloat(attendanceRate.toFixed(1)),
              overall_performance: calculateOverallPerformance(
                parseFloat(evaluationStats?.avg_progress_score || 0),
                attendanceRate,
                totalSessions
              )
            }
          },
          pending_actions: {
            vacation_requests: pendingVacations
          },
          created_at: specialistData.created_at,
          updated_at: specialistData.updated_at
        };
      })
    );

    // Get all available specializations for statistics
    const allSpecializations = await Specialist.findAll({
      where: { institution_id: institutionId },
      attributes: ['specialization'],
      group: ['specialization'],
      raw: true
    });

    res.status(200).json({
      success: true,
      data: specialistsWithStats,
      meta: {
        page: pageNum,
        limit: pageLimit,
        total: count,
        total_pages: Math.ceil(count / pageLimit),
        institution: {
          id: institutionId,
          name: manager.Institution.name
        },
        filters: {
          specializations: allSpecializations.map(s => s.specialization),
          total_specialists: count
        }
      }
    });

  } catch (error) {
    console.error('Error in getInstitutionSpecialists:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching specialists data',
      error: error.message
    });
  }
};

// ================= GET SPECIALIST DETAILS =================
exports.getSpecialistDetails = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { specialist_id } = req.params;

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
        message: 'Institution not found or manager not active'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const specialist = await Specialist.findOne({
      where: {
        specialist_id,
        institution_id: institutionId
      },
      include: [
        {
          model: User,
          attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture', 'created_at']
        }
      ]
    });

    if (!specialist) {
      return res.status(404).json({
        success: false,
        message: 'Specialist not found or does not belong to this institution'
      });
    }

    // Detailed statistics
    const detailedStats = await getSpecialistDetailedStats(specialist_id);

    // Recent sessions
    const recentSessions = await Session.findAll({
      where: { specialist_id },
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'full_name']
        },
        {
          model: SessionType,
          attributes: ['name', 'duration']
        }
      ],
      order: [['date', 'DESC'], ['time', 'DESC']],
      limit: 10
    });

    // Recent evaluations
    const recentEvaluations = await Evaluation.findAll({
      where: { specialist_id },
      include: [
        {
          model: Child,
          attributes: ['child_id', 'full_name']
        }
      ],
      order: [['created_at', 'DESC']],
      limit: 10
    });

    // Vacation requests
    const vacationRequests = await VacationRequest.findAll({
      where: { specialist_id },
      order: [['start_date', 'DESC']],
      limit: 5
    });

    // Work schedule
    const SpecialistSchedule = require('../../model/SpecialistSchedule');
    const schedule = await SpecialistSchedule.findAll({
      where: { specialist_id },
      order: [['day_of_week', 'ASC']]
    });

    res.status(200).json({
      success: true,
      data: {
        specialist: {
          id: specialist.specialist_id,
          personal_info: {
            name: specialist.User.full_name,
            email: specialist.User.email,
            phone: specialist.User.phone,
            profile_picture: specialist.User.profile_picture,
            join_date: specialist.User.created_at
          },
          professional_info: {
            specialization: specialist.specialization,
            years_experience: specialist.years_experience,
            qualifications: specialist.qualifications,
            bio: specialist.bio,
            hourly_rate: specialist.hourly_rate,
            rating: specialist.rating
          },
          institutional_info: {
            approval_status: specialist.approval_status,
            approval_date: specialist.approval_date,
            manager_notes: specialist.manager_notes,
            is_active: specialist.is_active,
            created_at: specialist.created_at
          }
        },
        detailed_statistics: detailedStats,
        recent_activity: {
          sessions: recentSessions,
          evaluations: recentEvaluations
        },
        schedule: schedule,
        vacation_requests: vacationRequests
      }
    });

  } catch (error) {
    console.error('Error in getSpecialistDetails:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching specialist details',
      error: error.message
    });
  }
};

// ================= UPDATE SPECIALIST STATUS =================
exports.updateSpecialistStatus = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { specialist_id } = req.params;
    const { approval_status, manager_notes, is_active } = req.body;

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
        message: 'Institution not found or manager not active'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const specialist = await Specialist.findOne({
      where: {
        specialist_id,
        institution_id: institutionId
      },
      include: [{
        model: User,
        attributes: ['user_id', 'full_name', 'email']
      }]
    });

    if (!specialist) {
      return res.status(404).json({
        success: false,
        message: 'Specialist not found'
      });
    }

    const updateData = {};
    if (approval_status) updateData.approval_status = approval_status;
    if (manager_notes !== undefined) updateData.manager_notes = manager_notes;
    if (is_active !== undefined) updateData.is_active = is_active;
    
    if (approval_status === 'Approved' && !specialist.approval_date) {
      updateData.approval_date = new Date();
    }

    await specialist.update(updateData);

    // Send notification to specialist
    const Notification = require('../../model/Notification');
    let notificationTitle = '';
    let notificationMessage = '';

    if (approval_status === 'Approved') {
      notificationTitle = 'Join request approved';
      notificationMessage = `Your request to join ${manager.Institution.name} has been approved. ${manager_notes ? `Manager notes: ${manager_notes}` : ''}`;
    } else if (approval_status === 'Rejected') {
      notificationTitle = 'Join request rejected';
      notificationMessage = `Your request to join ${manager.Institution.name} has been rejected. ${manager_notes ? `Reason: ${manager_notes}` : ''}`;
    } else if (is_active === false) {
      notificationTitle = 'Account suspended';
      notificationMessage = `Your account at ${manager.Institution.name} has been temporarily suspended. ${manager_notes ? `Reason: ${manager_notes}` : ''}`;
    }

    if (notificationTitle) {
      await Notification.create({
        user_id: specialist.specialist_id,
        title: notificationTitle,
        message: notificationMessage,
        type: 'specialist_status_update',
        related_id: specialist.specialist_id,
        is_read: false
      });
    }

    res.status(200).json({
      success: true,
      message: 'Specialist status updated successfully',
      data: {
        specialist_id: specialist.specialist_id,
        name: specialist.User.full_name,
        approval_status: specialist.approval_status,
        is_active: specialist.is_active,
        updated_at: new Date()
      }
    });

  } catch (error) {
    console.error('Error in updateSpecialistStatus:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating specialist status',
      error: error.message
    });
  }
};

// ================= GET SPECIALISTS STATISTICS =================
exports.getSpecialistsStatistics = async (req, res) => {
  try {
    const managerId = req.user.user_id;

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
        message: 'Institution not found or manager not active'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // Basic statistics using direct queries
    const totalSpecialists = await Specialist.count({
      where: { institution_id: institutionId }
    });

    const specialistsByStatus = await sequelize.query(`
      SELECT approval_status, COUNT(*) as count 
      FROM Specialists 
      WHERE institution_id = ? 
      GROUP BY approval_status
    `, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    const specialistsBySpecialization = await sequelize.query(`
      SELECT specialization, COUNT(*) as count 
      FROM Specialists 
      WHERE institution_id = ? 
      GROUP BY specialization
    `, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    // Session statistics using direct query
    const sessionStats = await sequelize.query(`
      SELECT 
        COUNT(s.session_id) as total_sessions,
        SUM(CASE WHEN s.status = 'Completed' THEN 1 ELSE 0 END) as completed_sessions,
        SUM(CASE WHEN s.status = 'Cancelled' THEN 1 ELSE 0 END) as cancelled_sessions
      FROM Sessions s
      INNER JOIN Specialists sp ON s.specialist_id = sp.specialist_id
      WHERE s.institution_id = ? AND sp.institution_id = ?
    `, {
      replacements: [institutionId, institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    // Evaluation statistics using direct query
    const evaluationStats = await sequelize.query(`
      SELECT 
        COUNT(e.evaluation_id) as total_evaluations,
        AVG(e.progress_score) as avg_progress_score
      FROM Evaluations e
      INNER JOIN Specialists sp ON e.specialist_id = sp.specialist_id
      WHERE sp.institution_id = ?
    `, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    // Most active specialists using direct query
    const topActiveSpecialists = await sequelize.query(`
      SELECT 
        s.specialist_id,
        COUNT(s.session_id) as session_count,
        sp.specialization,
        u.full_name
      FROM Sessions s
      INNER JOIN Specialists sp ON s.specialist_id = sp.specialist_id
      INNER JOIN Users u ON sp.specialist_id = u.user_id
      WHERE s.institution_id = ? 
        AND s.date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
      GROUP BY s.specialist_id, sp.specialization, u.full_name
      ORDER BY session_count DESC
      LIMIT 5
    `, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    // Pending vacation requests using direct query
    const pendingVacations = await sequelize.query(`
      SELECT COUNT(*) as count
      FROM VacationRequests vr
      INNER JOIN Specialists sp ON vr.specialist_id = sp.specialist_id
      WHERE sp.institution_id = ? AND vr.status = 'Pending'
    `, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    // Monthly statistics
    const monthlyTrends = await sequelize.query(`
      SELECT 
        DATE_FORMAT(date, '%Y-%m') as month,
        COUNT(session_id) as total_sessions,
        COUNT(DISTINCT specialist_id) as active_specialists
      FROM Sessions
      WHERE institution_id = ? AND date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(date, '%Y-%m')
      ORDER BY month ASC
    `, {
      replacements: [institutionId],
      type: sequelize.QueryTypes.SELECT
    });

    // Calculate average scores for active specialists
    const topPerformersWithScores = await Promise.all(
      topActiveSpecialists.map(async (specialist) => {
        const avgScoreResult = await sequelize.query(`
          SELECT AVG(progress_score) as avg_score
          FROM Evaluations
          WHERE specialist_id = ?
        `, {
          replacements: [specialist.specialist_id],
          type: sequelize.QueryTypes.SELECT
        });

        return {
          specialist_id: specialist.specialist_id,
          name: specialist.full_name,
          specialization: specialist.specialization,
          session_count: parseInt(specialist.session_count),
          avg_score: avgScoreResult[0]?.avg_score ? 
            parseFloat(avgScoreResult[0].avg_score).toFixed(1) : '0.0'
        };
      })
    );

    res.status(200).json({
      success: true,
      data: {
        institution: {
          id: institutionId,
          name: manager.Institution.name
        },
        overview: {
          total_specialists: totalSpecialists,
          by_approval_status: specialistsByStatus.reduce((acc, item) => {
            acc[item.approval_status] = parseInt(item.count);
            return acc;
          }, {}),
          by_specialization: specialistsBySpecialization.reduce((acc, item) => {
            acc[item.specialization] = parseInt(item.count);
            return acc;
          }, {}),
          active_this_month: sessionStats[0] ? parseInt(sessionStats[0].total_sessions) : 0
        },
        performance: {
          sessions: {
            total: sessionStats[0] ? parseInt(sessionStats[0].total_sessions) : 0,
            completed: sessionStats[0] ? parseInt(sessionStats[0].completed_sessions) : 0,
            cancelled: sessionStats[0] ? parseInt(sessionStats[0].cancelled_sessions) : 0,
            completion_rate: sessionStats[0] && parseInt(sessionStats[0].total_sessions) > 0 ? 
              (parseInt(sessionStats[0].completed_sessions) / parseInt(sessionStats[0].total_sessions) * 100).toFixed(1) : 0
          },
          evaluations: {
            total: evaluationStats[0] ? parseInt(evaluationStats[0].total_evaluations) : 0,
            average_score: evaluationStats[0] ? 
              parseFloat(evaluationStats[0].avg_progress_score || 0).toFixed(1) : '0.0'
          }
        },
        top_performers: topPerformersWithScores,
        pending_actions: {
          vacation_requests: pendingVacations[0] ? parseInt(pendingVacations[0].count) : 0
        },
        monthly_trends: monthlyTrends
      }
    });

  } catch (error) {
    console.error('Error in getSpecialistsStatistics:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching specialists statistics',
      error: error.message
    });
  }
};

// ================= GET SPECIALIST PERFORMANCE REPORT =================
exports.getSpecialistPerformanceReport = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { specialist_id } = req.params;
    const { start_date, end_date } = req.query;

    console.log('getSpecialistPerformanceReport called with:', {
      managerId,
      specialist_id,
      start_date,
      end_date
    });

    // Validate specialist_id
    if (!specialist_id) {
      return res.status(400).json({
        success: false,
        message: 'Specialist ID is required'
      });
    }

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
        message: 'Institution not found or manager not active'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const specialist = await Specialist.findOne({
      where: {
        specialist_id,
        institution_id: institutionId
      },
      include: [{
        model: User,
        attributes: ['full_name', 'email']
      }]
    });

    if (!specialist) {
      return res.status(404).json({
        success: false,
        message: 'Specialist not found'
      });
    }

    // Build dateFilter safely
    const dateFilter = {};
    
    if (start_date && end_date) {
      // Validate dates
      const startDate = new Date(start_date);
      const endDate = new Date(end_date);
      
      if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
        return res.status(400).json({
          success: false,
          message: 'Invalid date format'
        });
      }
      
      dateFilter.date = {
        [Op.between]: [startDate, endDate]
      };
    } else {
      // Use default range (last 30 days)
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      
      dateFilter.date = {
        [Op.gte]: thirtyDaysAgo
      };
    }

    console.log('Final date filter:', dateFilter);

    // Detailed report
    const performanceReport = await generatePerformanceReport(specialist_id, dateFilter);

    // Calculate number of days in the period
    let days = 30; // default
    if (start_date && end_date) {
      const start = new Date(start_date);
      const end = new Date(end_date);
      days = Math.round((end - start) / (1000 * 60 * 60 * 24)) + 1; // +1 to include first day
    }

    res.status(200).json({
      success: true,
      data: {
        specialist: {
          id: specialist.specialist_id,
          name: specialist.User.full_name,
          specialization: specialist.specialization,
          experience: specialist.years_experience
        },
        report_period: {
          start_date: start_date || new Date(new Date().setDate(new Date().getDate() - 30)).toISOString().split('T')[0],
          end_date: end_date || new Date().toISOString().split('T')[0],
          days: days
        },
        performance_report: performanceReport
      }
    });

  } catch (error) {
    console.error('Error in getSpecialistPerformanceReport:', error);
    res.status(500).json({
      success: false,
      message: 'Error generating performance report',
      error: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
};

// ================= HELPER FUNCTIONS =================

const calculateOverallPerformance = (avgScore, attendanceRate, totalSessions) => {
  if (totalSessions === 0) return 'Not specified';
  
  const score = (avgScore * 0.6) + (attendanceRate * 0.4);
  
  if (score >= 85) return 'Excellent';
  if (score >= 70) return 'Very Good';
  if (score >= 60) return 'Good';
  if (score >= 50) return 'Acceptable';
  return 'Needs Improvement';
};

const getSpecialistDetailedStats = async (specialistId) => {
  // Monthly session statistics
  const monthlySessions = await Session.findAll({
    where: { 
      specialist_id: specialistId,
      date: { [Op.gte]: new Date(new Date().setMonth(new Date().getMonth() - 6)) }
    },
    attributes: [
      [sequelize.fn('DATE_FORMAT', sequelize.col('date'), '%Y-%m'), 'month'],
      [sequelize.fn('COUNT', sequelize.col('session_id')), 'session_count'],
      [sequelize.fn('SUM', sequelize.literal("CASE WHEN status = 'Completed' THEN 1 ELSE 0 END")), 'completed_count']
    ],
    group: ['month'],
    order: [['month', 'ASC']],
    raw: true
  });

  // Session types distribution
  const sessionTypesDistribution = await Session.findAll({
    where: { specialist_id: specialistId },
    include: [{
      model: SessionType,
      attributes: ['name']
    }],
    attributes: [
      'session_type_id',
      [sequelize.fn('COUNT', sequelize.col('session_id')), 'count']
    ],
    group: ['session_type_id'],
    raw: true
  });

  // Children progress
  const childrenProgress = await Evaluation.findAll({
    where: { specialist_id: specialistId },
    attributes: [
      'child_id',
      [sequelize.fn('AVG', sequelize.col('progress_score')), 'avg_score'],
      [sequelize.fn('COUNT', sequelize.col('evaluation_id')), 'evaluation_count']
    ],
    include: [{
      model: Child,
      attributes: ['full_name']
    }],
    group: ['child_id'],
    having: sequelize.where(sequelize.fn('COUNT', sequelize.col('evaluation_id')), '>=', 2),
    raw: true
  });

  return {
    monthly_trend: monthlySessions,
    session_types: sessionTypesDistribution,
    children_progress: childrenProgress,
    performance_metrics: await calculatePerformanceMetrics(specialistId)
  };
};

const calculatePerformanceMetrics = async (specialistId) => {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const recentSessions = await Session.count({
    where: {
      specialist_id: specialistId,
      date: { [Op.gte]: thirtyDaysAgo }
    }
  });

  const completedSessions = await Session.count({
    where: {
      specialist_id: specialistId,
      date: { [Op.gte]: thirtyDaysAgo },
      status: 'Completed'
    }
  });

  const avgSessionDuration = await Session.findOne({
    where: { specialist_id: specialistId },
    include: [{
      model: SessionType,
      attributes: ['duration']
    }],
    attributes: [
      [sequelize.fn('AVG', sequelize.col('SessionType.duration')), 'avg_duration']
    ],
    raw: true
  });

  const clientSatisfaction = await Evaluation.findOne({
    where: { specialist_id: specialistId },
    attributes: [
      [sequelize.fn('AVG', sequelize.col('progress_score')), 'avg_progress']
    ],
    raw: true
  });

  return {
    productivity: {
      sessions_per_month: recentSessions,
      completion_rate: recentSessions > 0 ? (completedSessions / recentSessions) * 100 : 0
    },
    efficiency: {
      avg_session_duration: avgSessionDuration?.avg_duration || 0,
      clients_per_month: await Session.count({
        where: {
          specialist_id: specialistId,
          date: { [Op.gte]: thirtyDaysAgo }
        },
        distinct: true,
        col: 'child_id'
      })
    },
    quality: {
      avg_progress_score: clientSatisfaction?.avg_progress || 0,
      consistency_score: await calculateConsistencyScore(specialistId)
    }
  };
};

const calculateConsistencyScore = async (specialistId) => {
  const evaluations = await Evaluation.findAll({
    where: { specialist_id: specialistId },
    attributes: ['progress_score'],
    raw: true
  });

  if (evaluations.length < 2) return 100;

  const scores = evaluations.map(e => e.progress_score).filter(score => score != null);
  const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
  const variance = scores.reduce((a, b) => a + Math.pow(b - avg, 2), 0) / scores.length;
  
  return Math.max(0, 100 - (Math.sqrt(variance) * 2));
};

const getTopPerformersDetails = async (topSpecialists) => {
  const details = await Promise.all(
    topSpecialists.map(async (specialist) => {
      const spec = await Specialist.findByPk(specialist.specialist_id, {
        include: [{
          model: User,
          attributes: ['full_name']
        }]
      });

      const avgScore = await Evaluation.findOne({
        where: { specialist_id: specialist.specialist_id },
        attributes: [
          [sequelize.fn('AVG', sequelize.col('progress_score')), 'avg_score']
        ],
        raw: true
      });

      return {
        specialist_id: specialist.specialist_id,
        name: spec.User.full_name,
        specialization: spec.specialization,
        session_count: parseInt(specialist.session_count),
        avg_score: parseFloat(avgScore?.avg_score || 0).toFixed(1)
      };
    })
  );

  return details;
};

const getMonthlyTrends = async (institutionId) => {
  const sixMonthsAgo = new Date();
  sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

  const monthlyStats = await Session.findAll({
    where: { 
      institution_id: institutionId,
      date: { [Op.gte]: sixMonthsAgo }
    },
    attributes: [
      [sequelize.fn('DATE_FORMAT', sequelize.col('date'), '%Y-%m'), 'month'],
      [sequelize.fn('COUNT', sequelize.col('session_id')), 'total_sessions'],
      [sequelize.fn('COUNT', sequelize.fn('DISTINCT', sequelize.col('specialist_id'))), 'active_specialists']
    ],
    group: ['month'],
    order: [['month', 'ASC']],
    raw: true
  });

  return monthlyStats;
};

const generatePerformanceReport = async (specialistId, dateFilter) => {
  try {
    console.log('Starting generatePerformanceReport for specialist:', specialistId);
    console.log('Date filter:', dateFilter);

    // Build session where clause safely
    const sessionWhereClause = {
      specialist_id: specialistId
    };

    // Build evaluation where clause safely
    const evaluationWhereClause = {
      specialist_id: specialistId
    };

    // Process dateFilter for sessions
    if (dateFilter.date) {
      if (dateFilter.date[Op.between]) {
        sessionWhereClause.date = {
          [Op.between]: dateFilter.date[Op.between]
        };
        
        // Use same time range for evaluations
        evaluationWhereClause.created_at = {
          [Op.between]: dateFilter.date[Op.between]
        };
      } else if (dateFilter.date[Op.gte]) {
        sessionWhereClause.date = {
          [Op.gte]: dateFilter.date[Op.gte]
        };
        
        evaluationWhereClause.created_at = {
          [Op.gte]: dateFilter.date[Op.gte]
        };
      }
    } else {
      // Use default range (last 30 days)
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
      
      sessionWhereClause.date = {
        [Op.gte]: thirtyDaysAgo
      };
      
      evaluationWhereClause.created_at = {
        [Op.gte]: thirtyDaysAgo
      };
    }

    console.log('Session where clause:', sessionWhereClause);
    console.log('Evaluation where clause:', evaluationWhereClause);

    // Sessions in the specified period
    const sessions = await Session.findAll({
      where: sessionWhereClause,
      include: [
        {
          model: SessionType,
          attributes: ['name', 'duration', 'price']
        },
        {
          model: Child,
          as: 'child',
          attributes: ['full_name']
        }
      ]
    });

    console.log(`Found ${sessions.length} sessions`);

    // Evaluations in the specified period
    const evaluations = await Evaluation.findAll({
      where: evaluationWhereClause,
      include: [{
        model: Child,
        attributes: ['full_name']
      }]
    });

    console.log(`Found ${evaluations.length} evaluations`);

    // Performance analysis - with handling of undefined values
    const totalSessions = sessions.length;
    const completedSessions = sessions.filter(s => s.status === 'Completed').length;
    
    // Calculate revenue with SessionType check
    const totalRevenue = sessions
      .filter(s => s.status === 'Completed')
      .reduce((sum, session) => {
        const sessionPrice = session.SessionType?.price || 0;
        return sum + sessionPrice;
      }, 0);

    // Calculate average evaluations
    const validEvaluations = evaluations.filter(e => e.progress_score != null);
    const avgEvaluationScore = validEvaluations.length > 0 ?
      validEvaluations.reduce((sum, evaluation) => sum + evaluation.progress_score, 0) / validEvaluations.length : 0;

    // Session types distribution
    const sessionTypeAnalysis = sessions.reduce((acc, session) => {
      const typeName = session.SessionType?.name || 'Not specified';
      if (!acc[typeName]) {
        acc[typeName] = { count: 0, revenue: 0 };
      }
      acc[typeName].count++;
      if (session.status === 'Completed') {
        const sessionPrice = session.SessionType?.price || 0;
        acc[typeName].revenue += sessionPrice;
      }
      return acc;
    }, {});

    // Children progress analysis
    const childProgressAnalysis = evaluations.reduce((acc, evaluation) => {
      const childName = evaluation.Child?.full_name || 'Unknown';
      if (!acc[childName]) {
        acc[childName] = { evaluations: [], avgScore: 0 };
      }
      if (evaluation.progress_score != null) {
        acc[childName].evaluations.push(evaluation.progress_score);
        acc[childName].avgScore = acc[childName].evaluations.length > 0 ? 
          acc[childName].evaluations.reduce((sum, score) => sum + score, 0) / acc[childName].evaluations.length : 0;
      }
      return acc;
    }, {});

    // Calculate performance rates
    const completionRate = totalSessions > 0 ? (completedSessions / totalSessions) * 100 : 0;
    const revenuePerSession = totalSessions > 0 ? totalRevenue / totalSessions : 0;

    // Calculate performance indicators
    const consistencyScore = await calculateConsistencyScore(specialistId);
    const improvementTrend = calculateImprovementTrend(evaluations);
    const retentionRate = calculateRetentionRate(sessions);

    console.log('Performance metrics calculated successfully');

    return {
      summary: {
        total_sessions: totalSessions,
        completed_sessions: completedSessions,
        completion_rate: parseFloat(completionRate.toFixed(1)),
        total_revenue: parseFloat(totalRevenue.toFixed(2)),
        average_session_score: parseFloat(avgEvaluationScore.toFixed(1)),
        unique_children: new Set(sessions.map(s => s.child_id).filter(id => id != null)).size
      },
      session_analysis: {
        by_type: sessionTypeAnalysis,
        by_status: sessions.reduce((acc, session) => {
          const status = session.status || 'Not specified';
          acc[status] = (acc[status] || 0) + 1;
          return acc;
        }, {}),
        revenue_breakdown: Object.entries(sessionTypeAnalysis).map(([type, data]) => ({
          type,
          sessions: data.count,
          revenue: parseFloat(data.revenue.toFixed(2))
        }))
      },
      performance_indicators: {
        productivity: {
          sessions_per_week: parseFloat((totalSessions / 4).toFixed(1)),
          avg_sessions_per_day: parseFloat((totalSessions / 30).toFixed(1))
        },
        quality: {
          score_consistency: consistencyScore,
          improvement_trend: improvementTrend
        },
        efficiency: {
          revenue_per_session: parseFloat(revenuePerSession.toFixed(2)),
          client_retention_rate: retentionRate
        }
      },
      children_progress: childProgressAnalysis,
      recommendations: generatePerformanceRecommendations(
        totalSessions,
        completedSessions,
        avgEvaluationScore,
        sessionTypeAnalysis
      )
    };
  } catch (error) {
    console.error('Error in generatePerformanceReport:', error);
    throw new Error('Failed to generate performance report: ' + error.message);
  }
};

const calculateImprovementTrend = (evaluations) => {
  if (evaluations.length < 2) return 'Not specified';
  
  // Filter evaluations with valid scores
  const validEvaluations = evaluations
    .filter(e => e.progress_score != null && e.created_at)
    .sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  
  if (validEvaluations.length < 2) return 'Not specified';
  
  const firstScore = validEvaluations[0].progress_score;
  const lastScore = validEvaluations[validEvaluations.length - 1].progress_score;
  
  if (lastScore > firstScore + 5) return 'Advanced';
  if (lastScore > firstScore) return 'Improved';
  if (lastScore === firstScore) return 'Stable';
  return 'Declined';
};

const calculateRetentionRate = (sessions) => {
  try {
    const childSessions = sessions.reduce((acc, session) => {
      if (session.child_id == null) return acc;
      
      if (!acc[session.child_id]) {
        acc[session.child_id] = new Set();
      }
      acc[session.child_id].add(session.session_id);
      return acc;
    }, {});

    const multiSessionChildren = Object.values(childSessions).filter(sessions => sessions.size > 1).length;
    const totalChildren = Object.keys(childSessions).length;

    return totalChildren > 0 ? parseFloat((multiSessionChildren / totalChildren) * 100).toFixed(1) : 0;
  } catch (error) {
    console.error('Error in calculateRetentionRate:', error);
    return 0;
  }
};

const generatePerformanceRecommendations = (totalSessions, completedSessions, avgScore, sessionTypes) => {
  const recommendations = [];
  const completionRate = totalSessions > 0 ? (completedSessions / totalSessions) * 100 : 0;

  if (completionRate < 80) {
    recommendations.push('Improve session completion rate - Focus on follow-up with parents');
  }

  if (avgScore < 70) {
    recommendations.push('Improve evaluation quality - Review treatment methods used');
  }

  const mostUsedType = Object.entries(sessionTypes).sort((a, b) => b[1].count - a[1].count)[0];
  if (mostUsedType && mostUsedType[1].count > totalSessions * 0.7) {
    recommendations.push('Diversify session types - Develop skills in other specializations');
  }

  if (totalSessions < 20) {
    recommendations.push('Increase number of sessions - Work on attracting more clients');
  }

  return recommendations.length > 0 ? recommendations : ['Excellent performance - Continue current approach'];
};

module.exports = exports;