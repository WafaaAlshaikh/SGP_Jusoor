module.exports = (sequelize, DataTypes) => {
  const Questionnaire = sequelize.define('Questionnaire', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    title: {
      type: DataTypes.STRING,
      allowNull: false
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    min_age_months: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    max_age_months: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    type: {
      type: DataTypes.ENUM('autism', 'adhd', 'speech', 'general'),
      allowNull: false
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    }
  }, {
    tableName: 'questionnaires',
    timestamps: true
  });

  return Questionnaire;
};