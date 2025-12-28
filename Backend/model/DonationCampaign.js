const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

// Represents a donation campaign for an institution (goal-based fundraising)
const DonationCampaign = sequelize.define('DonationCampaign', {
  campaign_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  institution_id: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  target_amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    defaultValue: 0
  },
  start_date: {
    type: DataTypes.DATE,
    allowNull: true
  },
  end_date: {
    type: DataTypes.DATE,
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('Upcoming', 'Active', 'Completed', 'Archived'),
    allowNull: false,
    defaultValue: 'Upcoming'
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  amount_raised: {
  type: DataTypes.DECIMAL(10, 2),
  allowNull: false,
  defaultValue: 0
},

}, {
  tableName: 'DonationCampaigns',
  timestamps: false
});
DonationCampaign.associate = (models) => {
  DonationCampaign.hasMany(models.Donation, {
    foreignKey: 'campaign_id',
    as: 'donations'
  });
};


module.exports = DonationCampaign;
