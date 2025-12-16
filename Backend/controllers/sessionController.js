const Session = require('../model/Session');
const Child = require('../model/Child');
const Institution = require('../model/Institution');
const User = require('../model/User');
const SessionType = require('../model/SessionType');
const Invoice = require('../model/Invoice');
const Payment = require('../model/Payment');
const Notification = require('../model/Notification');
const FinancialAssistanceRequest = require('../model/FinancialAssistanceRequest');
const SessionFinancialAidRequest = require('../model/SessionFinancialAidRequest');
const DonationAllocation = require('../model/DonationAllocation');
const sequelize = require('../config/db');
const { Op } = require('sequelize');
const { createInvoiceForSession } = require('./invoiceController');



const getUpcomingSessions = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const children = await Child.findAll({
      where: {
        parent_id: parentId,
        registration_status: 'Approved'
      }
    });

    const childIds = children.map(c => c.child_id);
    if (childIds.length === 0) return res.status(200).json({ sessions: [] });

    const sessions = await Session.findAll({
      where: {
        child_id: { [Op.in]: childIds },
        status: ['Scheduled', 'Rescheduled'] 
      },
      include: [
        {
          model: Child,
          attributes: ['full_name'],
          as: 'child'
        },
        { model: User, attributes: ['full_name'], as: 'specialist' },
        { model: Institution, attributes: ['name'], as: 'institution' },
        { model: SessionType, attributes: ['name', 'duration', 'price'] }
      ],
      order: [['date', 'ASC'], ['time', 'ASC']]
    });

    const formatted = sessions.map(s => ({
      sessionId: s.session_id,
      childName: s.child.full_name,
      specialistName: s.specialist.full_name,
      institutionName: s.institution.name,
      sessionType: s.SessionType ? s.SessionType.name : 'N/A',
      duration: s.SessionType ? s.SessionType.duration : s.duration,
      price: s.SessionType ? parseFloat(s.SessionType.price) : parseFloat(s.price || 0),
      date: s.date,
      time: s.time,
      sessionLocation: s.session_type,
      status: s.status,
      isPaid: s.is_paid, 
      paymentStatus: s.payment_status 
    }));

    res.status(200).json({ sessions: formatted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

const parentSessionDecision = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { id } = req.params; // session id
    const { decision, requested_percentage, requested_amount, notes } = req.body;

    if (!decision || !['pay_full', 'request_aid', 'reject'].includes(decision)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid decision. Use pay_full, request_aid, or reject'
      });
    }

    const session = await Session.findByPk(id, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'parent_id', 'full_name']
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'price']
        },
        {
          model: Institution,
          as: 'institution',
          attributes: ['institution_id', 'donation_balance']
        }
      ]
    });

    if (!session || !session.child) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }
    if (session.child.parent_id !== parentId) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    if (session.status !== 'Pending Approval') {
      return res.status(400).json({
        success: false,
        message: 'Session is not pending parent decision',
        current_status: session.status
      });
    }

    const baseAmount = parseFloat(session.SessionType?.price) || 0;

    if (decision === 'reject') {
      await session.update({
        status: 'Rejected',
        parent_approved: false,
        is_pending: false,
        is_visible: false
      });

      return res.status(200).json({
        success: true,
        message: 'Session rejected by parent',
        session_id: session.session_id,
        new_status: 'Rejected'
      });
    }

    if (decision === 'pay_full') {
      const existingInvoice = await Invoice.findOne({ where: { session_id: session.session_id } });
      const invoice = existingInvoice
        ? existingInvoice
        : await Invoice.create({
            session_id: session.session_id,
            parent_id: parentId,
            institution_id: session.institution_id,
            invoice_number: `INV-${Date.now()}-${session.session_id}`,
            amount: baseAmount,
            tax_amount: 0,
            total_amount: baseAmount,
            status: 'Pending',
            due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
            issued_date: new Date(),
            notes: `Invoice for session ${session.session_id}`
          });

      await session.update({
        status: 'Scheduled',
        parent_approved: true,
        is_pending: false,
        is_paid: false,
        payment_status: 'Pending',
        original_price: baseAmount,
        applied_discount_percentage: 0,
        final_price: baseAmount,
        financial_assistance_applied: false,
        discount_reason: null
      });

      return res.status(200).json({
        success: true,
        message: 'Session approved by parent (full payment) and invoice created',
        session_id: session.session_id,
        new_status: 'Scheduled',
        invoice_id: invoice.invoice_id
      });
    }

    // decision === 'request_aid'
    // Fetch parent financial tier if exists (optional)
    let lastFinancialRequest = null;
    try {
      lastFinancialRequest = await FinancialAssistanceRequest.findOne({
        where: {
          child_id: session.child.child_id,
          institution_id: session.institution_id,
          status: { [Op.in]: ['approved', 'partially_approved', 'submitted', 'under_review', 'auto_generated'] }
        },
        order: [['created_at', 'DESC']]
      });
    } catch (e) {
      // ignore
    }

    // Parent should not be required to set any numbers; they can be omitted.
    const reqPercent = requested_percentage != null ? parseFloat(requested_percentage) : null;
    const reqAmount = requested_amount != null ? parseFloat(requested_amount) : null;

    const aidRequest = await SessionFinancialAidRequest.create({
      session_id: session.session_id,
      parent_id: parentId,
      child_id: session.child.child_id,
      institution_id: session.institution_id,
      parent_financial_request_id: lastFinancialRequest ? lastFinancialRequest.request_id : null,
      status: 'submitted',
      requested_percentage: Number.isFinite(reqPercent) ? reqPercent : null,
      requested_amount: Number.isFinite(reqAmount) ? reqAmount : null,
      decision_notes: notes || null
    });

    // ================== Auto Rules ==================
    const institutionBalance = parseFloat(session.institution?.donation_balance) || 0;
    const tier = lastFinancialRequest?.parent_financial_tier || null;
    const score = lastFinancialRequest?.parent_financial_score || null;

    // Suggested percent from score if not provided
    let suggestedPercent = Number.isFinite(reqPercent) ? reqPercent : 0;
    if ((!Number.isFinite(suggestedPercent) || suggestedPercent <= 0) && Number.isFinite(score)) {
      suggestedPercent = score >= 40 ? Math.min(100, Math.floor(score * 1.5)) : 0;
    }
    if (!Number.isFinite(suggestedPercent) || suggestedPercent < 0) suggestedPercent = 0;
    if (suggestedPercent > 100) suggestedPercent = 100;

    // If tier indicates no assistance
    if (tier === 'tier_5_no_assistance') {
      await aidRequest.update({
        status: 'rejected',
        decision_date: new Date(),
        decision_notes: aidRequest.decision_notes
          ? `${aidRequest.decision_notes}`
          : null
      });

      return res.status(200).json({
        success: true,
        message: 'Financial aid request submitted but auto-rejected by institution policy',
        session_id: session.session_id,
        aid_request_id: aidRequest.request_id,
        aid_status: 'rejected',
        next_action: 'parent_decision_required'
      });
    }

    // Calculate max affordable discount from donation balance
    const percentDiscountAmount = (baseAmount * suggestedPercent) / 100;
    const capAmount = Number.isFinite(reqAmount) && reqAmount > 0 ? reqAmount : percentDiscountAmount;
    const desiredDiscountCap = Math.min(percentDiscountAmount, capAmount);
    const approvedDiscount = Math.min(desiredDiscountCap, institutionBalance);

    if (approvedDiscount <= 0) {
      await aidRequest.update({ status: 'under_review' });
      return res.status(200).json({
        success: true,
        message: 'Financial aid request submitted and pending manager review',
        session_id: session.session_id,
        aid_request_id: aidRequest.request_id,
        aid_status: 'under_review'
      });
    }

    const desiredDiscount = approvedDiscount;

    let invoice;
    let discountAmount = 0;
    let finalAmount = baseAmount;
    let approvedPercent = 0;
    let newStatus = 'under_review';

    await sequelize.transaction(async (t) => {
      const inst = await Institution.findByPk(session.institution_id, {
        transaction: t,
        lock: t.LOCK.UPDATE,
      });

      const currentBalance = parseFloat(inst?.donation_balance || 0);
      const approvedDiscountTxn = Math.min(desiredDiscount, currentBalance);

      discountAmount = Math.max(0, Math.min(baseAmount, approvedDiscountTxn));
      finalAmount = Math.max(0, baseAmount - discountAmount);
      approvedPercent =
          baseAmount > 0 ? Math.min(100, (discountAmount / baseAmount) * 100) : 0;
      newStatus = discountAmount >= baseAmount ? 'approved' : 'partial_approved';

      await aidRequest.update(
        {
          status: newStatus,
          approved_amount: discountAmount,
          approved_percentage: approvedPercent,
          decision_date: new Date(),
        },
        { transaction: t }
      );

      const existingInvoice = await Invoice.findOne({
        where: { session_id: session.session_id },
        transaction: t,
        lock: t.LOCK.UPDATE,
      });

      invoice = existingInvoice
        ? existingInvoice
        : await Invoice.create(
            {
              session_id: session.session_id,
              parent_id: parentId,
              institution_id: session.institution_id,
              invoice_number: `INV-${Date.now()}-${session.session_id}`,
              amount: finalAmount,
              tax_amount: 0,
              total_amount: finalAmount,
              status: 'Pending',
              due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
              issued_date: new Date(),
              notes:
                finalAmount === 0
                  ? `Free session funded by financial aid (request ${aidRequest.request_id}).`
                  : `Invoice for session with financial aid discount applied (request ${aidRequest.request_id}).`,
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

      if (discountAmount > 0 && inst) {
        const allocations = await DonationAllocation.findAll({
          where: {
            institution_id: inst.institution_id,
            invoice_id: invoice.invoice_id,
          },
          transaction: t,
          lock: t.LOCK.UPDATE,
        });

        const alreadyAllocated = allocations.reduce(
          (sum, a) => sum + (parseFloat(a.amount_allocated) || 0),
          0
        );

        const remainingToAllocate = Math.max(0, discountAmount - alreadyAllocated);
        const deltaAllocate = Math.min(remainingToAllocate, currentBalance);

        if (deltaAllocate > 0) {
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
            { donation_balance: Math.max(0, currentBalance - deltaAllocate) },
            { transaction: t }
          );
        }
      }

      await session.update(
        {
          status: 'Scheduled',
          parent_approved: true,
          is_pending: false,
          is_paid: false,
          payment_status: finalAmount === 0 ? 'Paid' : 'Pending',
          original_price: baseAmount,
          applied_discount_percentage: approvedPercent,
          final_price: finalAmount,
          financial_assistance_applied: discountAmount > 0,
          financial_assistance_request_id: aidRequest.parent_financial_request_id,
          discount_reason: 'Session financial aid',
        },
        { transaction: t }
      );
    });

    return res.status(200).json({
      success: true,
      message: finalAmount === 0
        ? 'Financial aid approved (free session) and invoice created'
        : 'Financial aid approved and invoice created',
      session_id: session.session_id,
      new_status: 'Scheduled',
      invoice_id: invoice.invoice_id,
      aid_request_id: aidRequest.request_id,
      aid_status: newStatus,
      pricing: {
        original: baseAmount,
        discount: discountAmount,
        final: finalAmount
      }
    });
  } catch (err) {
    console.error('Parent session decision error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: err.message
    });
  }
};


const getCompletedSessions = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const children = await Child.findAll({ where: { parent_id: parentId } });
    const childIds = children.map(c => c.child_id);
    if (!childIds.length) return res.json({ sessions: [] });

    const sessions = await Session.findAll({
      where: { child_id: childIds, status: 'Completed' },
      include: [
        { model: Child, attributes: ['full_name'], as: 'child' },
        { model: User, attributes: ['full_name'], as: 'specialist' },
        { model: Institution, attributes: ['name'], as: 'institution' },
        { model: SessionType, attributes: ['name', 'duration', 'price'] }
      ],
      order: [['date', 'DESC'], ['time', 'DESC']]
    });

    const formatted = sessions.map(s => ({
      sessionId: s.session_id,
      childName: s.child.full_name,
      specialistName: s.specialist.full_name,
      institutionName: s.institution.name,
      sessionType: s.SessionType ? s.SessionType.name : (s.session_type || 'N/A'),
      duration: s.SessionType ? s.SessionType.duration : s.duration,
      price: s.SessionType ? parseFloat(s.SessionType.price) : parseFloat(s.price || 0),
      date: s.date,
      time: s.time,
      sessionLocation: s.session_type,
      status: s.status,
      rating: null,
      review: null, 
    }));

    res.json({ sessions: formatted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

const confirmSession = async (req, res) => {
  const { id } = req.params;
  try {
    const session = await Session.findByPk(id);
    if (!session) return res.status(404).json({ message: 'Session not found' });

    session.status = 'Confirmed';
    await session.save();
    res.json({ success: true, message: 'Session confirmed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};


const cancelSession = async (req, res) => {
// here send notification to specialist and refund pay
  const { id } = req.params;
  const { reason } = req.body;

  try {
    const session = await Session.findByPk(id, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['full_name']
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['user_id', 'full_name']
        }
      ]
    });

    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });

    const parentId = req.user.user_id;
    const child = await Child.findOne({
      where: { child_id: session.child_id, parent_id: parentId }
    });

    if (!child) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    await session.update({
      status: 'Cancelled',
      reason: reason || 'Cancelled by parent'
    });

    res.json({
      success: true,
      message: 'Session cancelled successfully'
    });
  } catch (err) {
    console.error('Cancel session error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Parent confirms automatically scheduled initial assessment session
const parentConfirmAutoSession = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { id } = req.params; // session id

    const session = await Session.findByPk(id, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'parent_id']
        }
      ]
    });

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'Session not found'
      });
    }

    if (!session.child || session.child.parent_id !== parentId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You can only confirm sessions for your own child.'
      });
    }

    if (session.status !== 'Pending Approval') {
      return res.status(400).json({
        success: false,
        message: 'Session is not pending parent confirmation',
        current_status: session.status
      });
    }

    const sessionType = await SessionType.findByPk(session.session_type_id);
    if (!sessionType) {
      return res.status(400).json({
        success: false,
        message: 'Session type not found for this session'
      });
    }

    // ================== Financial Assistance Discount Logic ==================
    let baseAmount = parseFloat(sessionType.price) || 0;
    let discountPercentage = 0;

    let financialRequest = null;

    try {
      // ابحث عن آخر طلب مساعدة مالية معتمد أو معتمد جزئياً لنفس الطفل والمؤسسة
      financialRequest = await FinancialAssistanceRequest.findOne({
        where: {
          child_id: session.child.child_id,
          institution_id: session.institution_id,
          status: {
            [Op.in]: ['approved', 'partially_approved']
          }
        },
        order: [['decision_date', 'DESC']]
      });

      if (financialRequest) {
        // النسبة الأساسية للخصم من قرار المساعدة المالية
        let baseDiscount =
          parseFloat(financialRequest.approved_discount_percentage) ||
          parseFloat(financialRequest.requested_discount_percentage) ||
          0;

        // حد الجلسات المدعومة (إن وجد)
        const approvedSessionsLimit =
          typeof financialRequest.approved_sessions_count === 'number'
            ? financialRequest.approved_sessions_count
            : (typeof financialRequest.requested_sessions_count === 'number'
                ? financialRequest.requested_sessions_count
                : null);

        if (approvedSessionsLimit && approvedSessionsLimit > 0) {
          // عدد الجلسات التي استخدمت خصم فعلاً لهذا الطفل وهذه المؤسسة
          const usedSupportedSessions = await Session.count({
            where: {
              child_id: session.child.child_id,
              institution_id: session.institution_id,
              financial_assistance_applied: true
            }
          });

          const remainingSupported = Math.max(0, approvedSessionsLimit - usedSupportedSessions);

          if (remainingSupported <= 0) {
            // تم استنفاد عدد الجلسات المدعومة، لا نطبق خصم على هذه الجلسة
            baseDiscount = 0;
          }
        }

        discountPercentage = baseDiscount;
      }
    } catch (faError) {
      console.error('Error fetching financial assistance for session invoice:', faError);
    }

    if (!Number.isFinite(discountPercentage) || discountPercentage < 0) {
      discountPercentage = 0;
    }
    if (discountPercentage > 100) {
      discountPercentage = 100;
    }

    const discountAmount = (baseAmount * discountPercentage) / 100;
    const finalAmount = Math.max(0, baseAmount - discountAmount);

    const taxAmount = 0;
    const totalAmount = finalAmount + taxAmount;

    const invoiceNumber = `INV-${Date.now()}-${session.session_id}`;

    const dueDate = new Date(session.date);
    dueDate.setDate(dueDate.getDate() + 3);

    let invoice;

    await sequelize.transaction(async (t) => {
      const existingInvoice = await Invoice.findOne({
        where: { session_id: session.session_id },
        transaction: t,
        lock: t.LOCK.UPDATE,
      });

      invoice = existingInvoice
        ? existingInvoice
        : await Invoice.create(
            {
              session_id: session.session_id,
              parent_id: parentId,
              institution_id: session.institution_id,
              invoice_number: invoiceNumber,
              amount: finalAmount,
              tax_amount: taxAmount,
              total_amount: totalAmount,
              status: 'Pending',
              due_date: dueDate,
              issued_date: new Date(),
              notes:
                discountPercentage > 0
                  ? `Invoice for initial assessment session on ${session.date} with ${discountPercentage}% financial assistance discount applied.`
                  : `Invoice for initial assessment session on ${session.date}`,
            },
            { transaction: t }
          );

      if (existingInvoice) {
        await existingInvoice.update(
          {
            amount: finalAmount,
            total_amount: totalAmount,
            status: totalAmount === 0 ? 'Paid' : existingInvoice.status,
          },
          { transaction: t }
        );
      }

      if (discountAmount > 0) {
        const institution = await Institution.findByPk(session.institution_id, {
          transaction: t,
          lock: t.LOCK.UPDATE,
        });

        if (institution) {
          const currentBalance = parseFloat(institution.donation_balance || 0);
          const allocationTarget = Math.min(discountAmount, currentBalance);

          const allocations = await DonationAllocation.findAll({
            where: {
              institution_id: institution.institution_id,
              invoice_id: invoice.invoice_id,
            },
            transaction: t,
            lock: t.LOCK.UPDATE,
          });

          const alreadyAllocated = allocations.reduce(
            (sum, a) => sum + (parseFloat(a.amount_allocated) || 0),
            0
          );

          const remainingToAllocate = Math.max(0, allocationTarget - alreadyAllocated);
          const deltaAllocate = Math.min(remainingToAllocate, currentBalance);

          if (deltaAllocate > 0) {
            await DonationAllocation.create(
              {
                institution_id: institution.institution_id,
                donation_id: null,
                invoice_id: invoice.invoice_id,
                financial_assistance_request_id:
                    financialRequest ? financialRequest.request_id : null,
                amount_allocated: deltaAllocate,
              },
              { transaction: t }
            );

            await institution.update(
              { donation_balance: Math.max(0, currentBalance - deltaAllocate) },
              { transaction: t }
            );
          }
        }
      }
    });

    // تحديث الجلسة بمعلومات التسعير والخصم (إن توفرت الحقول في الجدول)
    await session.update({
      status: 'Scheduled',
      payment_status: totalAmount === 0 ? 'Paid' : 'Pending',
      original_price: baseAmount,
      final_price: finalAmount,
      applied_discount_percentage: discountPercentage,
      financial_assistance_applied: discountPercentage > 0
    });

    return res.status(200).json({
      success: true,
      message: 'Session confirmed by parent and invoice created',
      session_id: session.session_id,
      new_status: 'Scheduled',
      invoice_id: invoice.invoice_id
    });

  } catch (err) {
    console.error('Parent confirm auto session error:', err);
    return res.status(500).json({
      success: false,
      message: 'Server error',
      error: err.message
    });
  }
};
const getChildSessions = async (req, res) => {
  try {
    const { childId } = req.params; 
    const userId = req.user.user_id;
    const userRole = req.user.role;

    if (!childId) return res.status(400).json({ message: 'Child ID is required' });

    if (userRole === 'Parent') {
      const child = await Child.findOne({
        where: { 
          child_id: childId,
          parent_id: userId
        }
      });

      if (!child) {
        return res.status(403).json({ 
          message: 'Access denied. This child does not belong to you.' 
        });
      }
    }

    const sessions = await Session.findAll({
      where: { child_id: childId, status: ['Scheduled', 'Completed', 'Cancelled', 'Confirmed'] },
      include: [
        { model: Child, attributes: ['full_name'], as: 'child' },
        { model: User, attributes: ['full_name'], as: 'specialist' },
        { model: Institution, attributes: ['name'], as: 'institution' },
      ],
      order: [['date', 'ASC'], ['time', 'ASC']]
    });

    const formatted = sessions.map(s => ({
      sessionId: s.session_id,
      childName: s.child.full_name,
      specialistName: s.specialist.full_name,
      institutionName: s.institution.name,
      date: s.date,
      time: s.time,
      duration: s.duration,
      price: s.price,
      sessionType: s.session_type,
      status: s.status,
    }));

    res.status(200).json({ sessions: formatted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};



const getAllSessions = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const children = await Child.findAll({ 
      where: { 
        parent_id: parentId,
        registration_status: 'Approved'
      } 
    });
    
    const childIds = children.map(c => c.child_id);
    if (childIds.length === 0) return res.status(200).json({ sessions: [] });

    const sessions = await Session.findAll({
      where: { 
        child_id: { [Op.in]: childIds }
      },
      include: [
        { 
          model: Child, 
          attributes: ['full_name'], 
          as: 'child'
        },
        { 
          model: User, 
          attributes: ['full_name'], 
          as: 'specialist' 
        },
        { 
          model: Institution, 
          attributes: ['name'], 
          as: 'institution' 
        }
      ],
      order: [['date', 'DESC'], ['time', 'DESC']]
    });

    const formatted = sessions.map(s => ({
      sessionId: s.session_id,
      childName: s.child.full_name,
      specialistName: s.specialist.full_name,
      institutionName: s.institution.name,
      sessionType: s.session_type,
      date: s.date,
      time: s.time,
      duration: s.duration,
      price: s.price,
      sessionLocation: s.session_location || s.session_type,
      status: s.status,
    }));

    res.status(200).json({ sessions: formatted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.approveSession = async (req, res) => {
  try {
    const { sessionId } = req.params;
    
    const session = await Session.findByPk(sessionId);
    await session.update({ status: 'Pending Payment' });
    
    const invoice = await createInvoiceForSession(sessionId);
    
    res.json({
      success: true,
      message: 'Session approved and invoice generated',
      session: { ...session.toJSON(), invoice }
    });
  } catch (error) {
    console.error('Error approving session:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

const getPendingSessions = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const children = await Child.findAll({ 
      where: { 
        parent_id: parentId,
        registration_status: 'Approved' 
      } 
    });
    
    const childIds = children.map(c => c.child_id);
    if (childIds.length === 0) return res.status(200).json({ sessions: [] });

    const sessions = await Session.findAll({
      where: { 
        child_id: { [Op.in]: childIds },
        status: 'Pending Approval'
      },
      include: [
        { 
          model: Child, 
          attributes: ['full_name'], 
          as: 'child'
        },
        { model: User, attributes: ['full_name'], as: 'specialist' },
        { model: Institution, attributes: ['name'], as: 'institution' },
        { model: SessionType, attributes: ['name', 'duration', 'price'] }
      ],
      order: [['date', 'ASC'], ['time', 'ASC']]
    });

    const formatted = sessions.map(s => ({
      sessionId: s.session_id,
      childName: s.child.full_name,
      specialistName: s.specialist.full_name,
      institutionName: s.institution.name,
      sessionType: s.SessionType ? s.SessionType.name : 'N/A', 
      duration: s.SessionType ? s.SessionType.duration : s.duration, 
      price: s.SessionType ? parseFloat(s.SessionType.price) : parseFloat(s.price || 0),
      date: s.date,
      time: s.time,
      sessionLocation: s.session_type,
      status: s.status,
    }));

    res.status(200).json({ sessions: formatted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

const getCancelledSessions = async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const children = await Child.findAll({ 
      where: { 
        parent_id: parentId,
        registration_status: 'Approved' 
      } 
    });
    
    const childIds = children.map(c => c.child_id);
    if (childIds.length === 0) return res.status(200).json({ sessions: [] });

    const sessions = await Session.findAll({
      where: { 
        child_id: { [Op.in]: childIds },
        status: 'Cancelled'
      },
      include: [
        { 
          model: Child, 
          attributes: ['full_name'], 
          as: 'child'
        },
        { model: User, attributes: ['full_name'], as: 'specialist' },
        { model: Institution, attributes: ['name'], as: 'institution' },
        { model: SessionType, attributes: ['name', 'duration', 'price'] }
      ],
      order: [['date', 'DESC'], ['time', 'DESC']]
    });

    const formatted = sessions.map(s => ({
      sessionId: s.session_id,
      childName: s.child.full_name,
      specialistName: s.specialist.full_name,
      institutionName: s.institution.name,
      sessionType: s.SessionType ? s.SessionType.name : 'N/A', 
      duration: s.SessionType ? s.SessionType.duration : s.duration, 
      price: s.SessionType ? parseFloat(s.SessionType.price) : parseFloat(s.price || 0),
      date: s.date,
      time: s.time,
      sessionLocation: s.session_type,
      status: s.status,
      cancellationReason: s.reason || null, 
    }));

    res.status(200).json({ sessions: formatted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

const rateSession = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { id } = req.params;
    const { rating, review } = req.body;

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ 
        success: false, 
        message: 'Rating must be between 1 and 5' 
      });
    }

    const session = await Session.findByPk(id, {
      include: [{
        model: Child,
        as: 'child',
        attributes: ['child_id', 'parent_id']
      }]
    });

    if (!session) {
      return res.status(404).json({ success: false, message: 'Session not found' });
    }

    if (session.child.parent_id !== parentId) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    if (session.status !== 'Completed') {
      return res.status(400).json({ 
        success: false, 
        message: 'Can only rate completed sessions' 
      });
    }

   
    await session.update({
      parent_notes: review || session.parent_notes || null
    });

   
    res.json({ 
      success: true, 
      message: 'Session rated successfully',
      rating: rating,
      review: review
    });
  } catch (err) {
    console.error('Rate session error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const processPayment = async (req, res) => {
  try {
      const { id } = req.params;
      const { paymentMethod, paymentDetails } = req.body;
      const parentId = req.user.user_id;

      console.log('💳 Processing payment for session:', { id, paymentMethod });

      const session = await Session.findOne({
        where: { session_id: id },
        include: [
          {
            model: Child,
            as: 'child',
            where: { parent_id: parentId },
            attributes: ['child_id']
          },
          {
            model: SessionType,
            attributes: ['price']
          },
          {
            model: Invoice, 
            as: 'Invoice',
            attributes: ['invoice_id', 'status']
          }
        ]
      });

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'Session not found or access denied'
      });
    }

    if (session.is_paid && session.payment_status === 'Paid') {
      return res.status(400).json({
        success: false,
        message: 'Session is already paid'
      });
    }

    
    const paymentSuccess = true;

    if (paymentSuccess) {
      await session.update({
        is_paid: true,
        payment_status: 'Paid',
        payment_date: new Date(),
        status: 'Scheduled' 
      });

      let invoice = await Invoice.findOne({ where: { session_id: id } });

      if (!invoice) {
        invoice = await Invoice.create({
          session_id: id,
          parent_id: parentId,
          institution_id: session.institution_id,
          invoice_number: `INV-${Date.now()}-${id}`,
          amount: session.SessionType ? session.SessionType.price : session.price,
          tax_amount: 0,
          total_amount: session.SessionType ? session.SessionType.price : session.price,
          status: 'Paid',
          due_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), 
          issued_date: new Date(),
          paid_date: new Date()
        });
      } else {
        await invoice.update({
          status: 'Paid',
          paid_date: new Date()
        });
      }

      await Payment.create({
        invoice_id: invoice.invoice_id,
        amount: invoice.total_amount,
        payment_method: paymentMethod || 'Credit Card',
        payment_gateway: 'Mock Gateway',
        transaction_id: `TXN-${Date.now()}-${id}`,
        status: 'Completed',
        payment_date: new Date()
      });

      if (session.specialist_id) {
        await Notification.create({
          user_id: session.specialist_id,
          title: 'Payment Received',
          message: `Payment has been received for session with ${session.child.full_name} scheduled on ${session.date}`,
          type: 'payment_received',
          related_id: session.session_id,
          is_read: false
        });
      }

      res.json({
        success: true,
        message: 'Payment processed successfully',
        session: {
          session_id: session.session_id,
          status: 'Scheduled',
          is_paid: true,
          payment_status: 'Paid'
        },
        invoice: {
          invoice_number: invoice.invoice_number,
          amount: invoice.total_amount
        }
      });
    } else {
      throw new Error('Payment processing failed');
    }

  } catch (error) {
    console.error('❌ Payment processing error:', error);
    res.status(500).json({
      success: false,
      message: 'Payment processing failed: ' + error.message
    });
  }
};

module.exports = {
  getUpcomingSessions,
  getCompletedSessions,
  getPendingSessions,
  getCancelledSessions,
  confirmSession,
  cancelSession,
   parentConfirmAutoSession,
  parentSessionDecision,
  rateSession,
  getChildSessions,
  getAllSessions,
  processPayment
};

