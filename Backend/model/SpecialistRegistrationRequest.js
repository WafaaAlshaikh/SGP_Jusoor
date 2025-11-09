const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');
const Institution = require('./Institution');

const SpecialistRegistrationRequest = sequelize.define('SpecialistRegistrationRequest', {
  request_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  user_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  institution_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  specialization: { type: DataTypes.STRING(100), allowNull: false },
  years_experience: { type: DataTypes.INTEGER },
  cv_url: { type: DataTypes.STRING(500) },
  status: { type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'), defaultValue: 'Pending' },
  requested_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  reviewed_by: { type: DataTypes.BIGINT.UNSIGNED },
  reviewed_at: { type: DataTypes.DATE }
}, { tableName: 'SpecialistRegistrationRequests', timestamps: false });

SpecialistRegistrationRequest.belongsTo(User, { foreignKey: 'user_id' });
SpecialistRegistrationRequest.belongsTo(Institution, { foreignKey: 'institution_id' });
SpecialistRegistrationRequest.belongsTo(User, { foreignKey: 'reviewed_by', as: 'reviewedBy' });

module.exports = SpecialistRegistrationRequest;
