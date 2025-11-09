const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Diagnosis = sequelize.define('Diagnosis', {
    diagnosis_id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
    name: { 
        type: DataTypes.ENUM('ASD','ADHD','Down Syndrome','Speech & Language Disorder'),
        allowNull: false
    },
    description: { type: DataTypes.TEXT }
}, { tableName: 'Diagnoses', timestamps: false });

module.exports = Diagnosis;
