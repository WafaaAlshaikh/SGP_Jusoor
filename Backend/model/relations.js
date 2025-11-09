const Invoice = require('./Invoice');
const Payment = require('./Payment');

Invoice.hasMany(Payment, { 
  foreignKey: 'invoice_id', 
  as: 'Payments'
});

Payment.belongsTo(Invoice, { 
  foreignKey: 'invoice_id',
  as: 'Invoice'
});

console.log('✅ Payment-Invoice relations established');