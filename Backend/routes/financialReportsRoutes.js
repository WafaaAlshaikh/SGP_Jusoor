const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const financialReportsController = require('../controllers/financialReportsController');

// ==============================================
// 📊 التقارير المالية الشاملة (للمديرين فقط)
// ==============================================

// 📋 متطلبات المصادقة - المديرين فقط
const authorizeManager = (req, res, next) => {
  if (req.user.role !== 'Manager') {
    return res.status(403).json({
      success: false,
      message: 'غير مصرح. هذا المسار للمديرين فقط'
    });
  }
  next();
};

// ==============================================
// 📈 التقارير الأساسية
// ==============================================

// 📊 التقرير المالي الشهري الكامل
router.get('/monthly', authMiddleware, authorizeManager, financialReportsController.getMonthlyFinancialReport);

// 📊 تقرير تدفق الأموال (Financial Flow)
// router.get('/flow', authMiddleware, authorizeManager, financialReportsController.getFinancialFlowReport);

// 📊 الوضع المالي الحالي (Dashboard)
// router.get('/current-status', authMiddleware, authorizeManager, financialReportsController.getCurrentFinancialStatus);

// 📊 تقرير مالي متقدم (Revenue + Expenses + Donations)
// router.get('/advanced', authMiddleware, authorizeManager, financialReportsController.getAdvancedFinancialReport);

// 📊 تقرير مالي شامل (V2) - endpoint موحد للشاشة المتقدمة
router.get('/advanced-v2', authMiddleware, authorizeManager, financialReportsController.getAdvancedFinancialReportV2);

// 📊 تقرير مالي تفصيلي (Detailed Financial Report)
// router.get('/detailed', authMiddleware, authorizeManager, financialReportsController.getDetailedFinancialReport);

// 📊 نظرة عامة على المساعدات المالية للعائلات
// router.get('/family-assistance/overview', authMiddleware, authorizeManager, financialReportsController.getFamilyAssistanceOverview);

// ==============================================
// 📋 التقارير التفصيلية
// ==============================================

// 📊 تقرير تفصيلي عن المساعدات المالية
// router.get('/assistance-detailed', authMiddleware, authorizeManager, financialReportsController.getFinancialAssistanceDetailedReport);

// 📊 تقرير التبرعات والتمويل
// router.get('/donations-funding', authMiddleware, authorizeManager, financialReportsController.getDonationsAndFundingReport);

// 📊 تحليل الدخل والنفقات
// router.get('/income-expense', authMiddleware, authorizeManager, financialReportsController.getIncomeExpenseAnalysis);

// 📊 تقرير الفواتير والدفعات (Invoices & Payments)
// router.get('/invoices-payments', authMiddleware, authorizeManager, financialReportsController.getInvoicesPaymentsReport);

// ==============================================
// ⬇️ تصدير التقارير
// ==============================================

// 📥 تصدير التقرير بصيغة Excel
router.get('/export/excel', authMiddleware, authorizeManager, async (req, res) => {
  try {
    const FinancialReportService = require('../services/financialReportService');
    const { start_date, end_date } = req.query;
    
    // الحصول على institution_id من المدير
    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: req.user.user_id }
    });
    
    const service = new FinancialReportService(manager.institution_id);
    const excelBuffer = await service.generateExcelReport(
      new Date(start_date || new Date().setMonth(new Date().getMonth() - 1)),
      new Date(end_date || new Date())
    );
    
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=financial_report_${Date.now()}.xlsx`);
    res.send(excelBuffer);
  } catch (error) {
    console.error('Export error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في تصدير التقرير',
      error: error.message 
    });
  }
});

// 📥 تصدير التقرير بصيغة PDF
router.get('/export/pdf', authMiddleware, authorizeManager, async (req, res) => {
  try {
    const FinancialReportService = require('../services/financialReportService');
    const { start_date, end_date } = req.query;
    
    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: req.user.user_id }
    });
    
    const service = new FinancialReportService(manager.institution_id);
    const pdfHTML = await service.generatePDFReport(
      new Date(start_date || new Date().setMonth(new Date().getMonth() - 1)),
      new Date(end_date || new Date())
    );
    
    // هنا يمكنك استخدام مكتبة مثل puppeteer لتحويل HTML إلى PDF
    // حالياً نعيد HTML كمثال
    res.setHeader('Content-Type', 'text/html');
    res.send(pdfHTML);
  } catch (error) {
    console.error('PDF export error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في إنشاء PDF',
      error: error.message 
    });
  }
});

// ==============================================
// 🔔 التنبيهات المالية
// ==============================================

// ⚠️ الحصول على التنبيهات المالية
router.get('/alerts', authMiddleware, authorizeManager, async (req, res) => {
  try {
    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: req.user.user_id }
    });
    
    const FinancialReportService = require('../services/financialReportService');
    const service = new FinancialReportService(manager.institution_id);
    const alerts = await service.createFinancialAlerts();
    
    res.json({ 
      success: true, 
      data: alerts,
      count: alerts.length 
    });
  } catch (error) {
    console.error('Alerts error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في جلب التنبيهات',
      error: error.message 
    });
  }
});

// ==============================================
// 📧 إرسال التقارير بالبريد
// ==============================================

// 📨 إرسال التقرير بالبريد الإلكتروني
router.post('/send-email', authMiddleware, authorizeManager, async (req, res) => {
  try {
    const { email, format = 'pdf', start_date, end_date } = req.body;
    
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'البريد الإلكتروني مطلوب'
      });
    }
    
    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: req.user.user_id }
    });
    
    const FinancialReportService = require('../services/financialReportService');
    const service = new FinancialReportService(manager.institution_id);
    
    // الحصول على بيانات التقرير
    const reportData = await service.getReportData(
      new Date(start_date || new Date().setMonth(new Date().getMonth() - 1)),
      new Date(end_date || new Date())
    );
    
    // إرسال التقرير
    const result = await service.sendReportByEmail(email, reportData, format);
    
    res.json({
      success: true,
      message: 'تم إرسال التقرير بنجاح',
      data: result
    });
  } catch (error) {
    console.error('Email send error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في إرسال التقرير',
      error: error.message 
    });
  }
});

// ==============================================
//🔧 إحصائيات سريعة
// ==============================================

// 📊 إحصائيات سريعة للوحة التحكم
router.get('/quick-stats', authMiddleware, authorizeManager, async (req, res) => {
  try {
    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: req.user.user_id }
    });
    
    const today = new Date();
    const currentMonthStart = new Date(today.getFullYear(), today.getMonth(), 1);
    const currentMonthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0, 23, 59, 59);
    
    // استيراد النماذج المطلوبة
    const Invoice = require('../model/Invoice');
    const Donation = require('../model/Donation');
    const FinancialAssistanceRequest = require('../model/FinancialAssistanceRequest');
    const Session = require('../model/Session');
    
    // جلب البيانات المتعددة بالتوازي
    const [
      monthRevenue,
      monthDonations,
      activeAssistanceRequests,
      upcomingSessions,
      pendingInvoices,
      overdueInvoices
    ] = await Promise.all([
      // الإيرادات الشهرية
      Invoice.sum('total_amount', {
        where: {
          institution_id: manager.institution_id,
          status: 'Paid',
          paid_date: {
            [require('sequelize').Op.between]: [currentMonthStart, currentMonthEnd]
          }
        }
      }) || 0,
      
      // التبرعات الشهرية
      Donation.sum('amount', {
        where: {
          institution_id: manager.institution_id,
          date: {
            [require('sequelize').Op.between]: [currentMonthStart, currentMonthEnd]
          }
        }
      }) || 0,
      
      // طلبات المساعدة النشطة
      FinancialAssistanceRequest.count({
        where: {
          institution_id: manager.institution_id,
          status: {
            [require('sequelize').Op.in]: ['submitted', 'under_review', 'pending_documents']
          }
        }
      }),
      
      // الجلسات القادمة
      Session.count({
        where: {
          institution_id: manager.institution_id,
          date: { [require('sequelize').Op.gte]: today },
          status: {
            [require('sequelize').Op.in]: ['Scheduled', 'Confirmed', 'Pending Payment']
          }
        }
      }),
      
      // الفواتير المستحقة
      Invoice.sum('total_amount', {
        where: {
          institution_id: manager.institution_id,
          status: 'Pending',
          due_date: {
            [require('sequelize').Op.lte]: currentMonthEnd
          }
        }
      }) || 0,
      
      // الفواتير المتأخرة
      Invoice.sum('total_amount', {
        where: {
          institution_id: manager.institution_id,
          status: 'Overdue'
        }
      }) || 0
    ]);
    
    res.json({
      success: true,
      data: {
        current_month: {
          revenue: parseFloat(monthRevenue),
          donations: parseFloat(monthDonations),
          total: parseFloat(monthRevenue) + parseFloat(monthDonations)
        },
        operations: {
          active_assistance_requests: activeAssistanceRequests,
          upcoming_sessions: upcomingSessions
        },
        receivables: {
          pending: parseFloat(pendingInvoices),
          overdue: parseFloat(overdueInvoices),
          total: parseFloat(pendingInvoices) + parseFloat(overdueInvoices)
        },
        period: {
          start: currentMonthStart.toISOString().split('T')[0],
          end: currentMonthEnd.toISOString().split('T')[0]
        }
      }
    });
    
  } catch (error) {
    console.error('Quick stats error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في جلب الإحصائيات السريعة',
      error: error.message 
    });
  }
});

// ==============================================
// 📱 تقارير الجوال
// ==============================================

// 📱 تقرير مبسط للجوال
router.get('/mobile-summary', authMiddleware, authorizeManager, async (req, res) => {
  try {
    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: req.user.user_id },
      include: [{
        model: require('../model/Institution'),
        attributes: ['name', 'donation_balance']
      }]
    });
    
    const today = new Date();
    const weekStart = new Date(today);
    weekStart.setDate(weekStart.getDate() - 7);
    
    // بيانات الأسبوع
    const weekRevenue = await require('../model/Invoice').sum('total_amount', {
      where: {
        institution_id: manager.institution_id,
        status: 'Paid',
        paid_date: {
          [require('sequelize').Op.between]: [weekStart, today]
        }
      }
    }) || 0;
    
    const weekDonations = await require('../model/Donation').sum('amount', {
      where: {
        institution_id: manager.institution_id,
        date: {
          [require('sequelize').Op.between]: [weekStart, today]
        }
      }
    }) || 0;
    
    res.json({
      success: true,
      data: {
        institution: {
          name: manager.Institution.name,
          donation_balance: parseFloat(manager.Institution.donation_balance || 0)
        },
        weekly_summary: {
          revenue: parseFloat(weekRevenue),
          donations: parseFloat(weekDonations),
          total: parseFloat(weekRevenue) + parseFloat(weekDonations)
        },
        snapshot_time: new Date().toISOString(),
        quick_links: [
          { title: 'التقرير الشهري', endpoint: '/financial-reports/monthly' },
          { title: 'المساعدات المالية', endpoint: '/financial-reports/assistance-detailed' },
          { title: 'التبرعات', endpoint: '/financial-reports/donations-funding' },
          { title: 'الجلسات', endpoint: '/financial-reports/sessions' }
        ]
      }
    });
    
  } catch (error) {
    console.error('Mobile summary error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في جلب التقرير المبسط',
      error: error.message 
    });
  }
});

// ==============================================
// 🔧 مسارات إضافية
// ==============================================

// 🔍 البحث في التقارير
router.get('/search', authMiddleware, authorizeManager, async (req, res) => {
  try {
    const { query, type, date_range } = req.query;
    
    // يمكن تنفيذ البحث المتقدم هنا
    res.status(200).json({
      success: true,
      message: 'بحث التقارير',
      feature: 'under_development',
      parameters: {
        query,
        type,
        date_range
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'خطأ في البحث',
      error: error.message
    });
  }
});

// 📅 الجدول الزمني المالي
router.get('/timeline', authMiddleware, authorizeManager, async (req, res) => {
  try {
    const { months = 6 } = req.query;
    
    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: req.user.user_id }
    });
    
    const endDate = new Date();
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - parseInt(months));
    
    // جلب البيانات التاريخية
    const Invoice = require('../model/Invoice');
    const Donation = require('../model/Donation');
    
    const monthlyData = [];
    
    for (let i = 0; i < parseInt(months); i++) {
      const monthStart = new Date(startDate.getFullYear(), startDate.getMonth() + i, 1);
      const monthEnd = new Date(startDate.getFullYear(), startDate.getMonth() + i + 1, 0, 23, 59, 59);
      
      const [revenue, donations] = await Promise.all([
        Invoice.sum('total_amount', {
          where: {
            institution_id: manager.institution_id,
            status: 'Paid',
            paid_date: { [require('sequelize').Op.between]: [monthStart, monthEnd] }
          }
        }) || 0,
        
        Donation.sum('amount', {
          where: {
            institution_id: manager.institution_id,
            date: { [require('sequelize').Op.between]: [monthStart, monthEnd] }
          }
        }) || 0
      ]);
      
      monthlyData.push({
        month: `${monthStart.getFullYear()}-${(monthStart.getMonth() + 1).toString().padStart(2, '0')}`,
        revenue: parseFloat(revenue),
        donations: parseFloat(donations),
        total: parseFloat(revenue) + parseFloat(donations)
      });
    }
    
    res.json({
      success: true,
      data: {
        timeline: monthlyData,
        period: {
          start: startDate.toISOString().split('T')[0],
          end: endDate.toISOString().split('T')[0],
          months: parseInt(months)
        },
        trends: calculateTimelineTrends(monthlyData)
      }
    });
    
  } catch (error) {
    console.error('Timeline error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في جلب الجدول الزمني',
      error: error.message 
    });
  }
});

// ==============================================
// ==============================================

function calculateTimelineTrends(monthlyData) {
  if (monthlyData.length < 2) {
    return { trend: 'insufficient_data' };
  }
  
  const recentMonths = monthlyData.slice(-3);
  const previousMonths = monthlyData.slice(-6, -3);
  
  const recentAvg = recentMonths.reduce((sum, m) => sum + m.total, 0) / recentMonths.length;
  const previousAvg = previousMonths.reduce((sum, m) => sum + m.total, 0) / previousMonths.length;
  
  const growthRate = previousAvg > 0 ? 
    ((recentAvg - previousAvg) / previousAvg) * 100 : 0;
  
  const volatility = calculateVolatility(monthlyData.map(m => m.total));
  
  return {
    average_growth_rate: growthRate,
    volatility: volatility,
    trend: growthRate > 10 ? 'strong_growth' :
           growthRate > 0 ? 'moderate_growth' :
           growthRate > -10 ? 'stable' : 'declining',
    current_trajectory: growthRate > 5 ? 'positive' : 
                       growthRate > -5 ? 'neutral' : 'negative'
  };
}

function calculateVolatility(data) {
  if (data.length < 2) return 0;
  
  const mean = data.reduce((sum, val) => sum + val, 0) / data.length;
  const variance = data.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / data.length;
  
  return Math.sqrt(variance) / Math.abs(mean) || 0;
}

// ==============================================
//📋 حالة النظام
// ==============================================

// 🩺 فحص صحة البيانات المالية
router.get('/health-check', authMiddleware, authorizeManager, async (req, res) => {
  try {
    const Manager = require('../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: req.user.user_id }
    });
    
    const checks = [];
    
    // 1. التحقق من وجود بيانات
    const hasInvoices = await require('../model/Invoice').count({
      where: { institution_id: manager.institution_id }
    }) > 0;
    
    checks.push({
      check: 'invoices_data',
      status: hasInvoices ? 'healthy' : 'no_data',
      message: hasInvoices ? 'توجد بيانات فواتير' : 'لا توجد بيانات فواتير'
    });
    
    // 2. التحقق من وجود تبرعات
    const hasDonations = await require('../model/Donation').count({
      where: { institution_id: manager.institution_id }
    }) > 0;
    
    checks.push({
      check: 'donations_data',
      status: hasDonations ? 'healthy' : 'no_data',
      message: hasDonations ? 'توجد بيانات تبرعات' : 'لا توجد بيانات تبرعات'
    });
    
    // 3. التحقق من رصيد التبرعات
    const institution = await require('../model/Institution').findByPk(manager.institution_id);
    const balanceStatus = parseFloat(institution.donation_balance) > 0 ? 'healthy' : 'low';
    
    checks.push({
      check: 'donation_balance',
      status: balanceStatus,
      message: `رصيد التبرعات: $${parseFloat(institution.donation_balance || 0).toFixed(2)}`,
      value: parseFloat(institution.donation_balance || 0)
    });
    
    // 4. التحقق من الفواتير المتأخرة
    const overdueAmount = await require('../model/Invoice').sum('total_amount', {
      where: {
        institution_id: manager.institution_id,
        status: 'Overdue'
      }
    }) || 0;
    
    checks.push({
      check: 'overdue_invoices',
      status: overdueAmount > 1000 ? 'warning' : 'healthy',
      message: `الفواتير المتأخرة: $${parseFloat(overdueAmount).toFixed(2)}`,
      value: parseFloat(overdueAmount)
    });
    
    const overallStatus = checks.every(c => c.status === 'healthy') ? 'healthy' :
                         checks.some(c => c.status === 'warning') ? 'needs_attention' : 'no_data';
    
    res.json({
      success: true,
      data: {
        institution_id: manager.institution_id,
        overall_status: overallStatus,
        checks: checks,
        timestamp: new Date().toISOString(),
        recommendations: generateHealthRecommendations(checks)
      }
    });
    
  } catch (error) {
    console.error('Health check error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في فحص صحة البيانات',
      error: error.message 
    });
  }
});

function generateHealthRecommendations(checks) {
  const recommendations = [];
  
  checks.forEach(check => {
    if (check.status === 'no_data') {
      recommendations.push({
        priority: 'medium',
        action: `add_${check.check}_data`,
        description: `إضافة بيانات ${check.message}`
      });
    } else if (check.status === 'warning') {
      recommendations.push({
        priority: 'high',
        action: `address_${check.check}`,
        description: `معالجة ${check.message}`
      });
    } else if (check.check === 'donation_balance' && check.value < 500) {
      recommendations.push({
        priority: 'medium',
        action: 'increase_donation_balance',
        description: 'زيادة رصيد التبرعات'
      });
    }
  });
  
  return recommendations;
}

module.exports = router;