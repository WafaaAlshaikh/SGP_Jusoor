const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');
const Institution = require('./Institution');

const Manager = sequelize.define('Manager', {
  manager_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    references: {
      model: User,
      key: 'user_id'
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
  department: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  permissions: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: {
      canManageStaff: true,
      canManageSessions: true,
      canApproveRequests: true,
      canViewReports: true
    }
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
}, {
  tableName: 'Managers',
  timestamps: false
});

Manager.belongsTo(User, { foreignKey: 'manager_id' });
Manager.belongsTo(Institution, { foreignKey: 'institution_id' });

module.exports = Manager;