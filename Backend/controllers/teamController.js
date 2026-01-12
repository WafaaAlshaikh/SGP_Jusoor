const TeamService = require('../services/teamService');
const ChildTeam = require('../model/ChildTeam');
const Manager = require('../model/Manager');
const Institution = require('../model/Institution');

exports.getChildTeamOverview = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { child_id } = req.params;

    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true },
      include: [{ model: Institution }]
    });

    if (!manager) {
      return res.status(404).json({ 
        success: false, 
        message: 'مدير غير موجود' 
      });
    }

    const childTeam = await TeamService.getChildTeamData(child_id, manager.Institution.institution_id);

    if (!childTeam) {
      return res.status(404).json({ 
        success: false, 
        message: 'لم يتم إنشاء فريق لهذا الطفل بعد' 
      });
    }

    res.status(200).json({
      success: true,
      data: {
        team_info: {
          team_id: childTeam.team_id,
          team_type: childTeam.team_type,
          status: childTeam.status,
          created_at: childTeam.created_at
        },
        child_info: {
          id: childTeam.Child.child_id,
          name: childTeam.Child.full_name,
          age: calculateAge(childTeam.Child.date_of_birth)
        },
        team_members: childTeam.ChildTeamMembers.map(member => ({
          specialist_id: member.Specialist.specialist_id,
          name: member.Specialist.User.full_name,
          role: member.role,
          specialization: member.Specialist.specialization,
          profile_picture: member.Specialist.User.profile_picture,
          status: member.status,
          assigned_date: member.assigned_date
        })),
        recent_activities: childTeam.TeamRoom.TeamActivities.map(activity => ({
          type: activity.activity_type,
          title: activity.title,
          description: activity.description,
          specialist: activity.Specialist.User.full_name,
          timestamp: activity.timestamp
        }))
      }
    });

  } catch (error) {
    console.error('Error in getChildTeamOverview:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب بيانات الفريق',
      error: error.message
    });
  }
};

function calculateAge(dateOfBirth) {
  if (!dateOfBirth) return 0;
  const birthDate = new Date(dateOfBirth);
  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  return age;
}

module.exports = exports;