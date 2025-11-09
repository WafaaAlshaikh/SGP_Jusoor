const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Child = require('./Child');
const Institution = require('./Institution');

const ChildInstitution = sequelize.define('ChildInstitution', {
  child_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    references: {
      model: Child,
      key: 'child_id'
    }
  },
  institution_id: {
    type: DataTypes.BIGINT.UNSIGNED,
    references: {
      model: Institution,
      key: 'institution_id'
    }
  }
}, {
  tableName: 'ChildInstitutions',
  timestamps: false
});

Child.belongsToMany(Institution, {
  through: ChildInstitution,
  foreignKey: 'child_id',
  otherKey: 'institution_id'
});

Institution.belongsToMany(Child, {
  through: ChildInstitution,
  foreignKey: 'institution_id',
  otherKey: 'child_id'
});

module.exports = { ChildInstitution };
