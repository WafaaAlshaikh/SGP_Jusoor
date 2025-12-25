const {
  Invoice,
  Payment,
  User,
  Child,
  Parent,
  Specialist,
  Questionnaire,
  Question,
  QuestionnaireResponse,
  ChildTeam,
  ChildTeamMember,
  TeamRoom,
  TeamActivity,
  Institution
} = require('./index');

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