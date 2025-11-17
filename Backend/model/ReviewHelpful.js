const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const ReviewHelpful = sequelize.define('ReviewHelpful', {
  id: {
    type: DataTypes.BIGINT.UNSIGNED,
    autoIncrement: true,
    primaryKey: true
  },
  review_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: 'Reviews',
      key: 'review_id'
    }
  },
  user_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: 'Users',
      key: 'user_id'
    }
  },
  is_helpful: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    comment: 'true = helpful, false = not helpful'
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'ReviewHelpful',
  timestamps: false,
  indexes: [
    {
      unique: true,
      fields: ['review_id', 'user_id']
    }
  ]
});

module.exports = ReviewHelpful;
