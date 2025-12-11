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
    type: DataTypes.STRING(100),
    allowNull: true
  },

  years_experience: {
    type: DataTypes.INTEGER,
    allowNull: true
  },

  salary: {
    type: DataTypes.DOUBLE,
    allowNull: true
  },

  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: true,
    references: {
      model: Institution,
      key: 'institution_id'
    }
  },

  approval_status: {
    type: DataTypes.ENUM('Pending', 'Approved', 'Rejected','Archived'),
    defaultValue: 'Pending'
  },

  // 👉 New fields
  average_rating: {
    type: DataTypes.FLOAT,
    defaultValue: 0
  },

  total_ratings: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },

  rating_summary: {
    type: DataTypes.JSON,
    defaultValue: {}
  },

  rating_badge: {
    type: DataTypes.ENUM('platinum', 'gold', 'silver', 'bronze', 'new'),
    defaultValue: 'new'
  },

  rating_updated_at: {
    type: DataTypes.DATE,
    allowNull: true
  }

}, { 
  tableName: 'Specialists',   
  timestamps: false 
});

// Relations
Specialist.belongsTo(User, { foreignKey: 'specialist_id' });
Specialist.belongsTo(Institution, { foreignKey: 'institution_id' });

module.exports = Specialist;