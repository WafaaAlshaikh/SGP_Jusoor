const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const TeamRoom = require('./TeamRoom');
const Specialist = require('./Specialist');

const TeamActivity = sequelize.define('TeamActivity', {
  activity_id: { 
    type: DataTypes.INTEGER, 
    primaryKey: true, 
    autoIncrement: true 
  },
  team_room_id: { 
    type: DataTypes.INTEGER, 
    allowNull: false 
  },
  specialist_id: { 
    type: DataTypes.BIGINT.UNSIGNED, 
    allowNull: false 
  },
  activity_type: { 
    type: DataTypes.ENUM('evaluation', 'session', 'note', 'recommendation'), 
    allowNull: false 
  },
  title: { 
    type: DataTypes.STRING(255), 
    allowNull: false 
  },
  description: { 
    type: DataTypes.TEXT, 
    allowNull: true 
  },
  related_id: { 
    type: DataTypes.INTEGER, 
    allowNull: true 
  },
  timestamp: { 
    type: DataTypes.DATE, 
    defaultValue: DataTypes.NOW 
  }
}, {
  tableName: 'TeamActivities',
  timestamps: false
});

TeamActivity.belongsTo(TeamRoom, { foreignKey: 'team_room_id' });
TeamActivity.belongsTo(Specialist, { foreignKey: 'specialist_id' });

module.exports = TeamActivity;