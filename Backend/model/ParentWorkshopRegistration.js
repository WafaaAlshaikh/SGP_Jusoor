const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const ParentWorkshop = require('./ParentWorkshop');
const Parent = require('./Parent');

const ParentWorkshopRegistration = sequelize.define('ParentWorkshopRegistration', {
  id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
  workshop_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  parent_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  status: {
    type: DataTypes.ENUM('registered', 'waitlist', 'attended', 'cancelled'),
    allowNull: false,
    defaultValue: 'registered'
  }
}, {
  tableName: 'ParentWorkshopRegistrations'
});

ParentWorkshopRegistration.belongsTo(ParentWorkshop, { foreignKey: 'workshop_id' });
ParentWorkshopRegistration.belongsTo(Parent, { foreignKey: 'parent_id' });

module.exports = ParentWorkshopRegistration;
