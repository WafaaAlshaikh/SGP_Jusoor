// models/InstitutionReview.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');
const Institution = require('./Institution');

const InstitutionReview = sequelize.define('InstitutionReview', {
  institution_review_id: {
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
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: Institution,
      key: 'institution_id'
    }
  },
  
  // مجالات التقييم
  facilities_rating: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  staff_rating: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  cleanliness_rating: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  accessibility_rating: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  
  // التقييم العام
  overall_rating: {
    type: DataTypes.DECIMAL(3, 2),
    allowNull: false,
    validate: { min: 1, max: 5 }
  },
  
  // المراجعة النصية
  review_text: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  
  // هل تنصح بالمؤسسة؟
  would_recommend: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  
  // بناء على كام زيارة؟
  based_on_visits: {
    type: DataTypes.INTEGER,
    defaultValue: 1
  },
  
  // تواريخ
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'InstitutionReviews',
  timestamps: false,
  hooks: {
    beforeCreate: (review) => {
      // حساب التقييم العام تلقائياً
      review.overall_rating = (
        review.facilities_rating + 
        review.staff_rating + 
        review.cleanliness_rating + 
        review.accessibility_rating
      ) / 4;
    },
    beforeUpdate: (review) => {
      if (review.changed('facilities_rating') || 
          review.changed('staff_rating') || 
          review.changed('cleanliness_rating') || 
          review.changed('accessibility_rating')) {
        review.overall_rating = (
          review.facilities_rating + 
          review.staff_rating + 
          review.cleanliness_rating + 
          review.accessibility_rating
        ) / 4;
        review.updated_at = new Date();
      }
    }
  }
});

// العلاقات
InstitutionReview.belongsTo(User, { foreignKey: 'parent_id', as: 'parent' });
InstitutionReview.belongsTo(Institution, { foreignKey: 'institution_id' });

module.exports = InstitutionReview;