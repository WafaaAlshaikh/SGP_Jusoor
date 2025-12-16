const { Op, Sequelize } = require('sequelize');
const ExcelJS = require('exceljs');

class FinancialReportService {
  constructor(institutionId) {
    this.institutionId = institutionId;
    this.sequelize = require('../config/db');
  }

  /**
   * إنشاء تقرير مالي بصيغة Excel
   */
  async generateExcelReport(startDate, endDate, reportType = 'comprehensive') {
    const workbook = new ExcelJS.Workbook();
    
    // إنشاء أوراق العمل
    const summarySheet = workbook.addWorksheet('ملخص');
    const revenueSheet = workbook.addWorksheet('الإيرادات');
    const donationsSheet = workbook.addWorksheet('التبرعات');
    const assistanceSheet = workbook.addWorksheet('المساعدات المالية');
    const sessionsSheet = workbook.addWorksheet('الجلسات');
    const receivablesSheet = workbook.addWorksheet('المستحقات');

    // تنسيق عام
    const headerStyle = {
      font: { bold: true, color: { argb: 'FFFFFF' } },
      fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: '4F81BD' } },
      alignment: { horizontal: 'center' }
    };

    const moneyStyle = {
      numFmt: '$#,##0.00'
    };

    // 1. ورقة الملخص
    await this.addSummarySheet(summarySheet, headerStyle, moneyStyle, startDate, endDate);

    // 2. ورقة الإيرادات
    await this.addRevenueSheet(revenueSheet, headerStyle, moneyStyle, startDate, endDate);

    // 3. ورقة التبرعات
    await this.addDonationsSheet(donationsSheet, headerStyle, moneyStyle, startDate, endDate);

    // 4. ورقة المساعدات المالية
    await this.addAssistanceSheet(assistanceSheet, headerStyle, moneyStyle, startDate, endDate);

    // 5. ورقة الجلسات
    await this.addSessionsSheet(sessionsSheet, headerStyle, moneyStyle, startDate, endDate);

    // 6. ورقة المستحقات
    await this.addReceivablesSheet(receivablesSheet, headerStyle, moneyStyle, startDate, endDate);

    // إنشاء المخزن المؤقت
    const buffer = await workbook.xlsx.writeBuffer();
    return buffer;
  }

  /**
   * إنشاء تقرير PDF
   */
  async generatePDFReport(startDate, endDate) {
    const reportData = await this.getReportData(startDate, endDate);
    
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>التقرير المالي - ${reportData.period.start} إلى ${reportData.period.end}</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; direction: rtl; }
          .header { text-align: center; margin-bottom: 30px; }
          .section { margin-bottom: 20px; border: 1px solid #ddd; padding: 15px; }
          .section-title { background-color: #f5f5f5; padding: 10px; font-weight: bold; }
          .table { width: 100%; border-collapse: collapse; margin-top: 10px; }
          .table th, .table td { border: 1px solid #ddd; padding: 8px; text-align: right; }
          .table th { background-color: #f2f2f2; }
          .total-row { font-weight: bold; background-color: #e8f4f8; }
          .positive { color: green; }
          .negative { color: red; }
          .info-box { background-color: #f0f8ff; padding: 15px; border-radius: 5px; margin: 15px 0; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>التقرير المالي الشامل</h1>
          <h3>الفترة: ${reportData.period.start} إلى ${reportData.period.end}</h3>
          <p>المؤسسة: ${reportData.institution.name}</p>
          <p>تاريخ الإنشاء: ${new Date().toLocaleDateString('ar-SA')}</p>
        </div>

        ${this.generateHTMLSections(reportData)}
        
        <div class="section">
          <div class="section-title">تحليل وتوصيات</div>
          ${this.generateRecommendationsHTML(reportData.recommendations)}
        </div>
      </body>
      </html>
    `;

    return html;
  }

  /**
   * إرسال التقرير بالبريد الإلكتروني
   */
  async sendReportByEmail(email, reportData, format = 'pdf') {
    // محاكاة لإرسال البريد الإلكتروني
    console.log(`إرسال تقرير إلى: ${email}, التنسيق: ${format}`);
    
    return { 
      success: true, 
      message: 'تم محاكاة إرسال التقرير بنجاح' 
    };
  }

  /**
   * إنشاء تنبيهات مالية
   */
  async createFinancialAlerts() {
    const alerts = [];

    // 1. تحقق من الديون المتأخرة
    const overdueAmount = await this.getOverdueAmount();
    if (overdueAmount > 1000) {
      alerts.push({
        type: 'warning',
        code: 'HIGH_OVERDUE',
        message: `لديك فواتير متأخرة بقيمة $${overdueAmount.toFixed(2)}`,
        priority: 'high',
        action: 'follow_up_overdue_invoices'
      });
    }

    // 2. تحقق من رصيد التبرعات
    const donationBalance = await this.getDonationBalance();
    if (donationBalance < 500) {
      alerts.push({
        type: 'warning',
        code: 'LOW_DONATION_BALANCE',
        message: `رصيد التبرعات منخفض: $${donationBalance.toFixed(2)}`,
        priority: 'medium',
        action: 'review_funding_strategy'
      });
    }

    // 3. تحقق من معدل الربحية
    const profitMargin = await this.getCurrentProfitMargin();
    if (profitMargin < 10) {
      alerts.push({
        type: 'warning',
        code: 'LOW_PROFIT_MARGIN',
        message: `هامش الربح الحالي منخفض: ${profitMargin.toFixed(1)}%`,
        priority: 'medium',
        action: 'review_pricing_costs'
      });
    }

    // 4. تحقق من كثافة المساعدات المالية
    const assistanceRate = await this.getFinancialAssistanceRate();
    if (assistanceRate > 30) {
      alerts.push({
        type: 'info',
        code: 'HIGH_ASSISTANCE_RATE',
        message: `نسبة المساعدات المالية مرتفعة: ${assistanceRate.toFixed(1)}% من الإيرادات`,
        priority: 'low',
        action: 'review_assistance_criteria'
      });
    }

    return alerts;
  }

  // ==================== Methods المساعدة ====================

  async getReportData(startDate, endDate) {
    try {
      // جمع البيانات من مصادر مختلفة
      const [revenue, donations, assistance, sessions, receivables] = await Promise.all([
        this.getRevenueData(startDate, endDate),
        this.getDonationData(startDate, endDate),
        this.getFinancialAssistanceData(startDate, endDate),
        this.getSessionsData(startDate, endDate),
        this.getReceivablesData(startDate, endDate)
      ]);

      const Institution = require('../model/Institution');
      const institution = await Institution.findByPk(this.institutionId, {
        attributes: ['name', 'donation_balance']
      });

      const summary = this.calculateSummary(revenue, donations, assistance, sessions, receivables);
      const recommendations = this.generateRecommendations(summary);

      return {
        period: {
          start: startDate.toISOString().split('T')[0],
          end: endDate.toISOString().split('T')[0]
        },
        institution: {
          name: institution?.name || 'غير معروف',
          donation_balance: parseFloat(institution?.donation_balance || 0)
        },
        revenue,
        donations,
        financial_assistance: assistance,
        sessions,
        receivables,
        summary,
        recommendations,
        generated_at: new Date().toISOString()
      };
    } catch (error) {
      console.error('Error in getReportData:', error);
      return this.getDefaultReportData(startDate, endDate);
    }
  }

  async getRevenueData(startDate, endDate) {
    try {
      const Invoice = require('../model/Invoice');
      
      // إجمالي الإيرادات
      const totalResult = await Invoice.findOne({
        where: {
          institution_id: this.institutionId,
          status: 'Paid',
          paid_date: { [Op.between]: [startDate, endDate] }
        },
        attributes: [
          [Sequelize.fn('SUM', Sequelize.col('total_amount')), 'total'],
          [Sequelize.fn('COUNT', Sequelize.col('invoice_id')), 'count']
        ],
        raw: true
      });

      // الإيرادات حسب الشهر
      const monthlyRevenue = await sequelize.query(`
        SELECT 
          DATE_FORMAT(paid_date, '%Y-%m') as month,
          SUM(total_amount) as amount,
          COUNT(invoice_id) as count
        FROM Invoices
        WHERE institution_id = ?
          AND status = 'Paid'
          AND paid_date BETWEEN ? AND ?
        GROUP BY DATE_FORMAT(paid_date, '%Y-%m')
        ORDER BY month ASC
      `, {
        replacements: [this.institutionId, startDate, endDate],
        type: Sequelize.QueryTypes.SELECT
      });

      // الإيرادات حسب الخدمة
      const byService = await sequelize.query(`
        SELECT 
          COALESCE(st.name, 'غير معروف') as service_type,
          SUM(i.total_amount) as amount,
          COUNT(i.invoice_id) as count
        FROM Invoices i
        LEFT JOIN Sessions s ON i.session_id = s.session_id
        LEFT JOIN SessionTypes st ON s.session_type_id = st.session_type_id
        WHERE i.institution_id = ?
          AND i.status = 'Paid'
          AND i.paid_date BETWEEN ? AND ?
        GROUP BY s.session_type_id, st.name
        ORDER BY SUM(i.total_amount) DESC
      `, {
        replacements: [this.institutionId, startDate, endDate],
        type: Sequelize.QueryTypes.SELECT
      });

      return {
        total: parseFloat(totalResult?.total || 0),
        count: parseInt(totalResult?.count || 0),
        monthly_breakdown: monthlyRevenue,
        by_service: byService
      };
    } catch (error) {
      console.error('Error in getRevenueData:', error);
      return {
        total: 0,
        count: 0,
        monthly_breakdown: [],
        by_service: []
      };
    }
  }

  async getDonationData(startDate, endDate) {
    try {
      const Donation = require('../model/Donation');
      const DonationCampaign = require('../model/DonationCampaign');

      // إجمالي التبرعات
      const totalResult = await Donation.findOne({
        where: {
          institution_id: this.institutionId,
          date: { [Op.between]: [startDate, endDate] }
        },
        attributes: [
          [Sequelize.fn('SUM', Sequelize.col('amount')), 'total'],
          [Sequelize.fn('COUNT', Sequelize.col('donation_id')), 'count'],
          [Sequelize.fn('AVG', Sequelize.col('amount')), 'average']
        ],
        raw: true
      });

      // التبرعات حسب الحملة
      const campaigns = await DonationCampaign.findAll({
        where: { institution_id: this.institutionId },
        attributes: ['campaign_id', 'name', 'target_amount', 'status'],
        raw: true
      });

      const byCampaign = [];
      for (const campaign of campaigns) {
        const campaignDonations = await Donation.sum('amount', {
          where: {
            institution_id: this.institutionId,
            campaign_id: campaign.campaign_id,
            date: { [Op.between]: [startDate, endDate] }
          }
        }) || 0;

        byCampaign.push({
          name: campaign.name,
          target: parseFloat(campaign.target_amount || 0),
          raised: parseFloat(campaignDonations),
          progress: parseFloat(campaign.target_amount) > 0 ? 
            (parseFloat(campaignDonations) / parseFloat(campaign.target_amount)) * 100 : 0
        });
      }

      return {
        total: parseFloat(totalResult?.total || 0),
        count: parseInt(totalResult?.count || 0),
        average: parseFloat(totalResult?.average || 0),
        by_campaign: byCampaign
      };
    } catch (error) {
      console.error('Error in getDonationData:', error);
      return {
        total: 0,
        count: 0,
        average: 0,
        by_campaign: []
      };
    }
  }

  async getFinancialAssistanceData(startDate, endDate) {
    try {
      const FinancialAssistanceRequest = require('../model/FinancialAssistanceRequest');

      // استخدام raw query لتجنب مشاكل GROUP BY
      const assistanceData = await sequelize.query(`
        SELECT 
          status,
          COUNT(request_id) as count,
          SUM(requested_total_amount * (requested_discount_percentage / 100)) as assistance_value
        FROM FinancialAssistanceRequests
        WHERE institution_id = ?
          AND submitted_at BETWEEN ? AND ?
        GROUP BY status
      `, {
        replacements: [this.institutionId, startDate, endDate],
        type: Sequelize.QueryTypes.SELECT
      });

      const byTierData = await sequelize.query(`
        SELECT 
          parent_financial_tier,
          COUNT(request_id) as count,
          SUM(requested_total_amount * (requested_discount_percentage / 100)) as assistance_value
        FROM FinancialAssistanceRequests
        WHERE institution_id = ?
          AND submitted_at BETWEEN ? AND ?
        GROUP BY parent_financial_tier
      `, {
        replacements: [this.institutionId, startDate, endDate],
        type: Sequelize.QueryTypes.SELECT
      });

      const byStatus = {};
      let totalRequests = 0;
      let totalValue = 0;

      assistanceData.forEach(item => {
        byStatus[item.status] = {
          count: parseInt(item.count || 0),
          value: parseFloat(item.assistance_value || 0)
        };
        totalRequests += parseInt(item.count || 0);
        totalValue += parseFloat(item.assistance_value || 0);
      });

      const byTier = {};
      byTierData.forEach(item => {
        byTier[item.parent_financial_tier || 'غير محدد'] = {
          count: parseInt(item.count || 0),
          value: parseFloat(item.assistance_value || 0)
        };
      });

      return {
        total_requests: totalRequests,
        total_value: totalValue,
        by_status: byStatus,
        by_tier: byTier
      };
    } catch (error) {
      console.error('Error in getFinancialAssistanceData:', error);
      return {
        total_requests: 0,
        total_value: 0,
        by_status: {},
        by_tier: {}
      };
    }
  }

  async getSessionsData(startDate, endDate) {
    try {
      const Session = require('../model/Session');
      const SessionType = require('../model/SessionType');

      // إحصائيات الجلسات حسب الحالة
      const sessionsResult = await Session.findAll({
        where: {
          institution_id: this.institutionId,
          date: { [Op.between]: [startDate, endDate] }
        },
        attributes: [
          'status',
          [Sequelize.fn('COUNT', Sequelize.col('session_id')), 'count'],
          [Sequelize.fn('SUM', Sequelize.col('final_price')), 'revenue']
        ],
        group: ['status'],
        raw: true
      });

      // الجلسات حسب النوع
      const byTypeData = await sequelize.query(`
        SELECT 
          COALESCE(st.name, 'غير معروف') as session_type,
          COUNT(s.session_id) as session_count,
          SUM(s.final_price) as revenue
        FROM Sessions s
        LEFT JOIN SessionTypes st ON s.session_type_id = st.session_type_id
        WHERE s.institution_id = ?
          AND s.date BETWEEN ? AND ?
        GROUP BY s.session_type_id, st.name
      `, {
        replacements: [this.institutionId, startDate, endDate],
        type: Sequelize.QueryTypes.SELECT
      });

      const totalSessions = sessionsResult.reduce((sum, s) => sum + parseInt(s.count || 0), 0);
      const completedSessions = sessionsResult.find(s => s.status === 'Completed')?.count || 0;
      const totalRevenue = sessionsResult.reduce((sum, s) => sum + parseFloat(s.revenue || 0), 0);

      return {
        total: totalSessions,
        completed: parseInt(completedSessions),
        revenue: totalRevenue,
        by_type: byTypeData.map(t => ({
          type: t.session_type,
          sessions: parseInt(t.session_count || 0),
          revenue: parseFloat(t.revenue || 0)
        }))
      };
    } catch (error) {
      console.error('Error in getSessionsData:', error);
      return {
        total: 0,
        completed: 0,
        revenue: 0,
        by_type: []
      };
    }
  }

  async getReceivablesData(startDate, endDate) {
    try {
      const Invoice = require('../model/Invoice');

      // الفواتير المستحقة
      const pendingResult = await Invoice.findOne({
        where: {
          institution_id: this.institutionId,
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
          institution_id: this.institutionId,
          status: 'Overdue'
        },
        attributes: [
          [Sequelize.fn('SUM', Sequelize.col('total_amount')), 'amount'],
          [Sequelize.fn('COUNT', Sequelize.col('invoice_id')), 'count']
        ],
        raw: true
      });

      // تحليل الديون حسب العمر
      const agingAnalysis = await sequelize.query(`
        SELECT 
          CASE
            WHEN status = 'Overdue' THEN 'متأخرة'
            WHEN DATEDIFF(CURDATE(), due_date) <= 0 THEN 'حالية'
            WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 1 AND 30 THEN '1-30 يوم'
            WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 31 AND 60 THEN '31-60 يوم'
            WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 61 AND 90 THEN '61-90 يوم'
            ELSE 'أكثر من 90 يوم'
          END as age_category,
          SUM(total_amount) as amount,
          COUNT(invoice_id) as count
        FROM Invoices
        WHERE institution_id = ?
          AND status IN ('Pending', 'Overdue')
        GROUP BY 
          CASE
            WHEN status = 'Overdue' THEN 'متأخرة'
            WHEN DATEDIFF(CURDATE(), due_date) <= 0 THEN 'حالية'
            WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 1 AND 30 THEN '1-30 يوم'
            WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 31 AND 60 THEN '31-60 يوم'
            WHEN DATEDIFF(CURDATE(), due_date) BETWEEN 61 AND 90 THEN '61-90 يوم'
            ELSE 'أكثر من 90 يوم'
          END
      `, {
        replacements: [this.institutionId],
        type: Sequelize.QueryTypes.SELECT
      });

      return {
        pending: {
          amount: parseFloat(pendingResult?.amount || 0),
          count: parseInt(pendingResult?.count || 0)
        },
        overdue: {
          amount: parseFloat(overdueResult?.amount || 0),
          count: parseInt(overdueResult?.count || 0)
        },
        total: parseFloat(pendingResult?.amount || 0) + parseFloat(overdueResult?.amount || 0),
        aging_analysis: agingAnalysis
      };
    } catch (error) {
      console.error('Error in getReceivablesData:', error);
      return {
        pending: { amount: 0, count: 0 },
        overdue: { amount: 0, count: 0 },
        total: 0,
        aging_analysis: []
      };
    }
  }

  calculateSummary(revenue, donations, assistance, sessions, receivables) {
    try {
      const totalRevenue = revenue.total + donations.total;
      const netRevenue = totalRevenue - assistance.total_value;
      const collectionRate = revenue.total > 0 ? 
        ((revenue.total - receivables.total) / revenue.total) * 100 : 100;
      const sessionUtilization = sessions.total > 0 ? 
        (sessions.completed / sessions.total) * 100 : 0;
      const assistanceRatio = totalRevenue > 0 ? (assistance.total_value / totalRevenue) * 100 : 0;

      return {
        total_revenue: totalRevenue,
        net_revenue: netRevenue,
        collection_rate: collectionRate,
        session_utilization: sessionUtilization,
        assistance_ratio: assistanceRatio,
        financial_health: this.calculateHealthScore(
          netRevenue,
          collectionRate,
          sessionUtilization,
          receivables.total
        )
      };
    } catch (error) {
      console.error('Error in calculateSummary:', error);
      return {
        total_revenue: 0,
        net_revenue: 0,
        collection_rate: 0,
        session_utilization: 0,
        assistance_ratio: 0,
        financial_health: 0
      };
    }
  }

  calculateHealthScore(netRevenue, collectionRate, sessionUtilization, receivables) {
    let score = 50;

    // الربحية
    if (netRevenue > 0) score += 20;
    else if (netRevenue > -1000) score += 10;
    else score -= 10;

    // معدل التحصيل
    if (collectionRate > 90) score += 15;
    else if (collectionRate > 80) score += 10;
    else if (collectionRate > 70) score += 5;
    else score -= 5;

    // استخدام الجلسات
    if (sessionUtilization > 90) score += 15;
    else if (sessionUtilization > 80) score += 10;
    else if (sessionUtilization > 70) score += 5;

    // الديون المستحقة
    if (receivables < 1000) score += 10;
    else if (receivables < 5000) score += 5;
    else if (receivables > 10000) score -= 10;

    return Math.min(100, Math.max(0, score));
  }

  generateRecommendations(summary) {
    const recommendations = [];

    if (summary.financial_health < 60) {
      recommendations.push({
        priority: 'high',
        description: 'الصحة المالية العامة تحتاج للتحسين',
        action: 'review_financial_strategy'
      });
    }

    if (summary.collection_rate < 80) {
      recommendations.push({
        priority: 'medium',
        description: `معدل التحصيل منخفض (${summary.collection_rate.toFixed(1)}%)`,
        action: 'improve_collection_process'
      });
    }

    if (summary.assistance_ratio > 30) {
      recommendations.push({
        priority: 'medium',
        description: `نسبة المساعدات المالية مرتفعة (${summary.assistance_ratio.toFixed(1)}%)`,
        action: 'review_assistance_policy'
      });
    }

    if (summary.session_utilization < 70) {
      recommendations.push({
        priority: 'low',
        description: `معدل استخدام الجلسات منخفض (${summary.session_utilization.toFixed(1)}%)`,
        action: 'improve_session_scheduling'
      });
    }

    return recommendations;
  }

  async getOverdueAmount() {
    try {
      const Invoice = require('../model/Invoice');
      
      const amount = await Invoice.sum('total_amount', {
        where: {
          institution_id: this.institutionId,
          status: 'Overdue'
        }
      }) || 0;

      return parseFloat(amount);
    } catch (error) {
      console.error('Error in getOverdueAmount:', error);
      return 0;
    }
  }

  async getDonationBalance() {
    try {
      const Institution = require('../model/Institution');
      
      const institution = await Institution.findByPk(this.institutionId, {
        attributes: ['donation_balance']
      });

      return parseFloat(institution?.donation_balance || 0);
    } catch (error) {
      console.error('Error in getDonationBalance:', error);
      return 0;
    }
  }

  async getCurrentProfitMargin() {
    try {
      const currentMonth = new Date();
      const monthStart = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
      const monthEnd = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0, 23, 59, 59);

      const Invoice = require('../model/Invoice');
      const revenue = await Invoice.sum('total_amount', {
        where: {
          institution_id: this.institutionId,
          status: 'Paid',
          paid_date: { [Op.between]: [monthStart, monthEnd] }
        }
      }) || 0;

      const estimatedCosts = await this.estimateMonthlyCosts(monthStart, monthEnd);

      return revenue > 0 ? ((revenue - estimatedCosts) / revenue) * 100 : 0;
    } catch (error) {
      console.error('Error in getCurrentProfitMargin:', error);
      return 0;
    }
  }

  async getFinancialAssistanceRate() {
    try {
      const currentMonth = new Date();
      const monthStart = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
      const monthEnd = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0, 23, 59, 59);

      const Invoice = require('../model/Invoice');
      const revenue = await Invoice.sum('total_amount', {
        where: {
          institution_id: this.institutionId,
          status: 'Paid',
          paid_date: { [Op.between]: [monthStart, monthEnd] }
        }
      }) || 0;

      const FinancialAssistanceRequest = require('../model/FinancialAssistanceRequest');
      const assistance = await FinancialAssistanceRequest.sum('approved_discount_percentage', {
        where: {
          institution_id: this.institutionId,
          status: 'approved',
          submitted_at: { [Op.between]: [monthStart, monthEnd] }
        }
      }) || 0;

      return revenue > 0 ? (assistance / revenue) * 100 : 0;
    } catch (error) {
      console.error('Error in getFinancialAssistanceRate:', error);
      return 0;
    }
  }

  async estimateMonthlyCosts(startDate, endDate) {
    try {
      const Specialist = require('../model/Specialist');
      const Session = require('../model/Session');

      const specialistCount = await Specialist.count({
        where: {
          institution_id: this.institutionId,
          approval_status: 'Approved'
        }
      });

      const sessionCount = await Session.count({
        where: {
          institution_id: this.institutionId,
          date: { [Op.between]: [startDate, endDate] }
        }
      });

      const staffCosts = specialistCount * 2000;
      const operationalCosts = sessionCount * 50;

      return staffCosts + operationalCosts;
    } catch (error) {
      console.error('Error in estimateMonthlyCosts:', error);
      return 0;
    }
  }

  getDefaultReportData(startDate, endDate) {
    return {
      period: {
        start: startDate.toISOString().split('T')[0],
        end: endDate.toISOString().split('T')[0]
      },
      institution: {
        name: 'غير معروف',
        donation_balance: 0
      },
      revenue: {
        total: 0,
        count: 0,
        monthly_breakdown: [],
        by_service: []
      },
      donations: {
        total: 0,
        count: 0,
        average: 0,
        by_campaign: []
      },
      financial_assistance: {
        total_requests: 0,
        total_value: 0,
        by_status: {},
        by_tier: {}
      },
      sessions: {
        total: 0,
        completed: 0,
        revenue: 0,
        by_type: []
      },
      receivables: {
        pending: { amount: 0, count: 0 },
        overdue: { amount: 0, count: 0 },
        total: 0,
        aging_analysis: []
      },
      summary: {
        total_revenue: 0,
        net_revenue: 0,
        collection_rate: 0,
        session_utilization: 0,
        assistance_ratio: 0,
        financial_health: 0
      },
      recommendations: [],
      generated_at: new Date().toISOString()
    };
  }

  // ==================== Methods إنشاء التقارير ====================

  async addSummarySheet(sheet, headerStyle, moneyStyle, startDate, endDate) {
    try {
      const reportData = await this.getReportData(startDate, endDate);

      // العنوان
      sheet.mergeCells('A1:C1');
      sheet.getCell('A1').value = 'التقرير المالي الشامل';
      sheet.getCell('A1').style = { ...headerStyle, font: { size: 16, bold: true } };
      sheet.getRow(1).height = 30;

      // معلومات الفترة
      sheet.addRow(['الفترة', `${startDate.toLocaleDateString('ar-SA')} - ${endDate.toLocaleDateString('ar-SA')}`, '']);
      sheet.addRow(['المؤسسة', reportData.institution.name, '']);
      sheet.addRow(['تاريخ الإنشاء', new Date().toLocaleDateString('ar-SA'), '']);
      sheet.addRow([]);

      // ملخص الأداء
      sheet.addRow(['ملخص الأداء المالي', '', '']);
      const summaryTitleRow = sheet.getRow(sheet.rowCount);
      summaryTitleRow.font = { bold: true };
      summaryTitleRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'F2F2F2' }
      };

      // البيانات
      const summaryData = [
        ['إجمالي الإيرادات', reportData.revenue.total, ''],
        ['إجمالي التبرعات', reportData.donations.total, ''],
        ['إجمالي المساعدات المالية', reportData.financial_assistance.total_value, ''],
        ['صافي الإيرادات', reportData.summary.net_revenue, ''],
        ['معدل التحصيل', '', `${reportData.summary.collection_rate.toFixed(1)}%`],
        ['معدل استخدام الجلسات', '', `${reportData.summary.session_utilization.toFixed(1)}%`],
        ['نسبة المساعدات', '', `${reportData.summary.assistance_ratio.toFixed(1)}%`],
        ['صحة مالية', '', `${reportData.summary.financial_health.toFixed(0)}/100`]
      ];

      summaryData.forEach(data => {
        const row = sheet.addRow(data);
        if (data[0].includes('الإيرادات') || data[0].includes('المساعدات') || data[0].includes('صافي')) {
          row.getCell(2).style = moneyStyle;
        }
      });

      // تلوين الصفوف
      for (let i = 1; i <= sheet.rowCount; i++) {
        if (i % 2 === 0) {
          sheet.getRow(i).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'F9F9F9' }
          };
        }
      }

    } catch (error) {
      console.error('Error in addSummarySheet:', error);
      sheet.addRow(['خطأ في إنشاء التقرير', error.message, '']);
    }
  }

  async addRevenueSheet(sheet, headerStyle, moneyStyle, startDate, endDate) {
    try {
      const reportData = await this.getReportData(startDate, endDate);

      // العنوان
      sheet.mergeCells('A1:D1');
      sheet.getCell('A1').value = 'تفاصيل الإيرادات';
      sheet.getCell('A1').style = { ...headerStyle, font: { size: 14, bold: true } };

      // رؤوس الجدول
      sheet.addRow(['نوع الإيرادات', 'المبلغ', 'العدد', 'النسبة']);
      sheet.getRow(2).eachCell(cell => {
        cell.style = headerStyle;
      });

      // البيانات
      sheet.addRow(['إيرادات الخدمات', reportData.revenue.total, reportData.revenue.count, '']);
      sheet.addRow(['التبرعات', reportData.donations.total, reportData.donations.count, '']);
      
      const totalRow = sheet.addRow([
        'الإجمالي', 
        reportData.revenue.total + reportData.donations.total, 
        reportData.revenue.count + reportData.donations.count, 
        ''
      ]);

      // تنسيق الأرقام
      for (let i = 3; i <= 5; i++) {
        sheet.getRow(i).getCell(2).style = moneyStyle;
      }

      // تنسيق صف الإجمالي
      totalRow.font = { bold: true };
      totalRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'E8F4F8' }
      };

      // الإيرادات حسب الخدمة
      sheet.addRow([]);
      sheet.mergeCells('A7:D7');
      sheet.getCell('A7').value = 'الإيرادات حسب نوع الخدمة';
      sheet.getCell('A7').style = { font: { bold: true } };

      sheet.addRow(['نوع الخدمة', 'المبلغ', 'العدد', 'النسبة']);
      sheet.getRow(8).eachCell(cell => {
        cell.style = { ...headerStyle, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'D9D9D9' } } };
      });

      let rowNum = 9;
      reportData.revenue.by_service.forEach(service => {
        const percentage = reportData.revenue.total > 0 ? 
          (service.amount / reportData.revenue.total) * 100 : 0;
        
        sheet.addRow([
          service.service_type,
          service.amount,
          service.count,
          `${percentage.toFixed(1)}%`
        ]);
        
        sheet.getRow(rowNum).getCell(2).style = moneyStyle;
        rowNum++;
      });

    } catch (error) {
      console.error('Error in addRevenueSheet:', error);
      sheet.addRow(['خطأ في إنشاء ورقة الإيرادات', error.message]);
    }
  }

  async addDonationsSheet(sheet, headerStyle, moneyStyle, startDate, endDate) {
    try {
      const reportData = await this.getReportData(startDate, endDate);

      // العنوان
      sheet.mergeCells('A1:E1');
      sheet.getCell('A1').value = 'تفاصيل التبرعات';
      sheet.getCell('A1').style = { ...headerStyle, font: { size: 14, bold: true } };

      // ملخص التبرعات
      sheet.addRow(['المجموع', reportData.donations.total, '', '']);
      sheet.addRow(['متوسط التبرع', reportData.donations.average, '', '']);
      sheet.addRow(['عدد التبرعات', reportData.donations.count, '', '']);
      sheet.addRow([]);

      // تنسيق الأرقام
      for (let i = 2; i <= 4; i++) {
        sheet.getRow(i).getCell(2).style = moneyStyle;
      }

      // التبرعات حسب الحملة
      sheet.mergeCells('A6:E6');
      sheet.getCell('A6').value = 'التبرعات حسب الحملة';
      sheet.getCell('A6').style = { font: { bold: true } };

      sheet.addRow(['الحملة', 'المستهدف', 'المجموع', 'النسبة', 'الحالة']);
      sheet.getRow(7).eachCell(cell => {
        cell.style = { ...headerStyle, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'D9D9D9' } } };
      });

      let rowNum = 8;
      reportData.donations.by_campaign.forEach(campaign => {
        const progressBar = '█'.repeat(Math.min(20, Math.floor(campaign.progress / 5)));
        
        sheet.addRow([
          campaign.name,
          campaign.target,
          campaign.raised,
          `${campaign.progress.toFixed(1)}% ${progressBar}`,
          campaign.progress >= 100 ? 'مكتملة' : 'مستمرة'
        ]);
        
        sheet.getRow(rowNum).getCell(2).style = moneyStyle;
        sheet.getRow(rowNum).getCell(3).style = moneyStyle;
        
        // تلوين نسبة الإنجاز
        const progressCell = sheet.getRow(rowNum).getCell(4);
        if (campaign.progress >= 100) {
          progressCell.font = { color: { argb: '00FF00' }, bold: true };
        } else if (campaign.progress >= 50) {
          progressCell.font = { color: { argb: 'FFA500' } };
        } else {
          progressCell.font = { color: { argb: 'FF0000' } };
        }
        
        rowNum++;
      });

    } catch (error) {
      console.error('Error in addDonationsSheet:', error);
      sheet.addRow(['خطأ في إنشاء ورقة التبرعات', error.message]);
    }
  }

  async addAssistanceSheet(sheet, headerStyle, moneyStyle, startDate, endDate) {
    try {
      const reportData = await this.getReportData(startDate, endDate);

      // العنوان
      sheet.mergeCells('A1:D1');
      sheet.getCell('A1').value = 'تفاصيل المساعدات المالية';
      sheet.getCell('A1').style = { ...headerStyle, font: { size: 14, bold: true } };

      // ملخص
      sheet.addRow(['إجمالي الطلبات', reportData.financial_assistance.total_requests, '', '']);
      sheet.addRow(['قيمة المساعدات', reportData.financial_assistance.total_value, '', '']);
      sheet.addRow([]);

      // تنسيق الأرقام
      sheet.getRow(3).getCell(2).style = moneyStyle;

      // حسب الحالة
      sheet.mergeCells('A5:D5');
      sheet.getCell('A5').value = 'الطلبات حسب الحالة';
      sheet.getCell('A5').style = { font: { bold: true } };

      sheet.addRow(['الحالة', 'العدد', 'القيمة', 'النسبة']);
      sheet.getRow(6).eachCell(cell => {
        cell.style = { ...headerStyle, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'D9D9D9' } } };
      });

      let rowNum = 7;
      Object.entries(reportData.financial_assistance.by_status).forEach(([status, data]) => {
        const percentage = reportData.financial_assistance.total_requests > 0 ?
          (data.count / reportData.financial_assistance.total_requests) * 100 : 0;
        
        sheet.addRow([
          this.translateStatus(status),
          data.count,
          data.value,
          `${percentage.toFixed(1)}%`
        ]);
        
        sheet.getRow(rowNum).getCell(3).style = moneyStyle;
        rowNum++;
      });

    } catch (error) {
      console.error('Error in addAssistanceSheet:', error);
      sheet.addRow(['خطأ في إنشاء ورقة المساعدات', error.message]);
    }
  }

  async addSessionsSheet(sheet, headerStyle, moneyStyle, startDate, endDate) {
    try {
      const reportData = await this.getReportData(startDate, endDate);

      // العنوان
      sheet.mergeCells('A1:D1');
      sheet.getCell('A1').value = 'تفاصيل الجلسات';
      sheet.getCell('A1').style = { ...headerStyle, font: { size: 14, bold: true } };

      // ملخص
      sheet.addRow(['إجمالي الجلسات', reportData.sessions.total, '', '']);
      sheet.addRow(['الجلسات المكتملة', reportData.sessions.completed, '', '']);
      sheet.addRow(['إيرادات الجلسات', reportData.sessions.revenue, '', '']);
      sheet.addRow(['معدل الإنجاز', `${reportData.summary.session_utilization.toFixed(1)}%`, '', '']);
      sheet.addRow([]);

      // تنسيق الأرقام
      sheet.getRow(4).getCell(2).style = moneyStyle;

      // حسب النوع
      sheet.mergeCells('A7:D7');
      sheet.getCell('A7').value = 'الجلسات حسب النوع';
      sheet.getCell('A7').style = { font: { bold: true } };

      sheet.addRow(['نوع الجلسة', 'العدد', 'الإيرادات', 'النسبة']);
      sheet.getRow(8).eachCell(cell => {
        cell.style = { ...headerStyle, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'D9D9D9' } } };
      });

      let rowNum = 9;
      reportData.sessions.by_type.forEach(sessionType => {
        const percentage = reportData.sessions.total > 0 ?
          (sessionType.sessions / reportData.sessions.total) * 100 : 0;
        
        sheet.addRow([
          sessionType.type,
          sessionType.sessions,
          sessionType.revenue,
          `${percentage.toFixed(1)}%`
        ]);
        
        sheet.getRow(rowNum).getCell(3).style = moneyStyle;
        rowNum++;
      });

    } catch (error) {
      console.error('Error in addSessionsSheet:', error);
      sheet.addRow(['خطأ في إنشاء ورقة الجلسات', error.message]);
    }
  }

  async addReceivablesSheet(sheet, headerStyle, moneyStyle, startDate, endDate) {
    try {
      const reportData = await this.getReportData(startDate, endDate);

      // العنوان
      sheet.mergeCells('A1:D1');
      sheet.getCell('A1').value = 'تفاصيل المستحقات';
      sheet.getCell('A1').style = { ...headerStyle, font: { size: 14, bold: true } };

      // ملخص
      sheet.addRow(['المستحقات الحالية', reportData.receivables.pending.amount, reportData.receivables.pending.count, '']);
      sheet.addRow(['المستحقات المتأخرة', reportData.receivables.overdue.amount, reportData.receivables.overdue.count, '']);
      
      const totalRow = sheet.addRow([
        'الإجمالي',
        reportData.receivables.total,
        reportData.receivables.pending.count + reportData.receivables.overdue.count,
        ''
      ]);
      sheet.addRow([]);

      // تنسيق الأرقام
      for (let i = 2; i <= 4; i++) {
        sheet.getRow(i).getCell(2).style = moneyStyle;
      }

      // تنسيق صف الإجمالي
      totalRow.font = { bold: true };
      totalRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FFE6E6' }
      };

      // تحليل حسب العمر
      sheet.mergeCells('A7:D7');
      sheet.getCell('A7').value = 'تحليل الديون حسب العمر';
      sheet.getCell('A7').style = { font: { bold: true } };

      sheet.addRow(['الفئة', 'المبلغ', 'العدد', 'النسبة']);
      sheet.getRow(8).eachCell(cell => {
        cell.style = { ...headerStyle, fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'D9D9D9' } } };
      });

      let rowNum = 9;
      reportData.receivables.aging_analysis.forEach(item => {
        const percentage = reportData.receivables.total > 0 ?
          (item.amount / reportData.receivables.total) * 100 : 0;
        
        sheet.addRow([
          item.age_category,
          item.amount,
          item.count,
          `${percentage.toFixed(1)}%`
        ]);
        
        sheet.getRow(rowNum).getCell(2).style = moneyStyle;
        
        // تلوين حسب العمر
        if (item.age_category.includes('متأخرة') || item.age_category.includes('90')) {
          sheet.getRow(rowNum).getCell(1).font = { color: { argb: 'FF0000' }, bold: true };
        }
        
        rowNum++;
      });

    } catch (error) {
      console.error('Error in addReceivablesSheet:', error);
      sheet.addRow(['خطأ في إنشاء ورقة المستحقات', error.message]);
    }
  }

  translateStatus(status) {
    const translations = {
      'submitted': 'مقدمة',
      'under_review': 'قيد المراجعة',
      'pending_documents': 'بانتظار المستندات',
      'approved': 'موافق عليها',
      'rejected': 'مرفوضة',
      'cancelled': 'ملغاة'
    };
    
    return translations[status] || status;
  }

  generateHTMLSections(reportData) {
    let html = '';

    // قسم الإيرادات
    html += `
      <div class="section">
        <div class="section-title">الإيرادات</div>
        <table class="table">
          <tr>
            <th>نوع الإيرادات</th>
            <th>المبلغ</th>
            <th>عدد المعاملات</th>
          </tr>
          <tr>
            <td>إيرادات الخدمات</td>
            <td>$${reportData.revenue.total.toFixed(2)}</td>
            <td>${reportData.revenue.count}</td>
          </tr>
          <tr>
            <td>التبرعات</td>
            <td>$${reportData.donations.total.toFixed(2)}</td>
            <td>${reportData.donations.count}</td>
          </tr>
          <tr class="total-row">
            <td>الإجمالي</td>
            <td>$${(reportData.revenue.total + reportData.donations.total).toFixed(2)}</td>
            <td>${reportData.revenue.count + reportData.donations.count}</td>
          </tr>
        </table>
        
        <div class="info-box">
          <h4>مؤشرات الأداء:</h4>
          <ul>
            <li>معدل التحصيل: ${reportData.summary.collection_rate.toFixed(1)}%</li>
            <li>صحة مالية: ${reportData.summary.financial_health.toFixed(0)}/100</li>
          </ul>
        </div>
      </div>
    `;

    // قسم المساعدات المالية
    html += `
      <div class="section">
        <div class="section-title">المساعدات المالية</div>
        <table class="table">
          <tr>
            <th>الحالة</th>
            <th>عدد الطلبات</th>
            <th>قيمة المساعدة</th>
          </tr>
    `;

    Object.entries(reportData.financial_assistance.by_status).forEach(([status, data]) => {
      html += `
        <tr>
          <td>${this.translateStatus(status)}</td>
          <td>${data.count}</td>
          <td>$${data.value.toFixed(2)}</td>
        </tr>
      `;
    });

    html += `
          <tr class="total-row">
            <td>الإجمالي</td>
            <td>${reportData.financial_assistance.total_requests}</td>
            <td>$${reportData.financial_assistance.total_value.toFixed(2)}</td>
          </tr>
        </table>
        
        <div class="info-box">
          <p>نسبة المساعدات من إجمالي الإيرادات: ${reportData.summary.assistance_ratio.toFixed(1)}%</p>
        </div>
      </div>
    `;

    // قسم الجلسات
    html += `
      <div class="section">
        <div class="section-title">الجلسات</div>
        <table class="table">
          <tr>
            <th>الإجمالي</th>
            <th>المكتملة</th>
            <th>الإيرادات</th>
            <th>معدل الإنجاز</th>
          </tr>
          <tr>
            <td>${reportData.sessions.total}</td>
            <td>${reportData.sessions.completed}</td>
            <td>$${reportData.sessions.revenue.toFixed(2)}</td>
            <td>${reportData.summary.session_utilization.toFixed(1)}%</td>
          </tr>
        </table>
      </div>
    `;

    // قسم المستحقات
    html += `
      <div class="section">
        <div class="section-title">المستحقات</div>
        <table class="table">
          <tr>
            <th>النوع</th>
            <th>المبلغ</th>
            <th>العدد</th>
          </tr>
          <tr>
            <td>الحالية</td>
            <td>$${reportData.receivables.pending.amount.toFixed(2)}</td>
            <td>${reportData.receivables.pending.count}</td>
          </tr>
          <tr>
            <td>المتأخرة</td>
            <td>$${reportData.receivables.overdue.amount.toFixed(2)}</td>
            <td>${reportData.receivables.overdue.count}</td>
          </tr>
          <tr class="total-row">
            <td>الإجمالي</td>
            <td>$${reportData.receivables.total.toFixed(2)}</td>
            <td>${reportData.receivables.pending.count + reportData.receivables.overdue.count}</td>
          </tr>
        </table>
      </div>
    `;

    return html;
  }

  generateRecommendationsHTML(recommendations) {
    if (!recommendations || recommendations.length === 0) {
      return '<div class="info-box"><p>لا توجد توصيات حالياً. الأداء المالي جيد.</p></div>';
    }

    let html = '<div class="info-box"><h4>التوصيات:</h4><ul>';
    
    recommendations.forEach(rec => {
      const priorityClass = rec.priority === 'high' ? 'negative' : 
                           rec.priority === 'medium' ? '' : 'positive';
      
      const priorityText = rec.priority === 'high' ? 'عالية' : 
                          rec.priority === 'medium' ? 'متوسطة' : 'منخفضة';
      
      html += `
        <li class="${priorityClass}">
          <strong>${rec.description}</strong><br>
          <small>الأولوية: ${priorityText} - الإجراء المقترح: ${rec.action}</small>
        </li>
      `;
    });
    
    html += '</ul></div>';

    return html;
  }
}

module.exports = FinancialReportService;