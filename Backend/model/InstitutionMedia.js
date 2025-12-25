const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Institution = require('./Institution');

const InstitutionMedia = sequelize.define('InstitutionMedia', {
  institution_media_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    autoIncrement: true,
    primaryKey: true
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: Institution,
      key: 'institution_id'
    }
  },
  media_type: {
    type: DataTypes.ENUM('logo', 'cover', 'gallery', 'video'),
    allowNull: false
  },
  url: {
    type: DataTypes.STRING(500),
    allowNull: false
  },
  title: {
    type: DataTypes.STRING(150),
    allowNull: true
  },
  description: {
    type: DataTypes.STRING(500),
    allowNull: true
  },
  sort_order: {
    type: DataTypes.INTEGER,
    allowNull: true,
    defaultValue: 0
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'InstitutionMedia',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

InstitutionMedia.belongsTo(Institution, { foreignKey: 'institution_id' });

module.exports = InstitutionMedia;
