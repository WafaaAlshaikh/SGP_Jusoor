// services/analysisService.js
const Groq = require('groq-sdk');

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY
});

class AnalysisService {
 
  static calculateStatistics(scores) {
    if (!scores || scores.length === 0) {
      return null;
    }

    const n = scores.length;
    
    // Average
    const average = scores.reduce((sum, score) => sum + score, 0) / n;
    
    // Standard Deviation
    const variance = scores.reduce((sum, score) => sum + Math.pow(score - average, 2), 0) / n;
    const standardDeviation = Math.sqrt(variance);
    
    // Coefficient of Variation 
    const cv = (standardDeviation / average) * 100;
    
    // Linear Regression for R² 
    const xValues = scores.map((_, index) => index + 1);
    const xMean = xValues.reduce((sum, x) => sum + x, 0) / n;
    const yMean = average;
    
    let numerator = 0;
    let denominatorX = 0;
    let denominatorY = 0;
    
    for (let i = 0; i < n; i++) {
      const xDiff = xValues[i] - xMean;
      const yDiff = scores[i] - yMean;
      numerator += xDiff * yDiff;
      denominatorX += xDiff * xDiff;
      denominatorY += yDiff * yDiff;
    }
    
    const rSquared = Math.pow(numerator / Math.sqrt(denominatorX * denominatorY), 2);
    
    // Slope 
    const slope = numerator / denominatorX;
    
    // Trend Detection
    const firstHalf = scores.slice(0, Math.floor(n / 2));
    const secondHalf = scores.slice(Math.floor(n / 2));
    const firstAvg = firstHalf.reduce((sum, s) => sum + s, 0) / firstHalf.length;
    const secondAvg = secondHalf.reduce((sum, s) => sum + s, 0) / secondHalf.length;
    const improvementRate = ((secondAvg - firstAvg) / firstAvg) * 100;
    
    return {
      average: parseFloat(average.toFixed(2)),
      standardDeviation: parseFloat(standardDeviation.toFixed(2)),
      coefficientOfVariation: parseFloat(cv.toFixed(2)),
      rSquared: parseFloat(rSquared.toFixed(4)),
      slope: parseFloat(slope.toFixed(2)),
      improvementRate: parseFloat(improvementRate.toFixed(2)),
      minScore: Math.min(...scores),
      maxScore: Math.max(...scores),
      latestScore: scores[scores.length - 1],
      firstScore: scores[0],
      totalChange: parseFloat((scores[scores.length - 1] - scores[0]).toFixed(2))
    };
  }

  
  static analyzeTrends(evaluations) {
    const scores = evaluations.map(e => parseFloat(e.progress_score));
    const dates = evaluations.map(e => new Date(e.created_at));
    
    // Calculating the intervals between sessions (in days)
    const intervals = [];
    for (let i = 1; i < dates.length; i++) {
      const daysDiff = Math.round((dates[i] - dates[i - 1]) / (1000 * 60 * 60 * 24));
      intervals.push(daysDiff);
    }
    
    const avgInterval = intervals.length > 0 
      ? intervals.reduce((sum, i) => sum + i, 0) / intervals.length 
      : 0;
    
    //  (Plateau)
    const lastThreeScores = scores.slice(-3);
    const isPlateau = lastThreeScores.length >= 3 && 
      Math.max(...lastThreeScores) - Math.min(...lastThreeScores) < 3;
    
    
    const recentScores = scores.slice(-5);
    const recentStdDev = this.calculateStatistics(recentScores)?.standardDeviation || 0;
    const isConsistent = recentStdDev < 5;
    
    return {
      averageSessionInterval: parseFloat(avgInterval.toFixed(1)),
      isPlateau,
      isConsistent,
      recentPerformance: recentScores.length > 0 ? recentScores : null,
      sessionCount: evaluations.length
    };
  }

  
  static async generateAIAnalysis(childData, evaluations, specialistInfo) {
    const scores = evaluations.map(e => parseFloat(e.progress_score));
    const statistics = this.calculateStatistics(scores);
    const trends = this.analyzeTrends(evaluations);
    
   
    const allNotes = evaluations.map((e, idx) => 
      `Session ${idx + 1} (${new Date(e.created_at).toLocaleDateString()}): Score ${e.progress_score}/100 - ${e.notes || 'No notes'}`
    ).join('\n');

    const prompt = `You are an experienced ${specialistInfo.specialization} specialist with ${specialistInfo.years_experience} years of experience analyzing child development progress.

**CHILD INFORMATION:**
- Name: ${childData.full_name}
- Age: ${this.calculateAge(childData.date_of_birth)} years old
- Gender: ${childData.gender}
- Diagnosis: ${childData.diagnosis?.name || 'Not specified'}
- Medical History: ${childData.medical_history || 'None'}

**STATISTICAL ANALYSIS:**
- Total Sessions: ${evaluations.length}
- Average Score: ${statistics?.average || 'N/A'}/100
- Standard Deviation: ${statistics?.standardDeviation || 'N/A'}
- Improvement Rate: ${statistics?.improvementRate || 'N/A'}%
- R² (Trend Strength): ${statistics?.rSquared || 'N/A'}
- Progress Slope: ${statistics?.slope || 'N/A'} points/session
- Score Range: ${statistics?.minScore || 'N/A'} - ${statistics?.maxScore || 'N/A'}
- Current Status: ${trends.isPlateau ? 'Plateau Detected' : 'Active Progress'}
- Performance Consistency: ${trends.isConsistent ? 'Stable' : 'Variable'}

**SESSION HISTORY & NOTES:**
${allNotes}

**YOUR TASK:**
Provide a comprehensive professional analysis in a STRUCTURED JSON format. Return ONLY valid JSON without any markdown, code blocks, or additional text.

The JSON must follow this exact structure:

{
  "overall_assessment": {
    "summary": "Brief 2-3 sentence overview of child's progress",
    "trend": "Improving/Stable/Declining/Variable",
    "progress_level": "Excellent/Good/Moderate/Needs Attention"
  },
  "strengths": [
    {
      "area": "Specific skill or behavior",
      "description": "Detailed observation with evidence from notes",
      "progress": "How it improved over time"
    }
  ],
  "challenges": [
    {
      "area": "Specific challenge",
      "description": "Detailed observation",
      "impact": "How it affects overall progress",
      "recommendation": "Specific strategy to address it"
    }
  ],
  "patterns_identified": {
    "optimal_timing": {
      "best_time": "Morning/Afternoon/Evening with specific hours",
      "evidence": "Data points supporting this conclusion"
    },
    "session_frequency": {
      "current": "Current frequency (e.g., weekly)",
      "effectiveness": "How well current frequency is working"
    },
    "performance_factors": [
      "Environmental or situational factors affecting performance"
    ]
  },
  "recommendations": {
    "session_schedule": {
      "frequency": "Recommended number per week",
      "duration": "Recommended session length",
      "timing": "Best time of day",
      "rationale": "Why this schedule is recommended"
    },
    "next_session": {
      "suggested_date": "Calculate exact date from last session",
      "focus_areas": ["Specific activity 1", "Specific activity 2"],
      "preparation": "What to prepare or bring"
    },
    "intensity_adjustment": {
      "action": "Increase/Decrease/Maintain",
      "reason": "Why this adjustment is needed",
      "implementation": "How to implement the change"
    }
  },
  "focus_areas": [
    {
      "priority": "High/Medium/Low",
      "skill": "Specific skill to work on",
      "activities": ["Specific exercise 1", "Specific exercise 2"],
      "expected_outcome": "What improvement to expect",
      "timeline": "Estimated time to see progress"
    }
  ],
  "goal_projection": {
    "target_score": 85,
    "current_score": ${statistics?.latestScore || 'N/A'},
    "estimated_sessions": "Number of sessions to reach target",
    "estimated_date": "Approximate date to reach target",
    "confidence_level": "High/Medium/Low",
    "factors": ["Key factors that could affect timeline"]
  },
  "parent_guidance": {
    "home_activities": ["Activity 1", "Activity 2"],
    "do_list": ["What parents should do"],
    "avoid_list": ["What parents should avoid"],
    "progress_indicators": ["Signs of improvement to watch for"]
  }
}

Be extremely specific and base all observations on actual data from the notes and scores. Calculate exact dates and provide quantifiable targets.`;

    try {
      const completion = await groq.chat.completions.create({
        model: 'llama-3.1-8b-instant',
        messages: [
          {
            role: 'system',
            content: 'You are an expert child development specialist. Return ONLY valid JSON without markdown or code blocks.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 3000
      });

      const rawResponse = completion.choices[0]?.message?.content || '{}';
      

      let cleanedResponse = rawResponse.trim();
      cleanedResponse = cleanedResponse.replace(/```json\n?/g, '');
      cleanedResponse = cleanedResponse.replace(/```\n?/g, '');
      cleanedResponse = cleanedResponse.trim();
      
   
      try {
        return JSON.parse(cleanedResponse);
      } catch (parseError) {
        console.error('JSON Parse Error:', parseError);
        console.error('Raw Response:', rawResponse);
        
     
        return {
          overall_assessment: {
            summary: rawResponse,
            trend: "Unable to parse",
            progress_level: "Analysis incomplete"
          },
          error: "Failed to parse AI response as JSON"
        };
      }
      
    } catch (error) {
      console.error('Groq API Error:', error);
      throw new Error('Failed to generate AI analysis');
    }
  }

 
static async generateInitialPlan(childData, firstEvaluation, specialistInfo) {
  const prompt = `You are a ${specialistInfo.specialization} specialist creating an initial treatment plan for a new child.

**CHILD INFORMATION:**
- Name: ${childData.full_name}
- Age: ${this.calculateAge(childData.date_of_birth)} years old
- Gender: ${childData.gender}
- Diagnosis: ${childData.diagnosis?.name || 'Under evaluation'}
- Medical History: ${childData.medical_history || 'None'}

**INITIAL EVALUATION:**
- Date: ${new Date(firstEvaluation.created_at).toLocaleDateString()}
- Score: ${firstEvaluation.progress_score}/100
- Notes: ${firstEvaluation.notes || 'No detailed notes provided'}
- Type: ${firstEvaluation.evaluation_type}

**IMPORTANT DISTINCTION:**
- "next_session" = Next therapy session (should be within 3-7 days from current date)
- "next_evaluation" = Next formal assessment/re-evaluation (should be after 3-4 weeks)

**YOUR TASK:**
Create a detailed initial treatment plan in STRUCTURED JSON format. Return ONLY valid JSON without markdown or code blocks.

{
  "baseline_assessment": {
    "current_abilities": ["Ability 1", "Ability 2"],
    "main_challenges": ["Challenge 1", "Challenge 2"],
    "behavioral_observations": ["Observation 1", "Observation 2"],
    "initial_score_interpretation": "What the score indicates"
  },
  "treatment_goals": {
    "short_term": [
      {
        "goal": "Specific measurable goal",
        "timeline": "1 month",
        "success_criteria": "How to measure success"
      }
    ],
    "long_term": [
      {
        "goal": "Specific measurable goal",
        "timeline": "3-6 months",
        "success_criteria": "How to measure success"
      }
    ]
  },
  "recommended_schedule": {
    "frequency": "Sessions per week",
    "duration": "Minutes per session",
    "best_timing": "Time of day",
    "rationale": "Why this schedule"
  },
  "initial_focus_areas": [
    {
      "area": "Skill/behavior to target",
      "priority": "High/Medium/Low",
      "approach": "How to work on it",
      "expected_progress": "What to expect in first month"
    }
  ],
  "next_session": {
    "suggested_date": "2025-11-26", // ⬅️ MUST be within 3-7 days (next therapy session)
    "focus_areas": ["Area 1", "Area 2"],
    "preparation": "What to prepare for next session"
  },
  "next_evaluation": {
    "suggested_date": "2025-12-23", // ⬅️ Formal re-assessment after 3-4 weeks
    "what_to_assess": ["Aspect 1", "Aspect 2"],
    "expected_improvements": ["Expected change 1", "Expected change 2"]
  },
  "parent_instructions": {
    "daily_activities": ["Activity 1", "Activity 2"],
    "environment_modifications": ["Change 1", "Change 2"],
    "what_to_monitor": ["Sign 1", "Sign 2"],
    "communication_tips": ["Tip 1", "Tip 2"]
  },
  "risk_factors": {
    "concerns": ["Concern 1 if any"],
    "monitoring_needed": ["What to watch"],
    "escalation_criteria": ["When to contact specialist urgently"]
  },
  "success_indicators": {
    "week_1": ["Expected milestone"],
    "week_2": ["Expected milestone"],
    "week_4": ["Expected milestone"],
    "month_3": ["Expected milestone"]
  }
}

Calculate dates based on current date: ${new Date().toISOString().split('T')[0]}
- Next session: 3-7 days from now
- Next evaluation: 3-4 weeks from now`;

  try {
    const completion = await groq.chat.completions.create({
      model: 'llama-3.1-8b-instant',
      messages: [
        {
          role: 'system',
          content: 'You are an experienced specialist. Return ONLY valid JSON without markdown.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.4,
      max_tokens: 2500
    });

    const rawResponse = completion.choices[0]?.message?.content || '{}';
    
    let cleanedResponse = rawResponse.trim();
    cleanedResponse = cleanedResponse.replace(/```json\n?/g, '');
    cleanedResponse = cleanedResponse.replace(/```\n?/g, '');
    cleanedResponse = cleanedResponse.trim();
    
    try {
      return JSON.parse(cleanedResponse);
    } catch (parseError) {
      console.error('JSON Parse Error:', parseError);
      return {
        baseline_assessment: {
          initial_score_interpretation: rawResponse
        },
        error: "Failed to parse AI response as JSON"
      };
    }
    
  } catch (error) {
    console.error('Groq API Error:', error);
    throw new Error('Failed to generate initial plan');
  }
}

  static calculateAge(dateOfBirth) {
    if (!dateOfBirth) return 'Unknown';
    const today = new Date();
    const birthDate = new Date(dateOfBirth);
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }
    return age;
  }


static normalizeDate(dateString) {
  if (!dateString) return null;
  
  try {
    // إزالة أي مسافات
    const cleanDate = dateString.toString().trim();
    
    // محاولة تحليل التاريخ بكل الطرق الممكنة
    let parsedDate;
    
    // صيغة: "11/19/2025" أو "11/19/25"
    if (cleanDate.includes('/')) {
      const parts = cleanDate.split('/');
      if (parts.length === 3) {
        let [month, day, year] = parts;
        year = year.length === 2 ? `20${year}` : year;
        parsedDate = new Date(`${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`);
      }
    }
    // صيغة: "2025-11-19"
    else if (cleanDate.includes('-') && cleanDate.split('-')[0].length === 4) {
      parsedDate = new Date(cleanDate);
    }
    // صيغة: "19-Nov-2025" أو أي صيغة نصية
    else {
      parsedDate = new Date(cleanDate);
    }
    
    if (!isNaN(parsedDate.getTime())) {
      return parsedDate.toISOString().split('T')[0];
    }
  } catch (error) {
    console.log('❌ Date normalization failed:', dateString, error);
  }
  
  return null;
}

static calculateNextSessionDate(evaluations, trends = null, aiAnalysis = null) {
  if (!evaluations || evaluations.length === 0) {
    const nextDate = new Date();
    nextDate.setDate(nextDate.getDate() + 7);
    return nextDate.toISOString().split('T')[0];
  }

  const lastSession = new Date(evaluations[evaluations.length - 1].created_at);
  
  
  console.log('🔍 Searching for AI date in:', Object.keys(aiAnalysis || {}));
  
 
  if (aiAnalysis && aiAnalysis.next_session) {
    const aiDate = aiAnalysis.next_session.suggested_date;
    if (aiDate) {
      const normalizedDate = this.normalizeDate(aiDate);
      if (normalizedDate) {
        console.log(`✅ Using AI suggested date (direct): ${aiDate} -> ${normalizedDate}`);
        return normalizedDate;
      }
    }
  }
  
  
  if (aiAnalysis && aiAnalysis.recommendations && aiAnalysis.recommendations.next_session) {
    const aiDate = aiAnalysis.recommendations.next_session.suggested_date;
    if (aiDate) {
      const normalizedDate = this.normalizeDate(aiDate);
      if (normalizedDate) {
        console.log(`✅ Using AI suggested date (in recommendations): ${aiDate} -> ${normalizedDate}`);
        return normalizedDate;
      }
    }
  }
  
 
  if (aiAnalysis) {
    
    const searchForDate = (obj, path = '') => {
      for (const key in obj) {
        if (key === 'suggested_date' && obj[key]) {
          console.log(`📍 Found suggested_date at: ${path}${key}`);
          const normalizedDate = this.normalizeDate(obj[key]);
          if (normalizedDate) {
            console.log(`✅ Using AI suggested date (searched): ${obj[key]} -> ${normalizedDate}`);
            return normalizedDate;
          }
        }
        if (typeof obj[key] === 'object' && obj[key] !== null) {
          const result = searchForDate(obj[key], `${path}${key}.`);
          if (result) return result;
        }
      }
      return null;
    };
    
    const foundDate = searchForDate(aiAnalysis);
    if (foundDate) return foundDate;
  }

 
  let recommendedInterval = 7;
  
  if (trends && trends.averageSessionInterval) {
    recommendedInterval = Math.round(trends.averageSessionInterval);
  }

  const calculatedDate = new Date(lastSession);
  calculatedDate.setDate(calculatedDate.getDate() + recommendedInterval);
  
  console.log(`📅 No AI date found, using calculated: ${calculatedDate.toISOString().split('T')[0]} (interval: ${recommendedInterval} days)`);
  
  return calculatedDate.toISOString().split('T')[0];
}

  static calculateDateRangeComparison(evaluations, startDate, endDate) {
    if (evaluations.length < 2) {
      throw new Error('Need at least 2 evaluations for comparison');
    }

    const scores = evaluations.map(e => parseFloat(e.progress_score));
    const firstScore = scores[0];
    const lastScore = scores[scores.length - 1];
    const scoreChange = lastScore - firstScore;
    const percentageChange = (scoreChange / firstScore) * 100;

    // Calculate daily improvement rate
    const daysDiff = Math.round((endDate - startDate) / (1000 * 60 * 60 * 24));
    const dailyImprovementRate = scoreChange / daysDiff;

    // Analyze trends within the period
    const statistics = this.calculateStatistics(scores);
    const trends = this.analyzeTrends(evaluations);

    // Identify best and worst performances
    const bestScore = Math.max(...scores);
    const worstScore = Math.min(...scores);
    const bestEvaluation = evaluations.find(e => parseFloat(e.progress_score) === bestScore);
    const worstEvaluation = evaluations.find(e => parseFloat(e.progress_score) === worstScore);

    return {
      scoreChange: parseFloat(scoreChange.toFixed(2)),
      percentageChange: parseFloat(percentageChange.toFixed(2)),
      dailyImprovementRate: parseFloat(dailyImprovementRate.toFixed(2)),
      trendDirection: statistics.slope > 0 ? 'Improving' : statistics.slope < 0 ? 'Declining' : 'Stable',
      averageScore: statistics.average,
      scoreVolatility: statistics.standardDeviation,
      consistencyRating: statistics.standardDeviation < 5 ? 'High' : statistics.standardDeviation < 10 ? 'Medium' : 'Low',
      bestPerformance: {
        score: bestScore,
        date: bestEvaluation?.created_at,
        type: bestEvaluation?.evaluation_type
      },
      challengingPeriods: {
        lowest_score: worstScore,
        date: worstEvaluation?.created_at,
        notes: worstEvaluation?.notes
      },
      periodAnalysis: {
        total_evaluations: evaluations.length,
        evaluation_frequency: evaluations.length / (daysDiff / 7), // per week
        progress_consistency: trends.isConsistent ? 'Consistent' : 'Variable'
      },
      sessionFrequency: `Average ${(daysDiff / evaluations.length).toFixed(1)} days between evaluations`,
      completionRate: `${evaluations.length} evaluations in ${daysDiff} days`,
      recommendedAdjustments: this.generateDateRangeRecommendations(statistics, trends, dailyImprovementRate)
    };
  }

  /**
   * Generate AI analysis for date range comparison
   */
  static async generateDateRangeAnalysis(childData, evaluations, startDate, endDate, comparisonStats) {
    const scores = evaluations.map(e => parseFloat(e.progress_score));
    const allNotes = evaluations.map((e, idx) => 
      `Evaluation ${idx + 1} (${new Date(e.created_at).toLocaleDateString()}): Score ${e.progress_score}/100 - ${e.notes || 'No notes'}`
    ).join('\n');

    const prompt = `You are comparing a child's progress between two specific dates.

**COMPARISON PERIOD:**
- From: ${startDate.toLocaleDateString()} To: ${endDate.toLocaleDateString()}
- Total Days: ${Math.round((endDate - startDate) / (1000 * 60 * 60 * 24))} days

**CHILD INFORMATION:**
- Name: ${childData.full_name}
- Age: ${this.calculateAge(childData.date_of_birth)}
- Diagnosis: ${childData.diagnosis?.name || 'Not specified'}

**PERFORMANCE DATA:**
- Starting Score: ${comparisonStats.scoreChange + parseFloat(evaluations[evaluations.length - 1].progress_score)}/100
- Ending Score: ${parseFloat(evaluations[evaluations.length - 1].progress_score)}/100
- Total Change: ${comparisonStats.scoreChange} points
- Percentage Change: ${comparisonStats.percentageChange}%
- Daily Improvement Rate: ${comparisonStats.dailyImprovementRate} points/day
- Average Score: ${comparisonStats.averageScore}/100
- Consistency: ${comparisonStats.consistencyRating}

**EVALUATION HISTORY:**
${allNotes}

**YOUR TASK:**
Provide a focused comparison analysis in STRUCTURED JSON format. Return ONLY valid JSON.

{
  "period_summary": {
    "overview": "Brief summary of progress during this period",
    "key_achievements": ["Achievement 1", "Achievement 2"],
    "main_challenges": ["Challenge 1", "Challenge 2"]
  },
  "progress_analysis": {
    "rate_of_progress": "Fast/Moderate/Slow compared to expectations",
    "consistency_analysis": "Analysis of performance stability",
    "critical_periods": {
      "breakthrough_moments": ["When and why progress accelerated"],
      "setback_periods": ["When and why challenges occurred"]
    }
  },
  "comparison_insights": {
    "starting_vs_ending": "Detailed comparison of capabilities",
    "skill_development": "Which skills improved most",
    "remaining_gaps": "Areas that still need work"
  },
  "period_specific_recommendations": {
    "what_worked": "Strategies that were effective in this period",
    "what_needs_change": "What should be adjusted",
    "carry_forward": "Successful approaches to continue"
  },
  "next_period_planning": {
    "build_on_success": "How to leverage progress",
    "address_remaining": "How to tackle ongoing challenges",
    "realistic_targets": "Goals for the next similar period"
  }
}`;

    try {
      const completion = await groq.chat.completions.create({
        model: 'llama-3.1-8b-instant',
        messages: [
          {
            role: 'system',
            content: 'You are analyzing progress between two specific dates. Return ONLY valid JSON.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 2000
      });

      const rawResponse = completion.choices[0]?.message?.content || '{}';
      const cleanedResponse = rawResponse.replace(/```json\n?|```\n?/g, '').trim();
      
      try {
        return JSON.parse(cleanedResponse);
      } catch (parseError) {
        console.error('JSON Parse Error in date range analysis:', parseError);
        return {
          period_summary: {
            overview: "Analysis incomplete due to parsing error",
            key_achievements: [],
            main_challenges: []
          },
          error: "Failed to parse AI response"
        };
      }
    } catch (error) {
      console.error('Groq API Error in date range analysis:', error);
      throw new Error('Failed to generate date range analysis');
    }
  }

  /**
   * Analyze progress for specific periods (week, month, 3 months, etc.)
   */
  static calculatePeriodAnalysis(evaluations, sessions, period, startDate, endDate) {
    const scores = evaluations.map(e => parseFloat(e.progress_score));
    const statistics = this.calculateStatistics(scores);
    const trends = this.analyzeTrends(evaluations);

    // Calculate period-specific metrics
    const daysInPeriod = Math.round((endDate - startDate) / (1000 * 60 * 60 * 24));
    const evaluationsPerWeek = (evaluations.length / (daysInPeriod / 7)).toFixed(1);

    // Group evaluations by week for detailed analysis
    const evaluationsByWeek = this.groupEvaluationsByWeek(evaluations, startDate, endDate);
    const averageScoresPerWeek = this.calculateWeeklyAverages(evaluationsByWeek);

    return {
      evaluationFrequency: `${evaluationsPerWeek} evaluations per week`,
      averageScore: statistics.average,
      startingScore: scores[0],
      endingScore: scores[scores.length - 1],
      netChange: parseFloat((scores[scores.length - 1] - scores[0]).toFixed(2)),
      progressTrend: statistics.slope > 0 ? 'Positive' : statistics.slope < 0 ? 'Negative' : 'Neutral',
      consistencyLevel: statistics.standardDeviation < 5 ? 'High' : statistics.standardDeviation < 10 ? 'Medium' : 'Low',
      improvementRate: statistics.improvementRate,
      sessionEffectiveness: this.calculateSessionEffectiveness(sessions, evaluations),
      strongestPeriod: this.identifyStrongestPeriod(evaluationsByWeek),
      challengingPeriod: this.identifyChallengingPeriod(evaluationsByWeek),
      evaluationsByWeek,
      averageScoresPerWeek,
      sessionCompletionRates: this.calculateCompletionRates(sessions),
      scheduleAdjustments: this.generatePeriodRecommendations(period, statistics, trends, evaluations.length),
      focusAreas: this.identifyPeriodFocusAreas(evaluations),
      intensityRecommendations: this.generateIntensityRecommendations(period, statistics)
    };
  }

  /**
   * Generate AI analysis for specific periods
   */
  static async generatePeriodAnalysis(childData, evaluations, sessions, period, periodAnalysis) {
    const periodNames = {
      'last_week': 'last week',
      'last_month': 'last month',
      'last_3_months': 'last 3 months',
      'last_6_months': 'last 6 months'
    };

    const prompt = `You are analyzing a child's progress over the ${periodNames[period]}.

**PERIOD ANALYSIS DATA:**
- Period: ${periodNames[period]}
- Total Evaluations: ${evaluations.length}
- Average Score: ${periodAnalysis.averageScore}/100
- Progress Trend: ${periodAnalysis.progressTrend}
- Consistency: ${periodAnalysis.consistencyLevel}
- Improvement Rate: ${periodAnalysis.improvementRate}%

**CHILD INFORMATION:**
- Name: ${childData.full_name}
- Age: ${this.calculateAge(childData.date_of_birth)}
- Diagnosis: ${childData.diagnosis?.name || 'Not specified'}

**YOUR TASK:**
Provide period-specific analysis in STRUCTURED JSON format. Return ONLY valid JSON.

{
  "period_overview": {
    "summary": "Overall assessment of this period",
    "success_level": "Very Successful/Successful/Needs Improvement",
    "key_highlights": ["Highlight 1", "Highlight 2"]
  },
  "progress_analysis": {
    "expectations_vs_reality": "How progress compares to expectations for this period",
    "rate_analysis": "Whether progress was faster/slower than expected",
    "pattern_identification": "Any recurring patterns in this period"
  },
  "period_specific_factors": {
    "seasonal_influences": "Any time-based factors affecting progress",
    "frequency_effectiveness": "How evaluation frequency impacted progress",
    "external_factors": "Other period-specific considerations"
  },
  "next_period_strategy": {
    "carry_forward": "What to continue from this period",
    "adjustments_needed": "What to change for next period",
    "realistic_targets": "Goals for the next ${periodNames[period]}"
  },
  "parent_guidance_period": {
    "home_activities": ["Period-specific home activities"],
    "progress_monitoring": "What parents should watch for",
    "communication_focus": "Key points to discuss with parents"
  }
}`;

    try {
      const completion = await groq.chat.completions.create({
        model: 'llama-3.1-8b-instant',
        messages: [
          {
            role: 'system',
            content: `You are analyzing progress for the ${periodNames[period]}. Return ONLY valid JSON.`
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 2000
      });

      const rawResponse = completion.choices[0]?.message?.content || '{}';
      const cleanedResponse = rawResponse.replace(/```json\n?|```\n?/g, '').trim();
      
      try {
        return JSON.parse(cleanedResponse);
      } catch (parseError) {
        console.error('JSON Parse Error in period analysis:', parseError);
        return {
          period_overview: {
            summary: "Period analysis incomplete",
            success_level: "Analysis unavailable",
            key_highlights: []
          }
        };
      }
    } catch (error) {
      console.error('Groq API Error in period analysis:', error);
      throw new Error('Failed to generate period analysis');
    }
  }

  // Helper methods
  static groupEvaluationsByWeek(evaluations, startDate, endDate) {
    const weeks = {};
    const currentDate = new Date(startDate);
    
    while (currentDate <= endDate) {
      const weekStart = new Date(currentDate);
      const weekEnd = new Date(currentDate);
      weekEnd.setDate(weekEnd.getDate() + 6);
      
      const weekKey = `${weekStart.toISOString().split('T')[0]} to ${weekEnd.toISOString().split('T')[0]}`;
      
      weeks[weekKey] = evaluations.filter(evaluation => {
        const evalDate = new Date(evaluation.created_at);
        return evalDate >= weekStart && evalDate <= weekEnd;
      });
      
      currentDate.setDate(currentDate.getDate() + 7);
    }
    
    return weeks;
  }

  static calculateWeeklyAverages(evaluationsByWeek) {
    const averages = {};
    
    for (const [week, evals] of Object.entries(evaluationsByWeek)) {
      if (evals.length > 0) {
        const scores = evals.map(evaluation => parseFloat(evaluation.progress_score));
        averages[week] = scores.reduce((sum, score) => sum + score, 0) / scores.length;
      }
    }
    
    return averages;
  }

  static calculateSessionEffectiveness(sessions, evaluations) {
    const completedSessions = sessions.filter(s => s.status === 'Completed').length;
    const totalSessions = sessions.length;
    const completionRate = totalSessions > 0 ? (completedSessions / totalSessions) * 100 : 0;
    
    return {
      completionRate: parseFloat(completionRate.toFixed(1)),
      effectiveness: completionRate > 80 ? 'High' : completionRate > 60 ? 'Medium' : 'Low'
    };
  }

  static identifyStrongestPeriod(evaluationsByWeek) {
    let strongestWeek = '';
    let highestAverage = 0;
    
    for (const [week, evals] of Object.entries(evaluationsByWeek)) {
      if (evals.length > 0) {
        const average = evals.reduce((sum, evaluation) => sum + parseFloat(evaluation.progress_score), 0) / evals.length;
        if (average > highestAverage) {
          highestAverage = average;
          strongestWeek = week;
        }
      }
    }
    
    return { week: strongestWeek, averageScore: parseFloat(highestAverage.toFixed(2)) };
  }

  static identifyChallengingPeriod(evaluationsByWeek) {
    let challengingWeek = '';
    let lowestAverage = 100;
    
    for (const [week, evals] of Object.entries(evaluationsByWeek)) {
      if (evals.length > 0) {
        const average = evals.reduce((sum, evaluation) => sum + parseFloat(evaluation.progress_score), 0) / evals.length;
        if (average < lowestAverage) {
          lowestAverage = average;
          challengingWeek = week;
        }
      }
    }
    
    return { week: challengingWeek, averageScore: parseFloat(lowestAverage.toFixed(2)) };
  }

  static calculateCompletionRates(sessions) {
    const statusCounts = {};
    sessions.forEach(session => {
      statusCounts[session.status] = (statusCounts[session.status] || 0) + 1;
    });
    
    return statusCounts;
  }

  static generateDateRangeRecommendations(statistics, trends, dailyImprovementRate) {
    const recommendations = [];
    
    if (dailyImprovementRate < 0.5) {
      recommendations.push('Consider increasing session frequency for better progress');
    }
    
    if (statistics.standardDeviation > 10) {
      recommendations.push('High score variability - investigate consistency factors');
    }
    
    if (trends.isPlateau) {
      recommendations.push('Progress plateau detected - consider strategy adjustment');
    }
    
    return recommendations.length > 0 ? recommendations : ['Current approach appears effective - maintain course'];
  }

  static generatePeriodRecommendations(period, statistics, trends, evaluationCount) {
    const recommendations = [];
    
    switch (period) {
      case 'last_week':
        if (evaluationCount < 2) {
          recommendations.push('Consider more frequent evaluations for weekly analysis');
        }
        break;
      case 'last_month':
        if (evaluationCount < 4) {
          recommendations.push('Aim for weekly evaluations for better monthly tracking');
        }
        break;
      case 'last_3_months':
        if (statistics.improvementRate < 10) {
          recommendations.push('Consider intensifying therapy for better 3-month progress');
        }
        break;
    }
    
    return recommendations;
  }

  static identifyPeriodFocusAreas(evaluations) {
    // Analyze notes to identify common focus areas
    const allNotes = evaluations.map(e => e.notes).join(' ').toLowerCase();
    const focusAreas = [];
    
    if (allNotes.includes('communication') || allNotes.includes('speech')) {
      focusAreas.push('Communication Skills');
    }
    if (allNotes.includes('social') || allNotes.includes('interaction')) {
      focusAreas.push('Social Interaction');
    }
    if (allNotes.includes('motor') || allNotes.includes('movement')) {
      focusAreas.push('Motor Skills');
    }
    if (allNotes.includes('behavior') || allNotes.includes('compliance')) {
      focusAreas.push('Behavior Management');
    }
    
    return focusAreas.length > 0 ? focusAreas : ['General Development'];
  }

  static generateIntensityRecommendations(period, statistics) {
    if (statistics.improvementRate > 20) {
      return 'Current intensity appears optimal - maintain current level';
    } else if (statistics.improvementRate > 10) {
      return 'Consider moderate intensity increase for better results';
    } else {
      return 'Significant intensity adjustment recommended - review therapy plan';
    }
  }
  // services/analysisService.js


static calculateDirectComparison(startEvaluation, endEvaluation, startDate, endDate) {
  const startScore = parseFloat(startEvaluation.progress_score);
  const endScore = parseFloat(endEvaluation.progress_score);
  
  const scoreChange = endScore - startScore;
  const percentageChange = (scoreChange / startScore) * 100;
  
  
  const daysBetween = Math.round((endDate - startDate) / (1000 * 60 * 60 * 24));
  const dailyImprovementRate = scoreChange / daysBetween;
  
  
  let trend, magnitude, progressSummary;
  
  if (scoreChange > 0) {
    trend = 'Improving';
    if (scoreChange > 20) {
      magnitude = 'Significant Improvement';
      progressSummary = 'Excellent progress between the two dates';
    } else if (scoreChange > 10) {
      magnitude = 'Moderate Improvement';
      progressSummary = 'Good progress between the two dates';
    } else {
      magnitude = 'Slight Improvement';
      progressSummary = 'Minor but positive progress between the two dates';
    }
  } else if (scoreChange < 0) {
    trend = 'Declining';
    magnitude = 'Needs Attention';
    progressSummary = 'Performance declined between the two dates';
  } else {
    trend = 'Stable';
    magnitude = 'No Change';
    progressSummary = 'Performance remained stable between the two dates';
  }
  
 
  const keyDifferences = this.analyzeNotesDifferences(startEvaluation.notes, endEvaluation.notes);
  
  
  const scoreDifference = Math.abs(scoreChange);
  const consistencyAnalysis = scoreDifference < 5 ? 'Highly Consistent' : 
                             scoreDifference < 15 ? 'Moderately Consistent' : 
                             'Significant Variation';
  
  return {
    scoreChange: parseFloat(scoreChange.toFixed(2)),
    percentageChange: parseFloat(percentageChange.toFixed(2)),
    dailyImprovementRate: parseFloat(dailyImprovementRate.toFixed(2)),
    daysBetween,
    trend,
    magnitude,
    progressSummary,
    keyDifferences,
    consistencyAnalysis,
    recommendations: this.generateDirectComparisonRecommendations(scoreChange, daysBetween)
  };
}


static analyzeNotesDifferences(startNotes, endNotes) {
  const differences = [];
  
  if (!startNotes && !endNotes) {
    return ['No notes available for comparison'];
  }
  
  if (!startNotes) {
    return ['No notes in starting evaluation'];
  }
  
  if (!endNotes) {
    return ['No notes in ending evaluation'];
  }
  
 
  const startLower = startNotes.toLowerCase();
  const endLower = endNotes.toLowerCase();
  
 
  const keywords = ['improved', 'better', 'progress', 'regressed', 'worse', 'challenge', 'difficulty', 'excellent', 'good'];
  
  keywords.forEach(keyword => {
    const inStart = startLower.includes(keyword);
    const inEnd = endLower.includes(keyword);
    
    if (inStart && !inEnd) {
      differences.push(`${keyword} mentioned in start but not in end`);
    } else if (!inStart && inEnd) {
      differences.push(`${keyword} mentioned in end but not in start`);
    }
  });
  
  return differences.length > 0 ? differences : ['Notes show development changes between evaluations'];
}


static generateDirectComparisonRecommendations(scoreChange, daysBetween) {
  const recommendations = [];
  
  if (scoreChange > 15) {
    recommendations.push('✅ Excellent progress - maintain current approach');
  } else if (scoreChange > 5) {
    recommendations.push('⚠️ Good progress - consider slight intensification');
  } else if (scoreChange > 0) {
    recommendations.push('📈 Slow progress - review intervention strategies');
  } else if (scoreChange < 0) {
    recommendations.push('❌ Declining - immediate strategy adjustment needed');
  } else {
    recommendations.push('➡️ No change - consider modifying approach');
  }
  
  if (daysBetween > 30) {
    recommendations.push('⏰ Long period between evaluations - consider more frequent assessments');
  } else if (daysBetween < 7) {
    recommendations.push('📅 Short period between evaluations - good monitoring frequency');
  }
  
  return recommendations;
}


static async generateDirectComparisonAnalysis(childData, startEvaluation, endEvaluation, startDate, endDate, comparisonStats) {
  const prompt = `You are comparing a child's progress between TWO SPECIFIC DATES only.

**DIRECT COMPARISON:**
- Start Date: ${startDate.toLocaleDateString()} | Score: ${startEvaluation.progress_score}/100
- End Date: ${endDate.toLocaleDateString()} | Score: ${endEvaluation.progress_score}/100
- Days Between: ${comparisonStats.daysBetween} days
- Score Change: ${comparisonStats.scoreChange} points
- Percentage Change: ${comparisonStats.percentageChange}%

**CHILD INFORMATION:**
- Name: ${childData.full_name}
- Age: ${this.calculateAge(childData.date_of_birth)}
- Diagnosis: ${childData.diagnosis?.name || 'Not specified'}

**STARTING EVALUATION (${startDate.toLocaleDateString()}):**
- Type: ${startEvaluation.evaluation_type}
- Score: ${startEvaluation.progress_score}/100
- Notes: ${startEvaluation.notes || 'No notes'}

**ENDING EVALUATION (${endDate.toLocaleDateString()}):**
- Type: ${endEvaluation.evaluation_type}
- Score: ${endEvaluation.progress_score}/100
- Notes: ${endEvaluation.notes || 'No notes'}

**YOUR TASK:**
Provide a focused DIRECT COMPARISON analysis in STRUCTURED JSON format. Return ONLY valid JSON.

{
  "direct_comparison_summary": {
    "overview": "Brief summary comparing ONLY these two specific evaluations",
    "progress_assessment": "Assessment based on score change between these two dates",
    "key_observation": "Most important observation from direct comparison"
  },
  "strengths_development": {
    "improved_areas": ["Area 1", "Area 2"],
    "maintained_strengths": ["Strength 1", "Strength 2"],
    "emerging_skills": ["New skill 1", "New skill 2"]
  },
  "challenges_evolution": {
    "resolved_issues": ["Issue 1", "Issue 2"],
    "ongoing_challenges": ["Challenge 1", "Challenge 2"],
    "new_concerns": ["Concern 1 if any"]
  },
  "specific_recommendations": {
    "immediate_actions": ["Action 1", "Action 2"],
    "strategy_adjustments": ["Adjustment 1", "Adjustment 2"],
    "focus_next_session": ["Focus 1", "Focus 2"]
  },
  "progress_trajectory": {
    "current_momentum": "Positive/Negative/Neutral based on this direct comparison",
    "expected_next_steps": "What to expect next based on this change",
    "urgency_level": "High/Medium/Low based on progress rate"
  }
}`;

  try {
    const completion = await groq.chat.completions.create({
      model: 'llama-3.1-8b-instant',
      messages: [
        {
          role: 'system',
          content: 'You are comparing TWO SPECIFIC evaluations only. Return ONLY valid JSON.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3,
      max_tokens: 1500
    });

    const rawResponse = completion.choices[0]?.message?.content || '{}';
    const cleanedResponse = rawResponse.replace(/```json\n?|```\n?/g, '').trim();
    
    try {
      return JSON.parse(cleanedResponse);
    } catch (parseError) {
      console.error('JSON Parse Error in direct comparison:', parseError);
      return {
        direct_comparison_summary: {
          overview: "Direct comparison analysis incomplete",
          progress_assessment: "Unable to parse AI response",
          key_observation: "Analysis failed"
        }
      };
    }
  } catch (error) {
    console.error('Groq API Error in direct comparison:', error);
    throw new Error('Failed to generate direct comparison analysis');
  }
}
}

module.exports = AnalysisService;