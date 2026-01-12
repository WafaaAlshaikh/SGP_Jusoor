const sequelize = require('../config/db');
const { Op, Sequelize } = require('sequelize');
const Invoice = require('../model/Invoice');
const Payment = require('../model/Payment');
const Donation = require('../model/Donation');
const DonationAllocation = require('../model/DonationAllocation');
const DonationCampaign = require('../model/DonationCampaign');
const FinancialAssistanceRequest = require('../model/FinancialAssistanceRequest');
const Session = require('../model/Session');
const SessionType = require('../model/SessionType');
const Child = require('../model/Child');
const Institution = require('../model/Institution');
const Manager = require('../model/Manager');
const Parent = require('../model/Parent');
const Specialist = require('../model/Specialist');
const User = require('../model/User');



exports.getMonthlyFinancialReport = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { year, month } = req.query;

    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true },
      include: [{ model: Institution }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'المدير أو المؤسسة غير موجودة'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const targetYear = parseInt(year) || new Date().getFullYear();
    const targetMonth = parseInt(month) || new Date().getMonth() + 1;

    const periodStart = new Date(targetYear, targetMonth - 1, 1);
    const periodEnd = new Date(targetYear, targetMonth, 0, 23, 59, 59);
    const previousMonthStart = new Date(targetYear, targetMonth - 2, 1);
    const previousMonthEnd = new Date(targetYear, targetMonth - 1, 0, 23, 59, 59);

    const revenueData = await getRevenueData(institutionId, periodStart, periodEnd, previousMonthStart, previousMonthEnd);

    const donationData = await getDonationData(institutionId, periodStart, periodEnd, previousMonthStart, previousMonthEnd);

    const financialAssistanceData = await getFinancialAssistanceData(institutionId, periodStart, periodEnd);

    const sessionsData = await getSessionsData(institutionId, periodStart, periodEnd);

    const receivablesData = await getReceivablesData(institutionId, periodStart, periodEnd);

    const expensesData = await getExpensesData(institutionId, periodStart, periodEnd);

    const performanceSummary = calculatePerformanceSummary(
      revenueData,
      donationData,
      financialAssistanceData,
      sessionsData,
      receivablesData,
      expensesData
    );

    const monthlyComparison = await getMonthlyComparison(
      institutionId,
      periodStart,
      periodEnd,
      previousMonthStart,
      previousMonthEnd
    );

    const nextMonthProjections = await getNextMonthProjections(
      institutionId,
      targetYear,
      targetMonth + 1
    );

    return res.status(200).json({
      success: true,
      data: {
        period: {
          month: targetMonth,
          year: targetYear,
          start: periodStart.toISOString().split('T')[0],
          end: periodEnd.toISOString().split('T')[0]
        },
        institution: {
          id: institutionId,
          name: manager.Institution.name
        },
        revenue: revenueData,
        donations: donationData,
        financial_assistance: financialAssistanceData,
        sessions: sessionsData,
        receivables: receivablesData,
        expenses: expensesData,
        performance_summary: performanceSummary,
        monthly_comparison: monthlyComparison,
        projections: nextMonthProjections
      }
    });

  } catch (error) {
    console.error('Error in getMonthlyFinancialReport:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في إنشاء تقرير مالي شهري',
      error: error.message
    });
  }
};


exports.getAdvancedFinancialReportV2 = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { start_date, end_date, year, month, limit_invoices, limit_specialists } = req.query;

    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true },
      include: [{ model: Institution }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'المدير أو المؤسسة غير موجودة'
      });
    }

    const institutionId = manager.Institution.institution_id;

    let periodStart;
    let periodEnd;

    if (start_date || end_date) {
      periodStart = start_date ? new Date(start_date) : new Date();
      periodStart.setHours(0, 0, 0, 0);
      periodEnd = end_date ? new Date(end_date) : new Date();
      periodEnd.setHours(23, 59, 59, 999);
    } else {
      const y = parseInt(year) || new Date().getFullYear();
      const m = parseInt(month);
      if (m && m >= 1 && m <= 12) {
        periodStart = new Date(y, m - 1, 1);
        periodEnd = new Date(y, m, 0, 23, 59, 59);
      } else {
        periodStart = new Date(y, 0, 1);
        periodEnd = new Date(y, 11, 31, 23, 59, 59);
      }
    }

    const invoiceLimit = Math.min(parseInt(limit_invoices || 50) || 50, 200);
    const specialistsLimit = Math.min(parseInt(limit_specialists || 10) || 10, 50);

    const paidInvoicesAgg = await Invoice.findOne({
      where: {
        institution_id: institutionId,
        status: 'Paid',
        paid_date: { [Op.between]: [periodStart, periodEnd] }
      },
      attributes: [
        [Sequelize.fn('COUNT', Sequelize.col('invoice_id')), 'count'],
        [Sequelize.fn('SUM', Sequelize.col('total_amount')), 'total_paid']
      ],
      raw: true
    });

    const totalPaidInvoices = parseInt(paidInvoicesAgg?.count || 0);
    const paidInvoicesRevenue = parseFloat(paidInvoicesAgg?.total_paid || 0);

    const totalDonationsRaw = await Donation.sum('amount', {
      where: {
        institution_id: institutionId,
        date: { [Op.between]: [periodStart, periodEnd] }
      }
    });
    const donationsRevenue = parseFloat(totalDonationsRaw || 0);

    const staffExpenses = parseFloat(
      (await Specialist.sum('salary', {
        where: {
          institution_id: institutionId,
          approval_status: 'Approved'
        }
      })) || 0
    );

    const donationAllocationsRaw = await DonationAllocation.sum('amount_allocated', {
      where: {
        institution_id: institutionId,
        created_at: { [Op.between]: [periodStart, periodEnd] }
      }
    });
    const donationAllocations = parseFloat(donationAllocationsRaw || 0);

    const totalRevenue = paidInvoicesRevenue + donationsRevenue;
    const totalExpenses = staffExpenses + donationAllocations;
    const netProfit = totalRevenue - totalExpenses;
    const profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0;

    const sessionsCompletedAgg = await Session.findOne({
      where: {
        institution_id: institutionId,
        status: 'Completed',
        date: { [Op.between]: [periodStart, periodEnd] }
      },
      attributes: [
        [Sequelize.fn('COUNT', Sequelize.col('session_id')), 'count'],
        [Sequelize.fn('AVG', Sequelize.col('final_price')), 'avg_price']
      ],
      raw: true
    });

    const sessionsCompleted = parseInt(sessionsCompletedAgg?.count || 0);
    const avgSessionPrice = parseFloat(sessionsCompletedAgg?.avg_price || 0);

    const activeDonorsRow = await sequelize.query(`
      SELECT COUNT(DISTINCT donor_id) as active_donors
      FROM Donations
      WHERE institution_id = ?
        AND date BETWEEN ? AND ?
    `, {
      replacements: [institutionId, periodStart, periodEnd],
      type: Sequelize.QueryTypes.SELECT
    });

    const activeDonors = parseInt(activeDonorsRow?.[0]?.active_donors || 0);

    const receivables = await getReceivablesData(institutionId, periodStart, periodEnd);
    const donationUtilization = await calculateDonationUtilization(institutionId);
    const healthScore = calculateFinancialHealthScore(netProfit, profitMargin, receivables.total_receivables, sessionsCompleted > 0 ? 100 : 0);

    const monthlyPerformance = await sequelize.query(`
      SELECT
        DATE_FORMAT(m.month_start, '%Y-%m') as month,
        COALESCE(inv.paid_invoices_revenue, 0) as invoice_revenue,
        COALESCE(don.donations_revenue, 0) as donation_revenue,
        (COALESCE(inv.paid_invoices_revenue, 0) + COALESCE(don.donations_revenue, 0)) as total_revenue,
        ? as staff_expenses,
        COALESCE(alloc.allocations_expenses, 0) as allocations_expenses,
        (? + COALESCE(alloc.allocations_expenses, 0)) as total_expenses,
        ((COALESCE(inv.paid_invoices_revenue, 0) + COALESCE(don.donations_revenue, 0)) - (? + COALESCE(alloc.allocations_expenses, 0))) as net_profit
      FROM (
        SELECT DATE_ADD(DATE(?), INTERVAL seq MONTH) as month_start
        FROM (
          SELECT 0 as seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
          UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
        ) s
      ) m
      LEFT JOIN (
        SELECT DATE_FORMAT(paid_date, '%Y-%m-01') as month_key,
               SUM(total_amount) as paid_invoices_revenue
        FROM Invoices
        WHERE institution_id = ?
          AND status = 'Paid'
          AND paid_date BETWEEN ? AND ?
        GROUP BY DATE_FORMAT(paid_date, '%Y-%m-01')
      ) inv ON inv.month_key = DATE_FORMAT(m.month_start, '%Y-%m-01')
      LEFT JOIN (
        SELECT DATE_FORMAT(date, '%Y-%m-01') as month_key,
               SUM(amount) as donations_revenue
        FROM Donations
        WHERE institution_id = ?
          AND date BETWEEN ? AND ?
        GROUP BY DATE_FORMAT(date, '%Y-%m-01')
      ) don ON don.month_key = DATE_FORMAT(m.month_start, '%Y-%m-01')
      LEFT JOIN (
        SELECT DATE_FORMAT(created_at, '%Y-%m-01') as month_key,
               SUM(amount_allocated) as allocations_expenses
        FROM DonationAllocations
        WHERE institution_id = ?
          AND created_at BETWEEN ? AND ?
        GROUP BY DATE_FORMAT(created_at, '%Y-%m-01')
      ) alloc ON alloc.month_key = DATE_FORMAT(m.month_start, '%Y-%m-01')
      WHERE m.month_start BETWEEN DATE_FORMAT(?, '%Y-%m-01') AND DATE_FORMAT(?, '%Y-%m-01')
      ORDER BY m.month_start ASC
    `, {
      replacements: [
        staffExpenses,
        staffExpenses,
        staffExpenses,
        periodStart,
        institutionId, periodStart, periodEnd,
        institutionId, periodStart, periodEnd,
        institutionId, periodStart, periodEnd,
        periodStart, periodEnd
      ],
      type: Sequelize.QueryTypes.SELECT
    });

    const topSpecialists = await sequelize.query(`
      SELECT
        s.specialist_id as specialist_id,
        COALESCE(u.full_name, 'Unknown') as specialist_name,
        COUNT(i.invoice_id) as paid_invoices_count,
        SUM(i.total_amount) as paid_revenue
      FROM Invoices i
      INNER JOIN Sessions s ON s.session_id = i.session_id
      LEFT JOIN Users u ON u.user_id = s.specialist_id
      WHERE i.institution_id = ?
        AND i.status = 'Paid'
        AND i.paid_date BETWEEN ? AND ?
      GROUP BY s.specialist_id, u.full_name
      ORDER BY SUM(i.total_amount) DESC
      LIMIT ?
    `, {
      replacements: [institutionId, periodStart, periodEnd, specialistsLimit],
      type: Sequelize.QueryTypes.SELECT
    });

    const invoiceDetails = await Invoice.findAll({
      where: {
        institution_id: institutionId,
        issued_date: { [Op.between]: [periodStart, periodEnd] }
      },
      include: [
        {
          model: User,
          as: 'parent',
          attributes: ['user_id', 'full_name', 'email', 'phone'],
          required: false
        },
        {
          model: Session,
          attributes: ['session_id', 'date', 'status', 'final_price', 'specialist_id'],
          required: false,
          include: [
            {
              model: User,
              as: 'specialist',
              attributes: ['user_id', 'full_name', 'email', 'phone'],
              required: false
            },
            {
              model: SessionType,
              attributes: ['session_type_id', 'name'],
              required: false
            },
            {
              model: Child,
              as: 'child',
              attributes: ['child_id', 'full_name'],
              required: false
            }
          ]
        }
      ],
      attributes: [
        'invoice_id',
        'invoice_number',
        'amount',
        'tax_amount',
        'total_amount',
        'status',
        'issued_date',
        'due_date',
        'paid_date',
        'refund_amount',
        'refunded_at'
      ],
      order: [['issued_date', 'DESC']],
      limit: invoiceLimit
    });

    return res.status(200).json({
      success: true,
      data: {
        period: {
          start: periodStart.toISOString().split('T')[0],
          end: periodEnd.toISOString().split('T')[0]
        },
        institution: {
          id: institutionId,
          name: manager.Institution.name
        },
        kpis: {
          total_revenue: totalRevenue,
          total_expenses: totalExpenses,
          net_profit: netProfit,
          profit_margin: profitMargin
        },
        revenue_sources: {
          session_payments: {
            amount: paidInvoicesRevenue,
            count: totalPaidInvoices
          },
          donations: {
            amount: donationsRevenue
          }
        },
        expenses: {
          staff_salaries: staffExpenses,
          donation_allocations: donationAllocations,
          total: totalExpenses
        },
        monthly_performance: monthlyPerformance,
        top_specialists: topSpecialists.map((s) => ({
          specialist_id: parseInt(s.specialist_id),
          specialist_name: s.specialist_name,
          paid_invoices_count: parseInt(s.paid_invoices_count || 0),
          paid_revenue: parseFloat(s.paid_revenue || 0)
        })),
        invoices: {
          limit: invoiceLimit,
          list: invoiceDetails
        },
        financial_summary: {
          sessions_completed: sessionsCompleted,
          active_donors: activeDonors,
          avg_session_price: avgSessionPrice
        },
        financial_health: {
          receivables,
          donation_utilization: donationUtilization,
          score: healthScore
        }
      }
    });
  } catch (error) {
    console.error('Error in getAdvancedFinancialReportV2:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في إنشاء التقرير المالي الشامل',
      error: error.message
    });
  }
};

async function getReceivablesData(institutionId, startDate, endDate) {
  try {
    const pendingResult = await Invoice.findOne({
      where: {
        institution_id: institutionId,
        status: 'Pending',
        due_date: { [Op.between]: [startDate, endDate] }
      },
      attributes: [
        [Sequelize.fn('SUM', Sequelize.col('total_amount')), 'amount'],
        [Sequelize.fn('COUNT', Sequelize.col('invoice_id')), 'count']
      ],
      raw: true
    });

    const overdueResult = await Invoice.findOne({
      where: {
        institution_id: institutionId,
        status: 'Overdue'
      },
      attributes: [
        [Sequelize.fn('SUM', Sequelize.col('total_amount')), 'amount'],
        [Sequelize.fn('COUNT', Sequelize.col('invoice_id')), 'count']
      ],
      raw: true
    });

    const agingAnalysis = await sequelize.query(`
      SELECT 
        CASE
          WHEN status = 'Overdue' THEN 'Overdue'
          WHEN DATEDIFF(CURDATE(), due_date) <= 0 THEN 'Current'
          WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 1 AND 30 THEN '1-30'
          WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 31 AND 60 THEN '31-60'
          WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 61 AND 90 THEN '61-90'
          ELSE '90+'
        END as age_category,
        SUM(total_amount) as amount,
        COUNT(invoice_id) as count
      FROM Invoices
      WHERE institution_id = ?
        AND status IN ('Pending', 'Overdue')
      GROUP BY 
        CASE
          WHEN status = 'Overdue' THEN 'Overdue'
          WHEN DATEDIFF(CURDATE(), due_date) <= 0 THEN 'Current'
          WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 1 AND 30 THEN '1-30'
          WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 31 AND 60 THEN '31-60'
          WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 61 AND 90 THEN '61-90'
          ELSE '90+'
        END
    `, {
      replacements: [institutionId],
      type: Sequelize.QueryTypes.SELECT
    });

    const pendingAmount = parseFloat(pendingResult?.amount || 0);
    const overdueAmount = parseFloat(overdueResult?.amount || 0);
    const totalReceivables = pendingAmount + overdueAmount;

    return {
      pending: {
        amount: pendingAmount,
        count: parseInt(pendingResult?.count || 0)
      },
      overdue: {
        amount: overdueAmount,
        count: parseInt(overdueResult?.count || 0)
      },
      total_receivables: totalReceivables,
      aging_analysis: agingAnalysis
    };
  } catch (error) {
    console.error('Error in getReceivablesData:', error);
    return {
      pending: { amount: 0, count: 0 },
      overdue: { amount: 0, count: 0 },
      total_receivables: 0,
      aging_analysis: []
    };
  }
}

function calculateFinancialHealthScore(netProfit, profitMargin, totalReceivables, operationalIndicator) {
  try {
    let score = 50;

    const np = parseFloat(netProfit || 0);
    const pm = parseFloat(profitMargin || 0);
    const tr = parseFloat(totalReceivables || 0);
    const oi = parseFloat(operationalIndicator || 0);

    if (np > 0) score += 20;
    else if (np > -1000) score += 10;
    else score -= 10;

    if (pm >= 20) score += 15;
    else if (pm >= 10) score += 10;
    else if (pm >= 0) score += 5;
    else score -= 10;

    if (tr <= 0) score += 10;
    else if (tr <= 500) score += 5;
    else if (tr <= 2000) score -= 5;
    else score -= 10;

    if (oi >= 80) score += 5;
    else if (oi >= 50) score += 2;
    else if (oi > 0) score -= 2;

    if (score < 0) score = 0;
    if (score > 100) score = 100;
    return score;
  } catch (error) {
    console.error('Error in calculateFinancialHealthScore:', error);
    return 0;
  }
}

async function analyzeRealExpensesByMonth(institutionId, year) {
  const monthlyExpenses = [];
  
  for (let month = 0; month < 12; month++) {
    try {
      const monthStart = new Date(year, month, 1);
      const monthEnd = new Date(year, month + 1, 0, 23, 59, 59);

      const totalMonthlySalaries = await Specialist.sum('salary', {
        where: {
          institution_id: institutionId,
          approval_status: 'Approved'
        }
      }) || 0;

      const staffExpenses = parseFloat(totalMonthlySalaries);
      const specialProjects = await DonationAllocation.sum('amount_allocated', {
        where: {
          institution_id: institutionId,
          created_at: { [Op.between]: [monthStart, monthEnd] },
          donation_id: { [Op.not]: null }
        }
      }) || 0;

      monthlyExpenses.push({
        month: month + 1,
        staff_expenses: staffExpenses,
        operational_expenses: 0,
        special_projects: parseFloat(specialProjects),
        total_expenses: staffExpenses + parseFloat(specialProjects)
      });
    } catch (error) {
      console.error(`Error analyzing expenses for month ${month + 1}:`, error);
      monthlyExpenses.push({
        month: month + 1,
        staff_expenses: 0,
        operational_expenses: 0,
        special_projects: 0,
        total_expenses: 0
      });
    }
  }

  return monthlyExpenses;
}

function calculateRevenueGrowth(monthlyRevenue) {
  if (monthlyRevenue.length < 2) return 0;

  const currentMonth = monthlyRevenue[monthlyRevenue.length - 1];
  const previousMonth = monthlyRevenue[monthlyRevenue.length - 2];

  return previousMonth.total_revenue > 0 ?
    ((currentMonth.total_revenue - previousMonth.total_revenue) / previousMonth.total_revenue) * 100 : 0;
}

function projectNextYearPerformance(monthlyRevenue, monthlyExpenses) {
  const lastSixMonths = monthlyRevenue.slice(-6);
  const avgMonthlyRevenue = lastSixMonths.reduce((sum, m) => sum + m.total_revenue, 0) / 6;
  const avgMonthlyExpenses = monthlyExpenses.slice(-6).reduce((sum, e) => sum + (e?.total_expenses || 0), 0) / 6;

  const projectedMonths = [];
  for (let month = 1; month <= 12; month++) {
    const seasonalAdjustment = calculateSeasonalAdjustment(month);
    const projectedRevenue = avgMonthlyRevenue * seasonalAdjustment;
    const projectedExpenses = avgMonthlyExpenses * 1.05;
    const projectedProfit = projectedRevenue - projectedExpenses;

    projectedMonths.push({
      month,
      projected_revenue: projectedRevenue,
      projected_expenses: projectedExpenses,
      projected_profit: projectedProfit,
      projected_profit_margin: projectedRevenue > 0 ? (projectedProfit / projectedRevenue) * 100 : 0
    });
  }

  return {
    projected_annual_revenue: projectedMonths.reduce((sum, m) => sum + m.projected_revenue, 0),
    projected_annual_expenses: projectedMonths.reduce((sum, m) => sum + m.projected_expenses, 0),
    projected_annual_profit: projectedMonths.reduce((sum, m) => sum + m.projected_profit, 0),
    monthly_projections: projectedMonths
  };
}

function calculateSeasonalAdjustment(month) {
  const seasonalFactors = {
    1: 0.9,  2: 0.95, 3: 1.0,  4: 1.05,
    5: 1.1,  6: 1.0,  7: 0.95, 8: 0.9,
    9: 1.0,  10: 1.1, 11: 1.05, 12: 1.2
  };

  return seasonalFactors[month] || 1.0;
}

function generateFinancialRecommendations(kpis, profitMarginAnalysis) {
  const recommendations = [];

  if (kpis.average_monthly_profit_margin < 10) {
    recommendations.push({
      priority: 'high',
      category: 'profitability',
      action: 'increase_prices_or_reduce_costs',
      description: `هامش الربح الشهري المتوسط منخفض (${kpis.average_monthly_profit_margin.toFixed(1)}%). النظر في زيادة الأسعار أو تخفيض التكاليف.`
    });
  }

  const currentProfitMargin = profitMarginAnalysis[profitMarginAnalysis.length - 1]?.profit_margin || 0;
  if (currentProfitMargin < 0) {
    recommendations.push({
      priority: 'critical',
      category: 'profitability',
      action: 'immediate_cost_review',
      description: 'هامش الربح الحالي سالب. مراجعة فورية للتكاليف والنفقات.'
    });
  }

  if (kpis.revenue_growth < 5) {
    recommendations.push({
      priority: 'medium',
      category: 'growth',
      action: 'expand_services_or_marketing',
      description: `نمو الإيرادات منخفض (${kpis.revenue_growth.toFixed(1)}%). النظر في توسيع الخدمات أو زيادة التسويق.`
    });
  }

  const worstMonth = kpis.worst_month;
  if (worstMonth && worstMonth.total_revenue < (kpis.average_monthly_revenue * 0.5)) {
    recommendations.push({
      priority: 'medium',
      category: 'consistency',
      action: 'address_seasonal_dips',
      description: `شهر ${worstMonth.month} يشهد انخفاضاً حاداً في الإيرادات. معالجة الانخفاضات الموسمية.`
    });
  }

  return recommendations;
}

async function calculateRevenueTarget(institutionId, currentMonth) {
  try {
    const year = new Date().getFullYear();
    const startDate = new Date(year, 0, 1);
    const endDate = new Date(year, currentMonth - 1, 0, 23, 59, 59);

    const historicalRevenue = await Invoice.sum('total_amount', {
      where: {
        institution_id: institutionId,
        status: 'Paid',
        paid_date: { [Op.between]: [startDate, endDate] }
      }
    }) || 0;

    const monthsPassed = currentMonth;
    const averageMonthlyRevenue = historicalRevenue / Math.max(1, monthsPassed);

    return averageMonthlyRevenue * 1.1;
  } catch (error) {
    console.error('Error in calculateRevenueTarget:', error);
    return 0;
  }
}

async function calculateDonationUtilization(institutionId) {
  try {
    const totalDonations = await Donation.sum('amount', {
      where: { institution_id: institutionId }
    }) || 0;

    const totalAllocations = await DonationAllocation.sum('amount_allocated', {
      where: { institution_id: institutionId }
    }) || 0;

    return totalDonations > 0 ? (totalAllocations / totalDonations) * 100 : 0;
  } catch (error) {
    console.error('Error in calculateDonationUtilization:', error);
    return 0;
  }
}

async function calculateAssistanceApprovalRate(institutionId) {
  try {
    const totalRequests = await FinancialAssistanceRequest.count({
      where: { institution_id: institutionId }
    });

    const approvedRequests = await FinancialAssistanceRequest.count({
      where: { 
        institution_id: institutionId,
        status: 'approved'
      }
    });

    return totalRequests > 0 ? (approvedRequests / totalRequests) * 100 : 0;
  } catch (error) {
    console.error('Error in calculateAssistanceApprovalRate:', error);
    return 0;
  }
}

async function calculateCollectionEfficiency(institutionId) {
  try {
    const totalBilled = await Invoice.sum('total_amount', {
      where: { 
        institution_id: institutionId,
        status: ['Paid', 'Pending', 'Overdue']
      }
    }) || 0;

    const totalCollected = await Invoice.sum('total_amount', {
      where: { 
        institution_id: institutionId,
        status: 'Paid'
      }
    }) || 0;

    return totalBilled > 0 ? (totalCollected / totalBilled) * 100 : 100;
  } catch (error) {
    console.error('Error in calculateCollectionEfficiency:', error);
    return 0;
  }
}

function generateQuickFinancialActions(warnings, pendingAmount, overdueAmount) {
  const actions = [];

  if (warnings.high_overdue) {
    actions.push({
      action: 'follow_up_overdue',
      priority: 'high',
      description: `متابعة الفواتير المتأخرة (قيمة: $${overdueAmount.toFixed(2)})`,
      icon: '⏰'
    });
  }

  if (warnings.low_donation_balance) {
    actions.push({
      action: 'review_funding',
      priority: 'high',
      description: 'مراجعة مصادر التمويل والتبرعات',
      icon: '💰'
    });
  }

  if (warnings.high_assistance_requests) {
    actions.push({
      action: 'review_assistance_criteria',
      priority: 'medium',
      description: 'مراجعة معايير المساعدة المالية',
      icon: '📋'
    });
  }

  if (pendingAmount > 1000) {
    actions.push({
      action: 'send_payment_reminders',
      priority: 'medium',
      description: `إرسال تذكير بدفع الفواتير المستحقة (قيمة: $${pendingAmount.toFixed(2)})`,
      icon: '📧'
    });
  }

  return actions;
}

module.exports = exports;