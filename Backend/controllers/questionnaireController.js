const Questionnaire = require('../model/Questionnaire');
const Question = require('../model/Question');
const Child = require('../model/Child');
const { Op } = require('sequelize');

// جلب الأسئلة حسب شجرة القرارات
exports.getQuestions = async (req, res) => {
  try {
    const { child_id, previous_answers } = req.query;
    const parentId = req.user.user_id;

    console.log('📋 Fetching questions for parent:', parentId, 'child:', child_id);

    let where = { is_active: true };
    
    // فلترة حسب عمر الطفل إذا كان محدد
    if (child_id) {
      const child = await Child.findOne({
        where: { 
          child_id: child_id, 
          parent_id: parentId,
          deleted_at: null 
        }
      });
      
      if (child && child.date_of_birth) {
        const age = calculateAge(child.date_of_birth);
        console.log('👶 Child age:', age);
        
        where = {
          ...where,
          [Op.and]: [
            { min_age: { [Op.lte]: age } },
            { max_age: { [Op.gte]: age } }
          ]
        };
      }
    }

    // تطبيق شجرة القرارات بناءً على الإجابات السابقة
    let questions = await Question.findAll({ 
      where,
      order: [['question_id', 'ASC']]
    });

    console.log('❓ Raw questions found:', questions.length);

    let filteredQuestions = questions;
    
    if (previous_answers) {
      try {
        const answers = typeof previous_answers === 'string' 
          ? JSON.parse(previous_answers) 
          : previous_answers;
        
        filteredQuestions = applyDecisionTree(questions, answers);
        console.log('🎯 Filtered questions after decision tree:', filteredQuestions.length);
      } catch (parseError) {
        console.log('⚠️ Error parsing previous_answers, using all questions');
      }
    }

    // تحويل البيانات للاستجابة
    const responseQuestions = filteredQuestions.map(q => ({
      question_id: q.question_id,
      category: q.category,
      question_text: q.question_text,
      question_type: q.question_type,
      options: q.options || [],
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
      progress: calculateProgress(previous_answers, responseQuestions.length)
    });

  } catch (error) {
    console.error('❌ Error fetching questions:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};

// حفظ إجابات الاستبيان
exports.saveQuestionnaireResponse = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { child_id, responses, questionnaire_id = null } = req.body;

    console.log('💾 Saving questionnaire responses for parent:', parentId);

    let questionnaire;
    
    if (questionnaire_id) {
      // تحديث استبيان موجود
      questionnaire = await Questionnaire.findOne({
        where: { questionnaire_id, parent_id: parentId }
      });
      
      if (!questionnaire) {
        return res.status(404).json({ 
          success: false,
          message: 'Questionnaire not found' 
        });
      }
      
      const updatedResponses = { ...questionnaire.responses, ...responses };
      await questionnaire.update({ responses: updatedResponses });
    } else {
      // إنشاء استبيان جديد
      questionnaire = await Questionnaire.create({
        parent_id: parentId,
        child_id: child_id || null,
        title: 'Initial Screening Assessment',
        type: 'Initial Screening',
        responses: responses,
        status: 'In Progress'
      });
    }

    // إذا كان الاستبيان مكتمل، نقوم بالتحليل
    if (isQuestionnaireComplete(responses)) {
      console.log('🔍 Questionnaire completed, starting analysis...');
      
      const analysis = await analyzeQuestionnaire(responses, child_id);
      
      await questionnaire.update({
        status: 'Completed',
        results: analysis.results,
        ai_analysis: analysis.ai_analysis,
        risk_level: analysis.risk_level,
        suggested_conditions: analysis.suggested_conditions,
        recommendations: analysis.recommendations,
        completed_at: new Date()
      });

      console.log('✅ Analysis completed for questionnaire:', questionnaire.questionnaire_id);

      res.status(200).json({
        success: true,
        message: 'Questionnaire completed and analyzed successfully',
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
        message: 'Responses saved successfully',
        questionnaire_id: questionnaire.questionnaire_id,
        status: questionnaire.status,
        progress: calculateProgress(responses, 20) // افتراضي 20 سؤال
      });
    }

  } catch (error) {
    console.error('❌ Error saving questionnaire:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to save responses', 
      error: error.message 
    });
  }
};

// تحليل الاستبيان
async function analyzeQuestionnaire(responses, child_id) {
  try {
    console.log('🧮 Starting questionnaire analysis...');
    
    // 1. التحليل الأساسي
    const basicAnalysis = performBasicAnalysis(responses);
    
    // 2. استخدام AI للتحليل المتقدم (يمكنك تفعيله لاحقاً)
    const aiAnalysis = await performAIAnalysis(responses, child_id);
    
    // 3. توليد التوصيات
    const recommendations = generateRecommendations(basicAnalysis, aiAnalysis);
    
    console.log('📊 Analysis results:', {
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
    console.error('Analysis error:', error);
    return getFallbackAnalysis(responses);
  }
}

// التحليل الأساسي
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
    'أبداً': 0, 'Never': 0,
    'نادراً': 1, 'Rarely': 1,
    'أحياناً': 2, 'Sometimes': 2,
    'غالباً': 3, 'Often': 3,
    'دائماً': 4, 'Always': 4
  };

  Object.values(responses).forEach(response => {
    if (response.category && response.answer) {
      const weight = answerWeights[response.answer] || 2; // قيمة افتراضية
      scores[response.category] += weight;
    }
  });

  const totalScore = Object.values(scores).reduce((a, b) => a + b, 0);
  const areasOfConcern = Object.entries(scores)
    .filter(([_, score]) => score > 8) // عتبة القلق
    .map(([category]) => category);

  return {
    category_scores: scores,
    total_score: totalScore,
    areas_of_concern: areasOfConcern,
    assessment_date: new Date().toISOString()
  };
}

// استخدام AI للتحليل (بدون تكاليف)
async function performAIAnalysis(responses, child_id) {
  try {
    // تحليل محلي بدلاً من API خارجي
    return performLocalAIAnalysis(responses);
  } catch (error) {
    console.log('🔄 Falling back to local analysis');
    return performLocalAIAnalysis(responses);
  }
}

// تحليل محلي
function performLocalAIAnalysis(responses) {
  const analysis = {
    analysis: "تم التحليل باستخدام الخوارزميات المحلية. هذه النتائج أولية وتستدعي استشارة متخصص.",
    suggested_conditions: [],
    confidence: 0.7
  };

  // تحليل بسيط بناءً على الإجابات
  const attentionScore = calculateCategoryScore(responses, 'Attention & Focus');
  const socialScore = calculateCategoryScore(responses, 'Social Interaction');
  const communicationScore = calculateCategoryScore(responses, 'Communication');

  if (attentionScore > 12) {
    analysis.suggested_conditions.push('ADHD');
  }

  if (socialScore > 10 || communicationScore > 10) {
    analysis.suggested_conditions.push('ASD');
  }

  if (analysis.suggested_conditions.length === 0) {
    analysis.suggested_conditions.push('تطور طبيعي - يوصى بمتابعة النمو');
  }

  return analysis;
}

// توليد التوصيات
function generateRecommendations(basicAnalysis, aiAnalysis) {
  const recommendations = {
    immediate_actions: [],
    resources: [],
    specialists: [],
    institutions: [],
    follow_up_actions: []
  };

  // تحليل ADHD
  if (basicAnalysis.category_scores['Attention & Focus'] > 12) {
    recommendations.immediate_actions.push(
      'استشارة طبيب أعصاب أطفال أو أخصائي ADHD',
      'تنفيظم روتين يومي منظم وجداول بصرية',
      'تقليل الملهيات في بيئة التعلم'
    );
    recommendations.resources.push(
      'دليل استراتيجيات تربية أطفال ADHD',
      'تمارين بناء التركيز والانتباه'
    );
    recommendations.specialists.push('طبيب أعصاب أطفال', 'أخصائي سلوكي');
  }

  // تحليل التوحد
  if (basicAnalysis.category_scores['Social Interaction'] > 10) {
    recommendations.immediate_actions.push(
      'حجز موعد مع أخصائي توحد',
      'بدء تدريب المهارات الاجتماعية',
      'استخدام وسائل اتصال بصرية'
    );
    recommendations.specialists.push('أخصائي علاج سلوكي', 'أخصائي نطق ولغة');
  }

  // توصيات عامة
  recommendations.immediate_actions.push(
    'متابعة النمو مع طبيب الأطفال',
    'توثيق الملاحظات السلوكية اليومية'
  );

  recommendations.institutions.push(
    'جمعية ياسمين الخيرية - مركز التوحد',
    'مركز سند - أخصائيون ADHD'
  );

  recommendations.follow_up_actions.push(
    'إعادة التقييم بعد 3 أشهر',
    'مشاركة النتائج مع المدرسة إذا كان الطفل في سن الدراسة'
  );

  return recommendations;
}

// دوال مساعدة
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
  return answeredCount >= 15; // اعتبار الاستبيان مكتملاً عند 15 إجابة
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

function getFallbackAnalysis(responses) {
  return {
    results: performBasicAnalysis(responses),
    ai_analysis: "تعذر التحليل المتقدم، يرجى استشارة متخصص",
    risk_level: 'Medium',
    suggested_conditions: ['يوصى باستشارة متخصص للتقييم الدقيق'],
    recommendations: {
      immediate_actions: ['حجز موعد مع أخصائي نمو أطفال'],
      resources: [],
      specialists: ['أخصائي نمو أطفال'],
      institutions: [],
      follow_up_actions: ['إعادة التقييم بعد استشارة المتخصص']
    }
  };
}

// جلب نتائج الاستبيانات السابقة
exports.getQuestionnaireHistory = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { page = 1, limit = 10 } = req.query;

    const questionnaires = await Questionnaire.findAll({
      where: { parent_id: parentId },
      include: [
        {
          model: require('../models/Child'),
          attributes: ['child_id', 'full_name']
        }
      ],
      order: [['created_at', 'DESC']],
      limit: parseInt(limit),
      offset: (parseInt(page) - 1) * parseInt(limit)
    });

    res.status(200).json({
      success: true,
      questionnaires: questionnaires.map(q => ({
        id: q.questionnaire_id,
        title: q.title,
        type: q.type,
        status: q.status,
        child_name: q.Child ? q.Child.full_name : 'تقييم عام',
        risk_level: q.risk_level,
        created_at: q.created_at,
        completed_at: q.completed_at
      })),
      total: await Questionnaire.count({ where: { parent_id: parentId } })
    });

  } catch (error) {
    console.error('Error fetching questionnaire history:', error);
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
};