const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const EquipmentDonation = sequelize.define('EquipmentDonation', {
  equipment_donation_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  donor_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true,
    comment: 'NULL للتبرعات المجهولة، يمكن أن يكون user_id'
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  category_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  equipment_name: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  condition: {
    type: DataTypes.ENUM('new', 'used_good', 'used_fair', 'needs_repair'),
    defaultValue: 'used_good'
  },
  estimated_value: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('pending', 'approved', 'rejected', 'scheduled', 'delivered', 'cancelled'),
    defaultValue: 'pending'
  },
  delivery_type: {
    type: DataTypes.ENUM('pickup', 'delivery'),
    defaultValue: 'pickup'
  },
  preferred_date: {
    type: DataTypes.DATE,
    allowNull: true
  },
  actual_delivery_date: {
    type: DataTypes.DATE,
    allowNull: true
  },
  contact_person: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  contact_phone: {
    type: DataTypes.STRING(20),
    allowNull: true
  },
  contact_email: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  images: {
    type: DataTypes.JSON,
    allowNull: true,
    comment: 'URLs للصور'
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true,
    comment: 'ملاحظات من المتبرع'
  },
  admin_notes: {
    type: DataTypes.TEXT,
    allowNull: true,
    comment: 'ملاحظات من المدير'
  },
  rejection_reason: {
    type: DataTypes.TEXT,
    allowNull: true,
    comment: 'سبب الرفض إذا تم رفض الطلب'
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'EquipmentDonations',
  timestamps: false
});

module.exports = EquipmentDonation;