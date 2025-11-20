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
    previous_diagnosis: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      comment: 'Has the child been previously diagnosed?'
    },
    screening_phase: {
      type: DataTypes.ENUM('initial', 'detailed', 'performance', 'completed'),
      defaultValue: 'initial',
      comment: 'Current phase of screening'
    },
    responses: {
      type: DataTypes.JSON,
      allowNull: false,
      defaultValue: {}
      // {question_id: {answer: 'no', score: 2, timestamp: '...'}, ...}
    },
    scores: {
      type: DataTypes.JSON,
      allowNull: false,
      defaultValue: {
        autism: { total: 0, critical: 0 },
        adhd: { inattention: 0, hyperactive: 0 },
        speech: { total: 0 }
      }
    },
    results: {
      type: DataTypes.JSON,
      allowNull: false,
      defaultValue: {}
    },
    completed_at: {
      type: DataTypes.DATE,
      allowNull: true
    }
  }, {
    tableName: 'questionnaire_responses',
    timestamps: true,
    indexes: [
      {
        fields: ['session_id']
      },
      {
        fields: ['screening_phase']
      },
      {
        fields: ['completed_at']
      }
    ]
  });

  return QuestionnaireResponse;
};