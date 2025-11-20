const { Questionnaire, Question, QuestionnaireResponse, sequelize } = require('../model/index');
const { Op } = require('sequelize');

class ScreeningController {
  
  // ========== MAIN METHODS ==========
  
  // Start new screening
  async startScreening(req, res) {
    try {
      const { child_age_months, child_gender } = req.body;
      
      console.log('🎯 START SCREENING REQUEST:', { child_age_months, child_gender });
      
      if (!child_age_months) {
        return res.status(400).json({
          success: false,
          message: 'Child age is required'
        });
      }
      
      // Create new session
      const session_id = `screening_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      const response = await QuestionnaireResponse.create({
        session_id,
        child_age_months: parseInt(child_age_months),
        child_gender,
        responses: {},
        scores: {},
        results: {}
      });
      
      // Get initial questions based on age
      const initialQuestions = await this.getInitialQuestions(parseInt(child_age_months));
      
      console.log('✅ SCREENING STARTED - Session:', session_id, 'Questions:', initialQuestions.length);
      
      res.json({
        success: true,
        session_id,
        questions: initialQuestions,
        progress: 0,
        total_questions: initialQuestions.length,
        age_group: this.getAgeGroup(child_age_months),
        message: `Screening started for ${child_age_months} months old child`
      });
      
    } catch (error) {
      console.error('❌ START SCREENING ERROR:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to start screening'
      });
    }
  }

  async submitAnswer(req, res) {
  try {
    const { session_id, question_id, answer } = req.body;
    
    console.log('📨 SUBMIT ANSWER REQUEST:', { session_id, question_id, answer });
    
    if (!session_id || !question_id || answer === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Session ID, question ID and answer are required'
      });
    }
    
    // Get current screening session
    const response = await QuestionnaireResponse.findOne({
      where: { session_id }
    });
    
    if (!response) {
      return res.status(404).json({
        success: false,
        message: 'Screening session not found'
      });
    }
    
    // Convert question_id to number for consistent storage
    const questionIdNum = parseInt(question_id);
    
    // 🔥 الإصلاح: احصل على الـ responses الحالية أولاً ثم أضف الجديدة
    const currentResponses = response.responses || {};
    
    // بديل الـ spread operator
const updatedResponses = Object.assign({}, currentResponses, {
  [questionIdNum]: {
    answer,
    timestamp: new Date()
  }
});
    
    await response.update({ responses: updatedResponses });
    
    const answeredCount = Object.keys(updatedResponses).length;
    console.log('✅ ANSWER SAVED - Question:', questionIdNum, 'Total Answered:', answeredCount);
    console.log('📋 CURRENT RESPONSES:', Object.keys(updatedResponses));
    console.log('🔍 ALL RESPONSES DATA:', JSON.stringify(updatedResponses, null, 2));
    
    // Get next question
    const nextQuestion = await this.getNextQuestion(
      response.child_age_months, 
      updatedResponses, 
      questionIdNum, 
      answer
    );
    
    // If no more questions, calculate results
    if (!nextQuestion) {
      console.log('🎉 SCREENING COMPLETED - Calculating results...');
      const results = await this.calculateResults(response.child_age_months, updatedResponses);
      await response.update({
        scores: results.scores,
        results: results.results,
        completed_at: new Date()
      });
      
      return res.json({
        success: true,
        completed: true,
        results: results.results,
        scores: results.scores
      });
    }
    
    const progress = this.calculateProgress(response.child_age_months, updatedResponses);
    
    console.log('➡️ SENDING NEXT QUESTION - ID:', nextQuestion.id, 'Order:', nextQuestion.order);
    
    res.json({
      success: true,
      completed: false,
      next_question: nextQuestion,
      progress: progress,
      answered_questions: answeredCount
    });
    
  } catch (error) {
    console.error('❌ SUBMIT ANSWER ERROR:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save answer'
    });
  }
}
  

// أضف هذه الدالة في الـ Controller
async debugSessionResponses(session_id) {
  try {
    const response = await QuestionnaireResponse.findOne({
      where: { session_id },
      attributes: ['id', 'session_id', 'responses', 'child_age_months']
    });
    
    if (!response) {
      return { error: 'Session not found' };
    }
    
    console.log('🔍 DEBUG SESSION RESPONSES:');
    console.log('   Session:', session_id);
    console.log('   Age:', response.child_age_months);
    console.log('   Responses Count:', Object.keys(response.responses || {}).length);
    console.log('   All Responses:', JSON.stringify(response.responses, null, 2));
    
    return {
      session_id,
      age: response.child_age_months,
      responses_count: Object.keys(response.responses || {}).length,
      responses: response.responses
    };
  } catch (error) {
    console.error('❌ DEBUG SESSION RESPONSES ERROR:', error);
    return { error: error.message };
  }
}
  // Get screening results
  async getResults(req, res) {
    try {
      const { session_id } = req.params;
      
      console.log('📊 GET RESULTS REQUEST:', session_id);
      
      const response = await QuestionnaireResponse.findOne({
        where: { session_id }
      });
      
      if (!response) {
        return res.status(404).json({
          success: false,
          message: 'Results not found'
        });
      }
      
      // If not completed, calculate results first
      if (!response.completed_at) {
        console.log('🔄 CALCULATING RESULTS FOR INCOMPLETE SESSION');
        const results = await this.calculateResults(response.child_age_months, response.responses);
        await response.update({
          scores: results.scores,
          results: results.results,
          completed_at: new Date()
        });
      }
      
      console.log('✅ RESULTS SENT - Session:', session_id);
      
      res.json({
        success: true,
        results: response.results,
        scores: response.scores,
        child_age_months: response.child_age_months,
        child_gender: response.child_gender,
        completed_at: response.completed_at
      });
      
    } catch (error) {
      console.error('❌ GET RESULTS ERROR:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get results'
      });
    }
  }
  
  // Get screening statistics
  async getScreeningStats(req, res) {
    try {
      console.log('📈 GET SCREENING STATS REQUEST');
      
      const totalScreenings = await QuestionnaireResponse.count();
      const completedScreenings = await QuestionnaireResponse.count({
        where: { completed_at: { [Op.ne]: null } }
      });
      
      // Get risk distribution
      const riskStats = await QuestionnaireResponse.findAll({
        attributes: [
          'results',
          [sequelize.fn('COUNT', sequelize.col('id')), 'count']
        ],
        where: { completed_at: { [Op.ne]: null } },
        group: ['results'],
        raw: true
      });
      
      console.log('✅ STATS SENT - Total:', totalScreenings, 'Completed:', completedScreenings);
      
      res.json({
        success: true,
        stats: {
          total_screenings: totalScreenings,
          completed_screenings: completedScreenings,
          completion_rate: totalScreenings > 0 ? (completedScreenings / totalScreenings * 100).toFixed(2) : 0,
          risk_distribution: riskStats
        }
      });
      
    } catch (error) {
      console.error('❌ GET STATS ERROR:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get statistics'
      });
    }
  }
  
  // ========== DEBUG METHODS ==========
  
  // Debug current session state
  async debugCurrentState(session_id) {
    try {
      console.log('🐛 DEBUG CURRENT STATE REQUEST:', session_id);
      
      const response = await QuestionnaireResponse.findOne({
        where: { session_id }
      });
      
      if (!response) {
        console.log('❌ SESSION NOT FOUND:', session_id);
        return { error: 'Session not found' };
      }
      
      const responses = response.responses || {};
      const answeredIds = Object.keys(responses).map(id => parseInt(id));
      
      console.log('🐛 DEBUG CURRENT STATE:');
      console.log('   Session:', session_id);
      console.log('   Age:', response.child_age_months);
      console.log('   Answered questions:', answeredIds.length);
      console.log('   Answered IDs:', answeredIds);
      console.log('   Full responses:', JSON.stringify(responses, null, 2));
      
      // Get all available questions
      const ageGroup = this.getAgeGroup(response.child_age_months);
      const availableQuestions = await Question.findAll({
        where: {
          age_group: { [Op.in]: [ageGroup, 'all'] },
          depends_on_previous: null
        },
        order: [['order', 'ASC']],
        raw: true
      });
      
      console.log('   Available questions:', availableQuestions.length);
      availableQuestions.forEach(q => {
        const answered = answeredIds.includes(q.id);
        console.log(`   - ID: ${q.id}, Order: ${q.order}, Answered: ${answered}, Text: ${q.question_text.substring(0, 40)}...`);
      });
      
      return {
        session_id,
        age: response.child_age_months,
        age_group: ageGroup,
        answered_count: answeredIds.length,
        answered_ids: answeredIds,
        responses_data: responses,
        available_questions: availableQuestions.map(q => ({
          id: q.id,
          order: q.order,
          text: q.question_text,
          category: q.category,
          answered: answeredIds.includes(q.id)
        }))
      };
      
    } catch (error) {
      console.error('❌ DEBUG CURRENT STATE ERROR:', error);
      return { error: error.message };
    }
  }

  // Debug query for specific age
  async debugQuery(child_age_months) {
    try {
      console.log('🔍 DEBUG QUERY REQUEST - Age:', child_age_months);
      
      const age_group = this.getAgeGroup(child_age_months);
      
      console.log('🔍 DEBUG QUERY:');
      console.log('   Age:', child_age_months, '-> Age Group:', age_group);
      
      // Get all available questions for this age
      const allQuestions = await Question.findAll({
        where: {
          age_group: { [Op.in]: [age_group, 'all'] }
        },
        order: [['age_group', 'ASC'], ['order', 'ASC']],
        raw: true
      });
      
      console.log('   All available questions:', allQuestions.length);
      allQuestions.forEach(q => {
        console.log(`   - ID: ${q.id}, Age: ${q.age_group}, Order: ${q.order}, Category: ${q.category}, Depends: ${q.depends_on_previous}`);
      });
      
      // Get initial questions only
      const initialQuestions = await Question.findAll({
        where: {
          [Op.and]: [
            { 
              age_group: { 
                [Op.in]: [age_group, 'all'] 
              } 
            },
            {
              [Op.or]: [
                { depends_on_previous: null },
                { depends_on_previous: { [Op.eq]: null } }
              ]
            }
          ]
        },
        order: [['order', 'ASC']],
        limit: 8,
        raw: true
      });
      
      console.log('   Initial questions found:', initialQuestions.length);
      initialQuestions.forEach(q => {
        console.log(`   - ID: ${q.id}, Order: ${q.order}, Text: ${q.question_text.substring(0, 50)}...`);
      });
      
      return {
        age_group,
        all_questions_count: allQuestions.length,
        initial_questions_count: initialQuestions.length,
        all_questions: allQuestions,
        initial_questions: initialQuestions
      };
      
    } catch (error) {
      console.error('❌ DEBUG QUERY ERROR:', error);
      return { error: error.message };
    }
  }

  // Debug all questions in database
  async debugAllQuestions(req, res) {
    try {
      console.log('📋 DEBUG ALL QUESTIONS REQUEST');
      
      const questions = await Question.findAll({
        attributes: ['id', 'question_text', 'age_group', 'category', 'order', 'depends_on_previous'],
        order: [['age_group', 'ASC'], ['order', 'ASC']],
        raw: true
      });
      
      const grouped = questions.reduce((acc, q) => {
        if (!acc[q.age_group]) acc[q.age_group] = [];
        acc[q.age_group].push({
          id: q.id,
          text: q.question_text,
          category: q.category,
          order: q.order,
          depends_on: q.depends_on_previous
        });
        return acc;
      }, {});
      
      // Statistics
      const stats = {
        total: questions.length,
        by_age_group: Object.keys(grouped).reduce((acc, ageGroup) => {
          acc[ageGroup] = grouped[ageGroup].length;
          return acc;
        }, {}),
        by_category: questions.reduce((acc, q) => {
          acc[q.category] = (acc[q.category] || 0) + 1;
          return acc;
        }, {})
      };
      
      console.log('✅ ALL QUESTIONS DEBUG - Total:', questions.length, 'Stats:', stats);
      
      res.json({
        success: true,
        stats: stats,
        questions_by_age: grouped,
        all_questions: questions
      });
      
    } catch (error) {
      console.error('❌ DEBUG ALL QUESTIONS ERROR:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  }

  // Debug next question logic
  async debugNextQuestionLogic(req, res) {
    try {
      const { session_id } = req.params;
      
      console.log('🔍 DEBUG NEXT QUESTION LOGIC - Session:', session_id);
      
      const response = await QuestionnaireResponse.findOne({
        where: { session_id }
      });
      
      if (!response) {
        return res.status(404).json({ success: false, message: 'Session not found' });
      }
      
      const responses = response.responses || {};
      const answeredIds = Object.keys(responses).map(id => parseInt(id));
      const ageGroup = this.getAgeGroup(response.child_age_months);
      
      console.log('🔍 NEXT QUESTION DEBUG:');
      console.log('   Session:', session_id);
      console.log('   Age:', response.child_age_months, '-> Group:', ageGroup);
      console.log('   Answered:', answeredIds.length, 'IDs:', answeredIds);
      
      // Find next question using the same logic as getNextQuestion
      const nextQuestion = await Question.findOne({
        where: {
          age_group: { [Op.in]: [ageGroup, 'all'] },
          depends_on_previous: null,
          id: { [Op.notIn]: answeredIds }
        },
        order: [['order', 'ASC']],
        raw: true
      });
      
      // All available questions for debugging
      const availableQuestions = await Question.findAll({
        where: {
          age_group: { [Op.in]: [ageGroup, 'all'] },
          depends_on_previous: null
        },
        order: [['order', 'ASC']],
        raw: true
      });
      
      const debugInfo = {
        session_id,
        age: response.child_age_months,
        age_group: ageGroup,
        answered_count: answeredIds.length,
        answered_ids: answeredIds,
        next_question: nextQuestion ? {
          id: nextQuestion.id,
          order: nextQuestion.order,
          text: nextQuestion.question_text
        } : null,
        available_questions: availableQuestions.map(q => ({
          id: q.id,
          order: q.order,
          text: q.question_text,
          available: !answeredIds.includes(q.id)
        }))
      };
      
      console.log('✅ NEXT QUESTION DEBUG RESULT:', debugInfo.next_question);
      
      res.json({
        success: true,
        ...debugInfo
      });
      
    } catch (error) {
      console.error('❌ DEBUG NEXT QUESTION ERROR:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  }
  
  // ========== HELPER METHODS ==========
  
  // Get initial questions based on age
  async getInitialQuestions(child_age_months) {
    console.log('🔍 GET INITIAL QUESTIONS - Age:', child_age_months, 'months');
    
    const age_group = this.getAgeGroup(child_age_months);
    
    console.log('📊 AGE GROUP CALCULATION:', child_age_months, '->', age_group);
    
    try {
      // Get basic questions only (without depends_on_previous)
      const questions = await Question.findAll({
        where: {
          [Op.and]: [
            { 
              age_group: { 
                [Op.in]: [age_group, 'all'] 
              } 
            },
            {
              [Op.or]: [
                { depends_on_previous: null },
                { depends_on_previous: { [Op.eq]: null } }
              ]
            }
          ]
        },
        order: [['order', 'ASC']],
        limit: 8
      });
      
      console.log('📋 INITIAL QUESTIONS FOUND:', questions.length, 'for age group:', age_group);
      
      // If no questions, get any general questions
      if (questions.length === 0) {
        console.log('🔄 NO QUESTIONS FOUND - Getting fallback questions...');
        const fallbackQuestions = await Question.findAll({
          where: {
            age_group: 'all',
            [Op.or]: [
              { depends_on_previous: null },
              { depends_on_previous: { [Op.eq]: null } }
            ]
          },
          order: [['order', 'ASC']],
          limit: 8
        });
        
        console.log('🔄 FALLBACK QUESTIONS FOUND:', fallbackQuestions.length);
        return fallbackQuestions.map(q => this.formatQuestion(q));
      }
      
      return questions.map(q => this.formatQuestion(q));
      
    } catch (error) {
      console.error('❌ GET INITIAL QUESTIONS ERROR:', error);
      return [];
    }
  }
  
  // Determine next question based on adaptive logic
  async getNextQuestion(child_age_months, responses, current_question_id, current_answer) {
    const answeredQuestions = Object.keys(responses).length;
    const ageGroup = this.getAgeGroup(child_age_months);
    
    // Convert answered IDs to numbers for proper comparison
    const answeredIds = Object.keys(responses).map(id => parseInt(id));
    
    console.log('🔄 GET NEXT QUESTION:');
    console.log('   - Age:', child_age_months, '-> Group:', ageGroup);
    console.log('   - Answered:', answeredQuestions, 'IDs:', answeredIds);
    console.log('   - Current Question:', current_question_id, 'Answer:', current_answer);
    
    // Find next question (avoid answered ones)
    const nextQuestion = await Question.findOne({
      where: {
        age_group: { [Op.in]: [ageGroup, 'all'] },
        depends_on_previous: null,
        id: { [Op.notIn]: answeredIds }
      },
      order: [['order', 'ASC']]
    });
    
    if (nextQuestion) {
      console.log('✅ NEXT QUESTION FOUND - ID:', nextQuestion.id, 'Order:', nextQuestion.order);
      return this.formatQuestion(nextQuestion);
    }
    
    console.log('🎉 NO MORE QUESTIONS - Screening completed');
    return null;
  }
  
  // Calculate final results
  async calculateResults(child_age_months, responses) {
    console.log('🧮 CALCULATING RESULTS - Age:', child_age_months, 'Responses:', Object.keys(responses).length);
    
    const scores = {
      autism: { total: 0, critical: 0 },
      adhd: { inattention: 0, hyperactive: 0 },
      speech: { total: 0, age_appropriate: 0 }
    };
    
    const results = {
      autism_risk: 'low',
      adhd_risk: 'none',
      speech_delay: 'none',
      recommendations: [],
      next_steps: []
    };
    
    // Calculate scores for each category
    for (const [question_id, response] of Object.entries(responses)) {
      const question = await Question.findByPk(question_id);
      if (question && question.scoring_rules) {
        const score = this.calculateScore(question.scoring_rules, response.answer);
        
        // Autism scoring
        if (question.category === 'autism') {
          scores.autism.total += score;
          if (question.is_critical && response.answer === 'no') {
            scores.autism.critical += 1;
          }
        }
        
        // ADHD scoring
        if (question.category === 'adhd_inattention') {
          if (score >= 2) scores.adhd.inattention += 1;
        }
        if (question.category === 'adhd_hyperactive') {
          if (score >= 2) scores.adhd.hyperactive += 1;
        }
        
        // Speech scoring
        if (question.category === 'speech') {
          scores.speech.total += score;
          if (response.answer === 'yes') {
            scores.speech.age_appropriate += 1;
          }
        }
      }
    }
    
    console.log('📊 CALCULATED SCORES:', scores);
    
    // Determine autism risk
    if (child_age_months <= 60) {
      if (scores.autism.critical >= 3) {
        results.autism_risk = 'high';
        results.recommendations.push('Immediate evaluation by autism specialist recommended');
        results.next_steps.push('Schedule developmental pediatrician appointment');
      } else if (scores.autism.critical >= 2 && scores.autism.total >= 8) {
        results.autism_risk = 'medium';
        results.recommendations.push('Follow-up with pediatrician for detailed assessment');
        results.next_steps.push('Monitor social communication skills');
      } else if (scores.autism.total >= 6) {
        results.autism_risk = 'low';
        results.recommendations.push('Continue routine developmental monitoring');
      }
    }
    
    // Determine ADHD risk
    if (child_age_months >= 72) {
      if (scores.adhd.inattention >= 6 || scores.adhd.hyperactive >= 6) {
        results.adhd_risk = 'high';
        results.recommendations.push('Comprehensive ADHD evaluation recommended');
        results.next_steps.push('Consult with child psychologist or psychiatrist');
      } else if (scores.adhd.inattention >= 4 || scores.adhd.hyperactive >= 4) {
        results.adhd_risk = 'medium';
        results.recommendations.push('School observation and teacher feedback recommended');
        results.next_steps.push('Implement behavior management strategies');
      }
    }
    
    // Determine speech delay
    const expectedMilestones = this.getExpectedMilestones(child_age_months);
    const speechDelayScore = expectedMilestones - scores.speech.age_appropriate;
    
    if (speechDelayScore >= 4) {
      results.speech_delay = 'significant';
      results.recommendations.push('Immediate speech-language evaluation recommended');
      results.next_steps.push('Contact speech-language pathologist');
    } else if (speechDelayScore >= 2) {
      results.speech_delay = 'moderate';
      results.recommendations.push('Speech therapy assessment recommended');
      results.next_steps.push('Practice language-building activities at home');
    } else if (speechDelayScore >= 1) {
      results.speech_delay = 'mild';
      results.recommendations.push('Continue language stimulation activities');
    }
    
    // Add general recommendations
    if (results.autism_risk === 'low' && results.adhd_risk === 'none' && results.speech_delay === 'none') {
      results.recommendations.push('Child appears to be developing typically for their age');
      results.recommendations.push('Continue with routine pediatric check-ups');
    }
    
    console.log('✅ FINAL RESULTS:', results);
    
    return { scores, results };
  }
  
  // ========== UTILITY METHODS ==========
  
  getAgeGroup(age_months) {
    if (age_months >= 16 && age_months <= 30) {
      return '16-30';
    } else if (age_months >= 31 && age_months <= 60) {
      return '2.5-5';
    } else if (age_months >= 61) {
      return '6+';
    }
    return 'all';
  }
  
  formatQuestion(question) {
    return {
      id: question.id,
      text: question.question_text,
      type: question.question_type,
      options: question.options,
      is_critical: question.is_critical,
      category: question.category,
      order: question.order
    };
  }
  
  calculateProgress(child_age_months, responses) {
    const totalQuestions = this.getTotalQuestionsCount(child_age_months);
    const answered = Object.keys(responses).length;
    const progress = Math.min(Math.round((answered / totalQuestions) * 100), 100);
    
    console.log('📊 PROGRESS CALCULATION:', answered, '/', totalQuestions, '=', progress + '%');
    
    return progress;
  }
  
  getTotalQuestionsCount(age_months) {
    if (age_months <= 30) return 20;
    if (age_months <= 60) return 25;
    return 30;
  }
  
  getExpectedMilestones(age_months) {
    if (age_months <= 30) return 5;
    if (age_months <= 48) return 6;
    if (age_months <= 60) return 7;
    return 8;
  }
  
  calculateScore(scoring_rules, answer) {
    if (typeof scoring_rules === 'object' && scoring_rules[answer] !== undefined) {
      return scoring_rules[answer];
    }
    return 0;
  }

  // Additional helper methods for adaptive logic
  async getMCHATQuestion(orderOffset) {
    const question = await Question.findOne({
      where: {
        questionnaire_id: 1,
        order: orderOffset + 1
      }
    });
    return question ? this.formatQuestion(question) : null;
  }
  
  async getADHDQuestion(orderOffset) {
    const question = await Question.findOne({
      where: {
        questionnaire_id: 3,
        order: orderOffset + 1
      }
    });
    return question ? this.formatQuestion(question) : null;
  }
  
  async getSpeechQuestion(child_age_months, orderOffset) {
    const ageGroup = this.getAgeGroup(child_age_months);
    const question = await Question.findOne({
      where: {
        questionnaire_id: 2,
        age_group: ageGroup,
        order: orderOffset + 1
      }
    });
    return question ? this.formatQuestion(question) : null;
  }
  
  async countCriticalNoAnswers(responses) {
    let count = 0;
    for (const [question_id, response] of Object.entries(responses)) {
      const question = await Question.findByPk(question_id);
      if (question && question.is_critical && response.answer === 'no') {
        count++;
      }
    }
    return count;
  }
  
  async calculateADHDScore(responses) {
    let score = 0;
    for (const [question_id, response] of Object.entries(responses)) {
      const question = await Question.findByPk(question_id);
      if (question && (question.category === 'adhd_inattention' || question.category === 'adhd_hyperactive')) {
        if (response.answer >= 2) {
          score++;
        }
      }
    }
    return score;
  }
  
  async calculateSpeechScore(child_age_months, responses) {
    let delayScore = 0;
    const expectedCount = this.getExpectedMilestones(child_age_months);
    
    for (const [question_id, response] of Object.entries(responses)) {
      const question = await Question.findByPk(question_id);
      if (question && question.category === 'speech') {
        if (response.answer === 'no') {
          delayScore++;
        }
      }
    }
    
    return delayScore;
  }
}

module.exports = ScreeningController;