// services/autoFinancialAidService.js
const { 
  Session, 
  SessionType, 
  Parent, 
  Child, 
  Institution, 
  DonationAllocation, 
  Invoice, 
  SessionFinancialAidRequest,
  Notification,
  sequelize 
} = require('../model');
const { Op } = require('sequelize');

class AutoFinancialAidService {
  
  /**
   * التحقق التلقائي وتطبيق المساعدة المالية عند إنشاء أي جلسة
   */
  static async autoApplyFinancialAid(sessionId) {
    try {
      console.log(`🤖 بدء التحقق التلقائي للمساعدة المالية للجلسة: ${sessionId}`);
      
      const session = await Session.findByPk(sessionId, {
        include: [
          {
            model: Child,
            as: 'child',
            attributes: ['child_id', 'parent_id', 'full_name']
          },
          {
            model: SessionType,
            attributes: ['session_type_id', 'price', 'name']
          },
          {
            model: Institution,
            as: 'institution',
            attributes: ['institution_id', 'name', 'donation_balance']
          }
        ]
      });

      if (!session) {
        throw new Error('Session not found');
      }

      // 🔍 1. التحقق من الحالة المالية للأهل
      const parent = await Parent.findOne({
        where: { parent_id: session.child.parent_id }
      });

      // إذا لم يكن هناك تقييم مالي، نستخدم القيم الافتراضية (بدون مساعدة)
      let financialTier = 'tier_5_no_assistance';
      let financialScore = 0;
      let discountPercentage = 0;

      if (parent && parent.financial_score && parent.financial_tier) {
        financialTier = parent.financial_tier;
        financialScore = parent.financial_score;
        
        // 🎯 حساب نسبة الخصم التلقائية بناءً على الفئة المالية
        discountPercentage = this.calculateAutoDiscountPercentage(financialTier, financialScore);
      }

      console.log(`💰 الحالة المالية: ${financialTier} (${financialScore}) - نسبة الخصم: ${discountPercentage}%`);

      // 🔍 2. التحقق من رصيد التبرعات المتاح
      const availableDonationBalance = parseFloat(session.institution?.donation_balance || 0);
      const sessionBasePrice = parseFloat(session.SessionType?.price || 0);
      
      console.log(`💵 سعر الجلسة: ${sessionBasePrice}, رصيد التبرعات: ${availableDonationBalance}`);

      // 🔍 3. حساب المبلغ الذي يمكن تغطيته من التبرعات
      const discountAmount = (sessionBasePrice * discountPercentage) / 100;
      const maxDiscountFromDonations = Math.min(discountAmount, availableDonationBalance);
      const actualDiscountPercentage = (maxDiscountFromDonations / sessionBasePrice) * 100;
      
      console.log(`📊 يمكن تغطية: ${maxDiscountFromDonations} من التبرعات، نسبة الخصم الفعلية: ${actualDiscountPercentage.toFixed(2)}%`);

      // 🔍 4. إذا لم يكن هناك تبرعات كافية، نلغي المساعدة المالية
      if (maxDiscountFromDonations <= 0) {
        console.log(`⚠️ لا توجد تبرعات كافية لتطبيق خصم، سيتم استخدام التسعير العادي`);
        return await this.handleNoFinancialAid(session);
      }

      // 🔍 5. تطبيق الخصم التلقائي
      return await this.applyAutoDiscount(
        session, 
        sessionBasePrice, 
        actualDiscountPercentage, 
        maxDiscountFromDonations,
        parent,
        financialTier
      );

    } catch (error) {
      console.error('❌ خطأ في التحقق التلقائي للمساعدة المالية:', error);
      throw error;
    }
  }

  /**
   * حساب نسبة الخصم التلقائية بناءً على الفئة المالية
   */
  static calculateAutoDiscountPercentage(financialTier, financialScore) {
    const discountRanges = {
      'tier_1_critical': { min: 80, max: 100 },
      'tier_2_high': { min: 60, max: 79 },
      'tier_3_medium': { min: 40, max: 59 },
      'tier_4_low': { min: 20, max: 39 },
      'tier_5_no_assistance': { min: 0, max: 0 }
    };

    const range = discountRanges[financialTier] || discountRanges['tier_5_no_assistance'];
    
    if (range.min === range.max) return range.min;

    // حساب النسبة بناءً على النتيجة المالية داخل الفئة
    const tierMinScore = this.getTierMinScore(financialTier);
    const tierMaxScore = this.getTierMaxScore(financialTier);
    
    const normalizedScore = Math.max(0, Math.min(1, 
      (financialScore - tierMinScore) / (tierMaxScore - tierMinScore)
    ));
    
    const discount = range.min + (range.max - range.min) * normalizedScore;
    return Math.round(discount);
  }

  static getTierMinScore(tier) {
    const scores = {
      'tier_1_critical': 85,
      'tier_2_high': 70,
      'tier_3_medium': 55,
      'tier_4_low': 40,
      'tier_5_no_assistance': 0
    };
    return scores[tier] || 0;
  }

  static getTierMaxScore(tier) {
    const scores = {
      'tier_1_critical': 100,
      'tier_2_high': 84,
      'tier_3_medium': 69,
      'tier_4_low': 54,
      'tier_5_no_assistance': 39
    };
    return scores[tier] || 0;
  }

  /**
   * معالجة الحالة بدون مساعدة مالية
   */
  static async handleNoFinancialAid(session) {
    const basePrice = parseFloat(session.SessionType?.price || 0);
    
    // إنشاء فاتورة بدون خصم
    const invoice = await Invoice.create({
      session_id: session.session_id,
      parent_id: session.child.parent_id,
      institution_id: session.institution_id,
      invoice_number: `INV-${Date.now()}-${session.session_id}`,
      amount: basePrice,
      tax_amount: 0,
      total_amount: basePrice,
      status: 'Pending',
      due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      issued_date: new Date(),
      notes: 'فاتورة الجلسة بدون مساعدة مالية'
    });

    // تحديث حالة الجلسة
    await session.update({
      original_price: basePrice,
      final_price: basePrice,
      applied_discount_percentage: 0,
      financial_assistance_applied: false,
      payment_status: 'Pending',
      auto_financial_assistance: false
    });

    return {
      success: true,
      auto_applied: false,
      discount_percentage: 0,
      discount_amount: 0,
      final_price: basePrice,
      invoice_id: invoice.invoice_id
    };
  }

  /**
   * تطبيق الخصم التلقائي
   */
  static async applyAutoDiscount(session, basePrice, discountPercentage, discountAmount, parent, financialTier) {
    const finalPrice = basePrice - discountAmount;
    
    console.log(`💰 تطبيق خصم: ${discountPercentage.toFixed(2)}% (${discountAmount}) - السعر النهائي: ${finalPrice}`);

    return await sequelize.transaction(async (t) => {
      // 1. خصم من رصيد التبرعات
      const institution = await session.institution.reload({ transaction: t });
      const currentBalance = parseFloat(institution.donation_balance || 0);
      const newBalance = Math.max(0, currentBalance - discountAmount);
      
      await institution.update({ 
        donation_balance: newBalance 
      }, { transaction: t });

      // 2. إنشاء فاتورة بالسعر النهائي
      const invoice = await Invoice.create({
        session_id: session.session_id,
        parent_id: session.child.parent_id,
        institution_id: session.institution_id,
        invoice_number: `INV-${Date.now()}-${session.session_id}`,
        amount: finalPrice,
        tax_amount: 0,
        total_amount: finalPrice,
        status: finalPrice === 0 ? 'Paid' : 'Pending',
        due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
        issued_date: new Date(),
        notes: finalPrice === 0 
          ? 'جلسة مجانية - تم تمويلها بالكامل من المساعدة المالية التلقائية'
          : `فاتورة الجلسة مع خصم تلقائي ${discountPercentage.toFixed(2)}%`
      }, { transaction: t });

      // 3. تسجيل عملية التخصيص
      await DonationAllocation.create({
        institution_id: session.institution_id,
        donation_id: null,
        invoice_id: invoice.invoice_id,
        financial_assistance_request_id: null,
        amount_allocated: discountAmount,
        allocation_type: 'auto_financial_aid',
        notes: `خصم تلقائي للجلسة ${session.session_id} - نسبة الخصم: ${discountPercentage.toFixed(2)}%`
      }, { transaction: t });

      // 4. تسجيل طلب المساعدة المالية التلقائية (للتاريخ)
      const financialAidRequest = await SessionFinancialAidRequest.create({
        session_id: session.session_id,
        parent_id: session.child.parent_id,
        child_id: session.child.child_id,
        institution_id: session.institution_id,
        requested_percentage: discountPercentage,
        approved_percentage: discountPercentage,
        approved_amount: discountAmount,
        status: 'approved',
        decision_date: new Date(),
        auto_applied: true,
        decision_notes: `تم تطبيق الخصم تلقائياً بناءً على الحالة المالية للأسرة (${financialTier})`
      }, { transaction: t });

      // 5. تحديث الجلسة
      await session.update({
        original_price: basePrice,
        final_price: finalPrice,
        applied_discount_percentage: discountPercentage,
        financial_assistance_applied: true,
        financial_assistance_request_id: financialAidRequest.request_id,
        payment_status: finalPrice === 0 ? 'Paid' : 'Pending',
        discount_reason: `خصم تلقائي بناءً على الحالة المالية (${financialTier})`,
        auto_financial_assistance: true,
        auto_discount_details: {
          financial_tier: financialTier,
          financial_score: parent?.financial_score || 0,
          calculated_at: new Date()
        }
      }, { transaction: t });

      // 6. تسجيل في سجل المساعدة المالية التلقائية
      await this.logAutoFinancialAid(
        session.session_id,
        session.child.parent_id,
        session.institution_id,
        basePrice,
        discountPercentage,
        discountAmount,
        finalPrice,
        financialTier,
        parent?.financial_score || 0,
        currentBalance,
        t
      );

      // 7. إرسال إشعار للأهل
      await this.sendAutoDiscountNotification(
        session.child.parent_id,
        session.child.full_name,
        discountPercentage,
        discountAmount,
        finalPrice,
        financialTier,
        t
      );

      // 8. إرسال إشعار للمدير (للعلم فقط)
      await this.sendManagerNotification(
        session.institution_id,
        session.child.full_name,
        discountPercentage,
        discountAmount,
        t
      );

      return {
        success: true,
        auto_applied: true,
        discount_percentage: discountPercentage,
        discount_amount: discountAmount,
        final_price: finalPrice,
        invoice_id: invoice.invoice_id,
        financial_aid_request_id: financialAidRequest.request_id,
        financial_tier: financialTier,
        notification_sent: true
      };
    });
  }

  /**
   * تسجيل في سجل المساعدة المالية التلقائية
   */
  static async logAutoFinancialAid(sessionId, parentId, institutionId, originalPrice, discountPercentage, discountAmount, finalPrice, financialTier, financialScore, availableBalance, transaction) {
    try {
      const AutoFinancialAidLog = require('../model/AutoFinancialAidLog');
      
      await AutoFinancialAidLog.create({
        session_id: sessionId,
        parent_id: parentId,
        institution_id: institutionId,
        original_price: originalPrice,
        applied_discount_percentage: discountPercentage,
        discount_amount: discountAmount,
        final_price: finalPrice,
        parent_financial_tier: financialTier,
        parent_financial_score: financialScore,
        available_donation_balance: availableBalance,
        applied_at: new Date()
      }, { transaction });
      
      console.log(`📝 تم تسجيل عملية المساعدة المالية التلقائية للجلسة ${sessionId}`);
    } catch (error) {
      console.error('❌ خطأ في تسجيل سجل المساعدة المالية:', error);
    }
  }

  /**
   * إرسال إشعار للأهل
   */
  static async sendAutoDiscountNotification(parentId, childName, discountPercentage, discountAmount, finalPrice, financialTier, transaction) {
    let title, message;
    
    if (finalPrice === 0) {
      title = 'جلسة مجانية تمت الموافقة عليها';
      message = `مبروك! تمت الموافقة على جلسة ${childName} بشكل مجاني بالكامل بناءً على حالتك المالية (${financialTier}).`;
    } else if (discountAmount > 0) {
      title = 'تم تطبيق خصم تلقائي على الجلسة';
      message = `تم تطبيق خصم تلقائي بنسبة ${discountPercentage.toFixed(2)}% على جلسة ${childName}. 
                تم خصم ${discountAmount} دينار. السعر النهائي: ${finalPrice} دينار.`;
    } else {
      title = 'تحديث بخصوص الجلسة';
      message = `لم يتم تطبيق أي خصم على جلسة ${childName}. السعر النهائي: ${finalPrice} دينار.`;
    }

    await Notification.create({
      user_id: parentId,
      title: title,
      message: message,
      type: 'auto_financial_aid',
      related_id: null,
      is_read: false,
      metadata: {
        discount_percentage: discountPercentage,
        discount_amount: discountAmount,
        financial_tier: financialTier,
        final_price: finalPrice
      }
    }, { transaction });
  }

  /**
   * إرسال إشعار للمدير
   */
  static async sendManagerNotification(institutionId, childName, discountPercentage, discountAmount, transaction) {
    try {
      const Manager = require('../model/Manager');
      const manager = await Manager.findOne({
        where: { 
          institution_id: institutionId,
          is_active: true 
        }
      });

      if (!manager) return;

      const message = discountAmount > 0
        ? `تم تطبيق خصم تلقائي بنسبة ${discountPercentage.toFixed(2)}% على جلسة ${childName}. 
           تم استخدام ${discountAmount} دينار من رصيد التبرعات.`
        : `تم إنشاء جلسة لـ ${childName} بدون خصم مالي.`;

      await Notification.create({
        user_id: manager.manager_id,
        title: 'تطبيق المساعدة المالية التلقائية',
        message: message,
        type: 'auto_financial_aid_summary',
        related_id: null,
        is_read: false,
        metadata: {
          discount_percentage: discountPercentage,
          discount_amount: discountAmount,
          child_name: childName
        }
      }, { transaction });
    } catch (error) {
      console.error('❌ خطأ في إرسال إشعار المدير:', error);
    }
  }

  /**
   * التحقق السريع من إمكانية المساعدة المالية (للعرض في الواجهة)
   */
  static async quickCheckFinancialAid(childId, institutionId, sessionTypeId) {
    try {
      // جلب بيانات الطفل والأهل
      const child = await Child.findByPk(childId, {
        include: [{
          model: Parent,
          attributes: ['parent_id', 'financial_score', 'financial_tier']
        }]
      });

      if (!child || !child.Parent) {
        return { 
          available: false, 
          reason: 'Child or parent not found',
          estimated_discount_percentage: 0 
        };
      }

      // جلب سعر الجلسة
      const sessionType = await SessionType.findByPk(sessionTypeId);
      if (!sessionType) {
        return { 
          available: false, 
          reason: 'Session type not found',
          estimated_discount_percentage: 0 
        };
      }

      // جلب رصيد التبرعات
      const institution = await Institution.findByPk(institutionId);
      if (!institution) {
        return { 
          available: false, 
          reason: 'Institution not found',
          estimated_discount_percentage: 0 
        };
      }

      // حساب نسبة الخصم المتوقعة
      const discountPercentage = this.calculateAutoDiscountPercentage(
        child.Parent.financial_tier,
        child.Parent.financial_score
      );

      const sessionPrice = parseFloat(sessionType.price || 0);
      const availableBalance = parseFloat(institution.donation_balance || 0);
      const maxDiscountAmount = Math.min(
        (sessionPrice * discountPercentage) / 100,
        availableBalance
      );
      const actualDiscountPercentage = sessionPrice > 0 ? (maxDiscountAmount / sessionPrice) * 100 : 0;

      return {
        available: maxDiscountAmount > 0,
        estimated_discount_percentage: actualDiscountPercentage,
        estimated_discount_amount: maxDiscountAmount,
        estimated_final_price: sessionPrice - maxDiscountAmount,
        parent_financial_tier: child.Parent.financial_tier,
        parent_financial_score: child.Parent.financial_score,
        available_donation_balance: availableBalance,
        session_base_price: sessionPrice,
        can_be_free: maxDiscountAmount >= sessionPrice,
        financial_status: this.getFinancialStatusDescription(child.Parent.financial_tier)
      };

    } catch (error) {
      console.error('❌ Error in quick financial aid check:', error);
      return { 
        available: false, 
        reason: 'Check failed',
        estimated_discount_percentage: 0 
      };
    }
  }

  /**
   * الحصول على وصف الحالة المالية
   */
  static getFinancialStatusDescription(tier) {
    const descriptions = {
      'tier_1_critical': 'حالة مالية حرجة - مؤهل لخصم كبير',
      'tier_2_high': 'حالة مالية صعبة - مؤهل لخصم مرتفع',
      'tier_3_medium': 'حالة مالية متوسطة - مؤهل لخصم معتدل',
      'tier_4_low': 'حالة مالية مقبولة - مؤهل لخصم بسيط',
      'tier_5_no_assistance': 'لا يحتاج لمساعدة مالية'
    };
    return descriptions[tier] || 'حالة غير معروفة';
  }

  /**
   * الحصول على سجل المساعدة المالية التلقائية للأهل
   */
  static async getParentAutoAidHistory(parentId, limit = 10) {
    try {
      const AutoFinancialAidLog = require('../model/AutoFinancialAidLog');
      
      const logs = await AutoFinancialAidLog.findAll({
        where: { parent_id: parentId },
        include: [
          {
            model: Session,
            attributes: ['session_id', 'date', 'time'],
            include: [
              {
                model: Child,
                as: 'child',
                attributes: ['full_name']
              },
              {
                model: SessionType,
                attributes: ['name']
              }
            ]
          },
          {
            model: Institution,
            attributes: ['name']
          }
        ],
        order: [['applied_at', 'DESC']],
        limit: limit
      });

      const summary = await AutoFinancialAidLog.findOne({
        where: { parent_id: parentId },
        attributes: [
          [sequelize.fn('COUNT', sequelize.col('log_id')), 'total_applications'],
          [sequelize.fn('SUM', sequelize.col('discount_amount')), 'total_savings'],
          [sequelize.fn('AVG', sequelize.col('applied_discount_percentage')), 'avg_discount_percentage']
        ],
        raw: true
      });

      return {
        logs: logs.map(log => ({
          log_id: log.log_id,
          session_id: log.session_id,
          child_name: log.Session?.child?.full_name,
          session_type: log.Session?.SessionType?.name,
          institution_name: log.Institution?.name,
          original_price: log.original_price,
          discount_percentage: log.applied_discount_percentage,
          discount_amount: log.discount_amount,
          final_price: log.final_price,
          applied_at: log.applied_at,
          financial_tier: log.parent_financial_tier
        })),
        summary: {
          total_applications: parseInt(summary?.total_applications || 0),
          total_savings: parseFloat(summary?.total_savings || 0),
          avg_discount_percentage: parseFloat(summary?.avg_discount_percentage || 0)
        }
      };

    } catch (error) {
      console.error('❌ خطأ في جلب سجل المساعدة المالية:', error);
      return { logs: [], summary: { total_applications: 0, total_savings: 0, avg_discount_percentage: 0 } };
    }
  }
}

module.exports = AutoFinancialAidService;