const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const AIDonorReport = sequelize.define('AIDonorReport', {
  report_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  donor_id: { type: DataTypes.INTEGER, allowNull: false },
  institution_id: { type: DataTypes.INTEGER },
  campaign_id: { type: DataTypes.INTEGER },
  report_text: { type: DataTypes.TEXT, allowNull: false },
  recommendation_type: { type: DataTypes.ENUM('Similar Campaign', 'Impact Report'), defaultValue: 'Impact Report' },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW }
});

module.exports = AIDonorReport;