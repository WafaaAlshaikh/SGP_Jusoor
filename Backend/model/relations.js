const Invoice = require('./Invoice');
const Payment = require('./Payment');
const User = require('./User');
const Child = require('./Child');
const Parent = require('./Parent');
const Specialist = require('./Specialist');
const Questionnaire = require('./Questionnaire');
const Question = require('./Question');
const QuestionnaireResponse = require('./QuestionnaireResponse');


const ChildTeam = require('./ChildTeam');
const ChildTeamMember = require('./ChildTeamMember');
const TeamRoom = require('./TeamRoom');
const TeamActivity = require('./TeamActivity');
const Institution = require('./Institution');


Invoice.hasMany(Payment, {
  foreignKey: 'invoice_id',
  as: 'Payments'
});

Payment.belongsTo(Invoice, {
  foreignKey: 'invoice_id',
  as: 'Invoice'
});

console.log('✅ Payment-Invoice relations established');




// علاقات ChildTeam
ChildTeam.hasMany(ChildTeamMember, { 
  foreignKey: 'child_team_id', 
  as: 'ChildTeamMembers' 
});
ChildTeamMember.belongsTo(ChildTeam, { 
  foreignKey: 'child_team_id' 
});

ChildTeam.hasOne(TeamRoom, { 
  foreignKey: 'child_team_id', 
  as: 'TeamRoom' 
});
TeamRoom.belongsTo(ChildTeam, { 
  foreignKey: 'child_team_id' 
});

// علاقات TeamRoom
TeamRoom.hasMany(TeamActivity, { 
  foreignKey: 'team_room_id', 
  as: 'TeamActivities' 
});
TeamActivity.belongsTo(TeamRoom, { 
  foreignKey: 'team_room_id' 
});

// علاقات ChildTeamMember مع Specialist
ChildTeamMember.belongsTo(Specialist, { 
  foreignKey: 'specialist_id' 
});
Specialist.hasMany(ChildTeamMember, { 
  foreignKey: 'specialist_id' 
});

// علاقات TeamActivity مع Specialist
TeamActivity.belongsTo(Specialist, { 
  foreignKey: 'specialist_id' 
});
Specialist.hasMany(TeamActivity, { 
  foreignKey: 'specialist_id' 
});

// علاقات Specialist مع User (إذا ما كانت موجودة)
Specialist.belongsTo(User, { 
  foreignKey: 'specialist_id', 
  targetKey: 'user_id' 
});
User.hasOne(Specialist, { 
  foreignKey: 'specialist_id', 
  sourceKey: 'user_id' 
});

console.log('✅ تم إنشاء علاقات الجداول الجديدة');


module.exports = {
  User,
  Child,
  Specialist,
  Invoice,
  Payment
};