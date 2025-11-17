const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Institution = require('./Institution');
const User = require('./User');

const SessionType = sequelize.define('SessionType', {
  session_type_id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  institution_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  name: { type: DataTypes.STRING(100), allowNull: false },
  duration: { type: DataTypes.INTEGER, allowNull: false },
  price: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  category: { 
    type: DataTypes.ENUM('Speech', 'Behavioral', 'Occupational', 'Educational'),
    allowNull: false 
  },
  specialist_specialization: {
    type: DataTypes.STRING(100),
    allowNull: false
  },
  target_conditions: {
    type: DataTypes.JSON, // ['ASD', 'ADHD', 'Down Syndrome', 'Speech & Language Disorder']
    allowNull: true,
    defaultValue: null 
  },
  approval_status: {
    type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'),
    defaultValue: 'Pending' // الجلسات الموجودة تكون موافق عليها، الجديدة تحتاج موافقة
  },
  created_by_specialist_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true // ID المختص الذي أنشأ نوع الجلسة
  }
}, { 
  tableName: 'SessionTypes', 
  timestamps: false 
});
SessionType.belongsTo(Institution, { foreignKey: 'institution_id' });
SessionType.belongsTo(User, { foreignKey: 'created_by_specialist_id', as: 'CreatedBySpecialist' });

module.exports = SessionType;
