// models/SessionRating.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Session = require('./Session');
const User = require('./User');
const Child = require('./Child');

const SessionRating = sequelize.define('SessionRating', {
  session_rating_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  session_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Session,
      key: 'session_id'
    }
  },
  parent_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  specialist_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: User,
      key: 'user_id'
    }
  },
  child_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: Child,
      key: 'child_id'
    }
  },
  
  // التقييم الأساسي (مطلوب)
  rating: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1,
      max: 5
    }
  },
  
  rating_tag: {
  type: DataTypes.ENUM('Excellent', 'Very Good', 'Good', 'Acceptable', 'Bad'),
  allowNull: true
},

  
  // التعليق القصير (اختياري)
  comment: {
    type: DataTypes.STRING(500),
    allowNull: true
  },
  
  // هل الجلسة كانت Online أو Onsite؟
  session_type: {
    type: DataTypes.ENUM('Online', 'Onsite'),
    allowNull: false
  },
  
  // تاريخ التقييم
  rated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'SessionRatings',
  timestamps: false,
  indexes: [
    { fields: ['session_id'] },
    { fields: ['specialist_id'] },
    { fields: ['parent_id'] },
    { fields: ['rated_at'] }
  ]
});

// العلاقات
SessionRating.belongsTo(Session, { foreignKey: 'session_id' });
SessionRating.belongsTo(User, { foreignKey: 'parent_id', as: 'parent' });
SessionRating.belongsTo(User, { foreignKey: 'specialist_id', as: 'specialist' });
SessionRating.belongsTo(Child, { foreignKey: 'child_id' });

module.exports = SessionRating;