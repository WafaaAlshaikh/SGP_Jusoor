const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');
const Child = require('./Child');
const Institution = require('./Institution');
const Session = require('./Session');
const FinancialAssistanceRequest = require('./FinancialAssistanceRequest');

const SessionFinancialAidRequest = sequelize.define('SessionFinancialAidRequest', {
  request_id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },

  session_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Session,
      key: 'session_id'
    }
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

  parent_financial_request_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: {
      model: FinancialAssistanceRequest,
      key: 'request_id'
    }
  },

  status: {
    type: DataTypes.ENUM(
      'submitted',
      'under_review',
      'approved',
      'partial_approved',
      'rejected'
    ),
    allowNull: false,
    defaultValue: 'submitted'
  },

  requested_percentage: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: true
  },
  requested_amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true
  },

  approved_percentage: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: true
  },
  approved_amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true
  },

  decided_by_manager_id: {
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

  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  updated_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW }
}, {
  tableName: 'SessionFinancialAidRequests',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

SessionFinancialAidRequest.belongsTo(Session, { foreignKey: 'session_id', as: 'session' });
SessionFinancialAidRequest.belongsTo(User, { foreignKey: 'parent_id', as: 'parent' });
SessionFinancialAidRequest.belongsTo(Child, { foreignKey: 'child_id', as: 'child' });
SessionFinancialAidRequest.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });
SessionFinancialAidRequest.belongsTo(User, { foreignKey: 'decided_by_manager_id', as: 'decidedBy' });
SessionFinancialAidRequest.belongsTo(FinancialAssistanceRequest, { foreignKey: 'parent_financial_request_id', as: 'parentFinancialRequest' });

module.exports = SessionFinancialAidRequest;
