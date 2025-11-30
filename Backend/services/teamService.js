const ChildTeam = require('../model/ChildTeam');
const ChildTeamMember = require('../model/ChildTeamMember');
const TeamRoom = require('../model/TeamRoom');
const TeamActivity = require('../model/TeamActivity');
const Specialist = require('../model/Specialist');
const User = require('../model/User');

class TeamService {
  
  static async createInitialTeamForChild(childId, institutionId) {
    try {
      console.log(`🏗️ إنشاء فريق متعدد التخصصات للطفل ${childId}`);

      const childTeam = await ChildTeam.create({
        child_id: childId,
        institution_id: institutionId,
        team_type: 'multidisciplinary',
        status: 'active'
      });

      const generalSpecialist = await Specialist.findOne({
        where: { 
          institution_id: institutionId,
          specialization: 'General',
          approval_status: 'Approved'
        },
        include: [{
          model: User,
          attributes: ['full_name']
        }]
      });

      if (generalSpecialist) {
        await ChildTeamMember.create({
          child_team_id: childTeam.team_id,
          specialist_id: generalSpecialist.specialist_id,
          role: 'initial_assessor',
          status: 'active',
          notes: 'تم التعيين تلقائياً كأخصائي عام أولي'
        });

        console.log(`✅ تم إضافة الأخصائي العام: ${generalSpecialist.User.full_name}`);
      }

      const teamRoom = await TeamRoom.create({
        child_team_id: childTeam.team_id,
        room_name: `فريق الطفل ${childId}`,
        status: 'active'
      });

      if (generalSpecialist) {
        await TeamActivity.create({
          team_room_id: teamRoom.room_id,
          specialist_id: generalSpecialist.specialist_id,
          activity_type: 'note',
          title: 'بداية الرحلة العلاجية',
          description: 'تم إنشاء الفريق المتعدد التخصصات وتعيين أخصائي عام للتقييم الأولي',
          timestamp: new Date()
        });
      }

      console.log(`✅ تم إنشاء فريق متعدد التخصصات للطفل ${childId} - Team ID: ${childTeam.team_id}`);
      return childTeam;

    } catch (error) {
      console.error('❌ خطأ في إنشاء الفريق:', error);
      throw error;
    }
  }

  static async updateTeamRoomWithEvaluation(childId, specialistId, evaluation) {
    try {
      const childTeam = await ChildTeam.findOne({
        where: { 
          child_id: childId, 
          status: 'active' 
        },
        include: [{
          model: TeamRoom
        }]
      });

      if (!childTeam) {
        console.log(`⚠️ لا يوجد فريق نشط للطفل ${childId}`);
        return;
      }

      const specialist = await Specialist.findByPk(specialistId, {
        include: [{
          model: User,
          attributes: ['full_name']
        }]
      });

      await TeamActivity.create({
        team_room_id: childTeam.TeamRoom.room_id,
        specialist_id: specialistId,
        activity_type: 'evaluation',
        title: `تقييم ${evaluation.evaluation_type}`,
        description: `نتيجة: ${evaluation.progress_score}/100 - ${evaluation.notes || 'لا توجد ملاحظات'}`,
        related_id: evaluation.evaluation_id,
        timestamp: new Date()
      });

      console.log(`✅ تم تحديث Team Room بتقييم جديد من ${specialist.User.full_name}`);

      if (specialist.specialization === 'General') {
        await this.analyzeInitialAssessment(childId, evaluation, childTeam.team_id, institutionId);
      }

    } catch (error) {
      console.error('❌ خطأ في تحديث Team Room:', error);
    }
  }

  static async analyzeInitialAssessment(childId, evaluation, teamId, institutionId) {
    try {
      console.log(`🔍 تحليل التقييم الأولي للطفل ${childId}`);

      const AIAnalysisService = require('./aiAnalysisServiceAddEvaluation');
      const analysis = await AIAnalysisService.analyzeEvaluationNotes(evaluation.notes, institutionId);
      
      const requiredSpecializations = analysis.suggested_specializations || ['Behavioral', 'Speech'];
      console.log(`📋 التخصصات المطلوبة: ${requiredSpecializations.join(', ')}`);

      for (const specialization of requiredSpecializations) {
        const availableSpecialist = await Specialist.findOne({
          where: { 
            institution_id: institutionId,
            specialization: specialization,
            approval_status: 'Approved'
          },
          include: [{
            model: User,
            attributes: ['full_name']
          }]
        });

        if (availableSpecialist) {
          const existingMember = await ChildTeamMember.findOne({
            where: { 
              child_team_id: teamId,
              specialist_id: availableSpecialist.specialist_id
            }
          });

          if (!existingMember) {
            await ChildTeamMember.create({
              child_team_id: teamId,
              specialist_id: availableSpecialist.specialist_id,
              role: `${specialization.toLowerCase()}_specialist`,
              status: 'active',
              notes: `تم التعيين تلقائياً بناءً على التقييم الأولي`
            });

            const teamRoom = await TeamRoom.findOne({ 
              where: { child_team_id: teamId } 
            });
            
            await TeamActivity.create({
              team_room_id: teamRoom.room_id,
              specialist_id: availableSpecialist.specialist_id,
              activity_type: 'recommendation',
              title: `مقترح إضافة أخصائي ${specialization}`,
              description: `بناءً على التقييم الأولي، تمت إضافة أخصائي ${specialization} إلى الفريق`,
              timestamp: new Date()
            });

            console.log(`✅ تم إضافة أخصائي ${specialization}: ${availableSpecialist.User.full_name}`);
          }
        } else {
          console.log(`⚠️ لا يوجد أخصائي ${specialization} متاح`);
        }
      }

    } catch (error) {
      console.error('❌ خطأ في تحليل التقييم الأولي:', error);
    }
  }

  static async getChildTeamData(childId, institutionId) {
  try {
    const childTeam = await ChildTeam.findOne({
      where: { 
        child_id: childId,
        institution_id: institutionId,
        status: 'active'
      },
      include: [
        {
          model: require('../model/Child'),
          attributes: ['child_id', 'full_name', 'date_of_birth']
        },
        {
          model: require('../model/ChildTeamMember'),
          as: 'ChildTeamMembers',
          include: [
            {
              model: require('../model/Specialist'),
              include: [
                {
                  model: require('../model/User'),
                  attributes: ['full_name', 'profile_picture']
                }
              ]
            }
          ]
        },
        {
          model: require('../model/TeamRoom'),
          as: 'TeamRoom',
          include: [
            {
              model: require('../model/TeamActivity'),
              as: 'TeamActivities',
              include: [
                {
                  model: require('../model/Specialist'),
                  include: [
                    {
                      model: require('../model/User'),
                      attributes: ['full_name']
                    }
                  ]
                }
              ],
              order: [['timestamp', 'DESC']],
              limit: 10
            }
          ]
        }
      ]
    });

    return childTeam;
  } catch (error) {
    console.error('❌ خطأ في جلب بيانات الفريق:', error);
    throw error;
  }
}
}

module.exports = TeamService;