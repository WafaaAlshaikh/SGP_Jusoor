const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Institution = require('./Institution');

const User = sequelize.define('User', {
    user_id: {
        type: DataTypes.BIGINT.UNSIGNED, 
        autoIncrement: true,
        primaryKey: true
    },
    full_name: {
        type: DataTypes.STRING(100),
        allowNull: false
    },
    email: {
        type: DataTypes.STRING(100),
        allowNull: false,
        unique: true
    },
    password: {
        type: DataTypes.STRING(255),
        allowNull: false
    },
    phone: {
        type: DataTypes.STRING(20),
        allowNull: true
    },
    role: {
        type: DataTypes.ENUM('Admin','Parent','Specialist','Donor','Manager'),
        allowNull: false,
        defaultValue: 'Parent'
    },
    institution_id: {
        type: DataTypes.BIGINT.UNSIGNED,
        allowNull: true,
        references: {
            model: Institution,
            key: 'institution_id'
        },
        onDelete: 'SET NULL',
        onUpdate: 'CASCADE'
    },
    profile_picture: {
        type: DataTypes.STRING(255),
        allowNull: true
    },
    status: {
        type: DataTypes.ENUM('Pending', 'Approved', 'Canceled'),
        defaultValue: 'Pending'
    },
    created_at: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW
    },
    updated_at: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW
    },

    location_lat: {
    type: DataTypes.DECIMAL(10, 8),
    allowNull: true
  },
  location_lng: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: true
  },
  location_address: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  city: {
        type: DataTypes.STRING(100),
        allowNull: true
    },
    region: {
        type: DataTypes.STRING(100),
        allowNull: true
    }

}, {
    tableName: 'Users',
    timestamps: false
});

User.belongsTo(Institution, { foreignKey: 'institution_id', as: 'institution' });

module.exports = User;

