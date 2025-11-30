const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const ChildTeam = require('./ChildTeam');

const TeamRoom = sequelize.define('TeamRoom', {
  room_id: { 
    type: DataTypes.INTEGER, 
    primaryKey: true, 
    autoIncrement: true 
  },
  child_team_id: { 
    type: DataTypes.INTEGER, 
    allowNull: false 
  },
  room_name: { 
    type: DataTypes.STRING(255), 
    allowNull: false 
  },
  status: { 
    type: DataTypes.ENUM('active', 'archived'), 
    defaultValue: 'active' 
  },
  created_at: { 
    type: DataTypes.DATE, 
    defaultValue: DataTypes.NOW 
  }
}, {
  tableName: 'TeamRooms',
  timestamps: false
});

TeamRoom.belongsTo(ChildTeam, { foreignKey: 'child_team_id' });

module.exports = TeamRoom;