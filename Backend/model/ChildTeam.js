const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Child = require('./Child');
const Institution = require('./Institution');

const ChildTeam = sequelize.define('ChildTeam', {
  team_id: { 
    type: DataTypes.INTEGER, 
    primaryKey: true, 
    autoIncrement: true 
  },
  child_id: { 
    type: DataTypes.BIGINT.UNSIGNED, 
    allowNull: false 
  },
  institution_id: { 
    type: DataTypes.BIGINT.UNSIGNED, 
    allowNull: false 
  },
  team_type: { 
    type: DataTypes.ENUM('multidisciplinary', 'specialized'), 
    defaultValue: 'multidisciplinary' 
  },
  status: { 
    type: DataTypes.ENUM('active', 'inactive', 'completed'), 
    defaultValue: 'active' 
  },
  created_at: { 
    type: DataTypes.DATE, 
    defaultValue: DataTypes.NOW 
  }
}, {
  tableName: 'ChildTeams',
  timestamps: false
});

ChildTeam.belongsTo(Child, { foreignKey: 'child_id' });
ChildTeam.belongsTo(Institution, { foreignKey: 'institution_id' });

module.exports = ChildTeam;