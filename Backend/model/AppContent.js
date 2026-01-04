// models/AppContent.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User'); // لازم يكون قبل الـ belongsTo

const AppContent = sequelize.define('AppContent', {
  content_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  content_type: {
    type: DataTypes.ENUM('help_section', 'about_section', 'faq', 'privacy_policy', 'terms_of_service'),
    allowNull: false
  },
  title_ar: { type: DataTypes.STRING(255), allowNull: false },
  title_en: { type: DataTypes.STRING(255), allowNull: false },
  content_ar: { type: DataTypes.TEXT, allowNull: false },
  content_en: { type: DataTypes.TEXT, allowNull: false },
  section_key: { type: DataTypes.STRING(100), unique: true, allowNull: false },
  display_order: { type: DataTypes.INTEGER, defaultValue: 0 },
  is_active: { type: DataTypes.BOOLEAN, defaultValue: true },
  icon: { type: DataTypes.STRING(100), comment: 'Icon name for the section' },
  metadata: { type: DataTypes.JSON, defaultValue: {} },
  created_by: {
    type: DataTypes.BIGINT.UNSIGNED,
    references: { model: 'User', key: 'user_id' }
  },
  updated_by: {
    type: DataTypes.BIGINT.UNSIGNED,
    references: { model: 'User', key: 'user_id' }
  }
}, {
  tableName: 'AppContent',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

// بعد تعريف AppContent، عرف الـ associations
AppContent.belongsTo(User, { foreignKey: 'created_by', as: 'creator' });
AppContent.belongsTo(User, { foreignKey: 'updated_by', as: 'updater' });

module.exports = AppContent;
