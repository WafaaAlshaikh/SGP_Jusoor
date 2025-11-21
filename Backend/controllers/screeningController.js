const { Questionnaire, Question, QuestionnaireResponse, sequelize } = require('../model/index');
const { Op } = require('sequelize');
const EnhancedScreeningController = require('./enhancedScreeningController');
const jwt = require('jsonwebtoken');
const User = require('../model/User'); 

class ScreeningController {

  constructor() {
    this.enhancedScreening = new EnhancedScreeningController();
  }
  
  // ========== MAIN METHODS ==========
  
  async startScreening(req, res) {
    try {
      const { child_age_months, child_gender, previous_diagnosis } = req.body;
      
      console.log('🎯 START SCREENING:', { child_age_months, child_gender });
      
      if (!child_age_months) {
        return res.status(400).json({
          success: false,
          message: 'Child age is required'
        });
      }

      const session_id = `screening_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      // Create session
      const response = await QuestionnaireResponse.create({
        session_id,
        child_age_months: parseInt(child_age_months),
        child_gender,
        previous_diagnosis: previous_diagnosis || false,
        responses: {},
        screening_phase: 'initial', // initial, detailed, performance
        scores: {
          autism: { total: 0, critical: 0 },
          adhd: { inattention: 0, hyperactive: 0 },
          speech: { total: 0 }
        },
        results: {}
      });

      // Get initial screening questions
      const initialQuestions = await this.getInitialQuestions(parseInt(child_age_months));
      const totalEstimated = this.estimateTotalQuestions(parseInt(child_age_months));

      console.log('✅ SCREENING STARTED:', session_id, '- Questions:', initialQuestions.length);

      res.json({
        success: true,
        session_id,
        phase: 'initial',
        questions: initialQuestions,
        progress: 0,
        total_estimated: totalEstimated,
        age_group: this.getAgeGroup(child_age_months),
        message: this.getWelcomeMessage(child_age_months)
      });
      
    } catch (error) {
      console.error('❌ START ERROR:', error);
      res.status(500).json({ success: false, message: 'Failed to start screening' });
    }
  }

  // async submitAnswer(req, res) {
  //   try {
  //     const { session_id, question_id, answer } = req.body;
      
  //     console.log('📨 SUBMIT ANSWER:', { session_id, question_id, answer });
      
  //     if (!session_id || !question_id || answer === undefined) {
  //       return res.status(400).json({
  //         success: false,
  //         message: 'Session ID, question ID and answer are required'
  //       });
  //     }

  //     const response = await QuestionnaireResponse.findOne({ where: { session_id } });
      
  //     if (!response) {
  //       return res.status(404).json({
  //         success: false,
  //         message: 'Screening session not found'
  //       });
  //     }

  //     const questionIdNum = parseInt(question_id);
  //     const currentResponses = response.responses || {};
      
  //     // Save answer
  //     const updatedResponses = Object.assign({}, currentResponses, {
  //       [questionIdNum]: {
  //         answer,
  //         timestamp: new Date()
  //       }
  //     });

  //     await response.update({ responses: updatedResponses });

  //     const answeredCount = Object.keys(updatedResponses).length;
  //     console.log('✅ ANSWER SAVED - Total:', answeredCount);

  //     // Calculate current scores
  //     const currentScores = await this.calculateCurrentScores(
  //       response.child_age_months,
  //       updatedResponses
  //     );

  //     await response.update({ scores: currentScores });

  //     // Determine next step
  //     const nextStep = await this.determineNextStep(
  //       response.child_age_months,
  //       updatedResponses,
  //       currentScores,
  //       response.screening_phase
  //     );

  //     if (nextStep.completed) {
  //       // Calculate final results
  //       console.log('🎉 SCREENING COMPLETED');
  //       const finalResults = await this.calculateFinalResults(
  //         response.child_age_months,
  //         updatedResponses,
  //         currentScores
  //       );

  //       await response.update({
  //         results: finalResults,
  //         completed_at: new Date()
  //       });

  //       return res.json({
  //         success: true,
  //         completed: true,
  //         results: finalResults,
  //         scores: currentScores,
  //         progress: 100
  //       });
  //     }

  //     // Update phase if needed
  //     if (nextStep.new_phase) {
  //       await response.update({ screening_phase: nextStep.new_phase });
  //     }

  //     // Calculate progress
  //     const progress = this.calculateDynamicProgress(
  //       response.child_age_months,
  //       updatedResponses,
  //       nextStep.new_phase || response.screening_phase
  //     );

  //     console.log('➡️ NEXT QUESTION:', nextStep.next_question.id, '- Phase:', nextStep.new_phase || response.screening_phase);

  //     res.json({
  //       success: true,
  //       completed: false,
  //       next_question: nextStep.next_question,
  //       phase: nextStep.new_phase || response.screening_phase,
  //       phase_message: nextStep.phase_message,
  //       progress: progress,
  //       answered_questions: answeredCount,
  //       current_scores: currentScores
  //     });

  //   } catch (error) {
  //     console.error('❌ SUBMIT ERROR:', error);
  //     res.status(500).json({ success: false, message: 'Failed to save answer' });
  //   }
  // }

  // ========== HELPER METHODS ==========

  async getInitialQuestions(child_age_months) {
    const ageGroup = this.getAgeGroup(child_age_months);
    
    console.log('🔍 GET INITIAL QUESTIONS - Age:', child_age_months, '→ Group:', ageGroup);

    let questions;

    if (child_age_months >= 16 && child_age_months <= 30) {
      // Age 16-30 months: M-CHAT initial (5 questions)
      questions = await Question.findAll({
        where: {
          age_group: '16-30',
          category: { [Op.in]: ['autism', 'speech'] },
          is_initial: true
        },
        order: [['order', 'ASC']],
        limit: 5
      });
    } else if (child_age_months >= 31 && child_age_months <= 60) {
      // Age 2.5-5 years: Mixed screening (7 questions)
      questions = await Question.findAll({
        where: {
          age_group: '2.5-5',
          category: { [Op.in]: ['autism', 'speech', 'adhd_inattention', 'adhd_hyperactive'] },
          is_initial: true
        },
        order: [['order', 'ASC']],
        limit: 7
      });
    } else {
      // Age 6+: ADHD + Speech screening (8 questions)
      questions = await Question.findAll({
        where: {
          age_group: '6+',
          category: { [Op.in]: ['adhd_inattention', 'adhd_hyperactive', 'speech'] },
          is_initial: true
        },
        order: [['order', 'ASC']],
        limit: 8
      });
    }

    console.log('📋 INITIAL QUESTIONS FOUND:', questions.length);
    return questions.map(q => this.formatQuestion(q));
  }

  async determineNextStep(child_age_months, responses, currentScores, currentPhase) {
    const ageGroup = this.getAgeGroup(child_age_months);
    const answeredIds = Object.keys(responses).map(id => parseInt(id));

    console.log('🔄 DETERMINE NEXT STEP - Phase:', currentPhase, '- Scores:', currentScores);

    // Phase 1: Initial screening
    if (currentPhase === 'initial') {
      const initialComplete = await this.isInitialPhaseComplete(child_age_months, answeredIds);
      
      if (initialComplete) {
        const needsDetailed = this.needsDetailedAssessment(child_age_months, currentScores);
        
        if (!needsDetailed) {
          // Low risk - complete screening
          return { completed: true };
        }

        // Determine which detailed questionnaires are needed
        const detailedType = this.determineDetailedType(child_age_months, currentScores);
        
        const nextQuestion = await this.getDetailedQuestion(
          child_age_months,
          detailedType,
          answeredIds
        );

        return {
          completed: false,
          new_phase: 'detailed',
          next_question: this.formatQuestion(nextQuestion),
          phase_message: this.getPhaseMessage(detailedType)
        };
      }

      // Continue initial phase
      const nextQuestion = await this.getNextInitialQuestion(child_age_months, answeredIds);
      return {
        completed: false,
        next_question: this.formatQuestion(nextQuestion)
      };
    }

    // Phase 2: Detailed assessment
    if (currentPhase === 'detailed') {
      const detailedType = this.determineDetailedType(child_age_months, currentScores);
      const nextQuestion = await this.getDetailedQuestion(
        child_age_months,
        detailedType,
        answeredIds
      );

      if (!nextQuestion) {
        // Check if we need performance questions (ADHD only)
        if (child_age_months >= 72 && 
            (currentScores.adhd.inattention >= 6 || currentScores.adhd.hyperactive >= 6)) {
          const perfQuestion = await this.getPerformanceQuestion(answeredIds);
          
          return {
            completed: false,
            new_phase: 'performance',
            next_question: this.formatQuestion(perfQuestion),
            phase_message: 'Now some questions about daily performance'
          };
        }

        // All questions completed
        return { completed: true };
      }

      return {
        completed: false,
        next_question: this.formatQuestion(nextQuestion)
      };
    }

    // Phase 3: Performance assessment (ADHD)
    if (currentPhase === 'performance') {
      const nextQuestion = await this.getPerformanceQuestion(answeredIds);
      
      if (!nextQuestion) {
        return { completed: true };
      }

      return {
        completed: false,
        next_question: this.formatQuestion(nextQuestion)
      };
    }

    return { completed: true };
  }

  async calculateCurrentScores(child_age_months, responses) {
    const scores = {
      autism: { total: 0, critical: 0 },
      adhd: { inattention: 0, hyperactive: 0 },
      speech: { total: 0 }
    };

    for (const [question_id, response] of Object.entries(responses)) {
      const question = await Question.findByPk(question_id);
      
      if (!question) continue;

      const score = this.calculateScore(question.scoring_rules, response.answer);

      if (question.category === 'autism') {
        scores.autism.total += score;
        if (question.is_critical && response.answer === 'no') {
          scores.autism.critical += 1;
        }
      } else if (question.category === 'adhd_inattention') {
        if (response.answer >= 2) {
          scores.adhd.inattention += 1;
        }
      } else if (question.category === 'adhd_hyperactive') {
        if (response.answer >= 2) {
          scores.adhd.hyperactive += 1;
        }
      } else if (question.category === 'speech') {
        scores.speech.total += score;
      }
    }

    return scores;
  }

  needsDetailedAssessment(child_age_months, scores) {
    if (child_age_months >= 16 && child_age_months <= 30) {
      // M-CHAT screening
      return scores.autism.critical >= 2 || scores.autism.total >= 3;
    } else if (child_age_months >= 31 && child_age_months <= 60) {
      // Mixed screening
      return scores.autism.total >= 3 || scores.speech.total >= 4;
    } else {
      // ADHD + Speech screening
      return scores.adhd.inattention >= 3 || 
             scores.adhd.hyperactive >= 3 || 
             scores.speech.total >= 4;
    }
  }

  determineDetailedType(child_age_months, scores) {
    const types = [];

    if (child_age_months <= 60 && (scores.autism.critical >= 2 || scores.autism.total >= 3)) {
      types.push('autism');
    }

    if (scores.speech.total >= 4) {
      types.push('speech');
    }

    if (child_age_months >= 72) {
      if (scores.adhd.inattention >= 3) types.push('adhd_inattention');
      if (scores.adhd.hyperactive >= 3) types.push('adhd_hyperactive');
    }

    return types;
  }

  async getDetailedQuestion(child_age_months, detailedTypes, answeredIds) {
    const ageGroup = this.getAgeGroup(child_age_months);

    // Get next unanswered detailed question
    const question = await Question.findOne({
      where: {
        age_group: { [Op.in]: [ageGroup, 'all'] },
        category: { [Op.in]: detailedTypes },
        is_initial: false,
        id: { [Op.notIn]: answeredIds }
      },
      order: [['order', 'ASC']]
    });

    return question;
  }

  async getPerformanceQuestion(answeredIds) {
    const question = await Question.findOne({
      where: {
        category: 'performance',
        id: { [Op.notIn]: answeredIds }
      },
      order: [['order', 'ASC']]
    });

    return question;
  }

  async isInitialPhaseComplete(child_age_months, answeredIds) {
    const expectedInitial = this.getExpectedInitialCount(child_age_months);
    return answeredIds.length >= expectedInitial;
  }

  getExpectedInitialCount(child_age_months) {
    if (child_age_months >= 16 && child_age_months <= 30) return 5;
    if (child_age_months >= 31 && child_age_months <= 60) return 7;
    return 8;
  }

  async calculateFinalResults(child_age_months, responses, scores) {
    const results = {
      primary_concern: null,
      secondary_concern: null,
      confidence_level: 'medium',
      risk_levels: {},
      recommendations: [],
      next_steps: [],
      red_flags: [],
      positive_indicators: []
    };

    // Determine Autism Risk
    if (child_age_months <= 60) {
      if (scores.autism.critical >= 3) {
        results.risk_levels.autism = 'high';
        results.primary_concern = 'autism';
        results.recommendations.push('Immediate evaluation by autism specialist');
        results.next_steps.push('Schedule appointment with developmental pediatrician');
        results.red_flags.push('Multiple critical autism signs');
      } else if (scores.autism.critical >= 2 && scores.autism.total >= 8) {
        results.risk_levels.autism = 'medium';
        if (!results.primary_concern) results.primary_concern = 'autism';
        results.recommendations.push('Follow-up with pediatrician for detailed assessment');
        results.next_steps.push('Monitor social communication skills');
      } else if (scores.autism.total >= 6) {
        results.risk_levels.autism = 'low';
        results.recommendations.push('Continue routine developmental monitoring');
      }
    }

    // Determine ADHD Risk
    if (child_age_months >= 72) {
      const hasPerformanceImpact = await this.checkPerformanceImpact(responses);
      
      if (scores.adhd.inattention >= 6 && hasPerformanceImpact) {
        results.risk_levels.adhd = 'high';
        if (!results.primary_concern) {
          results.primary_concern = 'adhd_inattention';
        } else {
          results.secondary_concern = 'adhd_inattention';
        }
        results.recommendations.push('Comprehensive ADHD evaluation');
        results.next_steps.push('Consult child psychologist or psychiatrist');
      }
      
      if (scores.adhd.hyperactive >= 6 && hasPerformanceImpact) {
        results.risk_levels.adhd_hyperactive = 'high';
        if (!results.primary_concern) {
          results.primary_concern = 'adhd_hyperactive';
        }
        results.recommendations.push('Evaluation for hyperactivity and impulsivity');
      }
    }

    // Determine Speech Delay
    const expectedMilestones = this.getExpectedSpeechMilestones(child_age_months);
    const speechDelay = scores.speech.total;
    
    if (speechDelay >= 9) {
      results.risk_levels.speech = 'significant';
      if (!results.primary_concern) {
        results.primary_concern = 'speech_delay';
      } else if (!results.secondary_concern) {
        results.secondary_concern = 'speech_delay';
      }
      results.recommendations.push('Immediate evaluation by speech-language pathologist');
      results.next_steps.push('Contact speech therapist');
    } else if (speechDelay >= 4) {
      results.risk_levels.speech = 'moderate';
      if (!results.secondary_concern) results.secondary_concern = 'speech_delay';
      results.recommendations.push('Speech therapy evaluation recommended');
      results.next_steps.push('Practice language building activities at home');
    }

    // If all normal
    if (!results.primary_concern) {
      results.confidence_level = 'high';
      results.recommendations.push('Your child appears to be developing normally for their age');
      results.recommendations.push('Continue routine check-ups with pediatrician');
      results.positive_indicators.push('Normal development in key areas');
    }

    return results;
  }

  async checkPerformanceImpact(responses) {
    let impactCount = 0;
    
    for (const [question_id, response] of Object.entries(responses)) {
      const question = await Question.findByPk(question_id);
      
      if (question && question.category === 'performance' && response.answer >= 4) {
        impactCount++;
      }
    }

    return impactCount >= 1;
  }

  // ========== UTILITY METHODS ==========

  getAgeGroup(age_months) {
    if (age_months >= 16 && age_months <= 30) return '16-30';
    if (age_months >= 31 && age_months <= 60) return '2.5-5';
    if (age_months >= 61) return '6+';
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

  calculateScore(scoring_rules, answer) {
    if (typeof scoring_rules === 'object' && scoring_rules[answer] !== undefined) {
      return scoring_rules[answer];
    }
    return 0;
  }

  estimateTotalQuestions(age_months) {
    if (age_months <= 30) return 20;
    if (age_months <= 60) return 25;
    return 30;
  }

  calculateDynamicProgress(age_months, responses, phase) {
    const answeredCount = Object.keys(responses).length;
    const estimated = this.estimateTotalQuestions(age_months);
    
    let phaseWeight = 0.2; // initial phase
    if (phase === 'detailed') phaseWeight = 0.6;
    if (phase === 'performance') phaseWeight = 0.9;
    
    const baseProgress = Math.min((answeredCount / estimated) * 100, 90);
    const adjustedProgress = baseProgress * phaseWeight + (phaseWeight * 100);
    
    return Math.min(Math.round(adjustedProgress), 99);
  }

  getWelcomeMessage(age_months) {
    if (age_months <= 30) {
      return 'We will start with early development screening (M-CHAT)';
    } else if (age_months <= 60) {
      return 'We will assess your child\'s social and language development';
    } else {
      return 'We will assess attention, behavior, and speech';
    }
  }

  getPhaseMessage(detailedTypes) {
    if (detailedTypes.includes('autism')) {
      return 'We will ask more detailed questions about autism';
    }
    if (detailedTypes.includes('adhd_inattention') || detailedTypes.includes('adhd_hyperactive')) {
      return 'We will ask more detailed questions about attention and behavior';
    }
    if (detailedTypes.includes('speech')) {
      return 'We will ask additional questions about speech and language';
    }
    return 'We will complete the assessment with more detailed questions';
  }

  getExpectedSpeechMilestones(age_months) {
    if (age_months <= 36) return 5;
    if (age_months <= 48) return 6;
    if (age_months <= 60) return 7;
    return 8;
  }

  // async getResults(req, res) {
  //   try {
  //     const { session_id } = req.params;
      
  //     const response = await QuestionnaireResponse.findOne({ where: { session_id } });
      
  //     if (!response) {
  //       return res.status(404).json({ success: false, message: 'Results not found' });
  //     }

  //     if (!response.completed_at) {
  //       const results = await this.calculateFinalResults(
  //         response.child_age_months,
  //         response.responses,
  //         response.scores
  //       );

  //       await response.update({
  //         results: results,
  //         completed_at: new Date()
  //       });
  //     }

  //     res.json({
  //       success: true,
  //       results: response.results,
  //       scores: response.scores,
  //       child_age_months: response.child_age_months,
  //       child_gender: response.child_gender,
  //       completed_at: response.completed_at
  //     });
      
  //   } catch (error) {
  //     console.error('❌ GET RESULTS ERROR:', error);
  //     res.status(500).json({ success: false, message: 'Failed to get results' });
  //   }
  // }

  async getScreeningStats(req, res) {
    try {
      const totalScreenings = await QuestionnaireResponse.count();
      const completedScreenings = await QuestionnaireResponse.count({
        where: { completed_at: { [Op.ne]: null } }
      });

      const ageDistribution = await QuestionnaireResponse.findAll({
        attributes: [
          [sequelize.fn('COUNT', sequelize.col('id')), 'count'],
          'child_age_months'
        ],
        group: ['child_age_months'],
        raw: true
      });

      res.json({
        success: true,
        stats: {
          total_screenings: totalScreenings,
          completed_screenings: completedScreenings,
          completion_rate: totalScreenings > 0 ? 
            ((completedScreenings / totalScreenings) * 100).toFixed(2) : 0,
          age_distribution: ageDistribution
        }
      });
    } catch (error) {
      console.error('❌ GET STATS ERROR:', error);
      res.status(500).json({ success: false, message: 'Failed to get statistics' });
    }
  }

  // Debug endpoint
  async debugSession(req, res) {
    try {
      const { session_id } = req.params;
      
      const response = await QuestionnaireResponse.findOne({ where: { session_id } });
      
      if (!response) {
        return res.status(404).json({ success: false, message: 'Session not found' });
      }

      const answeredIds = Object.keys(response.responses).map(id => parseInt(id));
      
      res.json({
        success: true,
        debug_info: {
          session_id: response.session_id,
          age_months: response.child_age_months,
          age_group: this.getAgeGroup(response.child_age_months),
          current_phase: response.screening_phase,
          answered_count: answeredIds.length,
          answered_ids: answeredIds,
          current_scores: response.scores,
          responses: response.responses
        }
      });
    } catch (error) {
      console.error('❌ DEBUG ERROR:', error);
      res.status(500).json({ success: false, message: 'Debug failed' });
    }
  }

  async getNextInitialQuestion(child_age_months, answeredIds) {
    const ageGroup = this.getAgeGroup(child_age_months);
    
    const question = await Question.findOne({
      where: {
        age_group: ageGroup,
        is_initial: true,
        id: { [Op.notIn]: answeredIds }
      },
      order: [['order', 'ASC']]
    });

    return question;
  }


  // ========== ENHANCED SUBMIT ANSWER ==========
async submitAnswer(req, res) {
  try {
    const { session_id, question_id, answer } = req.body;
    
    console.log('📨 SUBMIT ANSWER:', { session_id, question_id, answer });
    
    if (!session_id || !question_id || answer === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Session ID, question ID and answer are required'
      });
    }

    const response = await QuestionnaireResponse.findOne({ where: { session_id } });
    
    if (!response) {
      return res.status(404).json({
        success: false,
        message: 'Screening session not found'
      });
    }

    const questionIdNum = parseInt(question_id);
    const currentResponses = response.responses || {};
    
    // Save answer
    const updatedResponses = Object.assign({}, currentResponses, {
      [questionIdNum]: {
        answer,
        timestamp: new Date()
      }
    });

    await response.update({ responses: updatedResponses });

    const answeredCount = Object.keys(updatedResponses).length;
    console.log('✅ ANSWER SAVED - Total:', answeredCount);

    // Calculate current scores
    const currentScores = await this.calculateCurrentScores(
      response.child_age_months,
      updatedResponses
    );

    await response.update({ scores: currentScores });

    // Determine next step
    const nextStep = await this.determineNextStep(
      response.child_age_months,
      updatedResponses,
      currentScores,
      response.screening_phase
    );

    if (nextStep.completed) {
      // Calculate final results
      console.log('🎉 SCREENING COMPLETED');
      const finalResults = await this.calculateFinalResults(
        response.child_age_months,
        updatedResponses,
        currentScores
      );

      // ✅ GET PARENT LOCATION FROM TOKEN
      let parentLocation = {};
      try {
        const token = req.headers.authorization?.split(' ')[1];
        if (token) {
          const decoded = jwt.verify(token, process.env.JWT_SECRET);
          const parentUser = await User.findByPk(decoded.user_id);
          if (parentUser) {
            parentLocation = {
              lat: parentUser.location_lat,
              lng: parentUser.location_lng,
              city: parentUser.city,
              address: parentUser.location_address
            };
            console.log('📍 Parent location from token:', parentLocation);
          }
        }
      } catch (tokenError) {
        console.log('⚠️ Could not get parent location from token:', tokenError.message);
      }

      // ENHANCED: Add AI analysis and recommendations
      let enhancedAnalysis = null;
      try {
        enhancedAnalysis = await this.enhancedScreening.analyzeScreeningResults(
          finalResults,
          response.child_age_months,
          {
            city: response.city || '',
            address: response.address || ''
          },
          parentLocation // ✅ نمرر موقع الأب
        );
        
        // Merge enhanced analysis with final results
        finalResults.enhanced_analysis = enhancedAnalysis;
        
      } catch (enhancedError) {
        console.error('❌ Enhanced analysis failed, using basic results:', enhancedError);
        finalResults.enhanced_analysis = {
          success: false,
          error: enhancedError.message
        };
      }

      await response.update({
        results: finalResults,
        completed_at: new Date()
      });

      return res.json({
        success: true,
        completed: true,
        results: finalResults,
        scores: currentScores,
        progress: 100,
        // Include enhanced analysis in response
        enhanced_analysis: enhancedAnalysis
      });
    }

    // Update phase if needed
    if (nextStep.new_phase) {
      await response.update({ screening_phase: nextStep.new_phase });
    }

    // Calculate progress
    const progress = this.calculateDynamicProgress(
      response.child_age_months,
      updatedResponses,
      nextStep.new_phase || response.screening_phase
    );

    console.log('➡️ NEXT QUESTION:', nextStep.next_question.id, '- Phase:', nextStep.new_phase || response.screening_phase);

    res.json({
      success: true,
      completed: false,
      next_question: nextStep.next_question,
      phase: nextStep.new_phase || response.screening_phase,
      phase_message: nextStep.phase_message,
      progress: progress,
      answered_questions: answeredCount,
      current_scores: currentScores
    });

  } catch (error) {
    console.error('❌ SUBMIT ERROR:', error);
    res.status(500).json({ success: false, message: 'Failed to save answer' });
  }
}

  // ========== ENHANCED GET RESULTS ==========
  async getResults(req, res) {
    try {
      const { session_id } = req.params;
      
      const response = await QuestionnaireResponse.findOne({ where: { session_id } });
      
      if (!response) {
        return res.status(404).json({ success: false, message: 'Results not found' });
      }

      if (!response.completed_at) {
        const results = await this.calculateFinalResults(
          response.child_age_months,
          response.responses,
          response.scores
        );

        // ENHANCED: Add AI analysis if not already present
        if (!results.enhanced_analysis) {
          try {
            const enhancedAnalysis = await this.enhancedScreening.analyzeScreeningResults(
              results,
              response.child_age_months,
              {
                city: response.city || '',
                address: response.address || ''
              }
            );
            results.enhanced_analysis = enhancedAnalysis;
          } catch (error) {
            console.error('❌ Enhanced analysis in getResults failed:', error);
            results.enhanced_analysis = { success: false, error: error.message };
          }
        }

        await response.update({
          results: results,
          completed_at: new Date()
        });
      }

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
      res.status(500).json({ success: false, message: 'Failed to get results' });
    }
  }

  // ========== NEW: GET ENHANCED RECOMMENDATIONS ==========
  async getEnhancedRecommendations(req, res) {
    try {
      const { session_id } = req.params;

      const response = await QuestionnaireResponse.findOne({ 
        where: { session_id } 
      });

      if (!response) {
        return res.status(404).json({ 
          success: false, 
          message: 'Screening session not found' 
        });
      }

      if (!response.completed_at) {
        return res.status(400).json({ 
          success: false, 
          message: 'Screening not completed yet' 
        });
      }

      // Get enhanced analysis
      const enhancedAnalysis = await this.enhancedScreening.enhanceScreeningResults(session_id);

      res.json({
        success: true,
        session_id,
        enhanced_recommendations: enhancedAnalysis,
        screening_completed: response.completed_at
      });

    } catch (error) {
      console.error('❌ GET ENHANCED RECOMMENDATIONS ERROR:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Failed to get enhanced recommendations' 
      });
    }
  }
}

module.exports = ScreeningController;