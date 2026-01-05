// models/ChildSpecialistCompletion.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Child = require('./Child');
const Specialist = require('./Specialist');
const User = require('./User');

const ChildSpecialistCompletion = sequelize.define('ChildSpecialistCompletion', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  child_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: Child,
      key: 'child_id'
    }
  },
  specialist_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: Specialist,
      key: 'specialist_id'
    }
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    allowNull: false,
    references: {
      model: require('./Institution'),
      key: 'institution_id'
    }
  },
  
  // الشروط التلقائية
  has_no_active_sessions: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  has_final_evaluation: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  has_no_pending_requests: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  
  // تأكيد الأخصائي
  specialist_confirmed: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  confirmed_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  
  // حالة هذا السجل
  status: {
    type: DataTypes.ENUM(
      'pending',      // بانتظار تحقق الشروط
      'eligible',     // الشروط متحققة، يظهر زر التأكيد للأخصائي
      'confirmed',    // الأخصائي أكد
      'rejected'      // الأخصائي رفض (لسبب ما)
    ),
    defaultValue: 'pending'
  },
  
  // ملاحظات الأخصائي
  specialist_notes: {
    type: DataTypes.TEXT,
    allowNull: true
  }
}, {
  tableName: 'ChildSpecialistCompletions',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
  indexes: [
    {
      unique: true,
      fields: ['child_id', 'specialist_id']
    }
  ]
});

// العلاقات
ChildSpecialistCompletion.belongsTo(Child, { foreignKey: 'child_id' });
ChildSpecialistCompletion.belongsTo(Specialist, { foreignKey: 'specialist_id' });
ChildSpecialistCompletion.belongsTo(User, { 
  foreignKey: 'specialist_id', 
  targetKey: 'user_id',
  as: 'specialistUser' 
});

module.exports = ChildSpecialistCompletion;