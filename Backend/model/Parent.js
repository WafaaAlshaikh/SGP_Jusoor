  // models/Parent.js
  const { DataTypes } = require('sequelize');
  const sequelize = require('../config/db');
  const User = require('./User');

  const Parent = sequelize.define('Parent', {
    parent_id: { 
      type: DataTypes.BIGINT.UNSIGNED, 
      primaryKey: true 
    },
    address: { 
      type: DataTypes.STRING(255) 
    },
    occupation: { 
      type: DataTypes.STRING(100) 
    },
    // NEW FIELDS FOR FINANCIAL ASSESSMENT
    monthly_income: {
      type: DataTypes.DECIMAL(12, 2),
      allowNull: true,
      comment: 'Monthly household income in USD'
    },
    employment_status: {
      type: DataTypes.ENUM(
        'employed_full_time',
        'employed_part_time', 
        'self_employed',
        'unemployed',
        'student',
        'retired',
        'disabled'
      ),
      allowNull: true
    },
    family_size: {
      type: DataTypes.INTEGER,
      defaultValue: 1,
      validate: {
        min: 1
      }
    },
    dependents_count: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Number of family members who are dependent'
    },
    special_circumstances: {
      type: DataTypes.ENUM(
        'none',
        'single_parent',
        'widow_widower',
        'divorced',
        'refugee_displaced',
        'low_income_family',
        'special_needs_family_member',
        'medical_emergency'
      ),
      defaultValue: 'none'
    },
    receives_government_support: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    government_support_amount: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0
    },
    other_monthly_expenses: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0,
      comment: 'Other fixed monthly expenses (rent, utilities, etc.)'
    },
    additional_medical_expenses: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0,
      comment: 'Monthly medical expenses for the child'
    },
    // FINANCIAL ASSESSMENT FIELDS
    financial_score: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      validate: {
        min: 0,
        max: 100
      }
    },
    financial_tier: {
      type: DataTypes.ENUM(
        'tier_1_critical',
        'tier_2_high',
        'tier_3_medium', 
        'tier_4_low',
        'tier_5_no_assistance'
      ),
      defaultValue: 'tier_5_no_assistance'
    },
    last_financial_assessment: {
      type: DataTypes.DATE,
      allowNull: true
    },
    financial_documents: {
      type: DataTypes.JSON,
      allowNull: true,
      comment: 'Array of uploaded financial documents'
    },
    assessment_notes: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    credibility_score: {
      type: DataTypes.INTEGER,
      defaultValue: 50,
      validate: {
        min: 0,
        max: 100
      },
      comment: 'Score based on historical accuracy of information'
    }
  }, {
    tableName: 'Parents',
    timestamps: false
  });

  Parent.belongsTo(User, { foreignKey: 'parent_id' });

  module.exports = Parent;