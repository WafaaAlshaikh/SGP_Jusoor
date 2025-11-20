module.exports = (sequelize, DataTypes) => {
  const QuestionnaireResponse = sequelize.define('QuestionnaireResponse', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    session_id: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true
    },
    child_age_months: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    child_gender: {
      type: DataTypes.ENUM('male', 'female'),
      allowNull: true
    },
    responses: {
      type: DataTypes.JSON,
      allowNull: false // {question_id: {answer: 'no', score: 2}, ...}
    },
    scores: {
      type: DataTypes.JSON,
      allowNull: false // {autism: {total: 8, critical: 2}, adhd: {...}, speech: {...}}
    },
    results: {
      type: DataTypes.JSON,
      allowNull: false // {autism_risk: 'high', recommendations: ['...']}
    },
    completed_at: {
      type: DataTypes.DATE,
      allowNull: true
    }
  }, {
    tableName: 'questionnaire_responses',
    timestamps: true
  });

  return QuestionnaireResponse;
};