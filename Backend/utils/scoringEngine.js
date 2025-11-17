async function calculateQuestionnaireScores(questionnaire) {
  const answers = questionnaire.Answers || [];
  
  // Initialize scores
  const scores = {
    ASD: { general: 0, conditional: 0, total: 0, percentage: 0 },
    ADHD: { general: 0, conditional: 0, total: 0, percentage: 0 },
    Speech: { general: 0, conditional: 0, total: 0, percentage: 0 },
    Down: { general: 0, conditional: 0, total: 0, percentage: 0 }
  };

  // Separate answers by section
  const generalAnswers = answers.filter(a => a.section === 'general_screening');
  const asdAnswers = answers.filter(a => a.section === 'ASD_deep');
  const adhdAnswers = answers.filter(a => a.section === 'ADHD_deep');
  const speechAnswers = answers.filter(a => a.section === 'Speech_deep');
  const downAnswers = answers.filter(a => a.section === 'Down_deep');

  // ==================== Calculate General Scores ====================
  scores.ASD.general = calculateSectionScore(generalAnswers, 'ASD');
  scores.ADHD.general = calculateSectionScore(generalAnswers, 'ADHD');
  scores.Speech.general = calculateSectionScore(generalAnswers, 'Speech');
  scores.Down.general = calculateSectionScore(generalAnswers, 'Down');

  // ==================== Calculate Conditional Scores ====================
  scores.ASD.conditional = calculateSectionScore(asdAnswers, 'ASD');
  scores.ADHD.conditional = calculateSectionScore(adhdAnswers, 'ADHD');
  scores.Speech.conditional = calculateSectionScore(speechAnswers, 'Speech');
  scores.Down.conditional = calculateSectionScore(downAnswers, 'Down');

  // ==================== Calculate Total & Percentage ====================
  scores.ASD.total = Math.round((scores.ASD.general * 0.3) + (scores.ASD.conditional * 0.7));
  scores.ASD.percentage = Math.round((scores.ASD.total / 58) * 100);

  scores.ADHD.total = Math.round((scores.ADHD.general * 0.3) + (scores.ADHD.conditional * 0.7));
  scores.ADHD.percentage = Math.round((scores.ADHD.total / 57) * 100);

  scores.Speech.total = Math.round((scores.Speech.general * 0.3) + (scores.Speech.conditional * 0.7));
  scores.Speech.percentage = Math.round((scores.Speech.total / 57) * 100);

  scores.Down.total = Math.round((scores.Down.general * 0.2) + (scores.Down.conditional * 0.8));
  scores.Down.percentage = Math.round((scores.Down.total / 45) * 100);

  // ==================== Determine Primary Concern ====================
  const primary_concern = determinePrimaryConcern(scores);
  const primaryScoreObj = scores[primary_concern] || { percentage: 0 };
  const risk_level = determineRiskLevel(primaryScoreObj);
  const urgency_level = determineUrgencyLevel(scores, primary_concern);

  // ==================== Generate Findings ====================
  const findings = generateFindings(answers, scores);

  // ==================== Generate Recommendations ====================
  const recommendations = generateRecommendations(scores, primary_concern, risk_level);

  // ==================== Detailed Results ====================
  return {
    scores,
    primary_concern,
    secondary_concern: findSecondaryConcern(scores, primary_concern),
    risk_level,
    urgency_level,
    confidence_level: determineConfidence(answers.length, scores),
    
    // Detailed scores
    asd_score: buildASDScore(scores.ASD, asdAnswers),
    adhd_score: buildADHDScore(scores.ADHD, adhdAnswers),
    speech_score: buildSpeechScore(scores.Speech, speechAnswers),
    down_score: buildDownScore(scores.Down, downAnswers),
    
    // Findings
    red_flags: findings.red_flags,
    positive_indicators: findings.positive_indicators,
    
    // Recommendations
    immediate_actions: recommendations.immediate,
    follow_up_actions: recommendations.follow_up,
    home_strategies: recommendations.home,
    specialist_referrals: recommendations.specialists
  };
}

// ==========================================
// 📊 Calculate Section Score
// ==========================================
function calculateSectionScore(answers, condition) {
  let totalScore = 0;
  
  answers.forEach(answer => {
    const score = answer.score || 0;
    const weight = answer.weight || 1.0;
    totalScore += (score * weight);
  });
  
  return Math.round(totalScore);
}

// ==========================================
// 🎯 Determine Primary Concern
// ==========================================
function determinePrimaryConcern(scores) {
  const conditions = ['ASD', 'ADHD', 'Speech', 'Down'];
  let maxPercentage = 0;
  let primaryConcern = 'None';
  
  conditions.forEach(condition => {
    if (scores[condition].percentage > maxPercentage && scores[condition].percentage >= 25) {
      maxPercentage = scores[condition].percentage;
      primaryConcern = condition;
    }
  });
  
  return primaryConcern;
}

// ==========================================
// 🔍 Find Secondary Concern
// ==========================================
function findSecondaryConcern(scores, primaryConcern) {
  const conditions = ['ASD', 'ADHD', 'Speech', 'Down'].filter(c => c !== primaryConcern);
  let maxPercentage = 0;
  let secondaryConcern = null;
  
  conditions.forEach(condition => {
    if (scores[condition].percentage > maxPercentage && scores[condition].percentage >= 25) {
      maxPercentage = scores[condition].percentage;
      secondaryConcern = condition;
    }
  });
  
  return secondaryConcern;
}

// ==========================================
// ⚠️ Determine Risk Level
// ==========================================
function determineRiskLevel(score) {
  if (score.percentage >= 76) return 'very_high';
  if (score.percentage >= 51) return 'high';
  if (score.percentage >= 25) return 'medium';
  if (score.percentage >= 10) return 'low';
  return 'very_low';
}

// ==========================================
// 🚨 Determine Urgency Level
// ==========================================
function determineUrgencyLevel(scores, primaryConcern) {
  const percentage = scores[primaryConcern]?.percentage || 0;
  
  if (percentage >= 75) return 'immediate';
  if (percentage >= 50) return 'soon';
  if (percentage >= 25) return 'monitor';
  return 'low_concern';
}

// ==========================================
// 🎖️ Determine Confidence Level
// ==========================================
function determineConfidence(answersCount, scores) {
  const primaryScore = Math.max(
    scores.ASD.percentage,
    scores.ADHD.percentage,
    scores.Speech.percentage,
    scores.Down.percentage
  );
  
  if (answersCount >= 20 && primaryScore >= 50) return 'high';
  if (answersCount >= 15 && primaryScore >= 30) return 'medium-high';
  if (answersCount >= 10) return 'medium';
  return 'low';
}

// ==========================================
// 🧩 Build ASD Detailed Score
// ==========================================
function buildASDScore(score, answers) {
  const keyFindings = [];
  const positiveSigns = [];
  
  answers.forEach(answer => {
    if (answer.score >= 3) {
      keyFindings.push(getQuestionInterpretation(answer.question_id, 'ASD'));
    } else if (answer.score === 0) {
      positiveSigns.push(getQuestionInterpretation(answer.question_id, 'ASD'));
    }
  });
  
  return {
    ...score,
    risk_level: determineRiskLevel(score),
    key_findings: keyFindings.slice(0, 5),
    positive_signs: positiveSigns.slice(0, 3)
  };
}

// ==========================================
// 🧩 Build ADHD Detailed Score
// ==========================================
function buildADHDScore(score, answers) {
  let inattention_count = 0;
  let hyperactivity_count = 0;
  
  answers.forEach(answer => {
    if (answer.category === 'inattention' && answer.score >= 2) {
      inattention_count++;
    }
    if ((answer.category === 'hyperactivity' || answer.category === 'impulsivity') && answer.score >= 2) {
      hyperactivity_count++;
    }
  });
  
  let type = null;
  if (inattention_count >= 6 && hyperactivity_count >= 6) {
    type = 'combined';
  } else if (inattention_count >= 6) {
    type = 'predominantly_inattentive';
  } else if (hyperactivity_count >= 6) {
    type = 'predominantly_hyperactive';
  }
  
  return {
    ...score,
    risk_level: determineRiskLevel(score),
    inattention_count,
    hyperactivity_count,
    type
  };
}

// ==========================================
// 🧩 Build Speech Detailed Score
// ==========================================
function buildSpeechScore(score, answers) {
  const breakdown = {
    receptive: 0,
    expressive: 0,
    articulation: 0,
    pragmatic: 0
  };
  
  const categoryCount = { receptive: 0, expressive: 0, articulation: 0, pragmatic: 0 };
  
  answers.forEach(answer => {
    const cat = answer.category;
    if (breakdown.hasOwnProperty(cat)) {
      breakdown[cat] += answer.score;
      categoryCount[cat]++;
    }
  });
  
  // Calculate percentages
  Object.keys(breakdown).forEach(key => {
    if (categoryCount[key] > 0) {
      breakdown[key] = Math.round((breakdown[key] / (categoryCount[key] * 4)) * 100);
    }
  });
  
  return {
    ...score,
    risk_level: determineRiskLevel(score),
    breakdown
  };
}

// ==========================================
// 🧩 Build Down Detailed Score
// ==========================================
function buildDownScore(score, answers) {
  let physical_signs_count = 0;
  let medical_diagnosis = null;
  
  answers.forEach(answer => {
    if (answer.question_id === 'DOWN1' && answer.answer_values) {
      physical_signs_count = answer.answer_values.length;
    }
    if (answer.question_id === 'DOWN2') {
      if (answer.answer_value === 'karyotype_positive') {
        medical_diagnosis = 'confirmed';
      } else if (answer.answer_value === 'karyotype_negative') {
        medical_diagnosis = 'excluded';
      }
    }
  });
  
  return {
    ...score,
    risk_level: determineRiskLevel(score),
    physical_signs_count,
    medical_diagnosis
  };
}

// ==========================================
// 🔍 Generate Findings
// ==========================================
function generateFindings(answers, scores) {
  const red_flags = [];
  const positive_indicators = [];
  
  // Check for red flags based on high-score answers
  answers.forEach(answer => {
    if (answer.score >= 3) {
      const interpretation = getQuestionInterpretation(answer.question_id, answer.section);
      if (interpretation) red_flags.push(interpretation);
    }
  });
  
  // Check for positive indicators
  if (scores.ASD.percentage < 25) {
    positive_indicators.push('Good social communication skills');
  }
  if (scores.ADHD.percentage < 25) {
    positive_indicators.push('Age-appropriate attention span');
  }
  if (scores.Speech.percentage < 25) {
    positive_indicators.push('Language development on track');
  }
  
  return {
    red_flags: red_flags.slice(0, 7),
    positive_indicators: positive_indicators.slice(0, 5)
  };
}

// ==========================================
// 💡 Generate Recommendations
// ==========================================
function generateRecommendations(scores, primaryConcern, riskLevel) {
  const recommendations = {
    immediate: [],
    follow_up: [],
    home: [],
    specialists: []
  };
  
  // Based on risk level
  if (riskLevel === 'very_high' || riskLevel === 'high') {
    recommendations.immediate.push('Schedule appointment with specialist within 1-2 weeks');
    recommendations.immediate.push('Begin early intervention program');
  }
  
  if (riskLevel === 'medium') {
    recommendations.follow_up.push('Monitor development closely');
    recommendations.follow_up.push('Re-assess in 3-6 months');
  }
  
  // Condition-specific recommendations
  if (primaryConcern === 'ASD' && scores.ASD.percentage >= 25) {
    recommendations.immediate.push('Consult developmental pediatrician');
    recommendations.immediate.push('Consider ADOS-2 assessment');
    recommendations.specialists.push({
      type: 'Developmental Pediatrician',
      priority: 'high',
      reason: 'Comprehensive autism evaluation'
    });
    recommendations.home.push('Increase face-to-face interaction');
    recommendations.home.push('Use simple, repetitive language');
    recommendations.home.push('Create consistent daily routines');
  }
  
  if (primaryConcern === 'Speech' && scores.Speech.percentage >= 25) {
    recommendations.specialists.push({
      type: 'Speech-Language Pathologist',
      priority: 'high',
      reason: 'Language delay assessment and therapy'
    });
    recommendations.home.push('Read to child daily');
    recommendations.home.push('Narrate daily activities');
    recommendations.home.push('Encourage verbal communication');
  }
  
  if (primaryConcern === 'ADHD' && scores.ADHD.percentage >= 25) {
    recommendations.specialists.push({
      type: 'Child Psychologist',
      priority: 'medium',
      reason: 'ADHD evaluation'
    });
    recommendations.home.push('Establish clear routines');
    recommendations.home.push('Break tasks into small steps');
    recommendations.home.push('Provide structured environment');
  }
  
  return recommendations;
}

// ==========================================
// 📝 Get Question Interpretation
// ==========================================
function getQuestionInterpretation(questionId, section) {
  const interpretations = {
    'Q5': 'Limited eye contact',
    'Q6': 'Poor response to name',
    'Q11': 'Limited social interaction',
    'Q13': 'Repetitive behaviors present',
    'ASD1': 'No pretend play',
    'ASD2': 'No pointing to share interest',
    'SPEECH3': 'Significant language delay',
    'ADHD9': 'Excessive hyperactivity'
  };
  
  return interpretations[questionId] || null;
}

module.exports = {
  calculateQuestionnaireScores
};