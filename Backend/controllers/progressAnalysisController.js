// controllers/progressAnalysisController.js
const { 
  Specialist, 
  Child, 
  Parent, 
  User, 
  Evaluation, 
  Diagnosis, 
  Institution, 
  Session 
} = require('../model/index');
const AnalysisService = require('../services/analysisService');
const { Op } = require('sequelize');

/**
 * تحليل شامل لتقدم الطفل
 * GET /api/specialist/children/:childId/progress-analysis
 */
const analyzeChildProgress = async (req, res) => {
  try {
    const { childId } = req.params;
    const specialistId = req.user.user_id;

    // 1️⃣ التحقق من صلاحية الأخصائي
    const specialist = await Specialist.findOne({
      where: { specialist_id: specialistId },
      include: [{
        model: User,
        attributes: ['full_name', 'email']
      }]
    });

    if (!specialist) {
      return res.status(404).json({ 
        success: false, 
        message: 'Specialist not found' 
      });
    }

    // 2️⃣ التحقق من وجود جلسات مع الطفل
    const hasAccess = await Session.findOne({
      where: { 
        specialist_id: specialistId,
        child_id: childId 
      }
    });

    if (!hasAccess) {
      return res.status(403).json({ 
        success: false, 
        message: 'No access to this child\'s records' 
      });
    }

    // 3️⃣ جلب معلومات الطفل الكاملة
    const child = await Child.findOne({
      where: { child_id: childId },
      include: [
        {
          model: Parent,
          include: [{
            model: User,
            attributes: ['full_name', 'phone', 'email']
          }]
        },
        {
          model: Diagnosis,
          as: 'Diagnosis',
          attributes: ['name', 'description']
        },
        {
          model: Institution,
          as: 'currentInstitution',
          attributes: ['name']
        }
      ]
    });

    if (!child) {
      return res.status(404).json({ 
        success: false, 
        message: 'Child not found' 
      });
    }

    // 4️⃣ جلب جميع التقييمات مرتبة زمنياً
    const evaluations = await Evaluation.findAll({
      where: { 
        child_id: childId,
        specialist_id: specialistId 
      },
      order: [['created_at', 'ASC']],
      attributes: [
        'evaluation_id', 
        'evaluation_type', 
        'notes', 
        'progress_score', 
        'created_at'
      ]
    });

    // 5️⃣ جلب السيشنات للتحليل
    const sessions = await Session.findAll({
      where: { 
        child_id: childId,
        specialist_id: specialistId 
      },
      attributes: ['session_id', 'date', 'time', 'status', 'session_type'],
      order: [['date', 'DESC']]
    });

    // 6️⃣ التحقق من وجود تقييمات
    if (evaluations.length === 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'No evaluations found for this child. Please add at least one evaluation first.' 
      });
    }

    // 7️⃣ تحضير معلومات الأخصائي
    const specialistInfo = {
      specialist_id: specialist.specialist_id,
      full_name: specialist.User.full_name,
      specialization: specialist.specialization,
      years_experience: specialist.years_experience
    };

    // 8️⃣ تحضير معلومات الطفل
    const childData = {
      child_id: child.child_id,
      full_name: child.full_name,
      date_of_birth: child.date_of_birth,
      gender: child.gender,
      diagnosis: child.Diagnosis,
      medical_history: child.medical_history,
      current_institution: child.currentInstitution,
      parent: {
        full_name: child.Parent?.User?.full_name,
        phone: child.Parent?.User?.phone
      }
    };

    let aiAnalysis;
    let statistics = null;
    let trends = null;
    let analysisType;

    // 9️⃣ تحديد نوع التحليل
    if (evaluations.length === 1) {
      // 🆕 خطة أولية للطفل الجديد
      analysisType = 'initial_plan';
      aiAnalysis = await AnalysisService.generateInitialPlan(
        childData,
        evaluations[0],
        specialistInfo
      );
    } else {
      // 📊 تحليل شامل للتقدم
      analysisType = 'comprehensive_analysis';
      
      // حساب الإحصائيات
      const scores = evaluations.map(e => parseFloat(e.progress_score));
      statistics = AnalysisService.calculateStatistics(scores);
      trends = AnalysisService.analyzeTrends(evaluations);
      
      // توليد التحليل بالـ AI
      aiAnalysis = await AnalysisService.generateAIAnalysis(
        childData,
        evaluations,
        specialistInfo
      );
    }

    // 🔟 حساب موعد الجلسة القادمة المقترح
    // 🔟 حساب موعد الجلسة القادمة المقترح - متزامن مع AI
    const suggestedNextSession = AnalysisService.calculateNextSessionDate(
      evaluations,
      trends,           // ⬅️ غير هذا
      aiAnalysis        // ⬅️ أضف هذا
    );

    // 1️⃣1️⃣ بناء الاستجابة النهائية المحسّنة
    const response = {
      success: true,
      analysis_type: analysisType,
      generated_at: new Date().toISOString(),
      
      // معلومات الطفل والأخصائي
      profile: {
        child: {
          id: childData.child_id,
          name: childData.full_name,
          age: AnalysisService.calculateAge(child.date_of_birth),
          gender: childData.gender,
          diagnosis: childData.diagnosis?.name || 'Not specified',
          medical_history: childData.medical_history,
          institution: childData.current_institution?.name
        },
        specialist: {
          id: specialistInfo.specialist_id,
          name: specialistInfo.full_name,
          specialization: specialistInfo.specialization,
          experience_years: specialistInfo.years_experience
        },
        parent_contact: {
          name: childData.parent?.full_name,
          phone: childData.parent?.phone
        }
      },

      // ملخص الجلسات والتقييمات
      summary: {
        evaluations: {
          total: evaluations.length,
          first_date: new Date(evaluations[0].created_at).toLocaleDateString('en-US', { 
            year: 'numeric', month: 'long', day: 'numeric' 
          }),
          latest_date: new Date(evaluations[evaluations.length - 1].created_at).toLocaleDateString('en-US', { 
            year: 'numeric', month: 'long', day: 'numeric' 
          }),
          types_used: [...new Set(evaluations.map(e => e.evaluation_type))],
          duration_days: Math.round(
            (new Date(evaluations[evaluations.length - 1].created_at) - 
             new Date(evaluations[0].created_at)) / (1000 * 60 * 60 * 24)
          )
        },
        sessions: {
          total: sessions.length,
          completed: sessions.filter(s => s.status === 'Completed').length,
          scheduled: sessions.filter(s => s.status === 'Scheduled').length,
          cancelled: sessions.filter(s => s.status === 'Cancelled').length,
          last_session_date: sessions[0]?.date ? new Date(sessions[0].date).toLocaleDateString('en-US', {
            year: 'numeric', month: 'long', day: 'numeric'
          }) : null
        }
      },

      // الإحصائيات المفصلة
      performance_metrics: evaluations.length > 1 ? {
        score_analysis: {
          current_score: statistics.latestScore,
          starting_score: statistics.firstScore,
          average_score: statistics.average,
          highest_score: statistics.maxScore,
          lowest_score: statistics.minScore,
          total_improvement: statistics.totalChange,
          improvement_percentage: parseFloat(((statistics.totalChange / statistics.firstScore) * 100).toFixed(2))
        },
        statistical_indicators: {
          standard_deviation: {
            value: statistics.standardDeviation,
            interpretation: statistics.standardDeviation < 5 ? 'Very Consistent' : 
                           statistics.standardDeviation < 10 ? 'Consistent' : 
                           statistics.standardDeviation < 15 ? 'Moderately Variable' : 'Highly Variable'
          },
          coefficient_of_variation: {
            value: statistics.coefficientOfVariation,
            interpretation: statistics.coefficientOfVariation < 15 ? 'Low Variability' : 
                           statistics.coefficientOfVariation < 30 ? 'Moderate Variability' : 'High Variability'
          },
          r_squared: {
            value: statistics.rSquared,
            interpretation: statistics.rSquared > 0.9 ? 'Very Strong Trend' : 
                           statistics.rSquared > 0.7 ? 'Strong Trend' : 
                           statistics.rSquared > 0.5 ? 'Moderate Trend' : 'Weak Trend',
            confidence: statistics.rSquared > 0.9 ? 'High' : 
                       statistics.rSquared > 0.7 ? 'Good' : 'Low'
          },
          improvement_rate: {
            value: statistics.improvementRate,
            per_session: statistics.slope,
            interpretation: statistics.improvementRate > 50 ? 'Excellent Progress' : 
                           statistics.improvementRate > 25 ? 'Good Progress' : 
                           statistics.improvementRate > 0 ? 'Slow Progress' : 'Declining'
          }
        },
        trend_analysis: {
          overall_direction: statistics.slope > 5 ? 'Strong Upward' : 
                            statistics.slope > 2 ? 'Moderate Upward' : 
                            statistics.slope > 0 ? 'Slight Upward' : 
                            statistics.slope < -2 ? 'Downward' : 'Stable',
          consistency: trends.isConsistent ? 'Stable Performance' : 'Variable Performance',
          plateau_status: trends.isPlateau ? 'Plateau Detected - Adjustment Needed' : 'Active Progress',
          recent_performance: {
            scores: trends.recentPerformance,
            trend: trends.recentPerformance[trends.recentPerformance.length - 1] > 
                   trends.recentPerformance[0] ? 'Improving' : 'Declining'
          }
        },
        session_patterns: {
          average_interval_days: trends.averageSessionInterval,
          recommended_interval: trends.isPlateau ? 'Increase frequency' : 
                               statistics.slope > 5 ? 'Current frequency working well' : 
                               'Consider adjusting frequency'
        }
      } : {
        note: 'Statistical analysis requires at least 2 evaluations',
        current_score: parseFloat(evaluations[0].progress_score)
      },

      // التحليل الاحترافي من AI (منظم)
      professional_analysis: aiAnalysis,

      // خطة العمل والتوصيات
      "action_plan": {
    "quick_recommendations": evaluations.length > 1 ? [
      statistics.slope > 5 ? '✅ Maintain current approach - excellent progress' : 
      statistics.slope > 0 ? '⚠️ Progress is slow - consider intensifying sessions' : 
      '❌ Progress declining - immediate intervention needed',
      
      trends.isPlateau ? '⚠️ Plateau detected - modify treatment strategy' : 
      '✅ No plateau - continue with current plan',
      
      statistics.coefficientOfVariation > 30 ? '⚠️ High variability - identify and control factors' : 
      '✅ Performance is consistent'
    ] : [
      '📋 Initial plan created - follow recommended schedule',
      '📅 Schedule next evaluation as recommended',
      '👨‍👩‍👧 Engage parents in home activities'
    ]
  },

      // سجل التقييمات الكامل
      evaluation_history: evaluations.map((e, idx) => ({
        session_number: idx + 1,
        date: new Date(e.created_at).toLocaleDateString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric'
        }),
        type: e.evaluation_type,
        score: parseFloat(e.progress_score),
        score_change: idx > 0 ? parseFloat((parseFloat(e.progress_score) - parseFloat(evaluations[idx - 1].progress_score)).toFixed(2)) : 0,
        notes: e.notes,
        days_since_last: idx > 0 ? Math.round(
          (new Date(e.created_at) - new Date(evaluations[idx - 1].created_at)) / (1000 * 60 * 60 * 24)
        ) : 0
      })),

      // معلومات النظام
      metadata: {
        analysis_model: 'Groq Llama 3.1 8B Instant',
        analysis_date: new Date().toLocaleDateString('en-US', {
          year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit'
        }),
        data_quality: {
          evaluations_count: evaluations.length,
          sufficient_data: evaluations.length >= 3,
          recommendation: evaluations.length < 3 ? 'More data needed for comprehensive analysis' : 'Sufficient data for reliable analysis'
        }
      }
    };

    res.json(response);

  } catch (error) {
    console.error('Progress Analysis Error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to analyze child progress',
      error: error.message 
    });
  }
};

/**
 * تحليل سريع (بدون AI) - للإحصائيات فقط
 * GET /api/specialist/children/:childId/quick-stats
 */
const getQuickStatistics = async (req, res) => {
  try {
    const { childId } = req.params;
    const specialistId = req.user.user_id;

    // التحقق من الصلاحيات
    const hasAccess = await Session.findOne({
      where: { specialist_id: specialistId, child_id: childId }
    });

    if (!hasAccess) {
      return res.status(403).json({ 
        success: false, 
        message: 'No access to this child' 
      });
    }

    // جلب التقييمات
    const evaluations = await Evaluation.findAll({
      where: { child_id: childId, specialist_id: specialistId },
      order: [['created_at', 'ASC']]
    });

    if (evaluations.length === 0) {
      return res.status(400).json({ 
        success: false, 
        message: 'No evaluations found' 
      });
    }

    const scores = evaluations.map(e => parseFloat(e.progress_score));
    const statistics = AnalysisService.calculateStatistics(scores);
    const trends = AnalysisService.analyzeTrends(evaluations);

    res.json({
      success: true,
      child_id: childId,
      statistics,
      trends,
      evaluation_count: evaluations.length,
      latest_score: scores[scores.length - 1]
    });

  } catch (error) {
    console.error('Quick Stats Error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to calculate statistics',
      error: error.message 
    });
  }
};

/**
 * Compare progress between two specific dates
 * GET /api/specialist/children/:childId/compare-dates
 */
/**
 * Compare progress between two specific dates (ONLY evaluations on these exact dates)
 * GET /api/specialist/children/:childId/compare-dates
 */
const compareDateRangeProgress = async (req, res) => {
  try {
    const { childId } = req.params;
    const specialistId = req.user.user_id;
    const { startDate, endDate } = req.query;

    // Validate dates
    if (!startDate || !endDate) {
      return res.status(400).json({
        success: false,
        message: 'Both startDate and endDate are required (YYYY-MM-DD format)'
      });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);
    
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'Invalid date format. Use YYYY-MM-DD'
      });
    }

    if (start >= end) {
      return res.status(400).json({
        success: false,
        message: 'startDate must be before endDate'
      });
    }

    // Verify specialist access
    const hasAccess = await Session.findOne({
      where: { specialist_id: specialistId, child_id: childId }
    });

    if (!hasAccess) {
      return res.status(403).json({
        success: false,
        message: 'No access to this child\'s records'
      });
    }

    // Get child info
    const child = await Child.findOne({
      where: { child_id: childId },
      include: [
        {
          model: Parent,
          include: [{
            model: User,
            attributes: ['full_name']
          }]
        },
        {
          model: Diagnosis,
          as: 'Diagnosis',
          attributes: ['name']
        }
      ]
    });

    if (!child) {
      return res.status(404).json({
        success: false,
        message: 'Child not found'
      });
    }

    // 🔥 التغيير الرئيسي: جلب التقييمات في التاريخين المحددين فقط
    const startEvaluation = await Evaluation.findOne({
      where: {
        child_id: childId,
        specialist_id: specialistId,
        created_at: {
          [Op.between]: [
            new Date(startDate + 'T00:00:00.000Z'),
            new Date(startDate + 'T23:59:59.999Z')
          ]
        }
      },
      order: [['created_at', 'DESC']] // إذا كان هناك أكثر من تقييم في نفس اليوم، نأخذ الأخير
    });

    const endEvaluation = await Evaluation.findOne({
      where: {
        child_id: childId,
        specialist_id: specialistId,
        created_at: {
          [Op.between]: [
            new Date(endDate + 'T00:00:00.000Z'),
            new Date(endDate + 'T23:59:59.999Z')
          ]
        }
      },
      order: [['created_at', 'DESC']] // إذا كان هناك أكثر من تقييم في نفس اليوم، نأخذ الأخير
    });

    // التحقق من وجود التقييمين
    if (!startEvaluation || !endEvaluation) {
      const missingDates = [];
      if (!startEvaluation) missingDates.push(`start date (${startDate})`);
      if (!endEvaluation) missingDates.push(`end date (${endDate})`);
      
      return res.status(400).json({
        success: false,
        message: `No evaluations found on ${missingDates.join(' and ')}. Please ensure evaluations exist on both selected dates.`
      });
    }

    // إنشاء مصفوفة تحتوي على التقييمين فقط
    const evaluations = [startEvaluation, endEvaluation];

    // 🔥 التغيير: جلب الجلسات في التاريخين المحددين فقط
    const sessions = await Session.findAll({
      where: {
        child_id: childId,
        specialist_id: specialistId,
        date: {
          [Op.in]: [startDate, endDate]
        }
      },
      attributes: ['session_id', 'date', 'status', 'session_type']
    });

    // حساب المقارنة بين التقييمين فقط
    const comparisonStats = AnalysisService.calculateDirectComparison(
      startEvaluation,
      endEvaluation,
      start,
      end
    );

    // توليد تحليل AI للمقارنة المباشرة
    const aiComparison = await AnalysisService.generateDirectComparisonAnalysis(
      child,
      startEvaluation,
      endEvaluation,
      start,
      end,
      comparisonStats
    );

    // بناء الاستجابة
    const response = {
      success: true,
      comparison_type: 'direct_date_comparison',
      date_range: {
        start_date: startDate,
        end_date: endDate,
        total_days: Math.round((end - start) / (1000 * 60 * 60 * 24)),
        note: 'Comparing only evaluations on the exact selected dates'
      },
      child_info: {
        id: child.child_id,
        name: child.full_name,
        diagnosis: child.Diagnosis?.name,
        parent_name: child.Parent?.User?.full_name
      },
      summary: {
        total_evaluations_compared: 2,
        total_sessions_on_dates: sessions.length,
        completed_sessions: sessions.filter(s => s.status === 'Completed').length,
        comparison_period: `${comparisonStats.daysBetween} days between evaluations`
      },
      direct_comparison: {
        starting_point: {
          date: startEvaluation.created_at,
          score: parseFloat(startEvaluation.progress_score),
          evaluation_type: startEvaluation.evaluation_type,
          notes: startEvaluation.notes
        },
        ending_point: {
          date: endEvaluation.created_at,
          score: parseFloat(endEvaluation.progress_score),
          evaluation_type: endEvaluation.evaluation_type,
          notes: endEvaluation.notes
        },
        improvement: {
          score_change: comparisonStats.scoreChange,
          percentage_change: comparisonStats.percentageChange,
          daily_improvement_rate: comparisonStats.dailyImprovementRate,
          trend: comparisonStats.trend,
          magnitude: comparisonStats.magnitude
        }
      },
      performance_analysis: {
        progress_summary: comparisonStats.progressSummary,
        key_differences: comparisonStats.keyDifferences,
        consistency_analysis: comparisonStats.consistencyAnalysis
      },
      session_analysis: {
        sessions_on_start_date: sessions.filter(s => s.date.toISOString().split('T')[0] === startDate),
        sessions_on_end_date: sessions.filter(s => s.date.toISOString().split('T')[0] === endDate),
        recommendations: comparisonStats.recommendations
      },
      ai_direct_comparison: aiComparison,
      metadata: {
        analysis_generated: new Date().toISOString(),
        comparison_method: 'Direct comparison of evaluations on exact dates',
        data_quality: 'High - exact date matching'
      }
    };

    res.json(response);

  } catch (error) {
    console.error('Direct Date Comparison Error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to compare dates directly',
      error: error.message
    });
  }
};

/**
 * Analyze progress for a specific period (last month, week, 3 months, etc.)
 * GET /api/specialist/children/:childId/period-analysis
 */
const analyzePeriodProgress = async (req, res) => {
  try {
    const { childId } = req.params;
    const specialistId = req.user.user_id;
    const { period } = req.query; // 'last_week', 'last_month', 'last_3_months', 'custom'

    const validPeriods = ['last_week', 'last_month', 'last_3_months', 'last_6_months'];
    
    if (!validPeriods.includes(period)) {
      return res.status(400).json({
        success: false,
        message: `Invalid period. Use one of: ${validPeriods.join(', ')}`
      });
    }

    // Calculate date range based on period
    const endDate = new Date();
    const startDate = new Date();

    switch (period) {
      case 'last_week':
        startDate.setDate(endDate.getDate() - 7);
        break;
      case 'last_month':
        startDate.setMonth(endDate.getMonth() - 1);
        break;
      case 'last_3_months':
        startDate.setMonth(endDate.getMonth() - 3);
        break;
      case 'last_6_months':
        startDate.setMonth(endDate.getMonth() - 6);
        break;
    }

    // Verify specialist access
    const hasAccess = await Session.findOne({
      where: { specialist_id: specialistId, child_id: childId }
    });

    if (!hasAccess) {
      return res.status(403).json({
        success: false,
        message: 'No access to this child\'s records'
      });
    }

    // Get child info
    const child = await Child.findOne({
      where: { child_id: childId },
      include: [
        {
          model: Diagnosis,
          as: 'Diagnosis',
          attributes: ['name']
        }
      ]
    });

    if (!child) {
      return res.status(404).json({
        success: false,
        message: 'Child not found'
      });
    }

    // Get evaluations for the period
    const evaluations = await Evaluation.findAll({
      where: {
        child_id: childId,
        specialist_id: specialistId,
        created_at: {
          [Op.between]: [startDate, endDate]
        }
      },
      order: [['created_at', 'ASC']]
    });

    if (evaluations.length === 0) {
      return res.status(400).json({
        success: false,
        message: `No evaluations found for the ${period.replace('_', ' ')}`
      });
    }

    // Get sessions for the period
    const sessions = await Session.findAll({
      where: {
        child_id: childId,
        specialist_id: specialistId,
        date: {
          [Op.between]: [startDate, endDate]
        }
      }
    });

    // Calculate period-specific analysis
    const periodAnalysis = AnalysisService.calculatePeriodAnalysis(
      evaluations,
      sessions,
      period,
      startDate,
      endDate
    );

    // Generate AI analysis for the period
    const aiAnalysis = await AnalysisService.generatePeriodAnalysis(
      child,
      evaluations,
      sessions,
      period,
      periodAnalysis
    );

    const response = {
      success: true,
      analysis_type: 'period_analysis',
      period: {
        type: period,
        start_date: startDate.toISOString().split('T')[0],
        end_date: endDate.toISOString().split('T')[0],
        total_days: Math.round((endDate - startDate) / (1000 * 60 * 60 * 24))
      },
      child_info: {
        id: child.child_id,
        name: child.full_name,
        diagnosis: child.Diagnosis?.name
      },
      overview: {
        total_evaluations: evaluations.length,
        total_sessions: sessions.length,
        evaluation_frequency: periodAnalysis.evaluationFrequency,
        average_score: periodAnalysis.averageScore
      },
      progress_summary: {
        starting_score: periodAnalysis.startingScore,
        ending_score: periodAnalysis.endingScore,
        net_change: periodAnalysis.netChange,
        progress_trend: periodAnalysis.progressTrend,
        consistency_level: periodAnalysis.consistencyLevel
      },
      performance_insights: {
        strongest_period: periodAnalysis.strongestPeriod,
        challenging_period: periodAnalysis.challengingPeriod,
        improvement_rate: periodAnalysis.improvementRate,
        session_effectiveness: periodAnalysis.sessionEffectiveness
      },
      recommendations: {
        schedule_adjustments: periodAnalysis.scheduleAdjustments,
        focus_areas: periodAnalysis.focusAreas,
        intensity_recommendations: periodAnalysis.intensityRecommendations
      },
      ai_period_analysis: aiAnalysis,
      detailed_breakdown: {
        evaluations_by_week: periodAnalysis.evaluationsByWeek,
        average_scores_per_week: periodAnalysis.averageScoresPerWeek,
        session_completion_rates: periodAnalysis.sessionCompletionRates
      }
    };

    res.json(response);

  } catch (error) {
    console.error('Period Analysis Error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to analyze period progress',
      error: error.message
    });
  }
};

module.exports = {
  analyzeChildProgress,
  getQuickStatistics,
  compareDateRangeProgress,
  analyzePeriodProgress
};