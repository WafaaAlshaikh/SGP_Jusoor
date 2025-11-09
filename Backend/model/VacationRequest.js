const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Specialist = require('./Specialist');
const Institution = require('./Institution');

const VacationRequest = sequelize.define('VacationRequest', {
  request_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  specialist_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  institution_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  start_date: { type: DataTypes.DATEONLY, allowNull: false },
  end_date: { type: DataTypes.DATEONLY, allowNull: false },
  reason: { type: DataTypes.STRING(255), allowNull: true },
  status: { 
    type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'),
    defaultValue: 'Pending'
  }
}, { tableName: 'VacationRequests', timestamps: false });

VacationRequest.belongsTo(Specialist, { foreignKey: 'specialist_id', as: 'specialist' });
VacationRequest.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });

module.exports = VacationRequest;