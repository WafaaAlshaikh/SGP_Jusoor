const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Institution = require('./Institution');

const ParentWorkshop = sequelize.define('ParentWorkshop', {
  workshop_id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
  institution_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  title: { type: DataTypes.STRING(150), allowNull: false },
  description: { type: DataTypes.TEXT, allowNull: true },
  mode: { 
    type: DataTypes.ENUM('online', 'offline'),
    allowNull: false,
    defaultValue: 'offline'
  },
  online_link: { type: DataTypes.STRING(255), allowNull: true },
  location_address: { type: DataTypes.STRING(255), allowNull: true },
  date: { type: DataTypes.DATEONLY, allowNull: false },
  start_time: { type: DataTypes.TIME, allowNull: false },
  end_time: { type: DataTypes.TIME, allowNull: false },
  max_participants: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 20 },
  status: {
    type: DataTypes.ENUM('draft', 'published', 'cancelled'),
    allowNull: false,
    defaultValue: 'draft'
  }
}, {
  tableName: 'ParentWorkshops'
});

ParentWorkshop.belongsTo(Institution, { foreignKey: 'institution_id' });

module.exports = ParentWorkshop;
