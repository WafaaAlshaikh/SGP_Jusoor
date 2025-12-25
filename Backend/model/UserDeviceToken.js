const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');

const UserDeviceToken = sequelize.define('UserDeviceToken', {
  user_device_token_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    autoIncrement: true,
    primaryKey: true,
  },
  user_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: User,
      key: 'user_id',
    },
  },
  token: {
    type: DataTypes.STRING(500),
    allowNull: false,
  },
  platform: {
    type: DataTypes.STRING(30),
    allowNull: true,
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true,
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
}, {
  tableName: 'UserDeviceTokens',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
});

UserDeviceToken.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

module.exports = UserDeviceToken;
