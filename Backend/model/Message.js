const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Message = sequelize.define('Message', {
  message_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  sender_id: { type: DataTypes.INTEGER, allowNull: false },
  receiver_id: { type: DataTypes.INTEGER, allowNull: false },
  content: { type: DataTypes.TEXT, allowNull: false },
  attachment: DataTypes.STRING(255),
  date: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  is_read: { type: DataTypes.BOOLEAN, defaultValue: false }
});

module.exports = Message;