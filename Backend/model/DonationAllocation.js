const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

// يربط بين التبرعات / رصيد المؤسسة وبين الفواتير و/أو طلبات المساعدة المالية
const DonationAllocation = sequelize.define('DonationAllocation', {
  allocation_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false
  },
  // يمكن مستقبلاً ربطها بتبرع محدد أو تركها null في حال من "رصيد عام"
  donation_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true
  },
  invoice_id: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  financial_assistance_request_id: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  amount_allocated: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'DonationAllocations',
  timestamps: false
});


module.exports = DonationAllocation;
