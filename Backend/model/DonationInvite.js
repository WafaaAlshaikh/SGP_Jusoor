const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const DonationInvite = sequelize.define(
  'DonationInvite',
  {
    invite_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      primaryKey: true,
      autoIncrement: true,
    },
    inviter_user_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      allowNull: false,
    },
    institution_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      allowNull: false,
    },
    campaign_id: {
      type: DataTypes.BIGINT.UNSIGNED,
      allowNull: true,
    },
    code: {
      type: DataTypes.STRING(32),
      allowNull: false,
      unique: true,
    },
    share_message: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    is_active: {
      type: DataTypes.BOOLEAN,
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
  },
  {
    tableName: 'DonationInvites',
    timestamps: false,
  },
);

module.exports = DonationInvite;
