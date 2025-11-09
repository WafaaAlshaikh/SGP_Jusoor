const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');

const Notification = sequelize.define('Notification', {
  notification_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },

  // 🔹 المستخدم اللي وُجّه إليه الإشعار (مثلاً الأهل أو المدير)
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


  // 🔹 العنوان المختصر للإشعار
  title: {
    type: DataTypes.STRING,
    allowNull: false
  },

  // 🔹 محتوى الرسالة
  message: {
    type: DataTypes.TEXT,
    allowNull: false
  },

  // 🔹 نوع الإشعار (delete_request, session_update, status_update, session_completed, ...)
  type: {
    type: DataTypes.ENUM(
      'delete_request',
      'session_update',
      'status_update',
      'session_completed',
      'session_reminder',
      'session_cancelled',
      'vacation_request',
      'general'
    ),
    allowNull: false,
    defaultValue: 'general'
  },

  // 🔹 ID العنصر المرتبط (مثلاً رقم الجلسة)
  related_id: {
    type: DataTypes.INTEGER,
    allowNull: true
  },

  // 🔹 هل تمت قراءة الإشعار أم لا
  is_read: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },

  // 🔹 تاريخ إنشاء الإشعار
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'notifications',
  timestamps: false
});

// العلاقة مع جدول المستخدم
Notification.belongsTo(User, { foreignKey: 'user_id', as: 'user' });

module.exports = Notification;