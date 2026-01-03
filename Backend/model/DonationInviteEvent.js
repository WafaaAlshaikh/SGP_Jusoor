const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const DonationInviteEvent = sequelize.define(
  'DonationInviteEvent',
  {
    event_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      primaryKey: true,
      autoIncrement: true,
    },
    invite_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      allowNull: false,
    },
    event_type: {
      type: DataTypes.ENUM('click', 'checkout_started', 'donation_completed'),
      allowNull: false,
    },
    referred_user_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      allowNull: true,
    },
    donation_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      allowNull: true,
    },
    stripe_session_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    amount: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
    },
    currency: {
      type: DataTypes.STRING(3),
      allowNull: true,
    },
    ip_address: {
      type: DataTypes.STRING(45),
      allowNull: true,
    },
    user_agent: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    created_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: 'DonationInviteEvents',
    timestamps: false,
  },
);

module.exports = DonationInviteEvent;
