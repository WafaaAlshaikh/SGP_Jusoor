const Manager = require('../../model/Manager');
const User = require('../../model/User');
const Notification = require('../../model/Notification');
const TeamService = require('../../services/teamService');
const FinancialAssessmentService = require('../../services/financialAssessmentService');
const AutoSchedulingService = require('../../services/autoSchedulingService');
const FinancialAssistanceRequest = require('../../model/FinancialAssistanceRequest');
const SessionFinancialAidRequest = require('../../model/SessionFinancialAidRequest');
const ChildRegistrationRequest = require('../../model/ChildRegistrationRequest');
const Session = require('../../model/Session');
const SessionType = require('../../model/SessionType');
const Invoice = require('../../model/Invoice');
const DonationAllocation = require('../../model/DonationAllocation');
const sequelize = require('../../config/db');
const { Op, fn, col } = require('sequelize');
const FreeSessionOffer = require('../../model/FreeSessionOffer');
const Child = require('../../model/Child');
const Parent = require('../../model/Parent');
const Institution = require('../../model/Institution');



exports.getPendingSessionTypes = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'المستخدم غير مصرح له'
      });
    }

    const pendingSessionTypes = await SessionType.findAll({
      where: {
        institution_id: manager.institution_id,
        approval_status: 'Pending'
      },
      order: [['session_type_id', 'DESC']]
    });

    const sessionTypesWithSpecialist = await Promise.all(
      pendingSessionTypes.map(async (st) => {
        const sessionTypeData = st.toJSON();
        if (st.created_by_specialist_id) {
          const specialist = await User.findByPk(st.created_by_specialist_id, {
            attributes: ['user_id', 'full_name', 'email']
          });
          sessionTypeData.created_by_specialist = specialist;
        }
        return sessionTypeData;
      })
    );

    res.status(200).json({
      success: true,
      message: 'تم جلب أنواع الجلسات المعلقة بنجاح',
      data: sessionTypesWithSpecialist,
      count: sessionTypesWithSpecialist.length
    });

  } catch (error) {
    console.error('Error in getPendingSessionTypes:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في جلب أنواع الجلسات المعلقة',
      error: error.message
    });
  }
};

exports.getSessionFinancialAidRequests = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { status = 'under_review', page = 1, limit = 20 } = req.query;

    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      attributes: ['institution_id']
    });

    if (!manager) {
      return res.status(404).json({ success: false, message: 'Manager not found' });
    }

    const where = { institution_id: manager.institution_id };
    if (status && status !== 'all') {
      where.status = status;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const total = await SessionFinancialAidRequest.count({ where });

    const requests = await SessionFinancialAidRequest.findAll({
      where,
      include: [
        {
          model: require('../../model/Session'),
          as: 'session'
        },
        {
          model: require('../../model/User'),
          as: 'parent',
          attributes: ['full_name', 'phone', 'email']
        },
        {
          model: require('../../model/Child'),
          as: 'child',
          attributes: ['full_name']
        }
      ],
      order: [['created_at', 'DESC']],
      offset,
      limit: parseInt(limit)
    });

    res.status(200).json({
      success: true,
      data: requests,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        total_pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    console.error('Error getting session financial aid requests:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch session financial aid requests',
      error: error.message
    });
  }
};

exports.reviewSessionFinancialAidRequest = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { request_id } = req.params;
    const { action, approved_percentage, approved_amount, decision_notes } = req.body;

    if (!action || !['approve', 'partial_approve', 'reject'].includes(action)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid action. Use approve, partial_approve, or reject'
      });
    }

    const aidRequest = await SessionFinancialAidRequest.findOne({
      where: { request_id },
      include: [
        {
          model: require('../../model/Session'),
          as: 'session'
        },
        {
          model: require('../../model/Child'),
          as: 'child',
          attributes: ['child_id', 'parent_id', 'full_name']
        }
      ]
    });

    if (!aidRequest || !aidRequest.session) {
      return res.status(404).json({ success: false, message: 'Session aid request not found' });
    }

    const manager = await Manager.findOne({
      where: { manager_id: managerId, institution_id: aidRequest.institution_id }
    });
    if (!manager) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    const session = await Session.findByPk(aidRequest.session_id);
    const sessionType = await SessionType.findByPk(session.session_type_id);
    const baseAmount = parseFloat(sessionType?.price) || 0;

    if (action === 'reject') {
      await aidRequest.update({
        status: 'rejected',
        decided_by_manager_id: managerId,
        decision_date: new Date(),
        decision_notes: decision_notes || null
      });

      await session.update({
        status: 'Pending',
        payment_status: 'Unpaid'
      });

      await Notification.create({
        user_id: aidRequest.parent_id,
        title: 'Financial Aid Rejected',
        message: 'Your session financial aid request was rejected. Please decide to pay in full or reject the session.',
        type: 'financial_assistance_update',
        related_id: aidRequest.request_id,
        is_read: false
      });

      return res.status(200).json({
        success: true,
        message: 'Session financial aid request rejected',
        request_id: aidRequest.request_id,
        status: 'rejected'
      });
    }

    const percent = approved_percentage != null ? parseFloat(approved_percentage) : null;
    const amount = approved_amount != null ? parseFloat(approved_amount) : null;

    let desiredDiscount = 0;

    const requestedPercent = aidRequest.requested_percentage != null
      ? parseFloat(aidRequest.requested_percentage)
      : null;
    const requestedAmount = aidRequest.requested_amount != null
      ? parseFloat(aidRequest.requested_amount)
      : null;

    if (Number.isFinite(percent) && percent > 0) {
      desiredDiscount = (baseAmount * Math.min(100, Math.max(0, percent))) / 100;
    } else if (Number.isFinite(requestedPercent) && requestedPercent > 0) {
      desiredDiscount = (baseAmount * Math.min(100, Math.max(0, requestedPercent))) / 100;
    }

    if (Number.isFinite(amount) && amount > 0) {
      desiredDiscount = desiredDiscount > 0 ? Math.min(desiredDiscount, amount) : amount;
    } else if (Number.isFinite(requestedAmount) && requestedAmount > 0) {
      desiredDiscount = desiredDiscount > 0 ? Math.min(desiredDiscount, requestedAmount) : requestedAmount;
    }

    if (desiredDiscount <= 0) {
      if (action === 'approve') {
        desiredDiscount = baseAmount;
      } else {
        desiredDiscount = baseAmount * 0.5;
      }
    }

    await sequelize.transaction(async (t) => {
      const inst = await Institution.findByPk(aidRequest.institution_id, {
        transaction: t,
        lock: t.LOCK.UPDATE,
      });

      const balance = parseFloat(inst?.donation_balance || 0);
      const approvedDiscount = Math.min(desiredDiscount, balance);
      const appliedDiscount = Math.max(0, Math.min(baseAmount, approvedDiscount));
      const finalAmount = Math.max(0, baseAmount - appliedDiscount);
      const appliedPercent =
          baseAmount > 0 ? Math.min(100, (appliedDiscount / baseAmount) * 100) : 0;

      const newStatus = appliedDiscount >= baseAmount ? 'approved' : 'partial_approved';

      await aidRequest.update(
        {
          status: newStatus,
          approved_percentage: appliedPercent,
          approved_amount: appliedDiscount,
          decided_by_manager_id: managerId,
          decision_date: new Date(),
          decision_notes: decision_notes || null,
        },
        { transaction: t }
      );

      const existingInvoice = await Invoice.findOne({
        where: { session_id: session.session_id },
        transaction: t,
        lock: t.LOCK.UPDATE,
      });

      const invoice = existingInvoice
        ? existingInvoice
        : await Invoice.create(
            {
              session_id: session.session_id,
              parent_id: aidRequest.parent_id,
              institution_id: aidRequest.institution_id,
              invoice_number: `INV-${Date.now()}-${session.session_id}`,
              amount: finalAmount,
              tax_amount: 0,
              total_amount: finalAmount,
              status: 'Pending',
              due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
              issued_date: new Date(),
              notes:
                finalAmount === 0
                  ? `Free session funded by financial aid (session aid request ${aidRequest.request_id}).`
                  : `Invoice for session with financial aid discount applied (session aid request ${aidRequest.request_id}).`,
            },
            { transaction: t }
          );

      if (existingInvoice) {
        await existingInvoice.update(
          {
            amount: finalAmount,
            total_amount: finalAmount,
            status: finalAmount === 0 ? 'Paid' : existingInvoice.status,
          },
          { transaction: t }
        );
      }

      const allocations = await DonationAllocation.findAll({
        where: {
          institution_id: aidRequest.institution_id,
          invoice_id: invoice.invoice_id,
        },
        transaction: t,
        lock: t.LOCK.UPDATE,
      });

      const alreadyAllocated = allocations.reduce(
        (sum, a) => sum + (parseFloat(a.amount_allocated) || 0),
        0
      );

      const remainingToAllocate = Math.max(0, appliedDiscount - alreadyAllocated);
      const deltaAllocate = Math.min(remainingToAllocate, balance);

      if (deltaAllocate > 0 && inst) {
        await DonationAllocation.create(
          {
            institution_id: inst.institution_id,
            donation_id: null,
            invoice_id: invoice.invoice_id,
            financial_assistance_request_id: aidRequest.parent_financial_request_id,
            amount_allocated: deltaAllocate,
          },
          { transaction: t }
        );

        await inst.update(
          { donation_balance: Math.max(0, balance - deltaAllocate) },
          { transaction: t }
        );
      }

      await session.update(
        {
          status: 'Scheduled',
          payment_status: finalAmount === 0 ? 'Paid' : 'Pending',
          original_price: baseAmount,
          applied_discount_percentage: appliedPercent,
          final_price: finalAmount,
          financial_assistance_applied: appliedDiscount > 0,
          discount_reason: 'Session financial aid',
        },
        { transaction: t }
      );
    });

    await aidRequest.reload();
    const appliedDiscount = parseFloat(aidRequest.approved_amount || 0);
    const finalAmount = Math.max(0, baseAmount - appliedDiscount);

    const invoice = await Invoice.findOne({
      where: { session_id: session.session_id },
      attributes: ['invoice_id'],
    });

    await Notification.create({
      user_id: aidRequest.parent_id,
      title: 'Financial Aid Decision',
      message: finalAmount === 0
        ? 'Your session financial aid request was approved (free session).'
        : 'Your session financial aid request was approved. Invoice created.',
      type: 'financial_assistance_update',
      related_id: aidRequest.request_id,
      is_read: false
    });

    res.status(200).json({
      success: true,
      message: 'Session financial aid request reviewed',
      request: {
        request_id: aidRequest.request_id,
        status: aidRequest.status,
        approved_amount: aidRequest.approved_amount,
        approved_percentage: aidRequest.approved_percentage
      },
      invoice_id: invoice?.invoice_id ?? null
    });
  } catch (error) {
    console.error('Error reviewing session financial aid request:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to review session financial aid request',
      error: error.message
    });
  }
};

exports.generateFreeSessionOffers = async (req, res) => {
  try {
    return res.status(410).json({
      success: false,
      message:
        'Free session offers generation is deprecated. This feature is now read-only.',
    });

    const managerId = req.user.user_id;
    const {
      session_type_id,
      specialist_id,
      max_children = 5,
      notes,
    } = req.body;

    if (!session_type_id || !specialist_id) {
      return res.status(400).json({
        success: false,
        message: 'session_type_id و specialist_id مطلوبان',
      });
    }

    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true },
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'المستخدم غير مصرح له',
      });
    }

    const institutionId = manager.institution_id;

    const needyChildren = await Child.findAll({
      where: {
        current_institution_id: institutionId,
        registration_status: 'Approved',
      },
      include: [
        {
          model: Parent,
          attributes: ['parent_id', 'financial_tier'],
          required: true,
          where: {
            financial_tier: {
              [Op.in]: ['tier_1_critical', 'tier_2_high'],
            },
          },
        },
      ],
      limit: parseInt(max_children, 10) || 5,
    });

    if (!needyChildren || needyChildren.length === 0) {
      return res.status(200).json({
        success: true,
        message: 'لا يوجد أطفال مؤهلون للجلسات المجانية حالياً',
        data: [],
      });
    }

    const offers = [];
    for (const child of needyChildren) {
      const offer = await FreeSessionOffer.create({
        child_id: child.child_id,
        parent_id: child.Parent.parent_id,
        institution_id: institutionId,
        session_type_id,
        specialist_id,
        status: 'offered',
        notes,
      });
      offers.push(offer);
    }

    return res.status(201).json({
      success: true,
      message: 'تم إنشاء عروض الجلسات المجانية بنجاح',
      data: offers,
    });
  } catch (error) {
    console.error('Error generating free session offers:', error);
    return res.status(500).json({
      success: false,
      message: 'فشل في إنشاء عروض الجلسات المجانية',
      error: error.message,
    });
  }
};

exports.approveSessionType = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { session_type_id } = req.params;
    const { notes } = req.body;

    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'المستخدم غير مصرح له'
      });
    }

    const sessionType = await SessionType.findOne({
      where: {
        session_type_id,
        institution_id: manager.institution_id,
        approval_status: 'Pending'
      }
    });

    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'نوع الجلسة غير موجود أو غير معلق للموافقة'
      });
    }

    await sessionType.update({
      approval_status: 'Approved'
    });

    if (sessionType.created_by_specialist_id) {
      await Notification.create({
        user_id: sessionType.created_by_specialist_id,
        title: 'تمت الموافقة على نوع الجلسة',
        message: `تمت الموافقة على نوع الجلسة "${sessionType.name}" من قبل المدير. يمكنك الآن استخدامه في إنشاء الجلسات.`,
        type: 'general',
        related_id: sessionType.session_type_id,
        is_read: false
      });
    }

    res.status(200).json({
      success: true,
      message: 'تمت الموافقة على نوع الجلسة بنجاح',
      data: sessionType
    });

  } catch (error) {
    console.error('Error in approveSessionType:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في الموافقة على نوع الجلسة',
      error: error.message
    });
  }
};

exports.rejectSessionType = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { session_type_id } = req.params;
    const { reason } = req.body;

    const manager = await Manager.findOne({
      where: { manager_id: managerId, is_active: true }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'المستخدم غير مصرح له'
      });
    }

    const sessionType = await SessionType.findOne({
      where: {
        session_type_id,
        institution_id: manager.institution_id,
        approval_status: 'Pending'
      }
    });

    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'نوع الجلسة غير موجود أو غير معلق للموافقة'
      });
    }

    await sessionType.update({
      approval_status: 'Rejected'
    });

    if (sessionType.created_by_specialist_id) {
      await Notification.create({
        user_id: sessionType.created_by_specialist_id,
        title: 'تم رفض نوع الجلسة',
        message: `تم رفض نوع الجلسة "${sessionType.name}" من قبل المدير. ${reason ? `السبب: ${reason}` : ''}`,
        type: 'general',
        related_id: sessionType.session_type_id,
        is_read: false
      });
    }

    res.status(200).json({
      success: true,
      message: 'تم رفض نوع الجلسة بنجاح',
      data: sessionType
    });

  } catch (error) {
    console.error('Error in rejectSessionType:', error);
    res.status(500).json({
      success: false,
      message: 'خطأ في رفض نوع الجلسة',
      error: error.message
    });
  }
};



exports.approveChildRegistration = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { request_id } = req.params;
    const { 
      notes, 
      auto_schedule = true,
      apply_financial_assistance = 'auto',
      custom_discount_percentage,
      require_documents = false
    } = req.body;

    console.log(`🔍 Approving child registration request: ${request_id}`);

    const registrationRequest = await ChildRegistrationRequest.findOne({
      where: { 
        request_id,
        status: 'Pending'
      },
      include: [
        {
          model: Child,
          include: [{ model: Parent }]
        },
        {
          model: Institution,
          as: 'Institution'
        }
      ]
    });

    if (!registrationRequest) {
      return res.status(404).json({ 
        success: false,
        message: 'Registration request not found' 
      });
    }

    const Manager = require('../../model/Manager');
    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId,
        institution_id: registrationRequest.institution_id 
      }
    });

    if (!manager) {
      return res.status(403).json({ 
        success: false,
        message: 'Not authorized to approve this request' 
      });
    }

    await registrationRequest.update({
      status: 'Approved',
      reviewed_at: new Date(),
      reviewed_by: managerId,
      notes: notes
    });

    await Child.update(
      {
        registration_status: 'Approved',
        current_institution_id: registrationRequest.institution_id,
        updated_at: new Date()
      },
      { where: { child_id: registrationRequest.child_id } }
    );

    // ========== FINANCIAL ASSISTANCE PROCESSING ==========
    let financialAssistanceResult = null;
    let schedulingResult = null;
    
    if (apply_financial_assistance !== 'none') {
      console.log('💰 Processing financial assistance...');
      
      financialAssistanceResult = await FinancialAssessmentService.autoGenerateFinancialAssistanceRequest(
        registrationRequest.child_id,
        registrationRequest.institution_id,
        registrationRequest.Child.parent_id
      );
      
      if (financialAssistanceResult.success) {
        const financialRequest = financialAssistanceResult.request;
        
        if (custom_discount_percentage !== undefined) {
          await financialRequest.update({
            requested_discount_percentage: custom_discount_percentage,
            approved_discount_percentage: custom_discount_percentage,
            status: 'approved',
            approved_by_manager_id: managerId,
            decision_date: new Date(),
            decision_notes: `Manager manually set discount to ${custom_discount_percentage}%`
          });
        } else if (apply_financial_assistance === 'auto_approve') {
          await financialRequest.update({
            approved_discount_percentage: financialRequest.requested_discount_percentage,
            status: 'approved',
            approved_by_manager_id: managerId,
            decision_date: new Date(),
            decision_notes: 'Auto-approved based on financial assessment'
          });
        }
        
        if (require_documents && financialRequest.requested_discount_percentage >= 50) {
          await financialRequest.update({
            status: 'pending_documents',
            requires_documents: true,
            decision_notes: 'Documents required for verification'
          });
        }
        
        const finalFinancialRequest = await FinancialAssistanceRequest.findByPk(financialRequest.request_id);
        
        if (auto_schedule && finalFinancialRequest.status === 'approved') {
          console.log('📅 Auto-scheduling sessions with financial assistance...');
          
          schedulingResult = await AutoSchedulingService.scheduleSessionsWithFinancialAssistance(
            registrationRequest.child_id,
            registrationRequest.institution_id,
            finalFinancialRequest
          );
        }
      }
    } else {
      if (auto_schedule) {
        console.log('📅 Auto-scheduling sessions without financial assistance...');
        
        schedulingResult = await AutoSchedulingService.scheduleSessionsWithFinancialAssistance(
          registrationRequest.child_id,
          registrationRequest.institution_id,
          null
        );
      }
    }
    
    // ========== NOTIFICATIONS ==========
    await this.sendRegistrationApprovalNotifications(
      registrationRequest,
      financialAssistanceResult,
      schedulingResult,
      managerId
    );

    // ========== PREPARE RESPONSE ==========
    const response = {
      success: true,
      message: 'Child registration approved successfully',
      child: {
        id: registrationRequest.child_id,
        name: registrationRequest.Child.full_name,
        registration_status: 'Approved',
        institution_id: registrationRequest.institution_id
      },
      financial_assistance: financialAssistanceResult ? {
        provided: financialAssistanceResult.success,
        request_id: financialAssistanceResult.request?.request_id,
        status: financialAssistanceResult.request?.status,
        discount_percentage: financialAssistanceResult.request?.approved_discount_percentage || 
                            financialAssistanceResult.request?.requested_discount_percentage,
        notes: financialAssistanceResult.request?.decision_notes
      } : {
        provided: false,
        message: 'No financial assistance applied'
      },
      auto_scheduling: auto_schedule ? {
        enabled: true,
        result: schedulingResult
      } : {
        enabled: false,
        message: 'Auto-scheduling disabled'
      },
      manager_notes: notes,
      approval_date: new Date().toISOString()
    };

    res.status(200).json(response);

  } catch (error) {
    console.error('❌ Error approving child registration:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to approve registration', 
      error: error.message 
    });
  }
};

/**
 * Send notifications for registration approval
 */
exports.sendRegistrationApprovalNotifications = async (registrationRequest, financialResult, schedulingResult, managerId) => {
  try {
    const Notification = require('../../model/Notification');
    const User = require('../../model/User');
    
    const manager = await User.findByPk(managerId, {
      attributes: ['full_name']
    });
    
    let parentMessage = `✅ Your child ${registrationRequest.Child.full_name} has been approved for registration at ${registrationRequest.Institution.name}.`;
    
    if (financialResult?.success) {
      const discount = financialResult.request.approved_discount_percentage || 
                      financialResult.request.requested_discount_percentage;
      
      if (financialResult.request.status === 'approved') {
        parentMessage += ` Financial assistance of ${discount}% discount has been approved.`;
      } else if (financialResult.request.status === 'pending_documents') {
        parentMessage += ` Financial assistance request is pending document submission.`;
      }
    }
    
    if (schedulingResult?.success) {
      parentMessage += ` ${schedulingResult.total_sessions_scheduled} sessions have been scheduled.`;
    }
    
    await Notification.create({
      user_id: registrationRequest.Child.parent_id,
      title: 'Registration Approved',
      message: parentMessage,
      type: 'registration_approved',
      related_id: registrationRequest.request_id,
      is_read: false
    });
    
    await Notification.create({
      user_id: managerId,
      title: 'Registration Approved Successfully',
      message: `You approved registration for ${registrationRequest.Child.full_name}.`,
      type: 'manager_action',
      related_id: registrationRequest.request_id,
      is_read: false
    });
    
    console.log('📧 Registration approval notifications sent');
    
  } catch (error) {
    console.error('Error sending notifications:', error);
  }
};

/**
 * Get financial assistance requests for review
 */
exports.getFinancialAssistanceRequests = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { 
      status, 
      priority, 
      page = 1, 
      limit = 20,
      sort_by = 'financial_score',
      sort_order = 'DESC'
    } = req.query;
    
    const Manager = require('../../model/Manager');
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      attributes: ['institution_id']
    });
    
    if (!manager) {
      return res.status(404).json({ 
        success: false,
        message: 'Manager not found' 
      });
    }
    
    const whereConditions = {
      institution_id: manager.institution_id
    };
    
    if (status && status !== 'all') {
      whereConditions.status = status;
    }
    
    if (priority && priority !== 'all') {
      whereConditions.parent_financial_tier = {
        [Op.like]: `%${priority}%`
      };
    }
    
    const offset = (parseInt(page) - 1) * parseInt(limit);
    
    const totalCount = await FinancialAssistanceRequest.count({
      where: whereConditions
    });
    
    const requests = await FinancialAssistanceRequest.findAll({
      where: whereConditions,
      include: [
        {
          model: require('../../model/User'),
          as: 'parent',
          attributes: ['full_name', 'phone', 'email']
        },
        {
          model: require('../../model/Child'),
          as: 'child',
          attributes: ['full_name', 'date_of_birth', 'gender', 'diagnosis_id']
        },
        {
          model: require('../../model/User'),
          as: 'approvedByManager',
          attributes: ['full_name'],
          required: false
        }
      ],
      order: [
        [sort_by === 'financial_score' ? 'parent_financial_score' : sort_by, sort_order],
        ['created_at', 'DESC']
      ],
      offset: offset,
      limit: parseInt(limit)
    });
    
    const formattedRequests = requests.map(request => {
      const urgencyColor = {
        'critical': 'red',
        'high': 'orange',
        'medium': 'yellow',
        'low': 'green'
      }[request.child_condition_urgency] || 'gray';
      
      const tierLabel = {
        'tier_1_critical': 'Critical Need',
        'tier_2_high': 'High Need',
        'tier_3_medium': 'Medium Need',
        'tier_4_low': 'Low Need',
        'tier_5_no_assistance': 'No Assistance Needed'
      }[request.parent_financial_tier] || 'Unknown';

      const totalAmountNumber = Number(request.requested_total_amount || 0);
      const originalAmountFormatted = `$${(!isNaN(totalAmountNumber) ? totalAmountNumber : 0).toFixed(2)}`;
      
      return {
        request_id: request.request_id,
        parent: {
          name: request.parent.full_name,
          contact: request.parent.phone,
          email: request.parent.email
        },
        child: {
          name: request.child.full_name,
          age: request.child.date_of_birth ? 
            Math.floor((new Date() - new Date(request.child.date_of_birth)) / (1000 * 60 * 60 * 24 * 365)) : null,
          gender: request.child.gender,
          diagnosis_id: request.child.diagnosis_id
        },
        financial_assessment: {
          score: request.parent_financial_score,
          tier: request.parent_financial_tier,
          tier_label: tierLabel,
          suggested_discount: request.requested_discount_percentage
        },
        request_details: {
          status: request.status,
          auto_generated: request.auto_generated,
          requested_sessions: request.requested_sessions_count,
          requested_discount: `${request.requested_discount_percentage}%`,
          original_amount: originalAmountFormatted,
          approved_discount: request.approved_discount_percentage ? 
            `${request.approved_discount_percentage}%` : 'Pending',
          approved_by: request.approvedByManager?.full_name,
          decision_date: request.decision_date,
          requires_documents: request.requires_documents
        },
        urgency: {
          level: request.child_condition_urgency,
          color: urgencyColor
        },
        timeline: {
          submitted: request.submitted_at,
          created: request.created_at,
          days_pending: request.status === 'submitted' || request.status === 'under_review' ? 
            Math.floor((new Date() - new Date(request.submitted_at || request.created_at)) / (1000 * 60 * 60 * 24)) : 0
        }
      };
    });
    
    const stats = await FinancialAssistanceRequest.findAll({
      where: { institution_id: manager.institution_id },
      attributes: [
  'status',
  [fn('COUNT', col('request_id')), 'count'],
  [fn('AVG', col('requested_discount_percentage')), 'avg_discount']
],
      group: ['status']
    });
    
    const statistics = {
      total: totalCount,
      by_status: stats.reduce((acc, stat) => {
        acc[stat.status] = {
          count: parseInt(stat.get('count')),
          avg_discount: parseFloat(stat.get('avg_discount'))?.toFixed(1) || '0'
        };
        return acc;
      }, {}),
      pending_review: await FinancialAssistanceRequest.count({
        where: {
          institution_id: manager.institution_id,
          status: ['submitted', 'under_review', 'auto_generated']
        }
      }),
      estimated_monthly_subsidy: await this.calculateEstimatedSubsidy(manager.institution_id)
    };
    
    res.status(200).json({
      success: true,
      data: formattedRequests,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount,
        total_pages: Math.ceil(totalCount / parseInt(limit))
      },
      statistics: statistics,
      filters_applied: {
        status,
        priority,
        sort_by,
        sort_order
      }
    });
    
  } catch (error) {
    console.error('Error getting financial assistance requests:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to fetch financial assistance requests',
      error: error.message 
    });
  }
};

/**
 * Approve/Reject financial assistance request
 */
exports.reviewFinancialAssistanceRequest = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { request_id } = req.params;
    const { 
      action, // 'approve', 'reject', 'request_documents', 'partial_approve'
      approved_discount_percentage,
      approved_sessions_count,
      decision_notes,
      documents_required = false
    } = req.body;
    
    const financialRequest = await FinancialAssistanceRequest.findOne({
      where: { request_id },
      include: [
        {
          model: require('../../model/Institution'),
          as: 'institution'
        }
      ]
    });
    
    if (!financialRequest) {
      return res.status(404).json({
        success: false,
        message: 'Financial assistance request not found'
      });
    }
    
    const Manager = require('../../model/Manager');
    const manager = await Manager.findOne({
      where: { 
        manager_id: managerId,
        institution_id: financialRequest.institution_id 
      }
    });
    
    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to review this request'
      });
    }
    
    let updatedStatus = financialRequest.status;
    let updateData = {
      approved_by_manager_id: managerId,
      decision_date: new Date(),
      decision_notes: decision_notes
    };
    
    switch (action) {
      case 'approve':
        updatedStatus = 'approved';
        updateData.approved_discount_percentage = approved_discount_percentage || 
                                                 financialRequest.requested_discount_percentage;
        updateData.approved_sessions_count = approved_sessions_count || 
                                            financialRequest.requested_sessions_count;
        updateData.approved_total_amount = financialRequest.requested_total_amount * 
          (1 - (updateData.approved_discount_percentage / 100));
        break;
        
      case 'partial_approve':
        updatedStatus = 'partially_approved';
        updateData.approved_discount_percentage = approved_discount_percentage;
        updateData.approved_sessions_count = approved_sessions_count;
        updateData.approved_total_amount = financialRequest.requested_total_amount * 
          (1 - (approved_discount_percentage / 100));
        break;
        
      case 'request_documents':
        updatedStatus = 'pending_documents';
        updateData.requires_documents = true;
        break;
        
      case 'reject':
        updatedStatus = 'rejected';
        break;
        
      default:
        return res.status(400).json({
          success: false,
          message: 'Invalid action specified'
        });
    }
    
    updateData.status = updatedStatus;
    
    await financialRequest.update(updateData);
    
    let schedulingResult = null;
    if (action === 'approve' || action === 'partial_approve') {
      try {
        const AutoApprovalService = require('../../services/autoApprovalService');

        const generalSpecialist = await AutoApprovalService.findAvailableGeneralSpecialist(
          financialRequest.institution_id,
          null
        );

        if (!generalSpecialist) {
          schedulingResult = {
            success: false,
            reason: 'No General specialist available for this institution'
          };
        } else {
          const slot = await AutoApprovalService.findNextAvailableSlot(
            generalSpecialist.specialist_id,
            60 
          );

          if (!slot) {
            schedulingResult = {
              success: false,
              reason: 'No available time slots found for General specialist'
            };
          } else {
            const session = await AutoApprovalService.createInitialAssessmentSession(
              financialRequest.child_id,
              generalSpecialist.specialist_id,
              financialRequest.institution_id,
              {
                date: slot.date,
                startTime: slot.startTime
              }
            );

            schedulingResult = {
              success: true,
              session_id: session.session_id,
              date: session.date,
              time: session.time
            };
          }
        }
      } catch (scheduleError) {
        console.error('Error scheduling initial assessment after financial approval:', scheduleError);
        schedulingResult = {
          success: false,
          reason: scheduleError.message
        };
      }
    }
    
    
    if (action === 'approve' || action === 'partial_approve') {
      try {
        const linkedRegistration = await ChildRegistrationRequest.findOne({
          where: {
            financial_assistance_request_id: financialRequest.request_id,
            status: 'Pending'
          }
        });

        if (linkedRegistration) {
          await linkedRegistration.update({
            status: 'Approved',
            reviewed_at: new Date()
          });

          await Child.update(
            {
              registration_status: 'Approved',
              current_institution_id: financialRequest.institution_id,
              updated_at: new Date()
            },
            { where: { child_id: linkedRegistration.child_id } }
          );
        }
      } catch (linkError) {
        console.error('Error linking financial assistance approval to child registration:', linkError);
      }
    }
    
    await this.sendFinancialDecisionNotification(financialRequest, action, managerId);
    
    res.status(200).json({
      success: true,
      message: `Financial assistance request ${action}d successfully`,
      request: {
        request_id: financialRequest.request_id,
        status: updatedStatus,
        approved_discount: updateData.approved_discount_percentage,
        approved_sessions: updateData.approved_sessions_count
      },
      scheduling_result: schedulingResult,
      next_steps: this.getNextStepsForAction(action, financialRequest)
    });
    
  } catch (error) {
    console.error('Error reviewing financial assistance request:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to review financial assistance request',
      error: error.message
    });
  }
};

exports.calculateEstimatedSubsidy = async (institutionId) => {
  try {
    const result = await FinancialAssistanceRequest.findAll({
      where: {
        institution_id: institutionId,
        status: 'approved',
        decision_date: {
          [Op.gte]: new Date(new Date() - 30 * 24 * 60 * 60 * 1000) 
        }
      },
      attributes: [
        [sequelize.fn('SUM', sequelize.literal('requested_total_amount * (approved_discount_percentage / 100)')), 'total_subsidy']
      ],
      raw: true
    });
    
    return result[0]?.total_subsidy || 0;
  } catch (error) {
    console.error('Error calculating subsidy:', error);
    return 0;
  }
};

exports.sendFinancialDecisionNotification = async (financialRequest, action, managerId) => {
  try {
    const Notification = require('../../model/Notification');
    const User = require('../../model/User');
    
    const manager = await User.findByPk(managerId, {
      attributes: ['full_name']
    });
    
    let title = '';
    let message = '';
    
    switch (action) {
      case 'approve':
        title = 'Financial Assistance Approved';
        message = `Your financial assistance request has been approved with ${financialRequest.approved_discount_percentage}% discount.`;
        break;
      case 'partial_approve':
        title = 'Partial Financial Assistance Approved';
        message = `Your financial assistance request has been partially approved with ${financialRequest.approved_discount_percentage}% discount.`;
        break;
      case 'request_documents':
        title = 'Documents Required';
        message = 'Additional documents are required to process your financial assistance request.';
        break;
      case 'reject':
        title = 'Financial Assistance Request Rejected';
        message = 'Your financial assistance request has been rejected. Contact the institution for more information.';
        break;
    }
    
    await Notification.create({
      user_id: financialRequest.parent_id,
      title: title,
      message: message,
      type: 'financial_assistance_update',
      related_id: financialRequest.request_id,
      is_read: false
    });
    
  } catch (error) {
    console.error('Error sending financial decision notification:', error);
  }
};

exports.getNextStepsForAction = (action, request) => {
  const steps = [];
  
  switch (action) {
    case 'approve':
      steps.push('Sessions will be scheduled automatically');
      steps.push('Parent will receive confirmation notification');
      steps.push('Follow up on payment if partial discount applied');
      break;
    case 'partial_approve':
      steps.push('Sessions will be scheduled with partial discount');
      steps.push('Inform parent about remaining balance');
      steps.push('Set up payment plan if needed');
      break;
    case 'request_documents':
      steps.push('Wait for parent to submit required documents');
      steps.push('Review documents within 3 business days');
      steps.push('Make final decision after document verification');
      break;
    case 'reject':
      steps.push('Provide alternative options to parent if available');
      steps.push('Consider payment plans or installments');
      steps.push('Document rejection reason for records');
      break;
  }
  
  return steps;
};

module.exports = exports;

