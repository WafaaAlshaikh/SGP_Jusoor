// controllers/managerDashboardController.js
const { Session, SessionType, Child, Specialist, ChildRegistrationRequest, Institution, Manager, Donation, DonationAllocation } = require('../../model/index');
const { Op, Sequelize } = require('sequelize');
const Invoice = require('../../model/Invoice')

exports.getManagerDashboardStats = async (req, res) => {

  try {
    const managerId = req.user.user_id;

    console.log('Manager ID:', managerId);

    // الحصول على المؤسسة الخاصة بالمدير
    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId, 
        is_active: true 
      },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name', 'donation_balance']
      }]
    });

    if (!manager) {
      return res.status(404).json({
        success: false,
        message: 'المدير غير موجود'
      });
    }

    if (!manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'المؤسسة غير موجودة'
      });
    }

    const institutionId = manager.Institution.institution_id;
    console.log('Institution ID:', institutionId);

    const currentDate = new Date();
    console.log('Current Date:', currentDate);
    console.log('Current Month:', currentDate.getMonth() + 1); // +1 لأن الأشهر من 0-11
    
    // الشهر الحالي: من أول الشهر إلى آخر الشهر (ديسمبر)
    const currentMonthStart = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
    const currentMonthEnd = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0, 23, 59, 59);
    
    // الشهر الماضي: من أول الشهر الماضي إلى آخر الشهر الماضي (نوفمبر)
    const previousMonthStart = new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1);
    const previousMonthEnd = new Date(currentDate.getFullYear(), currentDate.getMonth(), 0, 23, 59, 59);

    console.log('Date ranges:', {
      currentMonth: {
        name: 'December',
        start: currentMonthStart,
        end: currentMonthEnd
      },
      previousMonth: {
        name: 'November', 
        start: previousMonthStart,
        end: previousMonthEnd
      }
    });

    // 1. إحصائيات الجلسات
    const sessionStats = await Session.findAll({
      where: {
        institution_id: institutionId,
        status: {
          [Op.in]: ['Scheduled', 'Confirmed', 'Completed']
        }
      },
      attributes: [
        'status',
        [Sequelize.fn('COUNT', Sequelize.col('session_id')), 'count']
      ],
      group: ['status'],
      raw: true
    });

    console.log('Session Stats:', sessionStats);

    const totalSessions = sessionStats.reduce((sum, stat) => sum + parseInt(stat.count), 0);
    
    // الجلسات اليوم
    const todaySessions = await Session.count({
      where: {
        institution_id: institutionId,
        date: currentDate.toISOString().split('T')[0],
        status: {
          [Op.in]: ['Scheduled', 'Confirmed']
        }
      }
    });

    console.log('Today Sessions:', todaySessions);

    // 2. الإيرادات الشهرية والمقارنة - بناءً على paid_date في Invoice
    let currentMonthRevenue = 0;
    let previousMonthRevenue = 0;

    try {
      // حساب إيرادات الشهر الحالي (ديسمبر): الفواتير المدفوعة هذا الشهر
      const currentMonthInvoices = await Invoice.findAll({
        where: {
          institution_id: institutionId,
          status: 'Paid',
          paid_date: {
            [Op.between]: [currentMonthStart, currentMonthEnd]
          }
        },
        attributes: ['invoice_id', 'total_amount', 'paid_date', 'status']
      });

      currentMonthRevenue = currentMonthInvoices.reduce((sum, invoice) => {
        const amount = parseFloat(invoice.total_amount) || 0;
        console.log(`Current Month Invoice: ID=${invoice.invoice_id}, Amount=${amount}, Paid Date=${invoice.paid_date}`);
        return sum + amount;
      }, 0);

      // حساب إيرادات الشهر السابق (نوفمبر): الفواتير المدفوعة الشهر الماضي
      const previousMonthInvoices = await Invoice.findAll({
        where: {
          institution_id: institutionId,
          status: 'Paid',
          paid_date: {
            [Op.between]: [previousMonthStart, previousMonthEnd]
          }
        },
        attributes: ['invoice_id', 'total_amount', 'paid_date', 'status']
      });

      previousMonthRevenue = previousMonthInvoices.reduce((sum, invoice) => {
        const amount = parseFloat(invoice.total_amount) || 0;
        console.log(`Previous Month Invoice: ID=${invoice.invoice_id}, Amount=${amount}, Paid Date=${invoice.paid_date}`);
        return sum + amount;
      }, 0);

      console.log('=== PAID INVOICE ANALYSIS ===');
      console.log('Current Month (December) Paid Invoices:', {
        count: currentMonthInvoices.length,
        total: currentMonthRevenue,
        invoices: currentMonthInvoices.map(inv => ({
          id: inv.invoice_id,
          amount: inv.total_amount,
          paid_date: inv.paid_date
        }))
      });
      
      console.log('Previous Month (November) Paid Invoices:', {
        count: previousMonthInvoices.length,
        total: previousMonthRevenue,
        invoices: previousMonthInvoices.map(inv => ({
          id: inv.invoice_id,
          amount: inv.total_amount,
          paid_date: inv.paid_date
        }))
      });

    } catch (invoiceError) {
      console.log('Invoice calculation error:', invoiceError.message);
      currentMonthRevenue = 0;
      previousMonthRevenue = 0;
    }

    console.log('Final Revenue:', {
      currentMonth: currentMonthRevenue,
      previousMonth: previousMonthRevenue
    });

    const revenueGrowth = previousMonthRevenue > 0 
      ? ((currentMonthRevenue - previousMonthRevenue) / previousMonthRevenue * 100).toFixed(1)
      : currentMonthRevenue > 0 ? 100 : 0;

    // 4.5. إحصائيات التبرعات للمؤسسة
    let donationStats = {
      totalDonations: 0,
      donationBalance: 0,
      totalAllocated: 0
    };

    try {
      const [totalDonationsRaw, totalAllocatedRaw] = await Promise.all([
        Donation.sum('amount', {
          where: { institution_id: institutionId }
        }),
        DonationAllocation.sum('amount_allocated', {
          where: { institution_id: institutionId }
        })
      ]);

      const institution = manager.Institution
        ? manager.Institution
        : await Institution.findByPk(institutionId);

      const donationBalance = institution
        ? parseFloat(institution.donation_balance || 0)
        : 0;

      donationStats = {
        totalDonations: parseFloat(totalDonationsRaw || 0),
        donationBalance,
        totalAllocated: parseFloat(totalAllocatedRaw || 0)
      };
    } catch (donationError) {
      console.log('Donation stats error:', donationError.message);
    }

    // 3. إحصائيات إضافية للفواتير حسب الحالة
    let invoiceStats = {};
    try {
      // جميع الفواتير للمؤسسة للتحقق
      const allInvoices = await Invoice.findAll({
        where: {
          institution_id: institutionId
        },
        attributes: ['invoice_id', 'total_amount', 'status', 'paid_date', 'due_date'],
        order: [['paid_date', 'DESC']]
      });

      console.log('=== ALL INVOICES FOR INSTITUTION ===');
      allInvoices.forEach(inv => {
        console.log(`Invoice ${inv.invoice_id}: Status=${inv.status}, Amount=${inv.total_amount}, Paid Date=${inv.paid_date}, Due Date=${inv.due_date}`);
      });

      // الفواتير المعلقة (Pending) المستحقة هذا الشهر
      const pendingInvoices = await Invoice.findAll({
        where: {
          institution_id: institutionId,
          status: 'Pending',
          due_date: {
            [Op.between]: [currentMonthStart, currentMonthEnd]
          }
        },
        attributes: ['total_amount']
      });

      const pendingRevenue = pendingInvoices.reduce((sum, invoice) => {
        return sum + (parseFloat(invoice.total_amount) || 0);
      }, 0);

      // الفواتير المتأخرة (Overdue)
      const overdueInvoices = await Invoice.findAll({
        where: {
          institution_id: institutionId,
          status: 'Overdue',
          due_date: {
            [Op.lte]: currentDate
          }
        },
        attributes: ['total_amount']
      });

      const overdueRevenue = overdueInvoices.reduce((sum, invoice) => {
        return sum + (parseFloat(invoice.total_amount) || 0);
      }, 0);

      invoiceStats = {
        paid: currentMonthRevenue,
        pending: pendingRevenue,
        overdue: overdueRevenue,
        paidCount: currentMonthRevenue > 0 ? await Invoice.count({
          where: {
            institution_id: institutionId,
            status: 'Paid',
            paid_date: {
              [Op.between]: [currentMonthStart, currentMonthEnd]
            }
          }
        }) : 0,
        pendingCount: pendingInvoices.length,
        overdueCount: overdueInvoices.length
      };

    } catch (invoiceStatsError) {
      console.log('Invoice stats error:', invoiceStatsError.message);
      invoiceStats = {
        paid: currentMonthRevenue,
        pending: 0,
        overdue: 0,
        paidCount: 0,
        pendingCount: 0,
        overdueCount: 0
      };
    }

    // 4. توزيع أنواع الجلسات
    // 4. توزيع أنواع الجلسات - جميع الأنواع حتى بدون جلسات
    let sessionDistribution = [];
    try {
      // جلب جميع أنواع الجلسات المعتمدة للمؤسسة
      const sessionTypes = await SessionType.findAll({
        where: {
          institution_id: institutionId,
          approval_status: 'Approved'
        },
        attributes: ['session_type_id', 'name'],
        order: [['name', 'ASC']] // ترتيب حسب الاسم
      });

      console.log('All Session Types in Institution:', sessionTypes.map(st => ({
        id: st.session_type_id,
        name: st.name
      })));

      // حساب عدد الجلسات لكل نوع جلسة
      const distributionPromises = sessionTypes.map(async (sessionType) => {
        const count = await Session.count({
          where: {
            institution_id: institutionId,
            session_type_id: sessionType.session_type_id,
            status: {
              [Op.in]: ['Scheduled', 'Confirmed', 'Completed']
            }
          }
        });

        return {
          name: sessionType.name,
          count: count,
          hasSessions: count > 0
        };
      });

      const distributionResults = await Promise.all(distributionPromises);
      
      // حساب العدد الإجمالي للجلسات (من الأنواع التي لديها جلسات)
      const totalSessionsForDistribution = distributionResults.reduce((sum, item) => sum + item.count, 0);

      // تحويل النتائج إلى التنسيق المطلوب
      sessionDistribution = distributionResults.map(item => ({
        category: item.name, // استخدام الاسم كنوع الفئة
        name: item.name, // نفس الشيء للتوافق
        count: item.count,
        hasSessions: item.hasSessions, // إضافة حقل لتحديد إذا كان فيه جلسات أم لا
        percentage: totalSessionsForDistribution > 0 
          ? Math.round((item.count / totalSessionsForDistribution) * 100)
          : 0
      }));

      console.log('Session Distribution (All Types):', {
        totalTypes: sessionDistribution.length,
        typesWithSessions: sessionDistribution.filter(item => item.hasSessions).length,
        totalSessions: totalSessionsForDistribution,
        distribution: sessionDistribution
      });

    } catch (distributionError) {
      console.log('Session distribution error:', distributionError.message);
      // في حالة الخطأ، نرجع مصفوفة فارغة بدل القيم الافتراضية
      sessionDistribution = [];
    }

    console.log('Final Session Distribution:', sessionDistribution);

    // 5. عدد الأطفال
    const totalChildren = await Child.count({
      where: {
        current_institution_id: institutionId,
        registration_status: 'Approved',
        deleted_at: null
      }
    });

    console.log('Total Children:', totalChildren);

    // 6. عدد الأخصائيين
    const totalSpecialists = await Specialist.count({
      where: {
        institution_id: institutionId,
        approval_status: 'Approved'
      }
    });

    console.log('Total Specialists:', totalSpecialists);

    // 7. طلبات التسجيل المنتظرة
    const pendingRegistrationRequests = await ChildRegistrationRequest.count({
      where: {
        institution_id: institutionId,
        status: 'Pending'
      }
    });

    console.log('Pending Registration Requests:', pendingRegistrationRequests);

    // 8. جلسات هذا الشهر (من أول الشهر إلى آخر الشهر)
    const monthlySessions = await Session.count({
      where: {
        institution_id: institutionId,
        date: {
          [Op.between]: [currentMonthStart.toISOString().split('T')[0], currentMonthEnd.toISOString().split('T')[0]]
        },
        status: {
          [Op.in]: ['Scheduled', 'Confirmed', 'Completed']
        }
      }
    });

    // 9. جلسات الشهر الماضي للمقارنة
    const previousMonthSessions = await Session.count({
      where: {
        institution_id: institutionId,
        date: {
          [Op.between]: [previousMonthStart.toISOString().split('T')[0], previousMonthEnd.toISOString().split('T')[0]]
        },
        status: {
          [Op.in]: ['Scheduled', 'Confirmed', 'Completed']
        }
      }
    });

    const sessionGrowth = previousMonthSessions > 0 
      ? ((monthlySessions - previousMonthSessions) / previousMonthSessions * 100).toFixed(1)
      : monthlySessions > 0 ? 100 : 0;

    res.status(200).json({
      success: true,
      data: {
        institution: {
          id: manager.Institution.institution_id,
          name: manager.Institution.name
        },
        sessionStats: {
          totalSessions,
          todaySessions,
          monthlySessions,
          sessionGrowth: parseFloat(sessionGrowth),
          byStatus: sessionStats.reduce((acc, stat) => {
            acc[stat.status] = parseInt(stat.count);
            return acc;
          }, {})
        },
        revenue: {
          currentMonth: parseFloat(currentMonthRevenue),     // الفواتير المدفوعة في ديسمبر
          previousMonth: parseFloat(previousMonthRevenue),   // الفواتير المدفوعة في نوفمبر
          growth: parseFloat(revenueGrowth),
          breakdown: {
            paid: invoiceStats.paid,                        // المدفوع فعلياً في ديسمبر
            pending: invoiceStats.pending,                  // المستحق ولم يدفع بعد في ديسمبر
            overdue: invoiceStats.overdue                   // المتأخر
          }
        },
        donations: donationStats,
        sessionDistribution,
        children: {
          total: totalChildren
        },
        specialists: {
          total: totalSpecialists
        },
        pendingRequests: {
          registrations: pendingRegistrationRequests
        },
        invoiceStats: {
          paidCount: invoiceStats.paidCount,
          pendingCount: invoiceStats.pendingCount,
          overdueCount: invoiceStats.overdueCount
        },
        periods: {
          currentMonth: {
            start: currentMonthStart.toISOString().split('T')[0],
            end: currentMonthEnd.toISOString().split('T')[0]
          },
          previousMonth: {
            start: previousMonthStart.toISOString().split('T')[0],
            end: previousMonthEnd.toISOString().split('T')[0]
          }
        }
      }
    });

  } catch (error) {
    console.error('Error in getManagerDashboardStats:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب إحصائيات لوحة التحكم',
      error: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};

// تقرير مالي مختصر للمؤسسة مع تأثير التبرعات
exports.getFinancialReport = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const manager = await Manager.findOne({
      where: {
        manager_id: managerId,
        is_active: true
      },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name', 'donation_balance']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'المدير أو المؤسسة غير موجودة'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const currentDate = new Date();

    const currentMonthStart = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
    const currentMonthEnd = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0, 23, 59, 59);

    let currentMonthRevenue = 0;
    let pendingRevenue = 0;
    let overdueRevenue = 0;
    let paidInvoicesCount = 0;
    let pendingInvoicesCount = 0;
    let overdueInvoicesCount = 0;

    try {
      const paidInvoices = await Invoice.findAll({
        where: {
          institution_id: institutionId,
          status: 'Paid',
          paid_date: {
            [Op.between]: [currentMonthStart, currentMonthEnd]
          }
        },
        attributes: ['invoice_id', 'total_amount']
      });

      currentMonthRevenue = paidInvoices.reduce((sum, inv) => {
        return sum + (parseFloat(inv.total_amount) || 0);
      }, 0);

      paidInvoicesCount = paidInvoices.length;

      const pendingInvoices = await Invoice.findAll({
        where: {
          institution_id: institutionId,
          status: 'Pending',
          due_date: {
            [Op.between]: [currentMonthStart, currentMonthEnd]
          }
        },
        attributes: ['total_amount']
      });

      pendingRevenue = pendingInvoices.reduce((sum, inv) => {
        return sum + (parseFloat(inv.total_amount) || 0);
      }, 0);

      pendingInvoicesCount = pendingInvoices.length;

      const overdueInvoices = await Invoice.findAll({
        where: {
          institution_id: institutionId,
          status: 'Overdue',
          due_date: {
            [Op.lte]: currentDate
          }
        },
        attributes: ['total_amount']
      });

      overdueRevenue = overdueInvoices.reduce((sum, inv) => {
        return sum + (parseFloat(inv.total_amount) || 0);
      }, 0);

      overdueInvoicesCount = overdueInvoices.length;
    } catch (invoiceError) {
      console.log('Financial report invoice error:', invoiceError.message);
    }

    let donationSummary = {
      totalDonationsAllTime: 0,
      totalAllocatedAllTime: 0,
      donationBalance: 0,
      donationsThisMonth: 0,
      allocatedThisMonth: 0,
    };

    try {
      const [
        totalDonationsAllTimeRaw,
        totalAllocatedAllTimeRaw,
        donationsThisMonthRaw,
        allocatedThisMonthRaw,
      ] = await Promise.all([
        Donation.sum('amount', {
          where: { institution_id: institutionId }
        }),
        DonationAllocation.sum('amount_allocated', {
          where: { institution_id: institutionId }
        }),
        Donation.sum('amount', {
          where: {
            institution_id: institutionId,
            date: { [Op.between]: [currentMonthStart, currentMonthEnd] }
          }
        }),
        DonationAllocation.sum('amount_allocated', {
          where: {
            institution_id: institutionId,
            created_at: { [Op.between]: [currentMonthStart, currentMonthEnd] }
          }
        }),
      ]);

      const donationBalance = parseFloat(manager.Institution.donation_balance || 0);

      donationSummary = {
        totalDonationsAllTime: parseFloat(totalDonationsAllTimeRaw || 0),
        totalAllocatedAllTime: parseFloat(totalAllocatedAllTimeRaw || 0),
        donationBalance,
        donationsThisMonth: parseFloat(donationsThisMonthRaw || 0),
        allocatedThisMonth: parseFloat(allocatedThisMonthRaw || 0),
      };
    } catch (donationError) {
      console.log('Financial report donation error:', donationError.message);
    }

    const totalSupportedFromDonations = donationSummary.allocatedThisMonth;
    const totalEconomicValue = currentMonthRevenue + pendingRevenue + overdueRevenue;
    const donationCoveragePercentage = totalEconomicValue > 0
      ? parseFloat(((totalSupportedFromDonations / totalEconomicValue) * 100).toFixed(1))
      : 0;

    return res.status(200).json({
      success: true,
      data: {
        institution: {
          id: manager.Institution.institution_id,
          name: manager.Institution.name
        },
        period: {
          start: currentMonthStart.toISOString().split('T')[0],
          end: currentMonthEnd.toISOString().split('T')[0]
        },
        revenue: {
          paid: currentMonthRevenue,
          pending: pendingRevenue,
          overdue: overdueRevenue,
          paidCount: paidInvoicesCount,
          pendingCount: pendingInvoicesCount,
          overdueCount: overdueInvoicesCount
        },
        donations: {
          donationBalance: donationSummary.donationBalance,
          donationsThisMonth: donationSummary.donationsThisMonth,
          allocatedThisMonth: donationSummary.allocatedThisMonth,
          totalDonationsAllTime: donationSummary.totalDonationsAllTime,
          totalAllocatedAllTime: donationSummary.totalAllocatedAllTime,
        },
        impact: {
          totalEconomicValue,
          totalSupportedFromDonations,
          donationCoveragePercentage
        }
      }
    });

  } catch (error) {
    console.error('Error in getFinancialReport:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب التقرير المالي',
      error: error.message
    });
  }
};

// تفاصيل التبرعات للمؤسسة (قائمة التبرعات + قائمة التخصيصات)
exports.getDonationDetails = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const manager = await Manager.findOne({
      where: {
        manager_id: managerId,
        is_active: true
      },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'المدير أو المؤسسة غير موجودة'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // قائمة التبرعات للمؤسسة
    const donations = await Donation.findAll({
      where: { institution_id: institutionId },
      order: [['date', 'DESC']],
      attributes: ['donation_id', 'donor_id', 'amount', 'date', 'campaign_id']
    });

    // قائمة التخصيصات من رصيد التبرعات
    const allocations = await DonationAllocation.findAll({
      where: { institution_id: institutionId },
      order: [['created_at', 'DESC']],
      attributes: ['allocation_id', 'donation_id', 'invoice_id', 'financial_assistance_request_id', 'amount_allocated', 'created_at']
    });

    // إحضار معلومات أساسية عن الفواتير المرتبطة لتحسين العرض في الواجهة
    const invoiceIds = allocations
      .map(a => a.invoice_id)
      .filter(id => !!id);

    let invoicesById = {};
    if (invoiceIds.length > 0) {
      const invoices = await Invoice.findAll({
        where: {
          invoice_id: {
            [Op.in]: invoiceIds
          }
        },
        attributes: ['invoice_id', 'total_amount', 'status', 'paid_date']
      });

      invoicesById = invoices.reduce((acc, inv) => {
        acc[inv.invoice_id] = inv;
        return acc;
      }, {});
    }

    return res.status(200).json({
      success: true,
      data: {
        institution: {
          id: manager.Institution.institution_id,
          name: manager.Institution.name
        },
        donations,
        allocations,
        invoices: invoicesById
      }
    });

  } catch (error) {
    console.error('Error in getDonationDetails:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب تفاصيل التبرعات',
      error: error.message
    });
  }
};

// دالة للتحقق من النماذج
exports.checkModels = async (req, res) => {
  try {
    const models = {
      Session: typeof Session,
      SessionType: typeof SessionType,
      Child: typeof Child,
      Specialist: typeof Specialist,
      Invoice: typeof Invoice,
      ChildRegistrationRequest: typeof ChildRegistrationRequest,
      Institution: typeof Institution,
      Manager: typeof Manager
    };

    // اختبار كل نموذج
    const tests = {};
    
    if (Session) {
      tests.Session = await Session.count().catch(e => e.message);
    }
    
    if (SessionType) {
      tests.SessionType = await SessionType.count().catch(e => e.message);
    }
    
    if (Child) {
      tests.Child = await Child.count().catch(e => e.message);
    }

    if (Specialist) {
      tests.Specialist = await Specialist.count().catch(e => e.message);
    }

    res.json({
      models,
      tests,
      sequelize: {
        Op: typeof Op,
        Sequelize: typeof Sequelize
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// أضف هذا الـ route للت debugging
exports.getDebugInfo = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [Institution]
    });

    if (!manager) {
      return res.status(404).json({ error: 'Manager not found' });
    }

    // عدِّد جميع الجداول للتأكد من البيانات
    const childrenCount = await Child.count({
      where: { current_institution_id: manager.Institution.institution_id }
    });

    const specialistsCount = await Specialist.count({
      where: { institution_id: manager.Institution.institution_id }
    });

    const sessionsCount = await Session.count({
      where: { institution_id: manager.Institution.institution_id }
    });

    const sessionTypesCount = await SessionType.count({
      where: { institution_id: manager.Institution.institution_id }
    });

    res.json({
      manager: {
        id: manager.manager_id,
        institution: manager.Institution
      },
      counts: {
        children: childrenCount,
        specialists: specialistsCount,
        sessions: sessionsCount,
        sessionTypes: sessionTypesCount
      }
    });

  } catch (error) {
    console.error('Debug error:', error);
    res.status(500).json({ error: error.message });
  }
};

// دالة لفحص الفواتير بالتفصيل
exports.getInvoiceDebugInfo = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [Institution]
    });

    if (!manager) {
      return res.status(404).json({ error: 'Manager not found' });
    }

    const institutionId = manager.Institution.institution_id;

    // الحصول على جميع الفواتير للمؤسسة
    const allInvoices = await Invoice.findAll({
      where: { institution_id: institutionId },
      attributes: ['invoice_id', 'total_amount', 'status', 'paid_date', 'due_date', 'issued_date'],
      order: [['paid_date', 'DESC']]
    });

    // إحصائيات الفواتير
    const invoiceStats = await Invoice.findAll({
      where: { institution_id: institutionId },
      attributes: [
        'status',
        [Sequelize.fn('COUNT', Sequelize.col('invoice_id')), 'count'],
        [Sequelize.fn('SUM', Sequelize.col('total_amount')), 'total']
      ],
      group: ['status'],
      raw: true
    });

    res.json({
      institution: manager.Institution.name,
      allInvoices: allInvoices,
      invoiceStats: invoiceStats
    });

  } catch (error) {
    console.error('Invoice debug error:', error);
    res.status(500).json({ error: error.message });
  }
};
// أضف هذا الـ route للت debugging
exports.getDebugInfo = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [Institution]
    });

    if (!manager) {
      return res.status(404).json({ error: 'Manager not found' });
    }

    // عدِّد جميع الجداول للتأكد من البيانات
    const childrenCount = await Child.count({
      where: { current_institution_id: manager.Institution.institution_id }
    });

    const specialistsCount = await Specialist.count({
      where: { institution_id: manager.Institution.institution_id }
    });

    const sessionsCount = await Session.count({
      where: { institution_id: manager.Institution.institution_id }
    });

    const sessionTypesCount = await SessionType.count({
      where: { institution_id: manager.Institution.institution_id }
    });

    res.json({
      manager: {
        id: manager.manager_id,
        institution: manager.Institution
      },
      counts: {
        children: childrenCount,
        specialists: specialistsCount,
        sessions: sessionsCount,
        sessionTypes: sessionTypesCount
      }
    });

  } catch (error) {
    console.error('Debug error:', error);
    res.status(500).json({ error: error.message });
  }
};

// أضف هذا الـ route للت debugging
exports.getDebugInfo = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [Institution]
    });

    if (!manager) {
      return res.status(404).json({ error: 'Manager not found' });
    }

    // عدِّد جميع الجداول للتأكد من البيانات
    const childrenCount = await Child.count({
      where: { current_institution_id: manager.Institution.institution_id }
    });

    const specialistsCount = await Specialist.count({
      where: { institution_id: manager.Institution.institution_id }
    });

    const sessionsCount = await Session.count({
      where: { institution_id: manager.Institution.institution_id }
    });

    res.json({
      manager: {
        id: manager.manager_id,
        institution: manager.Institution
      },
      counts: {
        children: childrenCount,
        specialists: specialistsCount,
        sessions: sessionsCount
      }
    });

  } catch (error) {
    console.error('Debug error:', error);
    res.status(500).json({ error: error.message });
  }
};