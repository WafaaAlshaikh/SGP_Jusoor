const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');
const Child = require('./Child');
const Institution = require('./Institution');
const SessionType = require('./SessionType');
const FinancialAssistanceRequest = require('./FinancialAssistanceRequest');

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


  is_pending: {          
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  parent_approved: {      
    type: DataTypes.BOOLEAN,
    allowNull: true
  },
  original_session_id: { 
    type: DataTypes.INTEGER,
    allowNull: true
  },
   reason: {      
    type: DataTypes.STRING(500), 
    allowNull: true,
    defaultValue: null
  },

  is_visible: {         
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },

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
    type: DataTypes.STRING(50),
    allowNull: true,
    defaultValue: 'Pending'
  },
  payment_date: {
    type: DataTypes.DATE,
    allowNull: true
  }, 
  original_price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true,
    comment: 'Original price before any discount'
  },
  applied_discount_percentage: {
    type: DataTypes.DECIMAL(5, 2),
    defaultValue: 0,
    validate: {
      min: 0,
      max: 100
    }
  },
  final_price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    comment: 'Price after discount'
  },
  financial_assistance_applied: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  financial_assistance_request_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: {
      model: FinancialAssistanceRequest,
      key: 'request_id'
    }
  },
  payment_plan_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    comment: 'For installment plans'
  },
  // TRACKING
  discount_reason: {
    type: DataTypes.TEXT,
    allowNull: true,
    comment: 'Reason for discount if applied'
  },
  subsidy_source: {
    type: DataTypes.ENUM(
      'institution_fund',
      'government_subsidy',
      'donor_funded',
      'charity_partner',
      'internal_discount'
    ),
    allowNull: true
  },
  subsidy_document_reference: {
    type: DataTypes.STRING(100),
    allowNull: true
  }, 
}, { 
  tableName: 'Sessions', 
  timestamps: false 
});

Session.belongsTo(User, { foreignKey: 'specialist_id', as: 'specialist' });
Session.belongsTo(Child, { foreignKey: 'child_id', as: 'child' });
Session.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });
Session.belongsTo(SessionType, { foreignKey: 'session_type_id' });

module.exports = Session;