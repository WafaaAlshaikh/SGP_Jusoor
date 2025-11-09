const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Resource = require('./Resource');
const Diagnosis = require('./Diagnosis');

const ResourceDiagnosis = sequelize.define('ResourceDiagnosis', {
  resource_id: {
    type: DataTypes.INTEGER,
    references: { model: Resource, key: 'resource_id' },
    primaryKey: true
  },
  diagnosis_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    references: { model: Diagnosis, key: 'diagnosis_id' },
    primaryKey: true
  }
}, {
  tableName: 'resource_diagnosis',
  timestamps: false
});

module.exports = ResourceDiagnosis;
