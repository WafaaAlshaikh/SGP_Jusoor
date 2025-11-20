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
      allowNull: true
      // {choices: [{value: 0, text: 'Yes'}, {value: 1, text: 'No'}]}
    },
    scoring_rules: {
      type: DataTypes.JSON,
      allowNull: true
      // {yes: 0, no: 2} or {threshold: 2}
    },
    age_group: {
      type: DataTypes.ENUM('16-30', '2.5-5', '6+', 'all'),
      defaultValue: 'all'
    },
    category: {
      type: DataTypes.ENUM(
        'autism', 
        'adhd_inattention', 
        'adhd_hyperactive', 
        'speech', 
        'performance',
        'general'
      ),
      defaultValue: 'general'
    },
    order: {
      type: DataTypes.INTEGER,
      defaultValue: 0
    },
    is_critical: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      comment: 'Critical questions for autism screening'
    },
    is_initial: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      comment: 'Part of initial screening phase'
    },
    depends_on_previous: {
      type: DataTypes.JSON,
      allowNull: true
    }
  }, {
    tableName: 'questions',
    timestamps: true,
    indexes: [
      {
        fields: ['age_group', 'category', 'is_initial']
      },
      {
        fields: ['category', 'order']
      }
    ]
  });

  return Question;
};