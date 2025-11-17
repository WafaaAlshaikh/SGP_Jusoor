const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');
const Child = require('./Child');
const Institution = require('./Institution');
const SessionType = require('./SessionType');

const Session = sequelize.define('Session', {
  session_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  child_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  specialist_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  institution_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  session_type_id: { type: DataTypes.INTEGER, allowNull: false },
  date: { type: DataTypes.DATEONLY, allowNull: false },
  time: { type: DataTypes.TIME, allowNull: false },
  session_type: { type: DataTypes.ENUM('Online', 'Onsite'), defaultValue: 'Onsite' },
  status: { 
    type: DataTypes.ENUM(
      'Pending Manager Approval',
      'Pending Approval',
      'Delete Requested',
      'Absent',
      'Reschedule Requested',
      'Rescheduled',  
      'Pending Specialist Approval', 
      'Approved',                   
      'Pending Payment',    
      'Confirmed',         
      'Scheduled',          
      'Completed',         
      'Cancelled',       
      'Rejected',                   
      'Refunded'           
    ), 
    defaultValue: 'Pending Manager Approval' 
  },
  // ✅ نظام الطلبات
  requested_by_parent: { 
    type: DataTypes.BOOLEAN, 
    defaultValue: false 
  },
  delete_request: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  delete_status: {
    type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'),
    allowNull: true
  },

  // ✅ نظام إعادة الجدولة
  is_pending: {           // هل الجلسة بانتظار موافقة
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  parent_approved: {      // موافقة الأهل (null = بانتظار, true = وافق, false = رفض)
    type: DataTypes.BOOLEAN,
    allowNull: true
  },
  original_session_id: {  // يشير للجلسة الأصلية (إذا كانت هذه معدلة)
    type: DataTypes.INTEGER,
    allowNull: true
  },
   reason: {      
    type: DataTypes.STRING(500), // ⭐ راح تستخدم للحذف والتعديل
    allowNull: true,
    defaultValue: null
  },

  // ✅ إدارة الرؤية
  is_visible: {           // هل الجلسة ظاهرة في الفرونت
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  requested_by_parent: { type: DataTypes.BOOLEAN, defaultValue: false }, 
  parent_notes: { type: DataTypes.TEXT, allowNull: true },
  is_first_booking: { type: DataTypes.BOOLEAN, defaultValue: false }, 
  approved_by_manager_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: true }, 
  manager_approval_date: { type: DataTypes.DATE, allowNull: true }, 
  manager_notes: { type: DataTypes.TEXT, allowNull: true },
is_paid: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  payment_status: {
    type: DataTypes.ENUM('Pending', 'Paid', 'Refunded', 'Failed'),
    defaultValue: 'Pending'
  },
  payment_date: {
    type: DataTypes.DATE,
    allowNull: true
  },  // ✅ تقييمات الجلسة - سيتم إضافتها لاحقاً بعد migration
  // parent_rating: { type: DataTypes.DECIMAL(2, 1), allowNull: true },
  // parent_review: { type: DataTypes.TEXT, allowNull: true },
  // specialist_rating: { type: DataTypes.DECIMAL(2, 1), allowNull: true },
  // cancellation_reason: { type: DataTypes.TEXT, allowNull: true } 
}, { 
  tableName: 'Sessions', 
  timestamps: false 
});

Session.belongsTo(User, { foreignKey: 'specialist_id', as: 'specialist' });
Session.belongsTo(Child, { foreignKey: 'child_id', as: 'child' });
Session.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });
Session.belongsTo(SessionType, { foreignKey: 'session_type_id' });

module.exports = Session;