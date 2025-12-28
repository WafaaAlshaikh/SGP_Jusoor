const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Donation = sequelize.define('Donation', {
  donation_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  donor_id: {
    type: DataTypes.INTEGER,
    allowNull: true, // ⬅️ غير إلى allowNull: true
    defaultValue: null
  },
  institution_id: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  campaign_id: {
    type: DataTypes.INTEGER
  },
  amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  currency: {
    type: DataTypes.STRING(3),
    allowNull: false,
    defaultValue: 'JOD'
  },
  status: {
    type: DataTypes.ENUM('pending', 'completed', 'failed', 'cancelled'),
    defaultValue: 'pending'
  },
  payment_status: {
    type: DataTypes.ENUM('unpaid', 'paid', 'failed'),
    defaultValue: 'unpaid'
  },
  payment_method: {
    type: DataTypes.STRING(50),
    defaultValue: 'stripe'
  },
  stripe_session_id: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  stripe_payment_intent_id: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  stripe_customer_id: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  stripe_subscription_id: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  donation_type: {
    type: DataTypes.ENUM('one_time', 'monthly'),
    defaultValue: 'one_time'
  },
  // ⭐ إضافة حقول للمتبرع المجهول
  anonymous_donor: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  donor_email: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  donor_name: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  donor_phone: {
    type: DataTypes.STRING(20),
    allowNull: true
  },
  date: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  payment_date: {
    type: DataTypes.DATE,
    allowNull: true
  },
  receipt_url: {
    type: DataTypes.STRING(500),
    allowNull: true
  },
  ip_address: {
    type: DataTypes.STRING(45),
    allowNull: true
  },
  user_agent: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  expires_at: {
    type: DataTypes.DATE,
    allowNull: true
  }
}, {
  tableName: 'Donations',
  timestamps: false
});

module.exports = Donation;