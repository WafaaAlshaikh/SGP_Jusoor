const Invoice = require('./Invoice');
const Payment = require('./Payment');
const User = require('./User');
const Child = require('./Child');
const Parent = require('./Parent');
const Specialist = require('./Specialist');
const Questionnaire = require('./Questionnaire');
const Question = require('./Question');
const QuestionnaireResponse = require('./QuestionnaireResponse');


Invoice.hasMany(Payment, {
  foreignKey: 'invoice_id',
  as: 'Payments'
});

Payment.belongsTo(Invoice, {
  foreignKey: 'invoice_id',
  as: 'Invoice'
});

console.log('✅ Payment-Invoice relations established');



// No relationships needed for QuestionnaireResponse - it's standalone
module.exports = {
  User,
  Child,
  Specialist,
  Invoice,
  Payment
};