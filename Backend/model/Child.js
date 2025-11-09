// models/Child.js - النسخة المحدثة
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Parent = require('./Parent');
const Diagnosis = require('./Diagnosis');
const Institution = require('./Institution');

const Child = sequelize.define('Child', {
  child_id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
  parent_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  full_name: { type: DataTypes.STRING(100), allowNull: false },
  date_of_birth: { type: DataTypes.DATE },
  gender: { type: DataTypes.ENUM('Male', 'Female') },
  diagnosis_id: { 
    type: DataTypes.BIGINT.UNSIGNED, 
    allowNull: true
  },
  suspected_condition: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  symptoms_description: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  ai_suggested_diagnosis: {
    type: DataTypes.JSON,
    allowNull: true
  },
  ai_confidence_score: {
    type: DataTypes.DECIMAL(5, 4),
    allowNull: true
  },
  recommended_institutions: {
    type: DataTypes.JSON, 
    allowNull: true
  },
  risk_level: {  
    type: DataTypes.ENUM('Low', 'Medium', 'High'),
    allowNull: true 
  },
  photo: { type: DataTypes.STRING(255) },
  medical_history: { type: DataTypes.TEXT },
  current_institution_id: { type: DataTypes.BIGINT.UNSIGNED },
  registration_status: { 
    type: DataTypes.ENUM('Pending', 'Approved', 'Not Registered', 'Archived'), 
    defaultValue: 'Not Registered' 
  },
  child_identifier: { 
    type: DataTypes.STRING(50), 
    allowNull: true 
  },
  city: { 
    type: DataTypes.STRING(100), 
    allowNull: true 
  },
  address: { 
    type: DataTypes.TEXT, 
    allowNull: true 
  },
  parent_phone: { 
    type: DataTypes.STRING(20), 
    allowNull: true 
  },
  school_info: { 
    type: DataTypes.TEXT, 
    allowNull: true 
  },
  previous_services: { 
    type: DataTypes.TEXT, 
    allowNull: true 
  },
  additional_notes: { 
    type: DataTypes.TEXT, 
    allowNull: true 
  },
  consent_given: { 
    type: DataTypes.BOOLEAN, 
    defaultValue: false 
  },
location_lat: {
  type: DataTypes.FLOAT,
  allowNull: true
},
location_lng: {
  type: DataTypes.FLOAT,
  allowNull: true
},
  deleted_at: { type: DataTypes.DATE, allowNull: true }
}, { 
  tableName: 'Children', 
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

Child.belongsTo(Parent, { foreignKey: 'parent_id' });
Child.belongsTo(Diagnosis, { foreignKey: 'diagnosis_id', as: 'Diagnosis' });
Child.belongsTo(Institution, { foreignKey: 'current_institution_id', as: 'currentInstitution' });

module.exports = Child;