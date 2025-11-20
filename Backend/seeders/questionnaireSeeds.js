const { Questionnaire, Question } = require('../model/index');

module.exports = async () => {
  try {
    console.log('🌱 Seeding questionnaires and questions...');
    
    // 1. Create basic questionnaires
    const questionnaires = await Questionnaire.bulkCreate([
      {
        title: 'Early Autism Screening (M-CHAT)',
        description: 'For children aged 16-30 months',
        min_age_months: 16,
        max_age_months: 30,
        type: 'autism'
      },
      {
        title: 'Speech and Language Development Screening',
        description: 'Monitoring speech development by age',
        min_age_months: 30,
        max_age_months: 120,
        type: 'speech'
      },
      {
        title: 'ADHD Screening',
        description: 'For detecting Attention Deficit Hyperactivity Disorder',
        min_age_months: 72,
        max_age_months: 180,
        type: 'adhd'
      }
    ], { ignoreDuplicates: true });
    
    // 2. Age 16-30 months questions (M-CHAT)
    const autismQuestions = [
      // Initial general questions
      {
        questionnaire_id: 1,
        question_text: "Does your child respond to their name when called?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 1,
        is_critical: true
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child point with finger to ask for something or show interest?",
        question_type: "binary", 
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism", 
        order: 2,
        is_critical: true
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child make eye contact for more than a second or two?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 3,
        is_critical: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child imitate your movements or sounds?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 4,
        is_critical: true
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child say at least 3 clear words?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30", 
        category: "speech",
        order: 5,
        is_critical: false
      },
      
      // Full M-CHAT questions (appear if risk detected)
      {
        questionnaire_id: 1,
        question_text: "Does your child enjoy being swung or bounced on your knee?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 6,
        is_critical: false,
        depends_on_previous: { min_critical_no: 2 }
      },
      {
        questionnaire_id: 1, 
        question_text: "Does your child take interest in other children?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 7,
        is_critical: true,
        depends_on_previous: { min_critical_no: 2 }
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child like climbing on things?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 8,
        is_critical: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child enjoy playing peek-a-boo or hide-and-seek?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 9,
        is_critical: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child ever pretend during play?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 1, no: 0 },
        age_group: "16-30",
        category: "autism",
        order: 10,
        is_critical: true
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child ever use index finger to point, to ask for something?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 11,
        is_critical: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child ever use index finger to point, to indicate interest?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 12,
        is_critical: true
      },
      {
        questionnaire_id: 1,
        question_text: "Can your child play properly with small toys without just mouthing or fiddling?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 13,
        is_critical: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child ever bring objects over to you to show you something?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 14,
        is_critical: true
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child seem oversensitive to noise?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 1, no: 0 },
        age_group: "16-30",
        category: "autism",
        order: 15,
        is_critical: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child smile in response to your face or your smile?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 1, no: 0 },
        age_group: "16-30",
        category: "autism",
        order: 16,
        is_critical: true
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child imitate you?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 17,
        is_critical: true
      },
      {
        questionnaire_id: 1,
        question_text: "If you point at a toy across the room, does your child look at it?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 18,
        is_critical: true
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child walk?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 19,
        is_critical: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child look at things you are looking at?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 20,
        is_critical: false
      }
    ];
    
    // 3. Speech questions for different ages
    const speechQuestions = [
      // Age 2.5-3 years
      {
        questionnaire_id: 2,
        question_text: "Does your child understand opposites (big-small, up-down)?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech", 
        order: 1,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child follow two-step commands?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 2,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child use words like 'in, out, on, under'?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 3,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child use 2-3 word sentences?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 4,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child have a word for almost everything?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 5,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child talk about things not present?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 6,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Do people who know your child well understand their speech?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 7,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child ask 'why' questions?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "2.5-5",
        category: "speech",
        order: 8,
        is_critical: false
      },

      // Age 3-4 years
      {
        questionnaire_id: 2,
        question_text: "Does your child respond when called from another room?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 9,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child understand color names?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 10,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child answer who/what/where questions?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 11,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child use pronouns correctly?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 12,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child use plurals?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 13,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Do most people understand your child's speech?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 14,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child use 4-word sentences?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 15,
        is_critical: false
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child talk about their day using 4 sentences in a row?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "2.5-5",
        category: "speech",
        order: 16,
        is_critical: false
      }
    ];
    
    // 4. ADHD questions
    const adhdQuestions = [
      // Inattention questions
      {
        questionnaire_id: 3,
        question_text: "Fails to give close attention to details or makes careless mistakes",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 1,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Has difficulty sustaining attention in tasks or play activities",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 2,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Does not seem to listen when spoken to directly",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 3,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Does not follow through on instructions and fails to finish tasks",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 4,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Has difficulty organizing tasks and activities",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 5,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Avoids or is reluctant to engage in tasks that require sustained mental effort",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 6,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Loses things necessary for tasks or activities",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 7,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Is easily distracted by extraneous stimuli",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 8,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Is forgetful in daily activities",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 9,
        is_critical: false
      },

      // Hyperactivity/Impulsivity questions
      {
        questionnaire_id: 3,
        question_text: "Fidgets with or taps hands or feet, or squirms in seat",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 10,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Leaves seat in situations when remaining seated is expected",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 11,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Runs about or climbs in situations where it is inappropriate",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 12,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Unable to play or engage in leisure activities quietly",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 13,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Is 'on the go' acting as if 'driven by a motor'",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 14,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Talks excessively",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 15,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Blurts out an answer before a question has been completed",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 16,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Has difficulty waiting their turn",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 17,
        is_critical: false
      },
      {
        questionnaire_id: 3,
        question_text: "Interrupts or intrudes on others",
        question_type: "scale",
        options: { 
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Occasionally" }, 
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 18,
        is_critical: false
      }
    ];

    // في questionnaireSeeds.js - تحديث الأسئلة
// أضف أسئلة عامة للجميع
const generalQuestions = [
  {
    questionnaire_id: 1,
    question_text: "Does your child respond when you call their name?",
    question_type: "binary",
    options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
    scoring_rules: { yes: 0, no: 1 },
    age_group: "all",
    category: "general",
    order: 1,
    is_critical: false
  },
  {
    questionnaire_id: 1,
    question_text: "Does your child make eye contact during interactions?",
    question_type: "binary",
    options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
    scoring_rules: { yes: 0, no: 1 },
    age_group: "all",
    category: "general",
    order: 2,
    is_critical: false
  },
  {
    questionnaire_id: 2,
    question_text: "Is your child's speech clear and understandable?",
    question_type: "binary",
    options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
    scoring_rules: { yes: 0, no: 1 },
    age_group: "all",
    category: "speech",
    order: 1,
    is_critical: false
  },
  {
    questionnaire_id: 3,
    question_text: "Does your child have difficulty paying attention in class or during activities?",
    question_type: "scale",
    options: { 
      choices: [
        { value: 0, text: "Never" },
        { value: 1, text: "Occasionally" }, 
        { value: 2, text: "Often" },
        { value: 3, text: "Very Often" }
      ]
    },
    scoring_rules: { threshold: 2 },
    age_group: "all",
    category: "adhd_inattention",
    order: 1,
    is_critical: false
  }
];

// ثم أضفهم للقائمة النهائية
const allQuestions = [...autismQuestions, ...speechQuestions, ...adhdQuestions, ...generalQuestions];
    
    // Combine all questions
    
    await Question.bulkCreate(allQuestions, { ignoreDuplicates: true });
    
    console.log(`✅ Seeded ${allQuestions.length} questions successfully!`);
    
  } catch (error) {
    console.error('❌ Seeding error:', error);
  }
};