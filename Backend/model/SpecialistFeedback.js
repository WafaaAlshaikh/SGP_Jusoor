// models/SpecialistFeedback.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');

const SpecialistFeedback = sequelize.define('SpecialistFeedback', {
  feedback_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
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
  
  // الأسئلة المحددة
  professionalism_score: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  communication_score: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  knowledge_score: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  punctuality_score: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  
  // النقاط
  strengths: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  improvements_needed: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  
  // هل تود الاستمرار؟
  would_continue: {
    type: DataTypes.BOOLEAN,
    allowNull: true
  },
  
  // للمدير فقط
  is_confidential: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  
  // التواريخ
  submitted_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'SpecialistFeedbacks',
  timestamps: false,
  hooks: {
    beforeCreate: (feedback) => {
      feedback.is_confidential = true; // دائمًا سري
    }
  }
});

// العلاقات
SpecialistFeedback.belongsTo(User, { foreignKey: 'parent_id', as: 'parent' });
SpecialistFeedback.belongsTo(User, { foreignKey: 'specialist_id', as: 'specialist' });

module.exports = SpecialistFeedback;