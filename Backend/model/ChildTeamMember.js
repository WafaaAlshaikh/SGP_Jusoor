const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const ChildTeam = require('./ChildTeam');
const Specialist = require('./Specialist');

const ChildTeamMember = sequelize.define('ChildTeamMember', {
  member_id: { 
    type: DataTypes.INTEGER, 
    primaryKey: true, 
    autoIncrement: true 
  },
  child_team_id: { 
    type: DataTypes.INTEGER, 
    allowNull: false 
  },
  specialist_id: { 
    type: DataTypes.BIGINT.UNSIGNED, 
    allowNull: false 
  },
  role: { 
    type: DataTypes.STRING(100), 
    allowNull: false 
  },
  status: { 
    type: DataTypes.ENUM('active', 'inactive', 'transferred'), 
    defaultValue: 'active' 
  },
  assigned_date: { 
    type: DataTypes.DATE, 
    defaultValue: DataTypes.NOW 
  },
  notes: { 
    type: DataTypes.TEXT, 
    allowNull: true 
  }
}, {
  tableName: 'ChildTeamMembers',
  timestamps: false
});

ChildTeamMember.belongsTo(ChildTeam, { foreignKey: 'child_team_id' });
ChildTeamMember.belongsTo(Specialist, { foreignKey: 'specialist_id' });

module.exports = ChildTeamMember;