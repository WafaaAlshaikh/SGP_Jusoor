const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Specialist = require('./Specialist');

const SpecialistSchedule = sequelize.define('SpecialistSchedule', {
  schedule_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  specialist_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  day_of_week: { type: DataTypes.ENUM('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'), allowNull: false },
  start_time: { type: DataTypes.TIME, allowNull: false },
  end_time: { type: DataTypes.TIME, allowNull: false }
}, { tableName: 'SpecialistSchedules', timestamps: false });

SpecialistSchedule.belongsTo(Specialist, { foreignKey: 'specialist_id' });

module.exports = SpecialistSchedule;
