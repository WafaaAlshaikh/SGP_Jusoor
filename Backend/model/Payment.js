const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');


const Payment = sequelize.define('Payment', {
  payment_id: { 
    type: DataTypes.INTEGER, 
    primaryKey: true, 
    autoIncrement: true 
  },
  invoice_id: { 
    type: DataTypes.INTEGER, 
    allowNull: false
    
  },
  amount: { 
    type: DataTypes.DECIMAL(10, 2), 
    allowNull: false 
  },
  payment_method: { 
    type: DataTypes.ENUM('Credit Card', 'Cash', 'Bank Transfer', 'Wallet'), 
    allowNull: false 
  },
  payment_gateway: {
    type: DataTypes.STRING(50)
  },
  transaction_id: {
    type: DataTypes.STRING(100),
    unique: true
  },
  status: { 
    type: DataTypes.ENUM('Pending', 'Completed', 'Failed', 'Refunded'), 
    defaultValue: 'Pending' 
  },
  payment_date: { 
    type: DataTypes.DATE, 
    defaultValue: DataTypes.NOW 
  },
  gateway_response: {
    type: DataTypes.TEXT
  },
  refund_amount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0
  }
}, { 
  tableName: 'Payments', 
  timestamps: false 
});


module.exports = Payment;