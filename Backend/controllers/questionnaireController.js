const Questionnaire = require('../model/Questionnaire');
const Question = require('../model/Question');
const Child = require('../model/Child');
const { Op } = require('sequelize');
const AIAnalysisService = require('../services/aiAnalysisService');

exports.getQuestions = async (req, res) => {
  try {
    const { child_id, previous_answers, language = 'ar' } = req.query;
    const parentId = req.user.user_id;

    console.log('📋 جلب أسئلة الاستبيان:', { parentId, child_id, language });

    let where = { is_active: true };
    let childAge = null;

    if (child_id) {
      const child = await Child.findOne({
        where: { 
          child_id: child_id, 
          parent_id: parentId,
          deleted_at: null 
        }
      });
      
      if (child && child.date_of_birth) {
        childAge = calculateAge(child.date_of_birth);
        console.log('👶 عمر الطفل:', childAge);
        
        where = {
          ...where,
          [Op.and]: [
            { min_age: { [Op.lte]: childAge } },
            { max_age: { [Op.gte]: childAge } }
          ]
        };
      }
    }

    let questions = await Question.findAll({ 
      where,
      order: [['question_id', 'ASC']]
    });

    console.log('❓ عدد الأسئلة المستلمة:', questions.length);

    let filteredQuestions = questions;
    
    if (previous_answers) {
      try {
        const answers = typeof previous_answers === 'string' 
          ? JSON.parse(previous_answers) 
          : previous_answers;
        
        filteredQuestions = applyDecisionTree(questions, answers);
        console.log('🎯 عدد الأسئلة بعد التصفية:', filteredQuestions.length);
      } catch (parseError) {
        console.log('⚠️ خطأ في تحليل الإجابات السابقة، استخدام جميع الأسئلة');
      }
    }

    const responseQuestions = filteredQuestions.map(q => ({
      question_id: q.question_id,
      category: q.category,
      question_text: language === 'ar' ? (q.question_text_ar || q.question_text) : q.question_text,
      question_type: q.question_type,
      options: language === 'ar' ? (q.options_ar || q.options || []) : (q.options || []),
      weight: q.weight,
      target_conditions: q.target_conditions || [],
      min_age: q.min_age,
      max_age: q.max_age,
      next_question_logic: q.next_question_logic
    }));

    res.status(200).json({
      success: true,
      questions: responseQuestions,
      total: responseQuestions.length,
      child_age: childAge,
      progress: calculateProgress(previous_answers, responseQuestions.length),
      language: language
    });

  } catch (error) {
    console.error('❌ خطأ في جلب الأسئلة:', error);
    res.status(500).json({ 
      success: false,
      message: 'فشل في جلب الأسئلة', 
      error: error.message 
    });
  }
};

exports.saveQuestionnaireResponse = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { child_id, responses, questionnaire_id = null, language = 'ar' } = req.body;

    console.log('💾 حفظ إجابات الاستبيان:', { parentId, child_id, responsesCount: Object.keys(responses || {}).length });

    if (!responses || Object.keys(responses).length === 0) {
      return res.status(400).json({
        success: false,
        message: 'لا توجد إجابات لحفظها'
      });
    }

    let questionnaire;
    
    if (questionnaire_id) {
      questionnaire = await Questionnaire.findOne({
        where: { questionnaire_id, parent_id: parentId }
      });
      
      if (!questionnaire) {
        return res.status(404).json({ 
          success: false,
          message: 'الاستبيان غير موجود' 
        });
      }
      
      const updatedResponses = { ...questionnaire.responses, ...responses };
      await questionnaire.update({ 
        responses: updatedResponses,
        status: 'In Progress'
      });
    } else {
      questionnaire = await Questionnaire.create({
        parent_id: parentId,
        child_id: child_id || null,
        title: language === 'ar' ? 'تقييم مبدئي' : 'Initial Screening Assessment',
        type: 'Initial Screening',
        responses: responses,
        status: 'In Progress'
      });
    }

    if (isQuestionnaireComplete(responses)) {
      console.log('🔍 الاستبيان مكتمل، بدء التحليل...');
      
      const analysis = await analyzeQuestionnaire(responses, child_id, language);
      
      await questionnaire.update({
        status: 'Completed',
        results: analysis.results,
        ai_analysis: analysis.ai_analysis,
        risk_level: analysis.risk_level,
        suggested_conditions: analysis.suggested_conditions,
        recommendations: analysis.recommendations,
        completed_at: new Date()
      });

      console.log('✅ اكتمل تحليل الاستبيان:', questionnaire.questionnaire_id);

      res.status(200).json({
        success: true,
        message: language === 'ar' ? 'تم إكمال الاستبيان والتحليل بنجاح' : 'Questionnaire completed and analyzed successfully',
        questionnaire_id: questionnaire.questionnaire_id,
        status: questionnaire.status,
        results: analysis.results,
        risk_level: analysis.risk_level,
        suggested_conditions: analysis.suggested_conditions,
        recommendations: analysis.recommendations
      });

    } else {
      res.status(200).json({
        success: true,
        message: language === 'ar' ? 'تم حفظ الإجابات بنجاح' : 'Responses saved successfully',
        questionnaire_id: questionnaire.questionnaire_id,
        status: questionnaire.status,
        progress: calculateProgress(responses, 20)
      });
    }

  } catch (error) {
    console.error('❌ خطأ في حفظ الاستبيان:', error);
    res.status(500).json({ 
      success: false,
      message: 'فشل في حفظ الإجابات', 
      error: error.message 
    });
  }
};

exports.getQuestionnaireHistory = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { page = 1, limit = 10, language = 'ar' } = req.query;

    const questionnaires = await Questionnaire.findAll({
      where: { parent_id: parentId },
      include: [
        {
          model: require('../model/Child'),
          attributes: ['child_id', 'full_name']
        }
      ],
      order: [['created_at', 'DESC']],
      limit: parseInt(limit),
      offset: (parseInt(page) - 1) * parseInt(limit)
    });

    const totalCount = await Questionnaire.count({ 
      where: { parent_id: parentId } 
    });

    res.status(200).json({
      success: true,
      questionnaires: questionnaires.map(q => ({
        id: q.questionnaire_id,
        title: q.title,
        type: q.type,
        status: q.status,
        child_name: q.Child ? q.Child.full_name : (language === 'ar' ? 'تقييم عام' : 'General Assessment'),
        risk_level: q.risk_level,
        created_at: q.created_at,
        completed_at: q.completed_at
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount,
        total_pages: Math.ceil(totalCount / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('❌ خطأ في جلب تاريخ الاستبيانات:', error);
    res.status(500).json({ 
      success: false,
      message: 'فشل في جلب التاريخ', 
      error: error.message 
    });
  }
};

exports.getQuestionnaire = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { id } = req.params;

    const questionnaire = await Questionnaire.findOne({
      where: { 
        questionnaire_id: id, 
        parent_id: parentId 
      },
      include: [
        {
          model: require('../model/Child'),
          attributes: ['child_id', 'full_name', 'date_of_birth']
        }
      ]
    });

    if (!questionnaire) {
      return res.status(404).json({
        success: false,
        message: 'الاستبيان غير موجود'
      });
    }

    res.status(200).json({
      success: true,
      questionnaire: {
        id: questionnaire.questionnaire_id,
        title: questionnaire.title,
        type: questionnaire.type,
        status: questionnaire.status,
        child: questionnaire.Child,
        responses: questionnaire.responses,
        results: questionnaire.results,
        risk_level: questionnaire.risk_level,
        suggested_conditions: questionnaire.suggested_conditions,
        recommendations: questionnaire.recommendations,
        created_at: questionnaire.created_at,
        completed_at: questionnaire.completed_at
      }
    });

  } catch (error) {
    console.error('❌ خطأ في جلب الاستبيان:', error);
    res.status(500).json({ 
      success: false,
      message: 'فشل في جلب الاستبيان', 
      error: error.message 
    });
  }
};

// ====================Helper methods ====================

function calculateAge(birthDate) {
  const today = new Date();
  const birth = new Date(birthDate);
  let age = today.getFullYear() - birth.getFullYear();
  const monthDiff = today.getMonth() - birth.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
    age--;
  }
  return age;
}

function applyDecisionTree(questions, previousAnswers) {
  return questions.filter(question => {
    if (!question.next_question_logic || !question.next_question_logic.depends_on_question) {
      return true;
    }
    
    const logic = question.next_question_logic;
    const requiredAnswer = previousAnswers[logic.depends_on_question];
    
    if (!requiredAnswer) return true;
    
    return logic.required_value === requiredAnswer;
  });
}

function calculateProgress(answers, totalQuestions) {
  if (!answers) return 0;
  
  const answeredCount = typeof answers === 'object' 
    ? Object.keys(answers).length 
    : 0;
    
  return Math.round((answeredCount / totalQuestions) * 100);
}

function isQuestionnaireComplete(responses) {
  if (!responses || typeof responses !== 'object') return false;
  
  const answeredCount = Object.keys(responses).length;
  return answeredCount >= 15; 
}

async function analyzeQuestionnaire(responses, child_id, language = 'ar') {
  try {
    console.log('🧮 بدء تحليل الاستبيان...');
    
    const basicAnalysis = performBasicAnalysis(responses);
    
    const aiAnalysis = await performAIAnalysis(responses, child_id, language);
    
    const recommendations = generateRecommendations(basicAnalysis, aiAnalysis, language);
    
    console.log('📊 نتائج التحليل:', {
      risk_level: calculateRiskLevel(basicAnalysis, aiAnalysis),
      suggested_conditions: aiAnalysis.suggested_conditions,
      recommendations_count: Object.values(recommendations).flat().length
    });
    
    return {
      results: basicAnalysis,
      ai_analysis: aiAnalysis.analysis,
      risk_level: calculateRiskLevel(basicAnalysis, aiAnalysis),
      suggested_conditions: aiAnalysis.suggested_conditions,
      recommendations: recommendations
    };
    
  } catch (error) {
    console.error('❌ خطأ في التحليل:', error);
    return getFallbackAnalysis(responses, language);
  }
}

function performBasicAnalysis(responses) {
  const scores = {
    'Attention & Focus': 0,
    'Social Interaction': 0,
    'Communication': 0,
    'Behavior Patterns': 0,
    'Motor Skills': 0,
    'Academic Performance': 0,
    'Daily Living Skills': 0
  };

  const answerWeights = {
    'أبداً': 0, 'Never': 0, 'لا': 0,
    'نادراً': 1, 'Rarely': 1, 'قليلاً': 1,
    'أحياناً': 2, 'Sometimes': 2, 'نعم، بشكل ملحوظ': 2,
    'غالباً': 3, 'Often': 3, 'نعم، بشكل مكثف': 3,
    'دائماً': 4, 'Always': 4
  };

  Object.values(responses).forEach(response => {
    if (response.category && response.answer) {
      const weight = answerWeights[response.answer] || 2;
      scores[response.category] += weight;
    }
  });

  const totalScore = Object.values(scores).reduce((a, b) => a + b, 0);
  const areasOfConcern = Object.entries(scores)
    .filter(([_, score]) => score > 8)
    .map(([category]) => category);

  return {
    category_scores: scores,
    total_score: totalScore,
    areas_of_concern: areasOfConcern,
    assessment_date: new Date().toISOString()
  };
}

async function performAIAnalysis(responses, child_id, language) {
  try {
    return await performExternalAIAnalysis(responses, language);
  } catch (error) {
    console.log('🔄 العودة للتحليل المحلي');
    return performLocalAIAnalysis(responses, language);
  }
}

function performLocalAIAnalysis(responses, language) {
  const analysis = {
    analysis: language === 'ar' 
      ? "تم التحليل باستخدام الخوارزميات المحلية. هذه النتائج أولية وتستدعي استشارة متخصص." 
      : "Analysis performed using local algorithms. These are preliminary results and require specialist consultation.",
    suggested_conditions: [],
    confidence: 0.7
  };

  const attentionScore = calculateCategoryScore(responses, 'Attention & Focus');
  const socialScore = calculateCategoryScore(responses, 'Social Interaction');
  const communicationScore = calculateCategoryScore(responses, 'Communication');

  if (attentionScore > 12) {
    analysis.suggested_conditions.push(language === 'ar' ? 'اضطراب فرط الحركة ونقص الانتباه' : 'ADHD');
  }

  if (socialScore > 10 || communicationScore > 10) {
    analysis.suggested_conditions.push(language === 'ar' ? 'طيف التوحد' : 'ASD');
  }

  if (analysis.suggested_conditions.length === 0) {
    analysis.suggested_conditions.push(
      language === 'ar' 
        ? 'تطور طبيعي - يوصى بمتابعة النمو' 
        : 'Normal development - growth monitoring recommended'
    );
  }

  return analysis;
}

async function performExternalAIAnalysis(responses, language) {
  try {
    const symptomsText = Object.values(responses)
      .map(r => `${r.category}: ${r.answer}`)
      .join('\n');

    const aiAnalysis = await AIAnalysisService.analyzeSymptoms(
      symptomsText,
      '',
      '',
      language
    );

    return {
      analysis: aiAnalysis.analysis || "AI analysis completed",
      suggested_conditions: aiAnalysis.suggested_conditions || [],
      confidence: aiAnalysis.analysis_confidence || 0.7
    };
  } catch (error) {
    throw new Error('External AI analysis failed');
  }
}

function generateRecommendations(basicAnalysis, aiAnalysis, language) {
  const recommendations = {
    immediate_actions: [],
    resources: [],
    specialists: [],
    institutions: [],
    follow_up_actions: []
  };

  const isArabic = language === 'ar';

  if (basicAnalysis.category_scores['Attention & Focus'] > 12) {
    recommendations.immediate_actions.push(
      isArabic ? 'استشارة طبيب أعصاب أطفال أو أخصائي ADHD' : 'Consult a pediatric neurologist or ADHD specialist',
      isArabic ? 'تنفيظم روتين يومي منظم وجداول بصرية' : 'Establish a structured daily routine and visual schedules',
      isArabic ? 'تقليل الملهيات في بيئة التعلم' : 'Reduce distractions in the learning environment'
    );
    recommendations.resources.push(
      isArabic ? 'دليل استراتيجيات تربية أطفال ADHD' : 'ADHD parenting strategies guide',
      isArabic ? 'تمارين بناء التركيز والانتباه' : 'Focus and attention building exercises'
    );
    recommendations.specialists.push(
      isArabic ? 'طبيب أعصاب أطفال' : 'Pediatric neurologist',
      isArabic ? 'أخصائي سلوكي' : 'Behavioral specialist'
    );
  }

  if (basicAnalysis.category_scores['Social Interaction'] > 10) {
    recommendations.immediate_actions.push(
      isArabic ? 'حجز موعد مع أخصائي توحد' : 'Book an appointment with an autism specialist',
      isArabic ? 'بدء تدريب المهارات الاجتماعية' : 'Start social skills training',
      isArabic ? 'استخدام وسائل اتصال بصرية' : 'Use visual communication tools'
    );
    recommendations.specialists.push(
      isArabic ? 'أخصائي علاج سلوكي' : 'Behavioral therapist',
      isArabic ? 'أخصائي نطق ولغة' : 'Speech and language specialist'
    );
  }

  recommendations.immediate_actions.push(
    isArabic ? 'متابعة النمو مع طبيب الأطفال' : 'Follow up growth with pediatrician',
    isArabic ? 'توثيق الملاحظات السلوكية اليومية' : 'Document daily behavioral observations'
  );

  recommendations.institutions.push(
    isArabic ? 'جمعية ياسمين الخيرية - مركز التوحد' : 'Yasmin Charity Association - Autism Center',
    isArabic ? 'مركز سند - أخصائيون ADHD' : 'Sanad Center - ADHD Specialists'
  );

  recommendations.follow_up_actions.push(
    isArabic ? 'إعادة التقييم بعد 3 أشهر' : 'Re-evaluation after 3 months',
    isArabic ? 'مشاركة النتائج مع المدرسة إذا كان الطفل في سن الدراسة' : 'Share results with school if child is school-aged'
  );

  return recommendations;
}

function calculateCategoryScore(responses, category) {
  let score = 0;
  Object.values(responses).forEach(response => {
    if (response.category === category) {
      const answerWeights = {
        'أبداً': 0, 'Never': 0, 'لا': 0,
        'نادراً': 1, 'Rarely': 1, 'قليلاً': 1,
        'أحياناً': 2, 'Sometimes': 2, 'نعم، بشكل ملحوظ': 2,
        'غالباً': 3, 'Often': 3, 'نعم، بشكل مكثف': 3,
        'دائماً': 4, 'Always': 4
      };
      score += answerWeights[response.answer] || 0;
    }
  });
  return score;
}

function calculateRiskLevel(basicAnalysis, aiAnalysis) {
  const totalScore = basicAnalysis.total_score;
  
  if (totalScore > 40) return 'High';
  if (totalScore > 25) return 'Medium';
  return 'Low';
}

function getFallbackAnalysis(responses, language) {
  return {
    results: performBasicAnalysis(responses),
    ai_analysis: language === 'ar' 
      ? "تعذر التحليل المتقدم، يرجى استشارة متخصص" 
      : "Advanced analysis unavailable, please consult a specialist",
    risk_level: 'Medium',
    suggested_conditions: [
      language === 'ar' 
        ? 'يوصى باستشارة متخصص للتقييم الدقيق' 
        : 'Specialist consultation recommended for accurate assessment'
    ],
    recommendations: {
      immediate_actions: [
        language === 'ar' 
          ? 'حجز موعد مع أخصائي نمو أطفال' 
          : 'Book an appointment with a child development specialist'
      ],
      resources: [],
      specialists: [
        language === 'ar' ? 'أخصائي نمو أطفال' : 'Child development specialist'
      ],
      institutions: [],
      follow_up_actions: [
        language === 'ar' 
          ? 'إعادة التقييم بعد استشارة المتخصص' 
          : 'Re-evaluation after specialist consultation'
      ]
    }
  };
}

module.exports = exports;