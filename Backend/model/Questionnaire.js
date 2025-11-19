const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Questionnaire = sequelize.define('Questionnaire', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  title: {
    type: DataTypes.STRING,
    allowNull: false
  },
  description: DataTypes.TEXT,
  type: {
    type: DataTypes.ENUM('ASD', 'ADHD', 'COMBINED', 'GATEWAY'),
    allowNull: false
  },
  min_age: DataTypes.INTEGER,
  max_age: DataTypes.INTEGER,
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
});

module.exports = Questionnaire;
