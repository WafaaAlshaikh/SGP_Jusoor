// controllers/screeningController.js
const { Questionnaire, Question, QuestionnaireResponse } = require('../model/index');
const { Op } = require('sequelize');
 
// 🎯 بداية الاستبيان - الحصول على الأسئلة حسب العمر
exports.startScreening = async (req, res) => {
  try {
    const { child_age, child_gender } = req.body;
    const parent_id = req.user.user_id;

    console.log('📝 Starting screening for:', { parent_id, child_age, child_gender });

    if (!child_age) {
      return res.status(400).json({
        success: false,
        error: 'Child age is required'
      });
    }

    // تحديد المسار الأولي بناءً على العمر
    let primaryType = child_age < 6 ? 'ASD' : 'ADHD';
    
    console.log('🎯 Primary type determined:', primaryType);
    
    // الحصول على أسئلة البوابة
    const gatewayQuestions = await Question.findAll({
      where: { is_gateway: true },
      include: [{ model: Questionnaire, as: 'questionnaire' }],
      order: [['order', 'ASC']]
    });

    console.log('📋 Gateway questions found:', gatewayQuestions.length);

    // تحويل البيانات لـ JSON بشكل آمن
    const questionsData = gatewayQuestions.map(q => ({
      id: q.id,
      question_text: q.question_text,
      question_type: q.question_type,
      options: q.options,
      category: q.category,
      is_gateway: q.is_gateway,
      order: q.order,
      risk_score: q.risk_score || 0
    }));

    res.json({
      success: true,
      screening_session: { 
        parent_id, 
        child_age, 
        child_gender, 
        primaryType 
      },
      gateway_questions: questionsData,
      next_step: 'gateway'
    });

  } catch (error) {
    console.error('❌ Start screening error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};

// 🎯 معالجة إجابات البوابة وتحديد المسار
// 🎯 الإصلاح في processGateway function
exports.processGateway = async (req, res) => {
  try {
    const { child_age, child_gender, responses } = req.body;
    const parent_id = req.user.user_id;
    
    let asdGatewayScore = 0;
    let adhdGatewayScore = 0;

    console.log('🔍 Raw responses from Flutter:', responses);

    // 🔥 الإصلاح: حساب النقاط بناءً على أنواع الـ categories المختلفة
    responses.forEach(response => {
      console.log(`🔍 Processing response: Q${response.question_id} - Answer: ${response.answer} - Category: ${response.category}`);
      
      // تحقق من كل أنواع الـ categories المحتملة لـ ASD
      if (response.answer && (
          response.category === 'ASD' ||
          response.category === 'social' || 
          response.category === 'communication' ||
          response.category === 'play' ||
          response.category.includes('ASD')
      )) {
        asdGatewayScore++;
        console.log(`✅ Added to ASD score. Total: ${asdGatewayScore}`);
      }
      
      // تحقق من كل أنواع الـ categories المحتملة لـ ADHD
      if (response.answer && (
          response.category === 'ADHD' ||
          response.category === 'hyperactivity' ||
          response.category === 'attention' ||
          response.category === 'impulsivity' ||
          response.category.includes('ADHD') ||
          response.category.includes('attention')
      )) {
        adhdGatewayScore++;
        console.log(`✅ Added to ADHD score. Total: ${adhdGatewayScore}`);
      }
    });

    console.log('🎯 Final Gateway Scores:', { asd: asdGatewayScore, adhd: adhdGatewayScore });

    // 🔍 DEBUG - Age Analysis
    console.log('🔍 DEBUG - Age Analysis:', {
      child_age: child_age,
      is_less_than_4: child_age < 48,
      is_4_to_6: child_age >= 48 && child_age <= 72,
      is_more_than_6: child_age > 72,
      asdGatewayScore: asdGatewayScore,
      adhdGatewayScore: adhdGatewayScore
    });

    // تحديد المسار الأساسي
    let primaryPath, secondaryPath;
    
    if (child_age < 48) {
      primaryPath = 'ASD';
      secondaryPath = asdGatewayScore >= 2 ? null : 'ADHD';
    } else if (child_age >= 48 && child_age <= 72) {
      if (asdGatewayScore >= 2) {
        primaryPath = 'ASD';
        secondaryPath = adhdGatewayScore >= 2 ? 'ADHD' : null;
      } else {
        primaryPath = 'ADHD';
        secondaryPath = asdGatewayScore >= 1 ? 'ASD' : null;
      }
    } else {
      primaryPath = 'ADHD';
      secondaryPath = asdGatewayScore >= 2 ? 'ASD' : null;
    }

    console.log('🎯 FINAL DECISION:', {
      primaryPath: primaryPath,
      secondaryPath: secondaryPath,
      expected: asdGatewayScore >= 2 ? 'ASD' : 'ADHD'
    });

    // ... باقي الكود
  } catch (error) {
    console.error('❌ Process gateway error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// 🎯 حفظ النتائج النهائية
exports.saveResults = async (req, res) => {
  try {
    const { 
      child_age, 
      child_gender, 
      screening_plan, 
      primary_responses, 
      secondary_responses, 
      final_scores 
    } = req.body;

    const parent_id = req.user.user_id;

    // تحليل النتائج
    const results = analyzeResults(final_scores, child_age);

    // حفظ النتائج النهائية
    const finalResponse = await QuestionnaireResponse.create({
      parent_id: parent_id,
      child_age: child_age,
      child_gender: child_gender,
      questionnaire_type: screening_plan.secondary_path ? 'COMBINED' : screening_plan.primary_path,
      responses: {
        primary: primary_responses,
        secondary: secondary_responses || []
      },
      scores: final_scores,
      result: results,
      screening_path: {
        primary: screening_plan.primary_path,
        secondary: screening_plan.secondary_path,
        age: child_age,
        gender: child_gender
      },
      is_anonymous: true
    });

    res.json({
      success: true,
      results: results,
      screening_id: finalResponse.id,
      message: 'Screening completed successfully'
    });
  } catch (error) {
    console.error('❌ Save results error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// 🎯 جلب تاريخ الفحوصات السابقة للأهل
exports.getMyScreenings = async (req, res) => {
  try {
    const parent_id = req.user.user_id;

    const screenings = await QuestionnaireResponse.findAll({
      where: { parent_id },
      order: [['createdAt', 'DESC']],
      attributes: ['id', 'child_age', 'child_gender', 'questionnaire_type', 'scores', 'result', 'createdAt']
    });

    res.json({
      success: true,
      screenings: screenings
    });
  } catch (error) {
    console.error('❌ Get screenings error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// 🎯 دالة تحليل النتائج
function analyzeResults(scores, age) {
  const { asd, adhd } = scores;
  
  let asdRisk = 'low';
  let adhdRisk = 'low';
  let recommendations = [];

  // تحليل ASD
  if (age < 6) {
    if (asd >= 8) asdRisk = 'high';
    else if (asd >= 3) asdRisk = 'medium';
  } else {
    if (asd >= 6) asdRisk = 'high';
    else if (asd >= 3) asdRisk = 'medium';
  }

  // تحليل ADHD
  if (adhd >= 6) adhdRisk = 'high';
  else if (adhd >= 4) adhdRisk = 'medium';

  // توليد التوصيات
  if (asdRisk === 'high' || adhdRisk === 'high') {
    recommendations.push('We recommend consulting a developmental specialist for comprehensive evaluation');
    recommendations.push('Consider early intervention services');
  }
  if (asdRisk === 'medium' || adhdRisk === 'medium') {
    recommendations.push('We recommend follow-up with pediatrician and re-evaluation in 3 months');
    recommendations.push('Monitor development and school performance');
  }
  if (asdRisk === 'low' && adhdRisk === 'low') {
    recommendations.push('No strong indicators currently detected, routine follow-up recommended');
  }

  return {
    risk_levels: { 
      asd: asdRisk, 
      adhd: adhdRisk 
    },
    scores: { asd, adhd },
    recommendations,
    next_steps: generateNextSteps(asdRisk, adhdRisk)
  };
}

function generateNextSteps(asdRisk, adhdRisk) {
  const steps = [];
  
  if (asdRisk === 'high') {
    steps.push('Urgent referral to autism specialist');
    steps.push('Comprehensive developmental evaluation');
  }
  if (adhdRisk === 'high') {
    steps.push('Neuropsychological assessment');
    steps.push('School performance evaluation');
  }
  if (asdRisk === 'medium') {
    steps.push('Monitor language and social development');
    steps.push('Speech and language evaluation if concerns persist');
  }
  if (adhdRisk === 'medium') {
    steps.push('Monitor behavior at school and home');
    steps.push('Classroom observation if available');
  }
  
  if (steps.length === 0) {
    steps.push('Continue routine developmental monitoring');
  }
  
  return steps;
}