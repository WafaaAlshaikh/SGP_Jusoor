const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Evaluation = require('./Evaluation');

const EvaluationAttachment = sequelize.define('EvaluationAttachment', {
  attachment_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  evaluation_id: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  file_name: {
    type: DataTypes.STRING(255),
    allowNull: false
  },
  file_path: {
    type: DataTypes.STRING(500),
    allowNull: false
  },
  file_size: DataTypes.INTEGER,
  uploaded_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, { tableName: 'EvaluationAttachments', timestamps: false });

EvaluationAttachment.belongsTo(Evaluation, { foreignKey: 'evaluation_id' });
Evaluation.hasMany(EvaluationAttachment, { foreignKey: 'evaluation_id' });

module.exports = EvaluationAttachment;
