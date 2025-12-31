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
  Institution,
  AdminUser,
  AuditLog,
  EquipmentCategory,
  EquipmentDonation,
  InstitutionEquipmentInventory,
  ChildEquipmentNeed,
  EquipmentAllocation,
  EquipmentItemHistory
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

// في model/relations.js أضف:
// AdminUser relations
User.hasOne(AdminUser, { foreignKey: 'admin_id' });
AdminUser.belongsTo(User, { foreignKey: 'admin_id' });

// AuditLog relations
AuditLog.belongsTo(User, { foreignKey: 'admin_id', as: 'admin' });
User.hasMany(AuditLog, { foreignKey: 'admin_id', as: 'adminActions' });

console.log('✅ تم إنشاء علاقات الجداول الجديدة');

// أضف في نهاية الملف:
// علاقات التبرع العيني
EquipmentCategory.hasMany(EquipmentDonation, {
  foreignKey: 'category_id',
  as: 'equipmentDonations'
});

EquipmentDonation.belongsTo(EquipmentCategory, {
  foreignKey: 'category_id',
  as: 'category'
});

EquipmentDonation.belongsTo(Institution, {
  foreignKey: 'institution_id',
  as: 'institution'
});

Institution.hasMany(EquipmentDonation, {
  foreignKey: 'institution_id',
  as: 'equipmentDonations'
});

EquipmentDonation.belongsTo(User, {
  foreignKey: 'donor_id',
  as: 'donor',
  required: false
});

User.hasMany(EquipmentDonation, {
  foreignKey: 'donor_id',
  as: 'equipmentDonations'
});

// علاقات مخزون المعدات (Inventory)
EquipmentCategory.hasMany(InstitutionEquipmentInventory, {
  foreignKey: 'category_id',
  as: 'inventoryItems'
});

InstitutionEquipmentInventory.belongsTo(EquipmentCategory, {
  foreignKey: 'category_id',
  as: 'category'
});

Institution.hasMany(InstitutionEquipmentInventory, {
  foreignKey: 'institution_id',
  as: 'equipmentInventory'
});

InstitutionEquipmentInventory.belongsTo(Institution, {
  foreignKey: 'institution_id',
  as: 'institution'
});

InstitutionEquipmentInventory.belongsTo(EquipmentDonation, {
  foreignKey: 'source_donation_id',
  as: 'sourceDonation',
  required: false
});

// علاقات احتياج الطفل (Needs)
Child.hasMany(ChildEquipmentNeed, {
  foreignKey: 'child_id',
  as: 'equipmentNeeds'
});

ChildEquipmentNeed.belongsTo(Child, {
  foreignKey: 'child_id',
  as: 'child'
});

Institution.hasMany(ChildEquipmentNeed, {
  foreignKey: 'institution_id',
  as: 'childEquipmentNeeds'
});

ChildEquipmentNeed.belongsTo(Institution, {
  foreignKey: 'institution_id',
  as: 'institution'
});

EquipmentCategory.hasMany(ChildEquipmentNeed, {
  foreignKey: 'category_id',
  as: 'childEquipmentNeeds'
});

ChildEquipmentNeed.belongsTo(EquipmentCategory, {
  foreignKey: 'category_id',
  as: 'category',
  required: false
});

// علاقات التخصيص (Allocations)
InstitutionEquipmentInventory.hasMany(EquipmentAllocation, {
  foreignKey: 'inventory_item_id',
  as: 'allocations'
});

EquipmentAllocation.belongsTo(InstitutionEquipmentInventory, {
  foreignKey: 'inventory_item_id',
  as: 'inventoryItem'
});

ChildEquipmentNeed.hasMany(EquipmentAllocation, {
  foreignKey: 'need_id',
  as: 'allocations'
});

EquipmentAllocation.belongsTo(ChildEquipmentNeed, {
  foreignKey: 'need_id',
  as: 'need',
  required: false
});

Child.hasMany(EquipmentAllocation, {
  foreignKey: 'child_id',
  as: 'equipmentAllocations'
});

EquipmentAllocation.belongsTo(Child, {
  foreignKey: 'child_id',
  as: 'child',
  required: false
});

Institution.hasMany(EquipmentAllocation, {
  foreignKey: 'institution_id',
  as: 'equipmentAllocations'
});

EquipmentAllocation.belongsTo(Institution, {
  foreignKey: 'institution_id',
  as: 'institution'
});

EquipmentAllocation.belongsTo(User, {
  foreignKey: 'allocated_by_user_id',
  as: 'allocatedBy',
  required: false
});

// علاقات سجل المعدات (History)
InstitutionEquipmentInventory.hasMany(EquipmentItemHistory, {
  foreignKey: 'inventory_item_id',
  as: 'history'
});

EquipmentItemHistory.belongsTo(InstitutionEquipmentInventory, {
  foreignKey: 'inventory_item_id',
  as: 'inventoryItem'
});

EquipmentItemHistory.belongsTo(Institution, {
  foreignKey: 'institution_id',
  as: 'institution'
});

EquipmentItemHistory.belongsTo(User, {
  foreignKey: 'actor_user_id',
  as: 'actor',
  required: false
});

module.exports = {
  User,
  Child,
  Specialist,
  Invoice,
  Payment
};