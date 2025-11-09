
const sequelize = require('../config/db');

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
const Question = require('./Question');
const Questionnaire = require('./Questionnaire');
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



// User relationships
User.hasMany(Post, { foreignKey: 'user_id', as: 'posts' });
User.hasMany(Comment, { foreignKey: 'user_id', as: 'comments' });
User.hasMany(Like, { foreignKey: 'user_id', as: 'likes' });

// Post relationships
Post.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Post.belongsTo(Post, { foreignKey: 'original_post_id', as: 'originalPost' });
Post.hasMany(Comment, { foreignKey: 'post_id', as: 'comments' });
Post.hasMany(Like, { foreignKey: 'post_id', as: 'likes' });

// Comment relationships
Comment.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Comment.belongsTo(Post, { foreignKey: 'post_id', as: 'post' });
Comment.hasMany(Like, { foreignKey: 'comment_id', as: 'likes' });

// Like relationships - هذه هي العلاقات المهمة
Like.belongsTo(User, { foreignKey: 'user_id', as: 'user' });
Like.belongsTo(Post, { foreignKey: 'post_id', as: 'post' });
Like.belongsTo(Comment, { foreignKey: 'comment_id', as: 'comment' });

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
  Question,
  Questionnaire,
  ChildAttachment,
  Comment,
  Like,
  Notification
};