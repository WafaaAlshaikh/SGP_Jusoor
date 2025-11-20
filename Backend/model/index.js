const sequelize = require('../config/db');
const { DataTypes } = require('sequelize');  

const User = require('./User');
const Parent = require('./Parent');
const Child = require('./Child');
const Diagnosis = require('./Diagnosis');
const Specialist = require('./Specialist');
const Institution = require('./Institution');
const Session = require('./Session');
const Payment = require('./Payment');
const Evaluation = require('./Evaluation');
const EvaluationAttachment = require('./EvaluationAttachment');
const SessionType = require('./SessionType');
const SpecialistSchedule = require('./SpecialistSchedule');
const ChildRegistrationRequest = require('./ChildRegistrationRequest');
const SpecialistRegistrationRequest = require('./SpecialistRegistrationRequest');
const VacationRequest = require('./VacationRequest');
const ChildAttachment = require('./ChildAttachment');

const AIDonorReport = require('./AIDonorReport');
const AIParentInteraction = require('./AIParentInteraction');
const AIRecommendation = require('./AIRecommendation');
const AISpecialistInsight = require('./AISpecialistInsight');
const Message = require('./Message');
const Post = require('./Post');
const Donation = require('./Donation');
const Resource = require('./Resource');
const ResourceDiagnosis = require('./ResourceDiagnosis');
const Comment = require('./Comment');
const Like = require('./Like');
const Notification = require('./Notification');

const Manager = require('./Manager');
const Questionnaire = require('./Questionnaire')(sequelize, DataTypes);
const Question = require('./Question')(sequelize, DataTypes);
const QuestionnaireResponse = require('./QuestionnaireResponse')(sequelize, DataTypes);

// ==================== Main Relations ====================

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
Session.belongsTo(Child, { foreignKey: 'child_id', as: 'SessionChild' }); // ⬅️ تغيير الـ alias
Session.belongsTo(Specialist, { foreignKey: 'specialist_id', as: 'SessionSpecialist' }); // ⬅️ تغيير الـ alias
Session.belongsTo(SessionType, { foreignKey: 'session_type_id' });
Session.belongsTo(Institution, { foreignKey: 'institution_id', as: 'SessionInstitution' }); // ⬅️ تغيير الـ alias

Child.hasMany(Session, { foreignKey: 'child_id', as: 'ChildSessions' }); // ⬅️ تغيير الـ alias
Specialist.hasMany(Session, { foreignKey: 'specialist_id', as: 'SpecialistSessions' }); // ⬅️ تغيير الـ alias
SessionType.hasMany(Session, { foreignKey: 'session_type_id' });
Institution.hasMany(Session, { foreignKey: 'institution_id', as: 'InstitutionSessions' }); // ⬅️ تغيير الـ alias

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


module.exports = {
  sequelize,
  User,
  Parent,
  Child,
  Diagnosis,
  Specialist,
  Institution,
  Session,
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
  Resource,
  ResourceDiagnosis,
  ChildAttachment,
  Comment,
  Like,
  Notification,
  Manager,
  Questionnaire,
  Question,
  QuestionnaireResponse
};