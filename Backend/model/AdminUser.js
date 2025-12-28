// models/AdminUser.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');

const AdminUser = sequelize.define('AdminUser', {
  admin_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  admin_level: {
    type: DataTypes.ENUM('super_admin', 'admin', 'moderator'),
    defaultValue: 'admin'
  },
  permissions: {
    type: DataTypes.JSON,
    defaultValue: {
      can_manage_institutions: true,
      can_manage_users: true,
      can_manage_reports: true,
      can_view_statistics: true,
      can_manage_settings: true,
      can_manage_donations: true
    }
  },
  last_login: {
    type: DataTypes.DATE,
    allowNull: true
  },
  login_count: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  }
}, {
  tableName: 'AdminUsers',
  timestamps: false
});

AdminUser.belongsTo(User, { foreignKey: 'admin_id' });

module.exports = AdminUser;