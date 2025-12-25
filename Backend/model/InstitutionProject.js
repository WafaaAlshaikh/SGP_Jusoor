const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Institution = require('./Institution');

const InstitutionProject = sequelize.define('InstitutionProject', {
  project_id: {
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
  description: {
    type: DataTypes.TEXT('long'),
    allowNull: true,
  },
  status: {
    type: DataTypes.ENUM('planned', 'active', 'completed'),
    allowNull: false,
    defaultValue: 'active',
  },
  cover_image_url: {
    type: DataTypes.STRING(500),
    allowNull: true,
  },
  goal_amount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: true,
  },
  raised_amount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: true,
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
  tableName: 'InstitutionProjects',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
});

InstitutionProject.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });

module.exports = InstitutionProject;
