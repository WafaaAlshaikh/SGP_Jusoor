const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');
const Institution = require('./Institution');

const Specialist = sequelize.define('Specialist', {
  specialist_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    primaryKey: true,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  specialization: {
    type: DataTypes.STRING(100)
  },
  years_experience: {
    type: DataTypes.INTEGER
  },
  salary: {
    type: DataTypes.DOUBLE
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    references: {
      model: Institution,
      key: 'institution_id'
    }
  },
  approval_status: {
    type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'),
    defaultValue: 'Pending'
  }
}, { tableName: 'Specialists', timestamps: false });

Specialist.belongsTo(User, { foreignKey: 'specialist_id' });
Specialist.belongsTo(Institution, { foreignKey: 'institution_id' });

module.exports = Specialist;
