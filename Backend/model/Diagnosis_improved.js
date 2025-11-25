const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const Diagnosis = sequelize.define('Diagnosis', {
    diagnosis_id: { 
        type: DataTypes.BIGINT.UNSIGNED, 
        autoIncrement: true, 
        primaryKey: true 
    },
    name: { 
        type: DataTypes.STRING(255), 
        allowNull: false,
        unique: true 
    },
    name_ar: {
        type: DataTypes.STRING(255), 
        allowNull: true
    },
    description: { 
        type: DataTypes.TEXT,
        allowNull: true
    },
    category: {
        type: DataTypes.ENUM(
            'Developmental',  
            'Neurological',  
            'Genetic',       
            'Sensory',       
            'Learning',       
            'Behavioral',    
            'Physical',      
            'Multiple'      
        ),
        allowNull: true,
        defaultValue: 'Developmental'
    },
    is_active: {
        type: DataTypes.BOOLEAN,
        defaultValue: true
    }
}, { 
    tableName: 'Diagnoses', 
    timestamps: false 
});

module.exports = Diagnosis;
