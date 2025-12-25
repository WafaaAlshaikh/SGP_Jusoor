const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Institution = require('./Institution');

const InstitutionProgram = sequelize.define('InstitutionProgram', {
  program_id: {
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
    type: DataTypes.STRING(800),
    allowNull: true,
  },
  icon: {
    type: DataTypes.STRING(80),
    allowNull: true,
  },
  image_url: {
    type: DataTypes.STRING(500),
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
  tableName: 'InstitutionPrograms',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
});

InstitutionProgram.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });

module.exports = InstitutionProgram;
