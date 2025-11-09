const { Specialist, Child, Parent, User, Evaluation, Diagnosis, Institution, Session } = require('../model/index');

// جلب جميع الأطفال للاخصائي مع معلوماتهم الكاملة
const getSpecialistChildren = async (req, res) => {
  try {
    const specialistId = req.user.user_id;

    // التحقق من وجود الأخصائي
    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId },
      include: [{
        model: User,
        attributes: ['full_name', 'email', 'phone']
      }]
    });

    if (!specialist) {
      return res.status(404).json({ 
        success: false, 
        message: 'specialist not found' 
      });
    }

    // جلب جميع جلسات الأخصائي مع الأطفال المرتبطين بها
    const sessions = await Session.findAll({
      where: { specialist_id: specialistId },
      include: [
        {
          model: Child,
          as: 'child', // alias موجود في موديل Session
          include: [
            {
              model: Parent,
              include: [{
                model: User,
                attributes: ['full_name', 'email', 'phone']
              }]
            },
            {
              model: Diagnosis,
              as: 'Diagnosis', // لازم يكون string
              attributes: ['name', 'description']
            },
            {
              model: Institution,
              as: 'currentInstitution',
              attributes: ['name']
            }
          ]
        }
      ],
      attributes: ['session_id', 'date', 'status']
    });

    // تجميع الأطفال مع تجنب التكرار
    const childrenMap = new Map();
    sessions.forEach(session => {
      if (session.child && !childrenMap.has(session.child.child_id)) {
        childrenMap.set(session.child.child_id, session.child);
      }
    });
    const children = Array.from(childrenMap.values());

    // جلب التقييمات لكل طفل
    const childrenWithEvaluations = await Promise.all(
      children.map(async (child) => {
        const evaluations = await Evaluation.findAll({
          where: { 
            child_id: child.child_id,
            specialist_id: specialistId 
          },
          attributes: ['evaluation_id', 'evaluation_type', 'notes', 'progress_score', 'created_at']
        });

        return {
          child_id: child.child_id,
          full_name: child.full_name,
          date_of_birth: child.date_of_birth,
          gender: child.gender,
          photo: child.photo,
          medical_history: child.medical_history,
          registration_status: child.registration_status,
          diagnosis: child.Diagnosis,
          current_institution: child.currentInstitution,
          parent: {
            parent_id: child.Parent.parent_id,
            full_name: child.Parent.User.full_name,
            email: child.Parent.User.email,
            phone: child.Parent.User.phone,
            address: child.Parent.address,
            occupation: child.Parent.occupation
          },
          evaluations,
          total_sessions: sessions.filter(s => s.child.child_id === child.child_id).length,
          last_session: sessions
            .filter(s => s.child.child_id === child.child_id)
            .sort((a, b) => new Date(b.date) - new Date(a.date))[0]
        };
      })
    );

    res.json({
      success: true,
      data: {
        specialist: {
          specialist_id: specialist.specialist_id,
          full_name: specialist.User.full_name,
          specialization: specialist.specialization,
          years_experience: specialist.years_experience
        },
        children: childrenWithEvaluations,
        total_children: childrenWithEvaluations.length
      }
    });

  } catch (error) {
    console.error('Error fetching specialist children:', error);
    res.status(500).json({ 
      success: false, 
      message: 'error in server',
      error: error.message 
    });
  }
};

// جلب طفل محدد مع معلوماته الكاملة
const getChildDetails = async (req, res) => {
  try {
    const { childId } = req.params;
    const specialistId = req.user.user_id;

    // التحقق من أن الأخصائي لديه جلسات مع هذا الطفل
    const hasSessions = await Session.findOne({
      where: { 
        specialist_id: specialistId,
        child_id: childId 
      }
    });

    if (!hasSessions) {
      return res.status(403).json({ 
        success: false, 
        message: 'cant access information about this child' 
      });
    }

    const child = await Child.findOne({
      where: { child_id: childId },
      include: [
        {
          model: Parent,
          include: [{
            model: User,
            attributes: ['full_name', 'email', 'phone']
          }]
        },
        {
          model: Diagnosis,
          as: 'Diagnosis',
          attributes: ['name', 'description']
        },
        {
          model: Institution,
          as: 'currentInstitution',
          attributes: ['name']
        }
      ]
    });

    if (!child) {
      return res.status(404).json({ 
        success: false, 
        message: 'child does not exist' 
      });
    }

    // جلب جميع التقييمات لهذا الطفل من قبل الأخصائي
    const evaluations = await Evaluation.findAll({
      where: { 
        child_id: childId,
        specialist_id: specialistId 
      },
      order: [['created_at', 'DESC']]
    });

    // جلب تاريخ الجلسات
    const sessions = await Session.findAll({
      where: { 
        child_id: childId,
        specialist_id: specialistId 
      },
      attributes: ['session_id', 'date', 'time', 'status', 'session_type'],
      order: [['date', 'DESC']]
    });

    res.json({
      success: true,
      data: {
        child: {
          child_id: child.child_id,
          full_name: child.full_name,
          date_of_birth: child.date_of_birth,
          gender: child.gender,
          photo: child.photo,
          medical_history: child.medical_history,
          registration_status: child.registration_status,
          diagnosis: child.Diagnosis,
          current_institution: child.currentInstitution,
          parent: {
            parent_id: child.Parent.parent_id,
            full_name: child.Parent.User.full_name,
            email: child.Parent.User.email,
            phone: child.Parent.User.phone,
            address: child.Parent.address,
            occupation: child.Parent.occupation
          }
        },
        evaluations,
        sessions,
        statistics: {
          total_sessions: sessions.length,
          completed_sessions: sessions.filter(s => s.status === 'Completed').length,
          total_evaluations: evaluations.length,
          latest_evaluation: evaluations[0] || null
        }
      }
    });

  } catch (error) {
    console.error('Error fetching child details:', error);
    res.status(500).json({ 
      success: false, 
      message: 'error in server',
      error: error.message 
    });
  }
};

module.exports = {
  getSpecialistChildren,
  getChildDetails
};
