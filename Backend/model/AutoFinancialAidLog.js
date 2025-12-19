// models/AutoFinancialAidLog.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const AutoFinancialAidLog = sequelize.define('AutoFinancialAidLog', {
  log_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  session_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'Sessions',
      key: 'session_id'
    }
  },
  parent_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: 'Parents',
      key: 'parent_id'
    }
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: 'Institutions',
      key: 'institution_id'
    }
  },
  original_price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    defaultValue: 0.00
  },
  applied_discount_percentage: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: false,
    defaultValue: 0.00
  },
  discount_amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    defaultValue: 0.00
  },
  final_price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    defaultValue: 0.00
  },
  parent_financial_tier: {
    type: DataTypes.STRING(50),
    allowNull: true
  },
  parent_financial_score: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  available_donation_balance: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true
  },
  applied_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'AutoFinancialAidLogs',
  timestamps: false,
  indexes: [
    {
      name: 'idx_auto_aid_parent',
      fields: ['parent_id']
    },
    {
      name: 'idx_auto_aid_session',
      fields: ['session_id']
    },
    {
      name: 'idx_auto_aid_date',
      fields: ['applied_at']
    }
  ]
});

// العلاقات
AutoFinancialAidLog.associate = (models) => {
  AutoFinancialAidLog.belongsTo(models.Session, {
    foreignKey: 'session_id',
    as: 'Session'
  });
  
  AutoFinancialAidLog.belongsTo(models.Parent, {
    foreignKey: 'parent_id',
    as: 'Parent'
  });
  
  AutoFinancialAidLog.belongsTo(models.Institution, {
    foreignKey: 'institution_id',
    as: 'Institution'
  });
};

module.exports = AutoFinancialAidLog;