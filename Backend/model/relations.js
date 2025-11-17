const Invoice = require('./Invoice');
const Payment = require('./Payment');
const User = require('./User');
const Child = require('./Child');
const Specialist = require('./Specialist');
const Questionnaire = require('./Questionnaire');
const QuestionnaireAnswer = require('./QuestionnaireAnswer');
const QuestionnaireResult = require('./QuestionnaireResult');

Invoice.hasMany(Payment, {
  foreignKey: 'invoice_id',
  as: 'Payments'
});

Payment.belongsTo(Invoice, {
  foreignKey: 'invoice_id',
  as: 'Invoice'
});

console.log('✅ Payment-Invoice relations established');


// Questionnaire relationships
Questionnaire.belongsTo(User, { foreignKey: 'parent_id', as: 'QuestionnaireParent' });
Questionnaire.belongsTo(Child, { foreignKey: 'child_id', as: 'QuestionnaireChild' });
Questionnaire.hasMany(QuestionnaireAnswer, { foreignKey: 'questionnaire_id', as: 'Answers' });
Questionnaire.hasOne(QuestionnaireResult, { foreignKey: 'questionnaire_id', as: 'Result' });

User.hasMany(Questionnaire, { foreignKey: 'parent_id', as: 'ParentQuestionnaires' });
Child.hasMany(Questionnaire, { foreignKey: 'child_id', as: 'ChildQuestionnaires' });

QuestionnaireAnswer.belongsTo(Questionnaire, { foreignKey: 'questionnaire_id' });

QuestionnaireResult.belongsTo(Questionnaire, { foreignKey: 'questionnaire_id' });
QuestionnaireResult.belongsTo(Specialist, { foreignKey: 'specialist_id', as: 'ReviewedBySpecialist' });


module.exports = {
  Questionnaire,
  QuestionnaireAnswer,
  QuestionnaireResult,
  User,
  Child,
  Specialist
};