const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');

const Notification = sequelize.define('Notification', {
  notification_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },

  user_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true,
    references: {
      model: User,
      key: 'user_id'
    },
    onDelete: 'CASCADE',
    onUpdate: 'CASCADE'
  },

  title: {
    type: DataTypes.STRING(255),
    allowNull: false
  },

  message: {
    type: DataTypes.TEXT,
    allowNull: false
  },

  // ⬇⬇⬇ type now VARCHAR(50) instead of ENUM
  type: {
    type: DataTypes.STRING(50),
    allowNull: false,
    defaultValue: 'general'
  },

  related_id: {
    type: DataTypes.INTEGER,
    allowNull: true
  },

  is_read: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },

  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'notifications',
  timestamps: false
});

Notification.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

module.exports = Notification;
