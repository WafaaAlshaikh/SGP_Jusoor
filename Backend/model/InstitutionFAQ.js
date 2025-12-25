const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Institution = require('./Institution');

const InstitutionFAQ = sequelize.define('InstitutionFAQ', {
  faq_id: {
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
  question: {
    type: DataTypes.STRING(300),
    allowNull: false,
  },
  answer: {
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
  tableName: 'InstitutionFAQ',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
});

InstitutionFAQ.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });

module.exports = InstitutionFAQ;
