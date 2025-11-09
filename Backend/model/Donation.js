const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Donation = sequelize.define('Donation', {
  donation_id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
  donor_id: { type: DataTypes.INTEGER, allowNull: false },
  institution_id: { type: DataTypes.INTEGER, allowNull: false },
  campaign_id: { type: DataTypes.INTEGER },
  amount: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  date: { type: DataTypes.DATE, defaultValue: DataTypes.NOW }
});

module.exports = Donation;