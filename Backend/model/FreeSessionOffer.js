const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const Child = require('./Child');
const Parent = require('./Parent');
const Institution = require('./Institution');
const SessionType = require('./SessionType');
const Specialist = require('./Specialist');

const FreeSessionOffer = sequelize.define('FreeSessionOffer', {
  offer_id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
  child_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  parent_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  institution_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  session_type_id: { type: DataTypes.INTEGER, allowNull: false },
  specialist_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
  status: {
    type: DataTypes.ENUM('offered', 'accepted', 'expired', 'cancelled'),
    allowNull: false,
    defaultValue: 'offered',
  },
  notes: { type: DataTypes.TEXT, allowNull: true },
  created_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  expires_at: { type: DataTypes.DATE, allowNull: true },
}, {
  tableName: 'FreeSessionOffers',
  timestamps: false,
});

FreeSessionOffer.belongsTo(Child, { foreignKey: 'child_id' });
FreeSessionOffer.belongsTo(Parent, { foreignKey: 'parent_id' });
FreeSessionOffer.belongsTo(Institution, { foreignKey: 'institution_id' });
FreeSessionOffer.belongsTo(SessionType, { foreignKey: 'session_type_id' });
FreeSessionOffer.belongsTo(Specialist, { foreignKey: 'specialist_id' });

module.exports = FreeSessionOffer;
