// models/FinancialAssistanceRequest.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Child = require('./Child');
const Institution = require('./Institution');
const User = require('./User');

const FinancialAssistanceRequest = sequelize.define('FinancialAssistanceRequest', {
  request_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  parent_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  child_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: Child,
      key: 'child_id'
    }
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: Institution,
      key: 'institution_id'
    }
  },
  // REQUEST DETAILS
  requested_sessions_count: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
    validate: {
      min: 1
    }
  },
  requested_discount_percentage: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: false,
    validate: {
      min: 0,
      max: 100
    }
  },
  requested_total_amount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false,
    comment: 'Original total amount before discount'
  },
  // FINANCIAL ASSESSMENT DATA
  parent_financial_score: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  parent_financial_tier: {
    type: DataTypes.ENUM(
      'tier_1_critical',
      'tier_2_high',
      'tier_3_medium',
      'tier_4_low',
      'tier_5_no_assistance'
    ),
    allowNull: false
  },
  child_condition_urgency: {
    type: DataTypes.ENUM('low', 'medium', 'high', 'critical'),
    defaultValue: 'medium'
  },
  // REQUEST STATUS
  status: {
    type: DataTypes.ENUM(
      'draft',
      'submitted',
      'under_review',
      'pending_documents',
      'approved',
      'partially_approved',
      'rejected',
      'auto_generated',
      'cancelled'
    ),
    defaultValue: 'draft'
  },
  // DECISION DETAILS
  approved_sessions_count: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  approved_discount_percentage: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: true
  },
  approved_total_amount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: true,
    comment: 'Amount after approved discount'
  },
  approved_by_manager_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  decision_date: {
    type: DataTypes.DATE,
    allowNull: true
  },
  decision_notes: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  // ADDITIONAL INFO
  auto_generated: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  requires_documents: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  documents_submitted: {
    type: DataTypes.JSON,
    allowNull: true,
    comment: 'Array of submitted document metadata'
  },
  estimated_processing_days: {
    type: DataTypes.INTEGER,
    defaultValue: 7
  },
  urgency_reason: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  // TIMESTAMPS
  submitted_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'FinancialAssistanceRequests',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

// Relationships
FinancialAssistanceRequest.belongsTo(User, {
  foreignKey: 'parent_id',
  as: 'parent'
});

FinancialAssistanceRequest.belongsTo(Child, {
  foreignKey: 'child_id',
  as: 'child'
});

FinancialAssistanceRequest.belongsTo(Institution, {
  foreignKey: 'institution_id',
  as: 'institution'
});

FinancialAssistanceRequest.belongsTo(User, {
  foreignKey: 'approved_by_manager_id',
  as: 'approvedByManager'
});

module.exports = FinancialAssistanceRequest;