const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Session = require('./Session');
const User = require('./User');
const Institution = require('./Institution');

const Invoice = sequelize.define('Invoice', {
  invoice_id: { 
    type: DataTypes.INTEGER, 
    primaryKey: true, 
    autoIncrement: true 
  },
  session_id: { 
    type: DataTypes.INTEGER, 
    allowNull: false,
    references: {
      model: Session,
      key: 'session_id'
    }
  },
  parent_id: { 
    type: DataTypes.BIGINT.UNSIGNED, 
    allowNull: false,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  institution_id: { 
    type: DataTypes.BIGINT.UNSIGNED, 
    allowNull: false,
    references: {
      model: Institution,
      key: 'institution_id'
    }
  },
  invoice_number: {
    type: DataTypes.STRING(50),
    unique: true,
    allowNull: false
  },
  amount: { 
    type: DataTypes.DECIMAL(10, 2), 
    allowNull: false 
  },
  tax_amount: { 
    type: DataTypes.DECIMAL(10, 2), 
    defaultValue: 0 
  },
  total_amount: { 
    type: DataTypes.DECIMAL(10, 2), 
    allowNull: false 
  },
  status: { 
    type: DataTypes.ENUM('Draft', 'Pending', 'Paid', 'Overdue', 'Cancelled'), 
    defaultValue: 'Draft' 
  },
  due_date: { 
    type: DataTypes.DATE, 
    allowNull: false 
  },
  issued_date: { 
    type: DataTypes.DATE, 
    defaultValue: DataTypes.NOW 
  },
  paid_date: { 
    type: DataTypes.DATE 
  },
  refund_amount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0
  },
  refund_reason: {
    type: DataTypes.TEXT
  },
  refunded_at: {
    type: DataTypes.DATE
  },
  notes: {
    type: DataTypes.TEXT
  }
}, { 
  tableName: 'Invoices', 
  timestamps: false 
});

Invoice.belongsTo(Session, { foreignKey: 'session_id' });
Invoice.belongsTo(User, { foreignKey: 'parent_id', as: 'parent' });
Invoice.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });


module.exports = Invoice;