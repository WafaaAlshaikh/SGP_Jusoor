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
      // الصلاحيات الأساسية
      can_manage_institutions: true,
      can_manage_users: true,
      can_manage_reports: true,
      can_view_statistics: true,
      can_manage_settings: true,
      can_manage_donations: true,
      
      // صلاحيات المحتوى المضافة
      can_manage_content: true,
      can_view_content: true,
      can_create_content: true,
      can_edit_content: true,
      can_delete_content: true,
      can_reorder_content: true
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