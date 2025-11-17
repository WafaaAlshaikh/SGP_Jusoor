const sequelize = require('../config/db');
const Question = require('../model/Question');

const sampleQuestions = [
  {
    category: 'Attention & Focus',
    question_text: 'How often does the child have difficulty sustaining attention in tasks or play activities?',
    question_text_ar: 'كم مرة يواجه الطفل صعوبة في الحفاظ على الانتباه في المهام أو أنشطة اللعب؟',
    question_type: 'Multiple Choice',
    options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
    options_ar: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
    weight: 1.0,
    target_conditions: ['ADHD', 'ASD'],
    min_age: 3,
    max_age: 12
  },
  {
    category: 'Social Interaction',
    question_text: 'Does the child make eye contact when interacting with others?',
    question_text_ar: 'هل يقوم الطفل بالاتصال البصري عند التفاعل مع الآخرين؟',
    question_type: 'Multiple Choice',
    options: ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'],
    options_ar: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
    weight: 1.2,
    target_conditions: ['ASD'],
    min_age: 2,
    max_age: 10
  },
  // ... المزيد من الأسئلة
];

async function seedQuestions() {
  try {
    await sequelize.authenticate();
    console.log('✅ Connected to database');

    await Question.bulkCreate(sampleQuestions);
    console.log('✅ Sample questions added successfully');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding questions:', error);
    process.exit(1);
  }
}

seedQuestions();