const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Institution = require('./Institution');

const InstitutionPageContent = sequelize.define('InstitutionPageContent', {
  content_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    autoIncrement: true,
    primaryKey: true,
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: Institution,
      key: 'institution_id',
    },
  },
  key: {
    type: DataTypes.ENUM('about', 'mission', 'our_world', 'contact', 'donate'),
    allowNull: false,
  },
  title: {
    type: DataTypes.STRING(150),
    allowNull: true,
  },
  content: {
    type: DataTypes.TEXT('long'),
    allowNull: false,
  },
  sort_order: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
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
  tableName: 'InstitutionPageContent',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
});

InstitutionPageContent.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });

module.exports = InstitutionPageContent;
