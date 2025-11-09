// model/ZoomMeeting.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Session = require('./Session');

const ZoomMeeting = sequelize.define('ZoomMeeting', {
  zoom_meeting_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    autoIncrement: true
  },
  session_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Session,
      key: 'session_id'
    },
    onDelete: 'CASCADE',
    onUpdate: 'CASCADE'
  },
  meeting_id: {
    type: DataTypes.STRING,
    allowNull: false
  },
  join_url: {
    type: DataTypes.STRING,
    allowNull: false
  },
  start_time: {
    type: DataTypes.DATE,
    allowNull: false
  },
  topic: {
    type: DataTypes.STRING,
    allowNull: false
  }
}, {
  tableName: 'zoom_meetings',
  timestamps: false
});

ZoomMeeting.belongsTo(Session, { foreignKey: 'session_id', as: 'session' });

module.exports = ZoomMeeting;