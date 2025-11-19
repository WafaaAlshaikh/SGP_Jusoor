const { Questionnaire, Question } = require('../model/index');

const seedQuestions = async () => {
  try {
    console.log('🌱 Seeding questionnaires and questions...');

    // 1. Create ASD Questionnaire (M-CHAT-R)
    const asdQuestionnaire = await Questionnaire.create({
      title: 'M-CHAT-R Modified Checklist for Autism in Toddlers',
      description: 'Autism screening for toddlers aged 16-48 months',
      type: 'ASD',
      min_age: 16,
      max_age: 48,
      is_active: true
    });

    // 2. Create ADHD Questionnaire (Vanderbilt)
    const adhdQuestionnaire = await Questionnaire.create({
      title: 'Vanderbilt ADHD Assessment Scale',
      description: 'ADHD screening for children aged 4+ years',
      type: 'ADHD', 
      min_age: 48,
      max_age: 120,
      is_active: true
    });

    // 3. GATEWAY QUESTIONS (For initial screening)
    // في seeders/questionnaireSeeds.js - أصلح الـ gatewayQuestions:

// 3. GATEWAY QUESTIONS (For initial screening)
const gatewayQuestions = [
  // ASD Gateway Questions - بس توضع في استبيان ASD
  {
    questionnaire_id: asdQuestionnaire.id, // 🔥 توضع في ASD فقط
    question_text: 'Does your child respond when you call his/her name?',
    question_type: 'yes_no',
    risk_score: 2,
    category: 'social',
    is_gateway: true,
    gateway_target: 'ASD',
    order: 1
  },
  {
    questionnaire_id: asdQuestionnaire.id, // 🔥 توضع في ASD فقط
    question_text: 'Does your child point with one finger to ask for something or get help?',
    question_type: 'yes_no',
    risk_score: 2,
    category: 'communication',
    is_gateway: true,
    gateway_target: 'ASD',
    order: 2
  },
  {
    questionnaire_id: asdQuestionnaire.id, // 🔥 توضع في ASD فقط
    question_text: 'Does your child play pretend or make-believe?',
    question_type: 'yes_no', 
    risk_score: 2,
    category: 'play',
    is_gateway: true,
    gateway_target: 'ASD',
    order: 3
  },

  // ADHD Gateway Questions - بس توضع في استبيان ADHD
  {
    questionnaire_id: adhdQuestionnaire.id, // 🔥 توضع في ADHD فقط
    question_text: 'Does your child have difficulty staying seated when expected?',
    question_type: 'yes_no',
    risk_score: 2, 
    category: 'hyperactivity',
    is_gateway: true,
    gateway_target: 'ADHD',
    order: 4
  },
  {
    questionnaire_id: adhdQuestionnaire.id, // 🔥 توضع في ADHD فقط
    question_text: 'Is your child easily distracted by noises or other stimuli?',
    question_type: 'yes_no',
    risk_score: 2,
    category: 'attention',
    is_gateway: true, 
    gateway_target: 'ADHD',
    order: 5
  },
  {
    questionnaire_id: adhdQuestionnaire.id, // 🔥 توضع في ADHD فقط
    question_text: 'Does your child interrupt or intrude on others?',
    question_type: 'yes_no',
    risk_score: 2,
    category: 'impulsivity',
    is_gateway: true,
    gateway_target: 'ADHD',
    order: 6
  }
];

    // 4. COMPLETE M-CHAT-R QUESTIONS (20 Questions)
    const asdQuestions = [
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'If you point at something across the room, does your child look at it?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'joint_attention',
        order: 10
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Have you ever wondered if your child might be deaf?',
        question_type: 'yes_no', 
        risk_score: 1,
        category: 'response',
        order: 11
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child play pretend or make-believe?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'play',
        order: 12
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child like climbing on things?',
        question_type: 'yes_no',
        risk_score: 0, // NO risk for climbing
        category: 'motor',
        order: 13
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child make unusual finger movements near his/her eyes?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'stereotyped',
        order: 14
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child point with one finger to ask for something or to get help?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'communication',
        order: 15
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child point with one finger to show you something interesting?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'joint_attention',
        order: 16
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Is your child interested in other children?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'social',
        order: 17
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child show you things by bringing them to you or holding them up for you to see – not to get help, but just to share?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'social',
        order: 18
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child respond when you call his/her name?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'response',
        order: 19
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'When you smile at your child, does he/she smile back at you?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'social',
        order: 20
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child get upset by everyday noises?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'sensory',
        order: 21
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child walk?',
        question_type: 'yes_no',
        risk_score: 0, // NO risk for walking
        category: 'motor',
        order: 22
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child look you in the eye when you are talking to him/her, playing with him/her, or dressing him/her?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'social',
        order: 23
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child try to copy what you do?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'imitation',
        order: 24
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'If you turn your head to look at something, does your child look around to see what you are looking at?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'joint_attention',
        order: 25
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child try to get you to watch him/her?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'social',
        order: 26
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child understand when you tell him/her to do something?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'comprehension',
        order: 27
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'If something new happens, does your child look at your face to see how you feel about it?',
        question_type: 'yes_no',
        risk_score: 1,
        category: 'social_referencing',
        order: 28
      },
      {
        questionnaire_id: asdQuestionnaire.id,
        question_text: 'Does your child like movement activities?',
        question_type: 'yes_no',
        risk_score: 0, // NO risk for movement activities
        category: 'motor',
        order: 29
      }
    ];

    // 5. COMPLETE VANDERBILT ADHD QUESTIONS (Parent Version - Core 18 + Performance)
    const adhdQuestions = [
      // Inattention Symptoms (1-9)
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Does not pay attention to details or makes careless mistakes with homework',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'inattention',
        order: 10
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Has difficulty keeping attention to what needs to be done',
        question_type: 'scale', 
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'inattention',
        order: 11
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Does not seem to listen when spoken to directly',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'inattention',
        order: 12
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Does not follow through when given directions and fails to finish activities',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'inattention',
        order: 13
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Has difficulty organizing tasks and activities',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'inattention',
        order: 14
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Avoids, dislikes, or does not want to start tasks that require ongoing mental effort',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'inattention',
        order: 15
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Loses things necessary for tasks or activities',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'inattention',
        order: 16
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Is easily distracted by noises or other stimuli',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'inattention',
        order: 17
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Is forgetful in daily activities',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'inattention',
        order: 18
      },

      // Hyperactivity/Impulsivity Symptoms (10-18)
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Fidgets with hands or feet or squirms in seat',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'hyperactivity',
        order: 19
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Leaves seat when remaining seated is expected',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'hyperactivity',
        order: 20
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Runs about or climbs too much when remaining seated is expected',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'hyperactivity',
        order: 21
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Has difficulty playing or beginning quiet play activities',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'hyperactivity',
        order: 22
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Is "on the go" or often acts as if "driven by a motor"',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'hyperactivity',
        order: 23
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Talks too much',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'hyperactivity',
        order: 24
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Blurts out answers before questions have been completed',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'impulsivity',
        order: 25
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Has difficulty waiting his/her turn',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'impulsivity',
        order: 26
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Interrupts or intrudes on others conversations and/or activities',
        question_type: 'scale',
        options: {
          choices: ['Never', 'Occasionally', 'Often', 'Very Often'],
          scores: { 'Never': 0, 'Occasionally': 1, 'Often': 2, 'Very Often': 3 }
        },
        risk_score: 1,
        category: 'impulsivity',
        order: 27
      },

      // Performance Questions (Critical for diagnosis)
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Overall school performance',
        question_type: 'performance',
        options: {
          choices: ['Excellent', 'Above Average', 'Average', 'Somewhat of a Problem', 'Problematic'],
          scores: { 'Excellent': 1, 'Above Average': 2, 'Average': 3, 'Somewhat of a Problem': 4, 'Problematic': 5 }
        },
        risk_score: 1,
        category: 'performance',
        order: 28
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Reading skills',
        question_type: 'performance',
        options: {
          choices: ['Excellent', 'Above Average', 'Average', 'Somewhat of a Problem', 'Problematic'],
          scores: { 'Excellent': 1, 'Above Average': 2, 'Average': 3, 'Somewhat of a Problem': 4, 'Problematic': 5 }
        },
        risk_score: 1,
        category: 'performance',
        order: 29
      },
      {
        questionnaire_id: adhdQuestionnaire.id,
        question_text: 'Relationship with peers',
        question_type: 'performance',
        options: {
          choices: ['Excellent', 'Above Average', 'Average', 'Somewhat of a Problem', 'Problematic'],
          scores: { 'Excellent': 1, 'Above Average': 2, 'Average': 3, 'Somewhat of a Problem': 4, 'Problematic': 5 }
        },
        risk_score: 1,
        category: 'performance',
        order: 30
      }
    ];

    // Insert all questions
    await Question.bulkCreate([...gatewayQuestions, ...asdQuestions, ...adhdQuestions]);
    
    console.log('✅ All questions seeded successfully!');
    console.log(`📊 ASD Questions: ${asdQuestions.length}`);
    console.log(`📊 ADHD Questions: ${adhdQuestions.length}`);
    console.log(`🚪 Gateway Questions: ${gatewayQuestions.length}`);
    console.log(`📋 Total Questions: ${gatewayQuestions.length + asdQuestions.length + adhdQuestions.length}`);

  } catch (error) {
    console.error('❌ Seeding error:', error);
    throw error;
  }
};

module.exports = seedQuestions;