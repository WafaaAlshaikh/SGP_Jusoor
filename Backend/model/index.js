const sequelize = require('../config/db');
const { DataTypes } = require('sequelize');  

const User = require('./User');
const Parent = require('./Parent');
const Child = require('./Child');
const Diagnosis = require('./Diagnosis');
const Specialist = require('./Specialist');
const Institution = require('./Institution');
const Session = require('./Session');
const Invoice = require('./Invoice');
const Payment = require('./Payment');
const Evaluation = require('./Evaluation');
const EvaluationAttachment = require('./EvaluationAttachment');
const SessionType = require('./SessionType');
const SpecialistSchedule = require('./SpecialistSchedule');
const ChildRegistrationRequest = require('./ChildRegistrationRequest');
const SpecialistRegistrationRequest = require('./SpecialistRegistrationRequest');
const VacationRequest = require('./VacationRequest');
const ChildAttachment = require('./ChildAttachment');

const ChildTeam = require('./ChildTeam');
const ChildTeamMember = require('./ChildTeamMember');
const TeamRoom = require('./TeamRoom');
const TeamActivity = require('./TeamActivity');

const Report = require('./Report');
const ReportMessage = require('./ReportMessage');

const AIDonorReport = require('./AIDonorReport');
const AIParentInteraction = require('./AIParentInteraction');
const AIRecommendation = require('./AIRecommendation');
const AISpecialistInsight = require('./AISpecialistInsight');
const Message = require('./Message');
const Post = require('./Post');
const Donation = require('./Donation');
const DonationAllocation = require('./DonationAllocation');
const DonationCampaign = require('./DonationCampaign');
const DonationInvite = require('./DonationInvite');
const DonationInviteEvent = require('./DonationInviteEvent');
const Resource = require('./Resource');
const ResourceDiagnosis = require('./ResourceDiagnosis');
const Comment = require('./Comment');
const Like = require('./Like');
const Notification = require('./Notification');

const UserDeviceToken = require('./UserDeviceToken');
const InstitutionFollower = require('./InstitutionFollower');

const Manager = require('./Manager');
const Questionnaire = require('./Questionnaire')(sequelize, DataTypes);
const Question = require('./Question')(sequelize, DataTypes);
const QuestionnaireResponse = require('./QuestionnaireResponse')(sequelize, DataTypes);

const SessionRating = require('./SessionRating');
const InstitutionReview = require('./InstitutionReview');
const SpecialistFeedback = require('./SpecialistFeedback');

const FinancialAssistanceRequest = require('./FinancialAssistanceRequest');
const SessionFinancialAidRequest = require('./SessionFinancialAidRequest');
const PaymentPlan = require('./PaymentPlan');

const AutoFinancialAidLog = require('./AutoFinancialAidLog');
const InstitutionPageContent = require('./InstitutionPageContent'); 
const InstitutionNews = require('./InstitutionNews');
const InstitutionProgram = require('./InstitutionProgram');
const InstitutionProject = require('./InstitutionProject');
const InstitutionFAQ = require('./InstitutionFAQ');
const InstitutionMedia = require('./InstitutionMedia');

const ImpactPost = require('./ImpactPost');

const AdminUser = require('./AdminUser');
const AuditLog = require('./AuditLog');
const SystemSettings = require('./SystemSettings');

const EquipmentCategory = require('./EquipmentCategory');
const EquipmentDonation = require('./EquipmentDonation');
const InstitutionEquipmentInventory = require('./InstitutionEquipmentInventory');
const ChildEquipmentNeed = require('./ChildEquipmentNeed');
const EquipmentAllocation = require('./EquipmentAllocation');
const EquipmentItemHistory = require('./EquipmentItemHistory');
const EquipmentDonationCampaign = require('./EquipmentDonationCampaign');

const ChildSpecialistCompletion = require('./ChildSpecialistCompletion');// ==================== Main Relations ====================

const ActivityRecommendation = require('./ActivityRecommendation');
const TempActivityAnalysis = require('./TempActivityAnalysis');
const SpecialistInterview = require('./SpecialistInterview');
Institution.hasMany(Donation, {
  foreignKey: 'institution_id'
});

Donation.belongsTo(Institution, {
  foreignKey: 'institution_id'
});

Donation.belongsTo(DonationCampaign, {
  foreignKey: 'campaign_id'
});

DonationInvite.belongsTo(User, { foreignKey: 'inviter_user_id', as: 'inviter' });
User.hasMany(DonationInvite, { foreignKey: 'inviter_user_id', as: 'donationInvites' });

DonationInvite.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });
Institution.hasMany(DonationInvite, { foreignKey: 'institution_id', as: 'donationInvites' });

DonationInvite.belongsTo(DonationCampaign, { foreignKey: 'campaign_id', as: 'campaign' });
DonationCampaign.hasMany(DonationInvite, { foreignKey: 'campaign_id', as: 'donationInvites' });

DonationInviteEvent.belongsTo(DonationInvite, { foreignKey: 'invite_id', as: 'invite' });
DonationInvite.hasMany(DonationInviteEvent, { foreignKey: 'invite_id', as: 'events' });

DonationInviteEvent.belongsTo(User, { foreignKey: 'referred_user_id', as: 'referredUser' });
DonationInviteEvent.belongsTo(Donation, { foreignKey: 'donation_id', as: 'donation' });


Questionnaire.hasMany(Question, { 
  foreignKey: 'questionnaire_id',
  as: 'questions'
});

Question.belongsTo(Questionnaire, { 
  foreignKey: 'questionnaire_id', 
  as: 'questionnaire'
});


// User relationships
User.hasOne(Parent, { foreignKey: 'parent_id' });
User.hasOne(Specialist, { foreignKey: 'specialist_id' });
User.hasOne(Manager, { foreignKey: 'manager_id' });

Parent.belongsTo(User, { foreignKey: 'parent_id' });
Specialist.belongsTo(User, { foreignKey: 'specialist_id' });
Manager.belongsTo(User, { foreignKey: 'manager_id' });

// Institution relationships
Institution.hasMany(Manager, { foreignKey: 'institution_id' });
Institution.hasMany(Specialist, { foreignKey: 'institution_id' });
Institution.hasMany(SessionType, { foreignKey: 'institution_id' });
Institution.hasMany(Session, { foreignKey: 'institution_id' });

Manager.belongsTo(Institution, { foreignKey: 'institution_id' });
Specialist.belongsTo(Institution, { foreignKey: 'institution_id' });
SessionType.belongsTo(Institution, { foreignKey: 'institution_id' });
Session.belongsTo(Institution, { foreignKey: 'institution_id' });

EquipmentDonationCampaign.belongsTo(Institution, {
  foreignKey: 'institution_id',
  as: 'institution'
});

Institution.hasMany(EquipmentDonationCampaign, {
  foreignKey: 'institution_id',
  as: 'equipmentCampaigns'
});

EquipmentDonationCampaign.belongsTo(Child, {
  foreignKey: 'child_id',
  as: 'child'
});

EquipmentDonationCampaign.belongsTo(ChildEquipmentNeed, {
  foreignKey: 'need_id',
  as: 'need'
});

EquipmentDonationCampaign.belongsTo(EquipmentCategory, {
  foreignKey: 'category_id',
  as: 'category'
});

// Child relationships 
Child.belongsTo(Parent, { foreignKey: 'parent_id' });
Child.belongsTo(Diagnosis, { 
  foreignKey: 'diagnosis_id', 
  as: 'ChildDiagnosis'
});
Child.belongsTo(Institution, { 
  foreignKey: 'current_institution_id', 
  as: 'CurrentInstitution' 
});

Parent.hasMany(Child, { foreignKey: 'parent_id' });
Diagnosis.hasMany(Child, { foreignKey: 'diagnosis_id', as: 'Children' });

// Session relationships
Session.belongsTo(Child, { foreignKey: 'child_id', as: 'SessionChild' }); 
Session.belongsTo(Specialist, { foreignKey: 'specialist_id', as: 'SessionSpecialist' }); 
Session.belongsTo(SessionType, { foreignKey: 'session_type_id' });
Session.belongsTo(Institution, { foreignKey: 'institution_id', as: 'SessionInstitution' });

Child.hasMany(Session, { foreignKey: 'child_id', as: 'ChildSessions' }); 
Specialist.hasMany(Session, { foreignKey: 'specialist_id', as: 'SpecialistSessions' }); 
SessionType.hasMany(Session, { foreignKey: 'session_type_id' });
Institution.hasMany(Session, { foreignKey: 'institution_id', as: 'InstitutionSessions' }); 

// ==================== Secondery Relations ====================

// Community relationships
User.hasMany(Post, { foreignKey: 'user_id', as: 'UserPosts' });
User.hasMany(Comment, { foreignKey: 'user_id', as: 'UserComments' });
User.hasMany(Like, { foreignKey: 'user_id', as: 'UserLikes' });

Post.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Post.hasMany(Comment, { foreignKey: 'post_id', as: 'comments' });
Post.hasMany(Like, { foreignKey: 'post_id', as: 'likes' });
Post.belongsTo(Post, { foreignKey: 'original_post_id', as: 'originalPost', required: false });

Comment.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Comment.belongsTo(Post, { foreignKey: 'post_id', as: 'CommentPost' });
Comment.hasMany(Like, { foreignKey: 'comment_id', as: 'CommentLikes' });

Like.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Like.belongsTo(Post, { foreignKey: 'post_id', as: 'LikePost' });
Like.belongsTo(Comment, { foreignKey: 'comment_id', as: 'LikeComment' });

// Notification relationships
Notification.belongsTo(User, { foreignKey: 'user_id', as: 'NotificationUser' });
User.hasMany(Notification, { foreignKey: 'user_id', as: 'UserNotifications' });

UserDeviceToken.belongsTo(User, { foreignKey: 'user_id', as: 'DeviceTokenUser' });
User.hasMany(UserDeviceToken, { foreignKey: 'user_id', as: 'UserDeviceTokens' });

InstitutionFollower.belongsTo(User, { foreignKey: 'user_id', as: 'FollowerUser' });
User.hasMany(InstitutionFollower, { foreignKey: 'user_id', as: 'UserInstitutionFollows' });
InstitutionFollower.belongsTo(Institution, { foreignKey: 'institution_id', as: 'FollowedInstitution' });
Institution.hasMany(InstitutionFollower, { foreignKey: 'institution_id', as: 'InstitutionFollowers' });

// Reports relationships
Report.belongsTo(User, { foreignKey: 'reporter_user_id', as: 'reporter' });
User.hasMany(Report, { foreignKey: 'reporter_user_id', as: 'UserReports' });
Report.belongsTo(Institution, { foreignKey: 'institution_id', as: 'ReportInstitution' });
Institution.hasMany(Report, { foreignKey: 'institution_id', as: 'InstitutionReports' });

Report.hasMany(ReportMessage, { foreignKey: 'report_id', as: 'messages' });
ReportMessage.belongsTo(Report, { foreignKey: 'report_id', as: 'report' });

// Donation.associate({ DonationCampaign });
// DonationCampaign.associate({ Donation });


module.exports = {
  sequelize,
  User,
  Parent,
  Child,
  Diagnosis,
  Specialist,
  Institution,
  Session,
  Invoice,
  Payment,
  Evaluation,
  EvaluationAttachment,
  SessionType,
  SpecialistSchedule,
  ChildRegistrationRequest,
  SpecialistRegistrationRequest,
  VacationRequest,
  AIDonorReport,
  AIParentInteraction,
  AIRecommendation,
  AISpecialistInsight,
  Message,
  Post,
  Donation,
  DonationAllocation,
  DonationCampaign,
  DonationInvite,
  DonationInviteEvent,
  Resource,
  ResourceDiagnosis,
  ChildAttachment,
  ChildTeam,
  ChildTeamMember,
  TeamRoom,
  TeamActivity,
  Report,
  ReportMessage,
  Comment,
  Like,
  Notification,
  UserDeviceToken,
  InstitutionFollower,
  Manager,
  Questionnaire,
  Question,
  QuestionnaireResponse,
  SessionRating,
  InstitutionReview,
  SpecialistFeedback,
  FinancialAssistanceRequest,
  SessionFinancialAidRequest,
  PaymentPlan,
  AutoFinancialAidLog,
  InstitutionPageContent,
  InstitutionNews,
  InstitutionProgram,
  InstitutionProject,
  InstitutionFAQ,
  InstitutionMedia,
  ImpactPost,
  AdminUser,
  AuditLog,
  SystemSettings,
  EquipmentCategory,
  EquipmentDonation,
  InstitutionEquipmentInventory,
  ChildEquipmentNeed,
  EquipmentAllocation,
  EquipmentItemHistory,
  EquipmentDonationCampaign,
  ChildSpecialistCompletion,
  ActivityRecommendation,
  TempActivityAnalysis,
  SpecialistInterview
};

