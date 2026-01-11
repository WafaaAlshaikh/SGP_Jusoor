// controllers/managerDashboardController.js
const { Session, SessionType, Child, Specialist, ChildRegistrationRequest, Institution, Manager, Donation, DonationAllocation,EquipmentDonation,EquipmentCategory,User, InstitutionEquipmentInventory, ChildEquipmentNeed, EquipmentAllocation, EquipmentItemHistory, EquipmentDonationCampaign } = require('../../model/index');
const { Op, Sequelize } = require('sequelize');
const Invoice = require('../../model/Invoice')

async function resolveManagerInstitution(managerUserId) {
  const manager = await Manager.findOne({
    where: {
      manager_id: managerUserId,
      is_active: true,
    },
    include: [{
      model: Institution,
      attributes: ['institution_id', 'name', 'donation_balance'],
    }],
  });

  if (manager && manager.Institution) {
    return {
      institutionId: manager.Institution.institution_id,
      institution: manager.Institution,
    };
  }

  const user = await User.findOne({
    where: { user_id: managerUserId },
    attributes: ['user_id', 'role', 'institution_id'],
  });

  if (!user || user.role !== 'Manager' || !user.institution_id) {
    return null;
  }

  const institution = await Institution.findOne({
    where: { institution_id: user.institution_id },
    attributes: ['institution_id', 'name', 'donation_balance'],
  });

  if (!institution) {
    return null;
  }

  return {
    institutionId: institution.institution_id,
    institution,
  };
}


exports.getManagerDashboardStats = async (req, res) => {

  try {
    const managerId = req.user.user_id;

    console.log('Manager ID:', managerId);

    const resolved = await resolveManagerInstitution(managerId);
    if (!resolved) {
      return res.status(404).json({
        success: false,
        message: 'المدير أو المؤسسة غير موجودة'
      });
    }

    const institutionId = resolved.institutionId;
    const institution = resolved.institution;
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
          where: { institution_id: institutionId, status: 'completed', payment_status: 'paid' }
        }),
        DonationAllocation.sum('amount_allocated', {
          where: { institution_id: institutionId }
        })
      ]);

      const donationBalance = parseFloat(institution.donation_balance || 0);

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
          id: institution.institution_id,
          name: institution.name,
          donation_balance: institution.donation_balance || 0
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

    const resolved = await resolveManagerInstitution(managerId);
    if (!resolved) {
      return res.status(404).json({
        success: false,
        message: 'المدير أو المؤسسة غير موجودة'
      });
    }

    const institutionId = resolved.institutionId;
    const institution = resolved.institution;

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
          where: { institution_id: institutionId, status: 'completed', payment_status: 'paid' }
        }),
        DonationAllocation.sum('amount_allocated', {
          where: { institution_id: institutionId }
        }),
        Donation.sum('amount', {
          where: {
            institution_id: institutionId,
            status: 'completed',
            payment_status: 'paid',
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

      const donationBalance = parseFloat(institution.donation_balance || 0);

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
          id: institution.institution_id,
          name: institution.name
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

    const resolved = await resolveManagerInstitution(managerId);
    if (!resolved) {
      return res.status(404).json({
        success: false,
        message: 'المدير أو المؤسسة غير موجودة'
      });
    }

    const institutionId = resolved.institutionId;
    const institution = resolved.institution;

    // قائمة التبرعات للمؤسسة
    const donations = await Donation.findAll({
      where: { institution_id: institutionId, status: 'completed', payment_status: 'paid' },
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
          id: institution.institution_id,
          name: institution.name
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

// الحصول على إحصائيات التبرعات العينية
exports.getEquipmentDonationStats = async (req, res) => {
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

    // إحصائيات حسب الحالة
    const statusStats = await EquipmentDonation.findAll({
      where: { institution_id: institutionId },
      attributes: [
        'status',
        [Sequelize.fn('COUNT', Sequelize.col('equipment_donation_id')), 'count']
      ],
      group: ['status'],
      raw: true
    });

    // إحصائيات حسب حالة الجهاز
    const conditionStats = await EquipmentDonation.findAll({
      where: { institution_id: institutionId },
      attributes: [
        'condition',
        [Sequelize.fn('COUNT', Sequelize.col('equipment_donation_id')), 'count']
      ],
      group: ['condition'],
      raw: true
    });

    // إحصائيات زمنية (آخر 30 يوم)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const recentDonations = await EquipmentDonation.count({
      where: {
        institution_id: institutionId,
        created_at: { [Op.gte]: thirtyDaysAgo }
      }
    });

    // إجمالي التبرعات المقدمة
    const totalDonations = await EquipmentDonation.count({
      where: { institution_id: institutionId }
    });

    // التبرعات المسلمة
    const deliveredDonations = await EquipmentDonation.count({
      where: {
        institution_id: institutionId,
        status: 'delivered'
      }
    });

    // التبرعات الأخيرة (آخر 5)
    const recentEquipmentDonations = await EquipmentDonation.findAll({
      where: { institution_id: institutionId },
      include: [
        {
          model: EquipmentCategory,
          as: 'category',
          attributes: ['name_ar', 'name_en'],
          required: false
        },
        {
          model: User,
          as: 'donor',
          attributes: ['full_name', 'profile_picture'],
          required: false
        }
      ],
      order: [['created_at', 'DESC']],
      limit: 5
    });

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          totalDonations,
          deliveredDonations,
          recentDonations30Days: recentDonations
        },
        byStatus: statusStats.reduce((acc, stat) => {
          acc[stat.status] = parseInt(stat.count);
          return acc;
        }, {}),
        byCondition: conditionStats.reduce((acc, stat) => {
          acc[stat.condition] = parseInt(stat.count);
          return acc;
        }, {}),
        recentDonations: recentEquipmentDonations.map(donation => ({
          id: donation.equipment_donation_id,
          equipment_name: donation.equipment_name,
          condition: donation.condition,
          status: donation.status,
          donor_name: donation.contact_person || (donation.donor?.full_name || 'Anonymous'),
          category: donation.category?.name_ar || donation.category?.name_en,
          created_at: donation.created_at,
          tracking_code: `EQ${donation.equipment_donation_id.toString().padStart(6, '0')}`
        }))
      }
    });

  } catch (error) {
    console.error('Error in getEquipmentDonationStats:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب إحصائيات التبرعات العينية',
      error: error.message
    });
  }
};

// الحصول على قائمة التبرعات العينية مع الفلاتر
exports.getEquipmentDonationsList = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId,
        is_active: true 
      },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية الوصول'
      });
    }

    const institutionId = manager.Institution.institution_id;
    const { 
      status, 
      condition, 
      category_id, 
      search,
      startDate,
      endDate,
      page = 1, 
      limit = 10 
    } = req.query;
    
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 10;
    const offset = (pageNum - 1) * limitNum;

    // بناء where clause مع الفلاتر
    const whereClause = { institution_id: institutionId };
    
    if (status && status !== 'all') {
      whereClause.status = status;
    }
    
    if (condition && condition !== 'all') {
      whereClause.condition = condition;
    }
    
    if (category_id && category_id !== 'all') {
      whereClause.category_id = parseInt(category_id);
    }
    
    if (search) {
      whereClause[Op.or] = [
        { equipment_name: { [Op.like]: `%${search}%` } },
        { contact_person: { [Op.like]: `%${search}%` } },
        { contact_phone: { [Op.like]: `%${search}%` } }
      ];
    }
    
    if (startDate || endDate) {
      whereClause.created_at = {};
      if (startDate) {
        whereClause.created_at[Op.gte] = new Date(startDate);
      }
      if (endDate) {
        whereClause.created_at[Op.lte] = new Date(endDate);
      }
    }

    const { count, rows } = await EquipmentDonation.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: EquipmentCategory,
          attributes: ['category_id', 'name_ar', 'name_en'],
          as: 'category',
          required: false
        },
        {
          model: User,
          as: 'donor',
          attributes: ['user_id', 'full_name', 'profile_picture', 'email'],
          required: false
        }
      ],
      order: [['created_at', 'DESC']],
      offset,
      limit: limitNum
    });

    // جلب الفئات المتاحة للفلترة
    const categories = await EquipmentCategory.findAll({
      where: { is_active: true },
      attributes: ['category_id', 'name_ar', 'name_en'],
      order: [['name_ar', 'ASC']]
    });

    return res.status(200).json({
      success: true,
      data: {
        donations: rows.map(donation => ({
          id: donation.equipment_donation_id,
          equipment_name: donation.equipment_name,
          description: donation.description,
          condition: donation.condition,
          estimated_value: donation.estimated_value,
          delivery_type: donation.delivery_type,
          status: donation.status,
          admin_notes: donation.admin_notes,
          rejection_reason: donation.rejection_reason,
          contact_person: donation.contact_person,
          contact_phone: donation.contact_phone,
          contact_email: donation.contact_email,
          preferred_date: donation.preferred_date,
          actual_delivery_date: donation.actual_delivery_date,
          images: donation.images,
          created_at: donation.created_at,
          updated_at: donation.updated_at,
          category: donation.category,
          donor: donation.donor,
          tracking_code: `EQ${donation.equipment_donation_id.toString().padStart(6, '0')}`,
          institution_id: donation.institution_id
        })),
        filters: {
          categories,
          statuses: [
            { value: 'pending', label: 'قيد المراجعة' },
            { value: 'approved', label: 'مقبول' },
            { value: 'rejected', label: 'مرفوض' },
            { value: 'scheduled', label: 'مجدول للاستلام' },
            { value: 'delivered', label: 'تم التسليم' },
            { value: 'cancelled', label: 'ملغي' }
          ],
          conditions: [
            { value: 'new', label: 'جديد' },
            { value: 'used_good', label: 'مستعمل - حالة جيدة' },
            { value: 'used_fair', label: 'مستعمل - حالة متوسطة' },
            { value: 'needs_repair', label: 'يحتاج صيانة' }
          ]
        },
        pagination: {
          page: pageNum,
          limit: limitNum,
          total: count,
          pages: Math.ceil(count / limitNum)
        }
      }
    });

  } catch (error) {
    console.error('Error fetching equipment donations list:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في جلب قائمة التبرعات العينية',
      error: error.message
    });
  }
};

// تحديث حالة التبرع العيني
exports.updateEquipmentDonationStatus = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { id } = req.params;
    const { status, admin_notes, rejection_reason, actual_delivery_date } = req.body;

    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId,
        is_active: true 
      },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية الوصول'
      });
    }

    const institutionId = manager.Institution.institution_id;

    const donation = await EquipmentDonation.findOne({
      where: {
        equipment_donation_id: id,
        institution_id: institutionId
      },
      include: [
        {
          model: User,
          as: 'donor',
          attributes: ['user_id', 'full_name', 'email']
        }
      ]
    });

    if (!donation) {
      return res.status(404).json({
        success: false,
        message: 'طلب التبرع غير موجود'
      });
    }

    const validStatuses = ['pending', 'approved', 'rejected', 'scheduled', 'delivered', 'cancelled'];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'حالة غير صالحة'
      });
    }

    const updateData = {
      status: status || donation.status,
      admin_notes: admin_notes || donation.admin_notes,
      updated_at: new Date()
    };

    if (status === 'rejected' && rejection_reason) {
      updateData.rejection_reason = rejection_reason;
    }

    if (actual_delivery_date) {
      updateData.actual_delivery_date = new Date(actual_delivery_date);
    }

    const oldStatus = donation.status;
    await donation.update(updateData);

    if (oldStatus !== 'delivered' && updateData.status === 'delivered') {
      const existingInventoryItem = await InstitutionEquipmentInventory.findOne({
        where: {
          institution_id: institutionId,
          source_donation_id: donation.equipment_donation_id,
        }
      });

      const inventoryItem = existingInventoryItem || await InstitutionEquipmentInventory.create({
        institution_id: institutionId,
        category_id: donation.category_id || null,
        equipment_name: donation.equipment_name,
        equipment_type: null,
        condition: donation.condition,
        quantity_available: 1,
        quantity_reserved: 0,
        usage_type: 'available',
        internal_department: null,
        source_donation_id: donation.equipment_donation_id,
        notes: donation.description || null,
        created_at: new Date(),
        updated_at: new Date()
      });

      if (!existingInventoryItem) {
        await EquipmentItemHistory.create({
          institution_id: institutionId,
          inventory_item_id: inventoryItem.inventory_item_id,
          event_type: 'inventory_added_from_donation',
          related_id: donation.equipment_donation_id,
          actor_user_id: managerId,
          details: {
            equipment_name: donation.equipment_name,
            donation_id: donation.equipment_donation_id
          },
          created_at: new Date()
        });
      }

      const normalizedDonationName = (donation.equipment_name || '').trim();
      const needBaseWhere = {
        institution_id: institutionId,
        status: 'open'
      };
      if (donation.category_id) {
        needBaseWhere.category_id = donation.category_id;
      }

      // Prefer needs that match the equipment name/type (fallback to category only)
      let need = null;
      if (normalizedDonationName.length > 0) {
        need = await ChildEquipmentNeed.findOne({
          where: {
            ...needBaseWhere,
            [Op.or]: [
              { equipment_name: { [Op.like]: `%${normalizedDonationName}%` } },
              { equipment_type: { [Op.like]: `%${normalizedDonationName}%` } },
            ]
          },
          order: [['priority_score', 'DESC'], ['created_at', 'ASC']]
        });
      }

      if (!need) {
        need = await ChildEquipmentNeed.findOne({
          where: needBaseWhere,
          order: [['priority_score', 'DESC'], ['created_at', 'ASC']]
        });
      }

      if (need) {
        if ((need.priority_score || 0) >= 70 && inventoryItem.quantity_available > 0) {
          await inventoryItem.update({
            quantity_available: Math.max(0, inventoryItem.quantity_available - 1),
            quantity_reserved: (inventoryItem.quantity_reserved || 0) + 1,
            usage_type: 'reserved',
            updated_at: new Date()
          });

          const allocation = await EquipmentAllocation.create({
            institution_id: institutionId,
            inventory_item_id: inventoryItem.inventory_item_id,
            need_id: need.need_id,
            child_id: need.child_id,
            allocation_mode: 'auto',
            allocated_by_user_id: null,
            usage_type: 'child',
            status: 'pending_receipt',
            created_at: new Date(),
            updated_at: new Date()
          });

          await need.update({ status: 'allocated', updated_at: new Date() });

          const campaign = await EquipmentDonationCampaign.findOne({ where: { need_id: need.need_id } });
          if (campaign && !['fulfilled', 'closed'].includes(campaign.status)) {
            const nextFulfilled = Math.min(
              campaign.quantity_needed || 1,
              (campaign.quantity_fulfilled || 0) + 1
            );
            const nextStatus = nextFulfilled >= (campaign.quantity_needed || 1) ? 'fulfilled' : 'partially_fulfilled';
            await campaign.update({
              status: nextStatus,
              quantity_fulfilled: nextFulfilled,
              updated_at: new Date()
            });
          }

          await EquipmentItemHistory.create({
            institution_id: institutionId,
            inventory_item_id: inventoryItem.inventory_item_id,
            event_type: 'auto_allocated',
            related_id: allocation.allocation_id,
            actor_user_id: null,
            details: { need_id: need.need_id, child_id: need.child_id, priority_score: need.priority_score },
            created_at: new Date()
          });
        } else {
          await need.update({ status: 'matched', updated_at: new Date() });

          await EquipmentItemHistory.create({
            institution_id: institutionId,
            inventory_item_id: inventoryItem.inventory_item_id,
            event_type: 'match_suggested',
            related_id: need.need_id,
            actor_user_id: managerId,
            details: { need_id: need.need_id, priority_score: need.priority_score, child_id: need.child_id },
            created_at: new Date()
          });
        }
      }
    }

    return res.status(200).json({
      success: true,
      message: 'تم تحديث حالة الطلب بنجاح',
      data: {
        id: donation.equipment_donation_id,
        status: donation.status,
        tracking_code: `EQ${donation.equipment_donation_id.toString().padStart(6, '0')}`
      }
    });

  } catch (error) {
    console.error('Error updating equipment donation:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في تحديث حالة الطلب',
      error: error.message
    });
  }
};