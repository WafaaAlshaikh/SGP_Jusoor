const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Child = require('./Child');
const Institution = require('./Institution');
const User = require('./User');

const ChildRegistrationRequest = sequelize.define('ChildRegistrationRequest', {
  request_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  child_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  institution_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  requested_by_parent_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  assigned_manager_id: { type: DataTypes.BIGINT.UNSIGNED },
  status: { type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'), defaultValue: 'Pending' },
  notes: { type: DataTypes.TEXT },
  requested_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  reviewed_at: { type: DataTypes.DATE }
}, { tableName: 'ChildRegistrationRequests', timestamps: false });

ChildRegistrationRequest.belongsTo(Child, { foreignKey: 'child_id' });
ChildRegistrationRequest.belongsTo(Institution, { foreignKey: 'institution_id' });
ChildRegistrationRequest.belongsTo(User, { foreignKey: 'requested_by_parent_id', as: 'requestedByParent' });
ChildRegistrationRequest.belongsTo(User, { foreignKey: 'assigned_manager_id', as: 'assignedManager' });

module.exports = ChildRegistrationRequest;

