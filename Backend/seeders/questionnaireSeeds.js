const { Questionnaire, Question } = require('../model/index');

module.exports = async () => {
  try {
    console.log('🌱 Seeding questionnaires and questions...');

    // Create questionnaires
    await Questionnaire.bulkCreate([
      {
        title: 'M-CHAT (Modified Checklist for Autism in Toddlers)',
        description: 'Autism screening for children 16-30 months',
        min_age_months: 16,
        max_age_months: 30,
        type: 'autism'
      },
      {
        title: 'Speech and Language Development',
        description: 'Speech and language screening',
        min_age_months: 30,
        max_age_months: 120,
        type: 'speech'
      },
      {
        title: 'Vanderbilt ADHD Diagnostic Scale',
        description: 'Vanderbilt scale for ADHD diagnosis',
        min_age_months: 72,
        max_age_months: 180,
        type: 'adhd'
      }
    ], { ignoreDuplicates: true });

    const allQuestions = [];

    // ========================================
    // AGE 16-30 MONTHS: M-CHAT
    // ========================================

    // Initial Screening (5 questions)
    allQuestions.push(
      {
        questionnaire_id: 1,
        question_text: "Does your child respond when you call their name?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 1,
        is_critical: true,
        is_initial: true
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child point with their finger to show interest in something?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 2,
        is_critical: true,
        is_initial: true
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child make eye contact for more than 1-2 seconds?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 3,
        is_critical: false,
        is_initial: true
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
        is_critical: true,
        is_initial: true
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
        is_critical: false,
        is_initial: true
      }
    );

    // M-CHAT Full (15 additional questions)
    allQuestions.push(
      {
        questionnaire_id: 1,
        question_text: "Does your child enjoy swinging or bouncing on your knees?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 6,
        is_critical: false,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Is your child interested in other children?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 7,
        is_critical: true,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child like to climb on things?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 8,
        is_critical: false,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child enjoy playing games like peek-a-boo?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 9,
        is_critical: false,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child pretend play (like making toy tea)?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 2, no: 0 },
        age_group: "16-30",
        category: "autism",
        order: 10,
        is_critical: true,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child point with finger to ask for something?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 11,
        is_critical: false,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child point with finger to show interest in something?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 12,
        is_critical: true,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child play with toys correctly (not just putting them in mouth)?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 13,
        is_critical: false,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child bring things to show you?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 14,
        is_critical: true,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child seem sensitive to noise?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 1, no: 0 },
        age_group: "16-30",
        category: "autism",
        order: 15,
        is_critical: false,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child smile back when you smile at them?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 2, no: 0 },
        age_group: "16-30",
        category: "autism",
        order: 16,
        is_critical: true,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child imitate your movements?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 17,
        is_critical: true,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "If you point to a toy across the room, does your child look at it?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "16-30",
        category: "autism",
        order: 18,
        is_critical: true,
        is_initial: false
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
        is_critical: false,
        is_initial: false
      },
      {
        questionnaire_id: 1,
        question_text: "Does your child look at things you're looking at?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "16-30",
        category: "autism",
        order: 20,
        is_critical: false,
        is_initial: false
      }
    );

    // ========================================
    // AGE 2.5-5 YEARS: Mixed Screening
    // ========================================

    // Initial Screening (7 questions)
    allQuestions.push(
      {
        questionnaire_id: 2,
        question_text: "Does your child respond when called from another room?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "2.5-5",
        category: "autism",
        order: 1,
        is_critical: false,
        is_initial: true
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child play and interact with other children?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "autism",
        order: 2,
        is_critical: false,
        is_initial: true
      },
      {
        questionnaire_id: 2,
        question_text: "Can your child form sentences of at least 3 words?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 3,
        is_critical: false,
        is_initial: true
      },
      {
        questionnaire_id: 2,
        question_text: "Does your child answer simple questions like 'Where? What? Who?'",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 4,
        is_critical: false,
        is_initial: true
      },
      {
        questionnaire_id: 2,
        question_text: "Can your child sit and focus on one activity for more than 5 minutes?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 1 },
        age_group: "2.5-5",
        category: "adhd_inattention",
        order: 5,
        is_critical: false,
        is_initial: true
      },
      {
        questionnaire_id: 2,
        question_text: "Is your child constantly moving and unable to sit quietly?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 1, no: 0 },
        age_group: "2.5-5",
        category: "adhd_hyperactive",
        order: 6,
        is_critical: false,
        is_initial: true
      },
      {
        questionnaire_id: 2,
        question_text: "Do most people understand your child's speech?",
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 7,
        is_critical: false,
        is_initial: true
      }
    );

    // Detailed Speech Questions for age 2.5-5 (16 questions total)
    const speechQuestions_2_5 = [
      "Does your child understand opposites (big-small, up-down)?",
      "Does your child follow two-step commands (like 'get the spoon and put it on the table')?",
      "Does your child use words like 'inside, outside, up, down'?",
      "Does your child use 2-3 word sentences?",
      "Does your child have a word for almost everything?",
      "Does your child talk about things not present?",
      "Do people who know your child understand their speech?",
      "Does your child ask 'Why?' questions?",
      "Does your child understand color names (red, blue, green)?",
      "Does your child use pronouns (I, you, we)?",
      "Does your child use plurals (toys, birds, buses)?",
      "Does your child use 4-word sentences?",
      "Does your child talk about their day using 4 consecutive sentences?",
      "Does your child pronounce most letters clearly?",
      "Does your child tell a short story in sequence?",
      "Does your child maintain conversation and respond to questions?"
    ];

    speechQuestions_2_5.forEach((text, idx) => {
      allQuestions.push({
        questionnaire_id: 2,
        question_text: text,
        question_type: "binary",
        options: { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: { yes: 0, no: 2 },
        age_group: "2.5-5",
        category: "speech",
        order: 8 + idx,
        is_critical: false,
        is_initial: false
      });
    });

    // ========================================
    // AGE 6+ YEARS: Vanderbilt ADHD
    // ========================================

    // Initial Screening (8 questions)
    const adhdInitial = [
      { text: "Does not pay attention to details or makes careless mistakes", cat: "adhd_inattention" },
      { text: "Easily distracted by sounds or surroundings", cat: "adhd_inattention" },
      { text: "Forgets their belongings or assignments", cat: "adhd_inattention" },
      { text: "Fidgets excessively and cannot sit still", cat: "adhd_hyperactive" },
      { text: "Interrupts others and cannot wait their turn", cat: "adhd_hyperactive" },
      { text: "Talks excessively", cat: "adhd_hyperactive" },
      { text: "Pronounces all sounds clearly", cat: "speech" },
      { text: "Tells a short story in sequence", cat: "speech" }
    ];

    adhdInitial.forEach((q, idx) => {
      const isADHD = q.cat.includes('adhd');
      allQuestions.push({
        questionnaire_id: 3,
        question_text: q.text,
        question_type: isADHD ? "scale" : "binary",
        options: isADHD ? 
          { choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Sometimes" },
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]} :
          { choices: [{ value: "yes", text: "Yes" }, { value: "no", text: "No" }] },
        scoring_rules: isADHD ? { threshold: 2 } : { yes: 0, no: 2 },
        age_group: "6+",
        category: q.cat,
        order: idx + 1,
        is_critical: false,
        is_initial: true
      });
    });

    // Full Vanderbilt - Inattention (9 questions)
    const inattentionFull = [
      "Fails to give close attention to details or makes careless mistakes",
      "Has difficulty sustaining attention in tasks",
      "Does not seem to listen when spoken to directly",
      "Does not follow through on instructions and fails to finish tasks",
      "Has difficulty organizing tasks and activities",
      "Avoids tasks that require sustained mental effort",
      "Loses things necessary for tasks (pen, notebook, toy)",
      "Easily distracted by extraneous stimuli",
      "Forgetful in daily activities"
    ];

    inattentionFull.forEach((text, idx) => {
      allQuestions.push({
        questionnaire_id: 3,
        question_text: text,
        question_type: "scale",
        options: {
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Sometimes" },
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_inattention",
        order: 9 + idx,
        is_critical: false,
        is_initial: false
      });
    });

    // Full Vanderbilt - Hyperactivity (9 questions)
    const hyperactiveFull = [
      "Fidgets with hands or feet or squirms in seat",
      "Leaves seat in situations where remaining seated is expected",
      "Runs about or climbs excessively in inappropriate situations",
      "Has difficulty playing or engaging in leisure activities quietly",
      "Is 'on the go' or acts as if 'driven by a motor'",
      "Talks excessively",
      "Blurts out answers before questions have been completed",
      "Has difficulty awaiting turn",
      "Interrupts or intrudes on others"
    ];

    hyperactiveFull.forEach((text, idx) => {
      allQuestions.push({
        questionnaire_id: 3,
        question_text: text,
        question_type: "scale",
        options: {
          choices: [
            { value: 0, text: "Never" },
            { value: 1, text: "Sometimes" },
            { value: 2, text: "Often" },
            { value: 3, text: "Very Often" }
          ]
        },
        scoring_rules: { threshold: 2 },
        age_group: "6+",
        category: "adhd_hyperactive",
        order: 18 + idx,
        is_critical: false,
        is_initial: false
      });
    });

    // Performance Questions (5 questions - required for ADHD diagnosis)
    const performanceQuestions = [
      "Overall academic performance",
      "Relationship with parents",
      "Relationship with other children",
      "Completing school assignments",
      "Organizational skills"
    ];

    performanceQuestions.forEach((text, idx) => {
      allQuestions.push({
        questionnaire_id: 3,
        question_text: text,
        question_type: "scale",
        options: {
          choices: [
            { value: 1, text: "Excellent" },
            { value: 2, text: "Above Average" },
            { value: 3, text: "Average" },
            { value: 4, text: "Some Problem" },
            { value: 5, text: "Major Problem" }
          ]
        },
        scoring_rules: { threshold: 4 },
        age_group: "6+",
        category: "performance",
        order: 27 + idx,
        is_critical: false,
        is_initial: false
      });
    });

    // Insert all questions
    await Question.bulkCreate(allQuestions, { 
      ignoreDuplicates: true,
      updateOnDuplicate: ['question_text', 'is_initial', 'order']
    });

    console.log(`✅ Successfully seeded ${allQuestions.length} questions!`);
    console.log('📊 Breakdown:');
    console.log('   - Age 16-30: M-CHAT (20 questions)');
    console.log('   - Age 2.5-5: Mixed screening (23 questions)');
    console.log('   - Age 6+: Vanderbilt ADHD (32 questions)');

  } catch (error) {
    console.error('❌ Seeding error:', error);
    throw error;
  }
};