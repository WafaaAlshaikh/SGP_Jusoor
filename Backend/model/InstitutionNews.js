const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Institution = require('./Institution');

const InstitutionNews = sequelize.define('InstitutionNews', {
  news_id: {
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
  title: {
    type: DataTypes.STRING(200),
    allowNull: false,
  },
  summary: {
    type: DataTypes.STRING(400),
    allowNull: true,
  },
  content: {
    type: DataTypes.TEXT('long'),
    allowNull: true,
  },
  cover_image_url: {
    type: DataTypes.STRING(500),
    allowNull: true,
  },
  published_at: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  is_published: {
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
  tableName: 'InstitutionNews',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
});

InstitutionNews.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });

module.exports = InstitutionNews;
