// models/ChildAttachment.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Child = require('./Child');

const ChildAttachment = sequelize.define('ChildAttachment', {
  attachment_id: {
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
  file_name: {
    type: DataTypes.STRING(255),
    allowNull: false
  },
  file_path: {
    type: DataTypes.STRING(500),
    allowNull: false
  },
  file_type: {
    type: DataTypes.STRING(100)
  },
  file_size: {
    type: DataTypes.INTEGER
  },
  description: {
    type: DataTypes.TEXT
  },
  uploaded_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'ChildAttachments',
  timestamps: false
});

ChildAttachment.belongsTo(Child, { foreignKey: 'child_id' });
Child.hasMany(ChildAttachment, { foreignKey: 'child_id', as: 'attachments' });

module.exports = ChildAttachment;