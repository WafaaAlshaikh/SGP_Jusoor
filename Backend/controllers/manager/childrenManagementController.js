const { 
  Child, 
  Session, 
  ChildRegistrationRequest, 
  Evaluation,
  Parent,
  Diagnosis,
  Institution,
  Manager,
  User,
  Specialist, // تأكد من إضافته
  SessionType
} = require('../../model/index');
const { Op } = require('sequelize');
const sequelize = require('../../config/db');

// دالة مساعدة لتنسيق التاريخ
const formatDate = (date) => {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
};




// الحصول على معلومات مفصلة عن طفل معين
exports.getChildDetailedInfo = async (req, res) => {
  console.log('=== START getChildDetailedInfo ===');
  
  try {
    const managerId = req.user.user_id;
    const { childId } = req.params;
    
    console.log('1. Manager ID:', managerId, 'Child ID:', childId);
    
    if (!childId) {
      return res.status(400).json({
        success: false,
        message: 'Child ID is required'
      });
    }

    // الحصول على معلومات المدير والمؤسسة
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
      console.log('❌ ERROR: Manager or institution not found');
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const institutionId = manager.Institution.institution_id;
    console.log('2. Institution ID:', institutionId);

    // 1. الحصول على معلومات الطفل الأساسية
    console.log('3. Fetching child basic info...');
    const child = await Child.findOne({
      where: {
        child_id: childId,
        current_institution_id: institutionId
      },
      include: [
        {
          model: Parent,
          include: [{
            model: User,
            attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture', 'city', 'region']
          }]
        },
        {
          model: Diagnosis,
          as: 'Diagnosis',
          attributes: ['diagnosis_id', 'name', 'description']
        },
        {
          model: Institution,
          as: 'currentInstitution',
          attributes: ['institution_id', 'name', 'location_address', 'contact_phone', 'contact_email']
        }
      ]
    });

    if (!child) {
      console.log('❌ ERROR: Child not found');
      return res.status(404).json({
        success: false,
        message: 'Child not found in your institution'
      });
    }

    console.log('4. Child found:', child.full_name);

    // 2. الحصول على جميع الجلسات للطفل
    console.log('5. Fetching all sessions for child...');
    const sessions = await Session.findAll({
      where: {
        child_id: childId,
        institution_id: institutionId
      },
      include: [
        {
          model: User,
          as: 'specialist',
          attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture']
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'duration', 'category', 'specialist_specialization']
        },
        {
          model: Institution,
          as: 'institution',
          attributes: ['name', 'location_address', 'contact_phone']
        }
      ],
      order: [['date', 'DESC'], ['time', 'DESC']]
    });

    console.log(`6. Found ${sessions.length} sessions`);

    // 3. الحصول على جميع التقييمات للطفل
    console.log('7. Fetching all evaluations for child...');
    const evaluations = await Evaluation.findAll({
      where: {
        child_id: childId
      },
      include: [
        {
          model: User,
          as: 'specialistUser',
          attributes: ['full_name', 'email', 'phone']
        }
      ],
      order: [['created_at', 'DESC']]
    });

    console.log(`8. Found ${evaluations.length} evaluations`);

    // 4. الحصول على الأخصائيين الذين عملوا مع الطفل
    console.log('9. Fetching specialists who worked with child...');
    const specialistIds = [...new Set(sessions.map(s => s.specialist_id))];
    const specialists = await User.findAll({
      where: {
        user_id: specialistIds,
        institution_id: institutionId,
        role: 'Specialist'
      },
      include: [{
        model: Specialist,
        attributes: ['specialization', 'years_experience', 'approval_status']
      }],
      attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture']
    });

    console.log(`10. Found ${specialists.length} specialists`);

    // 5. الحصول على آخر تقدم (آخر تقييم)
    console.log('11. Getting latest progress...');
    const latestEvaluation = evaluations.length > 0 ? evaluations[0] : null;
    const latestProgress = latestEvaluation ? {
      score: latestEvaluation.progress_score,
      date: latestEvaluation.created_at,
      type: latestEvaluation.evaluation_type,
      notes: latestEvaluation.notes,
      evaluated_by: latestEvaluation.specialistUser?.full_name
    } : null;

    // 6. تحليل الجلسات بشكل أفضل
    console.log('12. Analyzing sessions with better logic...');
    const now = new Date();
    
    // تصنيف الجلسات بشكل أدق
    const sessionCategories = {
      completed: [],
      upcoming: [],
      past_but_not_completed: [],
      cancelled: [],
      ongoing: []
    };

    sessions.forEach(session => {
      const sessionDateTime = new Date(session.date + ' ' + session.time);
      const sessionEndTime = new Date(sessionDateTime);
      // إضافة مدة الجلسة (افترض أن duration بالدقائق)
      const duration = session.SessionType?.duration || 60;
      sessionEndTime.setMinutes(sessionEndTime.getMinutes() + duration);

      if (session.status === 'Completed') {
        sessionCategories.completed.push(session);
      } else if (session.status === 'Cancelled' || session.status === 'Rejected') {
        sessionCategories.cancelled.push(session);
      } else if (sessionDateTime > now) {
        sessionCategories.upcoming.push(session);
      } else if (sessionDateTime <= now && sessionEndTime > now && session.status !== 'Completed') {
        sessionCategories.ongoing.push(session);
      } else if (sessionEndTime <= now && session.status !== 'Completed') {
        sessionCategories.past_but_not_completed.push(session);
      }
    });

    // تحليل الجلسات حسب الحالة
    const sessionAnalysis = {
      total: sessions.length,
      by_status: sessions.reduce((acc, session) => {
        acc[session.status] = (acc[session.status] || 0) + 1;
        return acc;
      }, {}),
      by_category: sessions.reduce((acc, session) => {
        const category = session.SessionType?.category || 'Unknown';
        acc[category] = (acc[category] || 0) + 1;
        return acc;
      }, {}),
      completed_sessions: sessionCategories.completed.length,
      upcoming_sessions: sessionCategories.upcoming.length,
      cancelled_sessions: sessionCategories.cancelled.length,
      ongoing_sessions: sessionCategories.ongoing.length,
      missed_sessions: sessionCategories.past_but_not_completed.length,
      // جلسات انتهى وقتها بالفعل (مكتملة أو مفوتهة أو ملغية)
      total_past_sessions: sessionCategories.completed.length + 
                          sessionCategories.past_but_not_completed.length + 
                          sessionCategories.cancelled.length
    };

    // 7. إحصائيات التقييمات
    console.log('13. Analyzing evaluations...');
    const evaluationStats = {
      total: evaluations.length,
      by_type: evaluations.reduce((acc, evalu) => {
        acc[evalu.evaluation_type] = (acc[evalu.evaluation_type] || 0) + 1;
        return acc;
      }, {}),
      average_score: evaluations.length > 0 
        ? evaluations.reduce((sum, evalu) => sum + (evalu.progress_score || 0), 0) / evaluations.length
        : null,
      progress_trend: evaluations.map(evalu => ({
        date: evalu.created_at,
        score: evalu.progress_score,
        type: evalu.evaluation_type
      })).sort((a, b) => new Date(a.date) - new Date(b.date))
    };

    // 8. جلسات الأسبوع الحالي
    console.log('14. Getting this week sessions...');
    const today = new Date();
    const startOfWeek = new Date(today);
    startOfWeek.setDate(today.getDate() - today.getDay());
    startOfWeek.setHours(0, 0, 0, 0);

    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);
    endOfWeek.setHours(23, 59, 59, 999);

    const thisWeekSessions = sessions.filter(session => {
      const sessionDate = new Date(session.date);
      return sessionDate >= startOfWeek && sessionDate <= endOfWeek;
    });

    // 9. الجلسات القادمة (الشهر القادم)
    console.log('15. Getting upcoming sessions...');
    const nextMonth = new Date();
    nextMonth.setMonth(nextMonth.getMonth() + 1);
    
    const upcomingSessions = sessions
      .filter(session => {
        const sessionDate = new Date(session.date + ' ' + session.time);
        return sessionDate > now && 
               sessionDate <= nextMonth &&
               !['Cancelled', 'Rejected'].includes(session.status);
      })
      .sort((a, b) => {
        const dateA = new Date(a.date + ' ' + a.time);
        const dateB = new Date(b.date + ' ' + b.time);
        return dateA - dateB;
      })
      .slice(0, 5); // أول 5 جلسات قادمة

    // 10. معلومات إضافية عن الطفل
    console.log('16. Preparing additional child info...');
    const childInfo = {
      basic_info: {
        child_id: child.child_id,
        full_name: child.full_name,
        date_of_birth: child.date_of_birth,
        gender: child.gender,
        child_identifier: child.child_identifier,
        registration_status: child.registration_status,
        registration_date: child.created_at,
        last_updated: child.updated_at
      },
      medical_info: {
        diagnosis: child.Diagnosis,
        suspected_condition: child.suspected_condition,
        symptoms_description: child.symptoms_description,
        medical_history: child.medical_history,
        risk_level: child.risk_level,
        ai_confidence_score: child.ai_confidence_score
      },
      personal_info: {
        city: child.city,
        address: child.address,
        school_info: child.school_info,
        previous_services: child.previous_services,
        additional_notes: child.additional_notes
      },
      institution_info: {
        current_institution: {
          id: child.currentInstitution?.institution_id,
          name: child.currentInstitution?.name,
          address: child.currentInstitution?.location_address,
          phone: child.currentInstitution?.contact_phone,
          email: child.currentInstitution?.contact_email
        },
        enrollment_date: child.created_at
      }
    };

    // 11. معلومات الأهل
    console.log('17. Preparing parent info...');
    const parentInfo = child.Parent ? {
      parent_id: child.Parent.parent_id,
      user_info: child.Parent.User,
      address: child.Parent.address,
      occupation: child.Parent.occupation,
      contact: {
        phone: child.parent_phone || child.Parent.User.phone,
        email: child.Parent.User.email
      }
    } : null;

    // 12. حساب نسبة الحضور الصحيحة
    console.log('18. Calculating attendance rate correctly...');
    let attendanceRate = '0%';
    let attendancePercentage = 0;
    
    if (sessionAnalysis.total_past_sessions > 0) {
      // نسبة الحضور = (الجلسات المكتملة) ÷ (إجمالي الجلسات الماضية - الملغية)
      const validPastSessions = sessionAnalysis.total_past_sessions - sessionAnalysis.cancelled_sessions;
      if (validPastSessions > 0) {
        attendancePercentage = (sessionAnalysis.completed_sessions / validPastSessions) * 100;
        attendanceRate = attendancePercentage.toFixed(2) + '%';
      }
    }

    // 13. جلسات الأسبوع الماضي للأداء
    console.log('19. Getting last week sessions for performance...');
    const lastWeekStart = new Date(today);
    lastWeekStart.setDate(today.getDate() - 7);
    lastWeekStart.setHours(0, 0, 0, 0);
    
    const lastWeekEnd = new Date(today);
    lastWeekEnd.setDate(today.getDate() - 1);
    lastWeekEnd.setHours(23, 59, 59, 999);

    const lastWeekSessions = sessions.filter(session => {
      const sessionDate = new Date(session.date);
      return sessionDate >= lastWeekStart && sessionDate <= lastWeekEnd;
    });

    const lastWeekCompleted = lastWeekSessions.filter(s => s.status === 'Completed').length;
    const lastWeekTotal = lastWeekSessions.filter(s => !['Cancelled', 'Rejected'].includes(s.status)).length;
    const lastWeekAttendance = lastWeekTotal > 0 ? (lastWeekCompleted / lastWeekTotal * 100).toFixed(2) + '%' : '0%';

    // إعداد الرد النهائي
    console.log('20. Preparing final response...');
    const response = {
      success: true,
      data: {
        child: childInfo,
        parents: parentInfo,
        sessions: {
          summary: sessionAnalysis,
          categories: {
            completed: sessionCategories.completed.length,
            upcoming: sessionCategories.upcoming.length,
            cancelled: sessionCategories.cancelled.length,
            ongoing: sessionCategories.ongoing.length,
            missed: sessionCategories.past_but_not_completed.length
          },
          all_sessions: sessions.map(session => ({
            session_id: session.session_id,
            date: session.date,
            time: session.time,
            status: session.status,
            session_type: session.session_type,
            specialist: session.specialist ? {
              id: session.specialist.user_id,
              name: session.specialist.full_name,
              specialization: session.SessionType?.specialist_specialization
            } : null,
            session_details: session.SessionType ? {
              name: session.SessionType.name,
              category: session.SessionType.category,
              duration: session.SessionType.duration
            } : null,
            institution_info: session.institution ? {
              name: session.institution.name,
              address: session.institution.location_address,
              phone: session.institution.contact_phone
            } : null,
            notes: session.parent_notes || session.manager_notes,
            is_paid: session.is_paid,
            payment_status: session.payment_status,
            is_past: new Date(session.date + ' ' + session.time) < now
          })),
          this_week: thisWeekSessions.map(s => ({
            date: s.date,
            time: s.time,
            status: s.status,
            specialist: s.specialist?.full_name,
            session_type: s.SessionType?.name
          })),
          upcoming: upcomingSessions.map(s => ({
            date: s.date,
            time: s.time,
            specialist: s.specialist?.full_name,
            session_type: s.SessionType?.name,
            status: s.status
          }))
        },
        specialists: specialists.map(spec => ({
          specialist_id: spec.user_id,
          full_name: spec.full_name,
          specialization: spec.Specialist?.specialization,
          years_experience: spec.Specialist?.years_experience,
          contact: {
            email: spec.email,
            phone: spec.phone
          },
          profile_picture: spec.profile_picture
        })),
        evaluations: {
          summary: evaluationStats,
          all_evaluations: evaluations.map(evalu => ({
            evaluation_id: evalu.evaluation_id,
            date: evalu.created_at,
            type: evalu.evaluation_type,
            progress_score: evalu.progress_score,
            evaluated_by: evalu.specialistUser?.full_name,
            notes: evalu.notes,
            attachment: evalu.attachment,
            ai_analysis: evalu.ai_analysis
          })),
          latest_progress: latestProgress
        },
        statistics: {
          // إحصائيات الجلسات
          total_sessions: sessions.length,
          completed_sessions: sessionAnalysis.completed_sessions,
          upcoming_sessions: sessionAnalysis.upcoming_sessions,
          cancelled_sessions: sessionAnalysis.cancelled_sessions,
          missed_sessions: sessionAnalysis.missed_sessions,
          ongoing_sessions: sessionAnalysis.ongoing_sessions,
          
          // إحصائيات الحضور
          attendance_rate: attendanceRate,
          attendance_percentage: attendancePercentage,
          last_week_attendance: lastWeekAttendance,
          total_past_sessions: sessionAnalysis.total_past_sessions,
          valid_past_sessions: sessionAnalysis.total_past_sessions - sessionAnalysis.cancelled_sessions,
          
          // إحصائيات التقييمات
          total_evaluations: evaluations.length,
          average_progress_score: evaluationStats.average_score,
          
          // نسبة نجاح الحضور
          attendance_breakdown: {
            completed: sessionAnalysis.completed_sessions,
            missed: sessionAnalysis.missed_sessions,
            cancelled: sessionAnalysis.cancelled_sessions,
            total_expected: sessionAnalysis.total_past_sessions - sessionAnalysis.cancelled_sessions
          }
        },
        performance: {
          // أداء الأسبوع الماضي
          last_week: {
            total_sessions: lastWeekTotal,
            completed: lastWeekCompleted,
            attendance_rate: lastWeekAttendance
          },
          // نسب حسب نوع الجلسة
          by_session_type: Object.entries(sessionAnalysis.by_category || {}).map(([category, count]) => ({
            category,
            count,
            percentage: ((count / sessions.length) * 100).toFixed(1) + '%'
          }))
        }
      }
    };

    console.log('21. Sending response...');
    console.log('=== END getChildDetailedInfo ===');
    
    res.status(200).json(response);

  } catch (error) {
    console.error('❌ ERROR in getChildDetailedInfo:', error);
    console.error('Stack trace:', error.stack);
    
    res.status(500).json({
      success: false,
      message: 'Error fetching child detailed information',
      error: error.message
    });
  }
};


// الحصول على إحصائيات الأطفال والمعلومات
exports.getChildrenManagementData = async (req, res) => {
  console.log('=== START getChildrenManagementData ===');
  
  try {
    const managerId = req.user.user_id;
    console.log('1. Manager ID from token:', managerId);
    
    // الحصول على المؤسسة الخاصة بالمدير
    console.log('2. Fetching manager with institution...');
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

    if (!manager) {
      console.log('❌ ERROR: Manager not found');
      return res.status(404).json({
        success: false,
        message: 'Manager not found'
      });
    }

    if (!manager.Institution) {
      console.log('❌ ERROR: Institution not found for manager');
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const institutionName = manager.Institution.name;
    console.log('3. Found institution:', { institutionId, institutionName });

    const today = formatDate(new Date());
    console.log('4. Today date (start of day):', today);
    
    // 1. الحصول على معلومات الأطفال حسب الحالة
    console.log('5. Fetching children by status for institution:', institutionId);
    const childrenByStatus = await Child.findAll({
      where: {
        current_institution_id: institutionId,
        registration_status: ['Pending', 'Approved', 'Inactive', 'Completed']
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
          as: 'Diagnosis',
          attributes: ['name']
        },
        {
          model: Institution,
          as: 'currentInstitution',
          attributes: ['name']
        }
      ],
      order: [['created_at', 'DESC']]
    });

    console.log(`6. Found ${childrenByStatus.length} total children`);
    
    // عرض حالة كل طفل
    childrenByStatus.forEach((child, index) => {
      console.log(`   Child ${index + 1}: ID=${child.child_id}, Name=${child.full_name}, Status=${child.registration_status}`);
    });

    // 2. حساب عدد الأطفال حسب الحالة
    console.log('7. Calculating status counts...');
    const statusCounts = {
      Pending: 0,
      Approved: 0,
      Inactive: 0,
      Completed: 0
    };

    childrenByStatus.forEach(child => {
      const status = child.registration_status;
      if (statusCounts[status] !== undefined) {
        statusCounts[status]++;
      }
    });

    console.log('8. Status counts:', statusCounts);

    // 3. الأطفال الذين سجلوا اليوم (بعد تغيير الحالة إلى Approved)
    console.log('9. Counting children updated today...');
    const childrenUpdatedToday = await Child.count({
      where: {
        current_institution_id: institutionId,
        registration_status: 'Approved',
        updated_at: {
          [Op.gte]: today
        }
      }
    });

    // للحصول على تفاصيل الأطفال المحدثين اليوم
    const updatedChildrenToday = await Child.findAll({
      where: {
        current_institution_id: institutionId,
        registration_status: 'Approved',
        updated_at: {
          [Op.gte]: today
        }
      },
      attributes: ['child_id', 'full_name', 'updated_at', 'registration_status']
    });

    console.log(`10. Children updated today: ${childrenUpdatedToday}`);
    updatedChildrenToday.forEach(child => {
      console.log(`    - ID: ${child.child_id}, Name: ${child.full_name}, Updated: ${child.updated_at}`);
    });

    // 4. جلسات اليوم
    console.log('11. Fetching today sessions...');
    const todaySessions = await Session.findAll({
      where: {
        institution_id: institutionId,
        date: today
      },
      include: [{
        model: Child,
        as: 'child',
        attributes: ['child_id', 'full_name']
      }]
    });

    console.log(`12. Found ${todaySessions.length} sessions today`);
    todaySessions.forEach((session, index) => {
      console.log(`    Session ${index + 1}: ID=${session.session_id}, Child=${session.child?.full_name}, Status=${session.status}`);
    });

    // 5. عدد الأطفال الذين لديهم جلسات اليوم
    console.log('13. Calculating children with sessions today...');
    const activeSessions = todaySessions.filter(session => 
      ['Approved', 'Confirmed', 'Scheduled', 'Completed'].includes(session.status)
    );
    
    console.log(`14. Active sessions today: ${activeSessions.length}`);
    
    const childrenWithSessionsToday = new Set(
      activeSessions.map(session => session.child_id)
    ).size;

    console.log(`15. Unique children with sessions today: ${childrenWithSessionsToday}`);

    // 6. عدد الأطفال الغائبين اليوم
    console.log('16. Calculating absent children...');
    const absentChildrenCount = todaySessions.filter(
      session => session.status === 'Absent'
    ).length;

    console.log(`17. Absent children today: ${absentChildrenCount}`);

    // 7. طلبات التسجيل اليوم (من جدول ChildRegistrationRequests)
    console.log('18. Counting registration requests today...');
    const registrationRequestsToday = await ChildRegistrationRequest.count({
      where: {
        institution_id: institutionId,
        requested_at: {
          [Op.gte]: today
        }
      }
    });

    console.log(`19. Registration requests today: ${registrationRequestsToday}`);

    // 8. الحصول على آخر تقييم لكل طفل
    console.log('20. Fetching latest evaluations...');
    const childIds = childrenByStatus.map(child => child.child_id);
    console.log(`21. Child IDs for evaluations: ${childIds.join(', ')}`);
    
    const latestEvaluations = await Evaluation.findAll({
      where: {
        child_id: childIds
      },
      attributes: [
        'child_id',
        [sequelize.fn('MAX', sequelize.col('created_at')), 'latest_date']
      ],
      group: ['child_id'],
      raw: true
    });

    console.log(`22. Found ${latestEvaluations.length} latest evaluation records`);
    latestEvaluations.forEach(eva => {
      console.log(`    - Child ${eva.child_id}: Latest eval date: ${eva.latest_date}`);
    });

    // الحصول على تفاصيل التقييمات الأخيرة
    console.log('23. Fetching evaluation details...');
    const evaluationDetails = await Evaluation.findAll({
      where: {
        [Op.or]: latestEvaluations.map(evalu => ({
          child_id: evalu.child_id,
          created_at: evalu.latest_date
        }))
      },
      attributes: ['child_id', 'progress_score', 'created_at', 'evaluation_type']
    });

    console.log(`24. Found ${evaluationDetails.length} evaluation details`);

    // إنشاء map للتقييمات الأخيرة
    const evaluationMap = {};
    evaluationDetails.forEach(evalu => {
      evaluationMap[evalu.child_id] = {
        progress_score: evalu.progress_score,
        last_evaluation_date: evalu.created_at,
        evaluation_type: evalu.evaluation_type
      };
    });

    console.log('25. Evaluation map created:', Object.keys(evaluationMap));

    // 9. إضافة معلومات التقدم لكل طفل
    console.log('26. Adding progress info to children...');
    const childrenWithProgress = childrenByStatus.map(child => {
      const childData = child.get({ plain: true });
      const evaluation = evaluationMap[child.child_id];
      
      console.log(`    Child ${child.child_id}: Has evaluation? ${!!evaluation}`);
      
      return {
        ...childData,
        latest_progress: evaluation ? {
          score: evaluation.progress_score,
          date: evaluation.last_evaluation_date,
          type: evaluation.evaluation_type
        } : null
      };
    });

    // 10. الحصول على آخر طلبات التسجيل
    console.log('27. Fetching latest registration requests...');
    const latestRegistrationRequests = await ChildRegistrationRequest.findAll({
      where: {
        institution_id: institutionId,
        status: 'Pending'
      },
      include: [{
        model: Child,
        attributes: ['child_id', 'full_name', 'date_of_birth', 'gender']
      }],
      order: [['requested_at', 'DESC']],
      limit: 10
    });

    console.log(`28. Found ${latestRegistrationRequests.length} pending registration requests`);

    // إعداد الرد النهائي
    console.log('29. Preparing final response...');
    const response = {
      success: true,
      data: {
        institution: {
          id: manager.Institution.institution_id,
          name: manager.Institution.name
        },
        statistics: {
          children_by_status: statusCounts,
          children_updated_today: childrenUpdatedToday,
          children_with_sessions_today: childrenWithSessionsToday,
          absent_children_today: absentChildrenCount,
          registration_requests_today: registrationRequestsToday,
          total_children: childrenByStatus.length
        },
        children: childrenWithProgress,
        latest_registration_requests: latestRegistrationRequests,
        today_sessions_summary: {
          total: todaySessions.length,
          by_status: todaySessions.reduce((acc, session) => {
            acc[session.status] = (acc[session.status] || 0) + 1;
            return acc;
          }, {})
        }
      }
    };

    console.log('30. Sending response...');
    console.log('=== END getChildrenManagementData ===');
    
    res.status(200).json(response);

  } catch (error) {
    console.error('❌ ERROR in getChildrenManagementData:', error);
    console.error('Stack trace:', error.stack);
    
    res.status(500).json({
      success: false,
      message: 'Error fetching children management data',
      error: error.message
    });
  }
};

// دالة إضافية للحصول على إحصائيات مفصلة
exports.getDetailedStatistics = async (req, res) => {
  console.log('=== START getDetailedStatistics ===');
  
  try {
    const managerId = req.user.user_id;
    console.log('1. Manager ID:', managerId);
    
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
      console.log('❌ ERROR: Manager or institution not found');
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const today = formatDate(new Date());
    const sevenDaysAgo = new Date(today);
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    console.log('2. Institution ID:', institutionId);
    console.log('3. Date range:', { sevenDaysAgo, today });

    // إحصائيات الأيام السبعة الماضية
    console.log('4. Fetching daily stats for last 7 days...');
    const dailyStats = await Child.findAll({
      where: {
        current_institution_id: institutionId,
        registration_status: 'Approved',
        updated_at: {
          [Op.gte]: sevenDaysAgo
        }
      },
      attributes: [
        [sequelize.fn('DATE', sequelize.col('updated_at')), 'date'],
        [sequelize.fn('COUNT', sequelize.col('child_id')), 'count']
      ],
      group: [sequelize.fn('DATE', sequelize.col('updated_at'))],
      order: [[sequelize.fn('DATE', sequelize.col('updated_at')), 'ASC']],
      raw: true
    });

    console.log('5. Daily stats:', dailyStats);

    // توزيع الأطفال حسب التشخيص
    console.log('6. Fetching diagnosis distribution...');
    const diagnosisStats = await Child.findAll({
      where: {
        current_institution_id: institutionId,
        registration_status: ['Approved', 'Completed']
      },
      include: [{
        model: Diagnosis,
        as: 'Diagnosis',
        attributes: ['name']
      }],
      attributes: [
        [sequelize.col('Diagnosis.name'), 'diagnosis'],
        [sequelize.fn('COUNT', sequelize.col('child_id')), 'count']
      ],
      group: [sequelize.col('Diagnosis.name')],
      raw: true
    });

    console.log('7. Diagnosis stats:', diagnosisStats);

    const response = {
      success: true,
      data: {
        daily_registrations: dailyStats,
        diagnosis_distribution: diagnosisStats,
        institution: {
          id: institutionId,
          name: manager.Institution.name
        }
      }
    };

    console.log('8. Sending response...');
    console.log('=== END getDetailedStatistics ===');
    
    res.status(200).json(response);

  } catch (error) {
    console.error('❌ ERROR in getDetailedStatistics:', error);
    console.error('Stack trace:', error.stack);
    
    res.status(500).json({
      success: false,
      message: 'Error fetching detailed statistics',
      error: error.message
    });
  }
};

// دالة جديدة لفحص البيانات بالتفصيل
exports.debugChildrenData = async (req, res) => {
  console.log('=== START debugChildrenData ===');
  
  try {
    const managerId = req.user.user_id;
    console.log('Manager ID:', managerId);
    
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
      console.log('❌ ERROR: Manager or institution not found');
      return res.status(404).json({
        success: false,
        message: 'Manager or institution not found'
      });
    }

    const institutionId = manager.Institution.institution_id;
    console.log('Institution ID:', institutionId);

    // الحصول على جميع الأطفال في المؤسسة
    console.log('Fetching ALL children in institution...');
    const allChildren = await Child.findAll({
      where: {
        current_institution_id: institutionId
      },
      attributes: ['child_id', 'full_name', 'registration_status', 'created_at', 'updated_at'],
      order: [['registration_status', 'ASC'], ['child_id', 'ASC']]
    });

    console.log(`Total children in institution: ${allChildren.length}`);
    
    // حساب التوزيع حسب الحالة
    const statusDistribution = {};
    allChildren.forEach(child => {
      const status = child.registration_status;
      statusDistribution[status] = (statusDistribution[status] || 0) + 1;
    });

    console.log('Status distribution:', statusDistribution);

    // عرض تفاصيل كل طفل
    console.log('\n=== Children Details ===');
    allChildren.forEach((child, index) => {
      console.log(`${index + 1}. ID: ${child.child_id}, Name: ${child.full_name}, Status: ${child.registration_status}, Created: ${child.created_at}, Updated: ${child.updated_at}`);
    });

    // الحصول على طلبات التسجيل
    console.log('\n=== Registration Requests ===');
    const allRequests = await ChildRegistrationRequest.findAll({
      where: {
        institution_id: institutionId
      },
      attributes: ['request_id', 'child_id', 'status', 'requested_at'],
      order: [['requested_at', 'DESC']]
    });

    console.log(`Total registration requests: ${allRequests.length}`);
    
    // حساب التوزيع حسب الحالة
    const requestStatusDistribution = {};
    allRequests.forEach(req => {
      requestStatusDistribution[req.status] = (requestStatusDistribution[req.status] || 0) + 1;
    });

    console.log('Request status distribution:', requestStatusDistribution);

    // عرض تفاصيل كل طلب
    allRequests.forEach((req, index) => {
      console.log(`${index + 1}. Request ID: ${req.request_id}, Child ID: ${req.child_id}, Status: ${req.status}, Requested: ${req.requested_at}`);
    });

    // تحقق من التاريخ اليوم
    const today = formatDate(new Date());
    console.log('\n=== Today Analysis ===');
    console.log('Today (start of day):', today);

    // الأطفال المحدثين اليوم
    const childrenUpdatedTodayList = await Child.findAll({
      where: {
        current_institution_id: institutionId,
        updated_at: {
          [Op.gte]: today
        }
      },
      attributes: ['child_id', 'full_name', 'registration_status', 'updated_at']
    });

    console.log(`Children updated today: ${childrenUpdatedTodayList.length}`);
    childrenUpdatedTodayList.forEach(child => {
      console.log(`  - ID: ${child.child_id}, Name: ${child.full_name}, Status: ${child.registration_status}, Updated: ${child.updated_at}`);
    });

    const response = {
      success: true,
      data: {
        institution: {
          id: institutionId,
          name: manager.Institution.name
        },
        children_summary: {
          total: allChildren.length,
          by_status: statusDistribution
        },
        registration_requests_summary: {
          total: allRequests.length,
          by_status: requestStatusDistribution
        },
        today_analysis: {
          children_updated: childrenUpdatedTodayList.map(child => ({
            id: child.child_id,
            name: child.full_name,
            status: child.registration_status,
            updated_at: child.updated_at
          }))
        }
      }
    };

    console.log('=== END debugChildrenData ===');
    
    res.status(200).json(response);

  } catch (error) {
    console.error('❌ ERROR in debugChildrenData:', error);
    console.error('Stack trace:', error.stack);
    
    res.status(500).json({
      success: false,
      message: 'Error debugging children data',
      error: error.message
    });
  }
};