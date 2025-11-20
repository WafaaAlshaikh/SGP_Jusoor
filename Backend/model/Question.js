module.exports = (sequelize, DataTypes) => {
  const Question = sequelize.define('Question', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    questionnaire_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'questionnaires',
        key: 'id'
      }
    },
    question_text: {
      type: DataTypes.TEXT,
      allowNull: false
    },
    question_type: {
      type: DataTypes.ENUM('binary', 'scale', 'multiple_choice', 'text'),
      defaultValue: 'binary'
    },
    options: {
      type: DataTypes.JSON,
      allowNull: true // {choices: [{value: 0, text: 'نعم'}, {value: 1, text: 'لا'}]}
    },
    scoring_rules: {
      type: DataTypes.JSON,
      allowNull: true // {yes: 0, no: 2, critical: true}
    },
    age_group: {
      type: DataTypes.ENUM('16-30', '2.5-5', '6+', 'all'),
      defaultValue: 'all'
    },
    category: {
      type: DataTypes.ENUM('autism', 'adhd_inattention', 'adhd_hyperactive', 'speech', 'general'),
      defaultValue: 'general'
    },
    order: {
      type: DataTypes.INTEGER,
      defaultValue: 0
    },
    is_critical: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    depends_on_previous: {
      type: DataTypes.JSON,
      allowNull: true // {question_id: 1, answer: 'no'}
    }
  }, {
    tableName: 'questions',
    timestamps: true
  });

  return Question;
};