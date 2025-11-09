const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');

const Parent = sequelize.define('Parent', {
  parent_id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true },
  address: { type: DataTypes.STRING(255) },
  occupation: { type: DataTypes.STRING(100) }
}, { tableName: 'Parents', timestamps: false });

Parent.belongsTo(User, { foreignKey: 'parent_id' });

module.exports = Parent;