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
const AutoFinancialAidService = require('../services/autoFinancialAidService');



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

// const parentSessionDecision = async (req, res) => {
//   try {
//     const parentId = req.user.user_id;
//     const { id } = req.params; // session id
//     const { decision, requested_percentage, requested_amount, notes } = req.body;

//     if (!decision || !['pay_full', 'request_aid', 'reject'].includes(decision)) {
//       return res.status(400).json({
//         success: false,
//         message: 'Invalid decision. Use pay_full, request_aid, or reject'
//       });
//     }

//     const session = await Session.findByPk(id, {
//       include: [
//         {
//           model: Child,
//           as: 'child',
//           attributes: ['child_id', 'parent_id', 'full_name']
//         },
//         {
//           model: SessionType,
//           attributes: ['session_type_id', 'name', 'price']
//         },
//         {
//           model: Institution,
//           as: 'institution',
//           attributes: ['institution_id', 'donation_balance']
//         }
//       ]
//     });

//     if (!session || !session.child) {
//       return res.status(404).json({ success: false, message: 'Session not found' });
//     }
//     if (session.child.parent_id !== parentId) {
//       return res.status(403).json({ success: false, message: 'Access denied' });
//     }
//     if (session.status !== 'Pending Approval') {
//       return res.status(400).json({
//         success: false,
//         message: 'Session is not pending parent decision',
//         current_status: session.status
//       });
//     }

//     const baseAmount = parseFloat(session.SessionType?.price) || 0;

//     if (decision === 'reject') {
//       await session.update({
//         status: 'Rejected',
//         parent_approved: false,
//         is_pending: false,
//         is_visible: false
//       });

//       return res.status(200).json({
//         success: true,
//         message: 'Session rejected by parent',
//         session_id: session.session_id,
//         new_status: 'Rejected'
//       });
//     }

//     if (decision === 'pay_full') {
//       const existingInvoice = await Invoice.findOne({ where: { session_id: session.session_id } });
//       const invoice = existingInvoice
//         ? existingInvoice
//         : await Invoice.create({
//             session_id: session.session_id,
//             parent_id: parentId,
//             institution_id: session.institution_id,
//             invoice_number: `INV-${Date.now()}-${session.session_id}`,
//             amount: baseAmount,
//             tax_amount: 0,
//             total_amount: baseAmount,
//             status: 'Pending',
//             due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
//             issued_date: new Date(),
//             notes: `Invoice for session ${session.session_id}`
//           });

//       await session.update({
//         status: 'Scheduled',
//         parent_approved: true,
//         is_pending: false,
//         is_paid: false,
//         payment_status: 'Pending',
//         original_price: baseAmount,
//         applied_discount_percentage: 0,
//         final_price: baseAmount,
//         financial_assistance_applied: false,
//         discount_reason: null
//       });

//       return res.status(200).json({
//         success: true,
//         message: 'Session approved by parent (full payment) and invoice created',
//         session_id: session.session_id,
//         new_status: 'Scheduled',
//         invoice_id: invoice.invoice_id
//       });
//     }

//     // decision === 'request_aid'
//     // Fetch parent financial tier if exists (optional)
//     let lastFinancialRequest = null;
//     try {
//       lastFinancialRequest = await FinancialAssistanceRequest.findOne({
//         where: {
//           child_id: session.child.child_id,
//           institution_id: session.institution_id,
//           status: { [Op.in]: ['approved', 'partially_approved', 'submitted', 'under_review', 'auto_generated'] }
//         },
//         order: [['created_at', 'DESC']]
//       });
//     } catch (e) {
//       // ignore
//     }

//     // Parent should not be required to set any numbers; they can be omitted.
//     const reqPercent = requested_percentage != null ? parseFloat(requested_percentage) : null;
//     const reqAmount = requested_amount != null ? parseFloat(requested_amount) : null;

//     const aidRequest = await SessionFinancialAidRequest.create({
//       session_id: session.session_id,
//       parent_id: parentId,
//       child_id: session.child.child_id,
//       institution_id: session.institution_id,
//       parent_financial_request_id: lastFinancialRequest ? lastFinancialRequest.request_id : null,
//       status: 'submitted',
//       requested_percentage: Number.isFinite(reqPercent) ? reqPercent : null,
//       requested_amount: Number.isFinite(reqAmount) ? reqAmount : null,
//       decision_notes: notes || null
//     });

//     // ================== Auto Rules ==================
//     const institutionBalance = parseFloat(session.institution?.donation_balance) || 0;
//     const tier = lastFinancialRequest?.parent_financial_tier || null;
//     const score = lastFinancialRequest?.parent_financial_score || null;

//     // Suggested percent from score if not provided
//     let suggestedPercent = Number.isFinite(reqPercent) ? reqPercent : 0;
//     if ((!Number.isFinite(suggestedPercent) || suggestedPercent <= 0) && Number.isFinite(score)) {
//       suggestedPercent = score >= 40 ? Math.min(100, Math.floor(score * 1.5)) : 0;
//     }
//     if (!Number.isFinite(suggestedPercent) || suggestedPercent < 0) suggestedPercent = 0;
//     if (suggestedPercent > 100) suggestedPercent = 100;

//     // If tier indicates no assistance
//     if (tier === 'tier_5_no_assistance') {
//       await aidRequest.update({
//         status: 'rejected',
//         decision_date: new Date(),
//         decision_notes: aidRequest.decision_notes
//           ? `${aidRequest.decision_notes}`
//           : null
//       });

//       return res.status(200).json({
//         success: true,
//         message: 'Financial aid request submitted but auto-rejected by institution policy',
//         session_id: session.session_id,
//         aid_request_id: aidRequest.request_id,
//         aid_status: 'rejected',
//         next_action: 'parent_decision_required'
//       });
//     }

//     // Calculate max affordable discount from donation balance
//     const percentDiscountAmount = (baseAmount * suggestedPercent) / 100;
//     const capAmount = Number.isFinite(reqAmount) && reqAmount > 0 ? reqAmount : percentDiscountAmount;
//     const desiredDiscountCap = Math.min(percentDiscountAmount, capAmount);
//     const approvedDiscount = Math.min(desiredDiscountCap, institutionBalance);

//     if (approvedDiscount <= 0) {
//       await aidRequest.update({ status: 'under_review' });
//       return res.status(200).json({
//         success: true,
//         message: 'Financial aid request submitted and pending manager review',
//         session_id: session.session_id,
//         aid_request_id: aidRequest.request_id,
//         aid_status: 'under_review'
//       });
//     }

//     const desiredDiscount = approvedDiscount;

//     let invoice;
//     let discountAmount = 0;
//     let finalAmount = baseAmount;
//     let approvedPercent = 0;
//     let newStatus = 'under_review';

//     await sequelize.transaction(async (t) => {
//       const inst = await Institution.findByPk(session.institution_id, {
//         transaction: t,
//         lock: t.LOCK.UPDATE,
//       });

//       const currentBalance = parseFloat(inst?.donation_balance || 0);
//       const approvedDiscountTxn = Math.min(desiredDiscount, currentBalance);

//       discountAmount = Math.max(0, Math.min(baseAmount, approvedDiscountTxn));
//       finalAmount = Math.max(0, baseAmount - discountAmount);
//       approvedPercent =
//           baseAmount > 0 ? Math.min(100, (discountAmount / baseAmount) * 100) : 0;
//       newStatus = discountAmount >= baseAmount ? 'approved' : 'partial_approved';

//       await aidRequest.update(
//         {
//           status: newStatus,
//           approved_amount: discountAmount,
//           approved_percentage: approvedPercent,
//           decision_date: new Date(),
//         },
//         { transaction: t }
//       );

//       const existingInvoice = await Invoice.findOne({
//         where: { session_id: session.session_id },
//         transaction: t,
//         lock: t.LOCK.UPDATE,
//       });

//       invoice = existingInvoice
//         ? existingInvoice
//         : await Invoice.create(
//             {
//               session_id: session.session_id,
//               parent_id: parentId,
//               institution_id: session.institution_id,
//               invoice_number: `INV-${Date.now()}-${session.session_id}`,
//               amount: finalAmount,
//               tax_amount: 0,
//               total_amount: finalAmount,
//               status: 'Pending',
//               due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
//               issued_date: new Date(),
//               notes:
//                 finalAmount === 0
//                   ? `Free session funded by financial aid (request ${aidRequest.request_id}).`
//                   : `Invoice for session with financial aid discount applied (request ${aidRequest.request_id}).`,
//             },
//             { transaction: t }
//           );

//       if (existingInvoice) {
//         await existingInvoice.update(
//           {
//             amount: finalAmount,
//             total_amount: finalAmount,
//             status: finalAmount === 0 ? 'Paid' : existingInvoice.status,
//           },
//           { transaction: t }
//         );
//       }

//       if (discountAmount > 0 && inst) {
//         const allocations = await DonationAllocation.findAll({
//           where: {
//             institution_id: inst.institution_id,
//             invoice_id: invoice.invoice_id,
//           },
//           transaction: t,
//           lock: t.LOCK.UPDATE,
//         });

//         const alreadyAllocated = allocations.reduce(
//           (sum, a) => sum + (parseFloat(a.amount_allocated) || 0),
//           0
//         );

//         const remainingToAllocate = Math.max(0, discountAmount - alreadyAllocated);
//         const deltaAllocate = Math.min(remainingToAllocate, currentBalance);

//         if (deltaAllocate > 0) {
//           await DonationAllocation.create(
//             {
//               institution_id: inst.institution_id,
//               donation_id: null,
//               invoice_id: invoice.invoice_id,
//               financial_assistance_request_id: aidRequest.parent_financial_request_id,
//               amount_allocated: deltaAllocate,
//             },
//             { transaction: t }
//           );

//           await inst.update(
//             { donation_balance: Math.max(0, currentBalance - deltaAllocate) },
//             { transaction: t }
//           );
//         }
//       }

//       await session.update(
//         {
//           status: 'Scheduled',
//           parent_approved: true,
//           is_pending: false,
//           is_paid: false,
//           payment_status: finalAmount === 0 ? 'Paid' : 'Pending',
//           original_price: baseAmount,
//           applied_discount_percentage: approvedPercent,
//           final_price: finalAmount,
//           financial_assistance_applied: discountAmount > 0,
//           financial_assistance_request_id: aidRequest.parent_financial_request_id,
//           discount_reason: 'Session financial aid',
//         },
//         { transaction: t }
//       );
//     });

//     return res.status(200).json({
//       success: true,
//       message: finalAmount === 0
//         ? 'Financial aid approved (free session) and invoice created'
//         : 'Financial aid approved and invoice created',
//       session_id: session.session_id,
//       new_status: 'Scheduled',
//       invoice_id: invoice.invoice_id,
//       aid_request_id: aidRequest.request_id,
//       aid_status: newStatus,
//       pricing: {
//         original: baseAmount,
//         discount: discountAmount,
//         final: finalAmount
//       }
//     });
//   } catch (err) {
//     console.error('Parent session decision error:', err);
//     return res.status(500).json({
//       success: false,
//       message: 'Server error',
//       error: err.message
//     });
//   }
// };

// ================= وظيفة جديدة: التحقق التلقائي من حالة الأهل المالية عند استلام جلسة =================
const checkAutoFinancialAssistance = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { session_id } = req.params;

    console.log('🔍 التحقق التلقائي من المساعدة المالية للجلسة:', session_id);

    const session = await Session.findByPk(session_id, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'parent_id', 'full_name']
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'price']
        }
      ]
    });

    if (!session || !session.child) {
      return res.status(404).json({ 
        success: false, 
        message: 'Session not found' 
      });
    }

    if (session.child.parent_id !== parentId) {
      return res.status(403).json({ 
        success: false, 
        message: 'Access denied' 
      });
    }

    if (session.status !== 'Pending Approval') {
      return res.status(400).json({
        success: false,
        message: 'Session is not pending approval',
        current_status: session.status
      });
    }

    // التحقق من حالة الأهل المالية
    const Parent = require('../model/Parent');
    const parent = await Parent.findOne({ 
      where: { parent_id: parentId } 
    });

    let financialAssessment = null;
    let discountPercentage = 0;
    let tierLabel = '';

    if (parent && parent.financial_score) {
      // تحديد نسبة الخصم بناءً على الفئة المالية
      if (parent.financial_tier === 'tier_1_critical') {
        discountPercentage = 80;
        tierLabel = 'حرج';
      } else if (parent.financial_tier === 'tier_2_high') {
        discountPercentage = 60;
        tierLabel = 'مرتفع';
      } else if (parent.financial_tier === 'tier_3_medium') {
        discountPercentage = 40;
        tierLabel = 'متوسط';
      } else if (parent.financial_tier === 'tier_4_low') {
        discountPercentage = 20;
        tierLabel = 'منخفض';
      } else {
        discountPercentage = 0;
        tierLabel = 'لا يحتاج';
      }

      financialAssessment = {
        has_assessment: true,
        financial_score: parent.financial_score,
        financial_tier: parent.financial_tier,
        tier_label: tierLabel,
        suggested_discount: discountPercentage,
        last_assessment: parent.last_financial_assessment,
        assessment_valid: parent.last_financial_assessment ? 
          (new Date() - new Date(parent.last_financial_assessment)) / (1000 * 60 * 60 * 24) <= 30 : false
      };
    }

    const baseAmount = parseFloat(session.SessionType?.price) || 0;
    const discountAmount = (baseAmount * discountPercentage) / 100;
    const finalAmount = baseAmount - discountAmount;

    return res.status(200).json({
      success: true,
      session: {
        session_id: session.session_id,
        child_name: session.child.full_name,
        session_type: session.SessionType?.name,
        base_price: baseAmount,
        status: session.status
      },
      financial_assessment: financialAssessment,
      discount_analysis: {
        eligible_for_auto_discount: discountPercentage > 0,
        discount_percentage: discountPercentage,
        discount_amount: discountAmount,
        final_amount: finalAmount,
        monthly_savings: discountAmount,
        yearly_savings: discountAmount * 12
      },
      actions: [
        {
          type: 'auto_apply',
          label: 'تطبيق الخصم تلقائياً',
          description: `تطبيق خصم ${discountPercentage}% بناءً على حالتك المالية`,
          available: discountPercentage > 0,
          endpoint: `/api/sessions/${session_id}/auto-apply-discount`
        },
        {
          type: 'manual_request',
          label: 'طلب مساعدة مالية يدوياً',
          description: 'طلب نسبة خصم مختلفة',
          available: true,
          endpoint: `/api/sessions/${session_id}/request-aid`
        },
        {
          type: 'pay_full',
          label: 'الدفع الكامل',
          description: 'دفع المبلغ كاملاً',
          available: true,
          endpoint: `/api/sessions/${session_id}/pay-full`
        }
      ]
    });

  } catch (error) {
    console.error('Error checking auto financial assistance:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to check financial assistance',
      error: error.message
    });
  }
};

// ================= وظيفة لتطبيق الخصم التلقائي =================
const applyAutoDiscount = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { session_id } = req.params;

    console.log('💰 تطبيق خصم تلقائي للجلسة:', session_id);

    // استخدام نفس المنطق الموجود في parentSessionDecision
    req.params.id = session_id;
    req.body.decision = 'request_aid';
    
    return await parentSessionDecision(req, res);

  } catch (error) {
    console.error('Error applying auto discount:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to apply auto discount',
      error: error.message
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
// const parentConfirmAutoSession = async (req, res) => {
//   try {
//     const parentId = req.user.user_id;
//     const { id } = req.params; // session id

//     const session = await Session.findByPk(id, {
//       include: [
//         {
//           model: Child,
//           as: 'child',
//           attributes: ['child_id', 'parent_id']
//         }
//       ]
//     });

//     if (!session) {
//       return res.status(404).json({
//         success: false,
//         message: 'Session not found'
//       });
//     }

//     if (!session.child || session.child.parent_id !== parentId) {
//       return res.status(403).json({
//         success: false,
//         message: 'Access denied. You can only confirm sessions for your own child.'
//       });
//     }

//     if (session.status !== 'Pending Approval') {
//       return res.status(400).json({
//         success: false,
//         message: 'Session is not pending parent confirmation',
//         current_status: session.status
//       });
//     }

//     const sessionType = await SessionType.findByPk(session.session_type_id);
//     if (!sessionType) {
//       return res.status(400).json({
//         success: false,
//         message: 'Session type not found for this session'
//       });
//     }

//     // ================== Financial Assistance Discount Logic ==================
//     let baseAmount = parseFloat(sessionType.price) || 0;
//     let discountPercentage = 0;

//     let financialRequest = null;

//     try {
//       // ابحث عن آخر طلب مساعدة مالية معتمد أو معتمد جزئياً لنفس الطفل والمؤسسة
//       financialRequest = await FinancialAssistanceRequest.findOne({
//         where: {
//           child_id: session.child.child_id,
//           institution_id: session.institution_id,
//           status: {
//             [Op.in]: ['approved', 'partially_approved']
//           }
//         },
//         order: [['decision_date', 'DESC']]
//       });

//       if (financialRequest) {
//         // النسبة الأساسية للخصم من قرار المساعدة المالية
//         let baseDiscount =
//           parseFloat(financialRequest.approved_discount_percentage) ||
//           parseFloat(financialRequest.requested_discount_percentage) ||
//           0;

//         // حد الجلسات المدعومة (إن وجد)
//         const approvedSessionsLimit =
//           typeof financialRequest.approved_sessions_count === 'number'
//             ? financialRequest.approved_sessions_count
//             : (typeof financialRequest.requested_sessions_count === 'number'
//                 ? financialRequest.requested_sessions_count
//                 : null);

//         if (approvedSessionsLimit && approvedSessionsLimit > 0) {
//           // عدد الجلسات التي استخدمت خصم فعلاً لهذا الطفل وهذه المؤسسة
//           const usedSupportedSessions = await Session.count({
//             where: {
//               child_id: session.child.child_id,
//               institution_id: session.institution_id,
//               financial_assistance_applied: true
//             }
//           });

//           const remainingSupported = Math.max(0, approvedSessionsLimit - usedSupportedSessions);

//           if (remainingSupported <= 0) {
//             // تم استنفاد عدد الجلسات المدعومة، لا نطبق خصم على هذه الجلسة
//             baseDiscount = 0;
//           }
//         }

//         discountPercentage = baseDiscount;
//       }
//     } catch (faError) {
//       console.error('Error fetching financial assistance for session invoice:', faError);
//     }

//     if (!Number.isFinite(discountPercentage) || discountPercentage < 0) {
//       discountPercentage = 0;
//     }
//     if (discountPercentage > 100) {
//       discountPercentage = 100;
//     }

//     const discountAmount = (baseAmount * discountPercentage) / 100;
//     const finalAmount = Math.max(0, baseAmount - discountAmount);

//     const taxAmount = 0;
//     const totalAmount = finalAmount + taxAmount;

//     const invoiceNumber = `INV-${Date.now()}-${session.session_id}`;

//     const dueDate = new Date(session.date);
//     dueDate.setDate(dueDate.getDate() + 3);

//     let invoice;

//     await sequelize.transaction(async (t) => {
//       const existingInvoice = await Invoice.findOne({
//         where: { session_id: session.session_id },
//         transaction: t,
//         lock: t.LOCK.UPDATE,
//       });

//       invoice = existingInvoice
//         ? existingInvoice
//         : await Invoice.create(
//             {
//               session_id: session.session_id,
//               parent_id: parentId,
//               institution_id: session.institution_id,
//               invoice_number: invoiceNumber,
//               amount: finalAmount,
//               tax_amount: taxAmount,
//               total_amount: totalAmount,
//               status: 'Pending',
//               due_date: dueDate,
//               issued_date: new Date(),
//               notes:
//                 discountPercentage > 0
//                   ? `Invoice for initial assessment session on ${session.date} with ${discountPercentage}% financial assistance discount applied.`
//                   : `Invoice for initial assessment session on ${session.date}`,
//             },
//             { transaction: t }
//           );

//       if (existingInvoice) {
//         await existingInvoice.update(
//           {
//             amount: finalAmount,
//             total_amount: totalAmount,
//             status: totalAmount === 0 ? 'Paid' : existingInvoice.status,
//           },
//           { transaction: t }
//         );
//       }

//       if (discountAmount > 0) {
//         const institution = await Institution.findByPk(session.institution_id, {
//           transaction: t,
//           lock: t.LOCK.UPDATE,
//         });

//         if (institution) {
//           const currentBalance = parseFloat(institution.donation_balance || 0);
//           const allocationTarget = Math.min(discountAmount, currentBalance);

//           const allocations = await DonationAllocation.findAll({
//             where: {
//               institution_id: institution.institution_id,
//               invoice_id: invoice.invoice_id,
//             },
//             transaction: t,
//             lock: t.LOCK.UPDATE,
//           });

//           const alreadyAllocated = allocations.reduce(
//             (sum, a) => sum + (parseFloat(a.amount_allocated) || 0),
//             0
//           );

//           const remainingToAllocate = Math.max(0, allocationTarget - alreadyAllocated);
//           const deltaAllocate = Math.min(remainingToAllocate, currentBalance);

//           if (deltaAllocate > 0) {
//             await DonationAllocation.create(
//               {
//                 institution_id: institution.institution_id,
//                 donation_id: null,
//                 invoice_id: invoice.invoice_id,
//                 financial_assistance_request_id:
//                     financialRequest ? financialRequest.request_id : null,
//                 amount_allocated: deltaAllocate,
//               },
//               { transaction: t }
//             );

//             await institution.update(
//               { donation_balance: Math.max(0, currentBalance - deltaAllocate) },
//               { transaction: t }
//             );
//           }
//         }
//       }
//     });

//     // تحديث الجلسة بمعلومات التسعير والخصم (إن توفرت الحقول في الجدول)
//     await session.update({
//       status: 'Scheduled',
//       payment_status: totalAmount === 0 ? 'Paid' : 'Pending',
//       original_price: baseAmount,
//       final_price: finalAmount,
//       applied_discount_percentage: discountPercentage,
//       financial_assistance_applied: discountPercentage > 0
//     });

//     return res.status(200).json({
//       success: true,
//       message: 'Session confirmed by parent and invoice created',
//       session_id: session.session_id,
//       new_status: 'Scheduled',
//       invoice_id: invoice.invoice_id
//     });

//   } catch (err) {
//     console.error('Parent confirm auto session error:', err);
//     return res.status(500).json({
//       success: false,
//       message: 'Server error',
//       error: err.message
//     });
//   }
// };
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

// ================= تعديل الوظيفة لدعم التخفيض التلقائي =================
// const parentSessionDecision = async (req, res) => {
//   try {
//     const parentId = req.user.user_id;
//     const { id } = req.params; // session id
//     const { decision, requested_percentage, requested_amount, notes } = req.body;

//     if (!decision || !['pay_full', 'request_aid', 'reject'].includes(decision)) {
//       return res.status(400).json({
//         success: false,
//         message: 'Invalid decision. Use pay_full, request_aid, or reject'
//       });
//     }

//     const session = await Session.findByPk(id, {
//       include: [
//         {
//           model: Child,
//           as: 'child',
//           attributes: ['child_id', 'parent_id', 'full_name']
//         },
//         {
//           model: SessionType,
//           attributes: ['session_type_id', 'name', 'price']
//         },
//         {
//           model: Institution,
//           as: 'institution',
//           attributes: ['institution_id', 'donation_balance']
//         }
//       ]
//     });

//     if (!session || !session.child) {
//       return res.status(404).json({ success: false, message: 'Session not found' });
//     }
//     if (session.child.parent_id !== parentId) {
//       return res.status(403).json({ success: false, message: 'Access denied' });
//     }
//     if (session.status !== 'Pending Approval') {
//       return res.status(400).json({
//         success: false,
//         message: 'Session is not pending parent decision',
//         current_status: session.status
//       });
//     }

//     const baseAmount = parseFloat(session.SessionType?.price) || 0;

//     // 🔄 NEW: التحقق التلقائي من المساعدة المالية للأهل
//     let autoFinancialAssistance = null;
//     let autoDiscountPercentage = 0;
    
//     try {
//       console.log('💰 التحقق التلقائي من حالة الأهل المالية...');
      
//       const Parent = require('../model/Parent');
//       const parent = await Parent.findOne({ 
//         where: { parent_id: parentId } 
//       });
      
//       if (parent && parent.financial_score) {
//         // 🎯 حساب الخصم التلقائي بناءً على درجة الحاجة المالية
//         if (parent.financial_tier === 'tier_1_critical') {
//           autoDiscountPercentage = 80;
//           autoFinancialAssistance = {
//             type: 'auto_critical',
//             tier: 'tier_1_critical',
//             financial_score: parent.financial_score,
//             discount_reason: 'حالة مالية حرجة - تطبيق خصم تلقائي بنسبة 80%'
//           };
//         } else if (parent.financial_tier === 'tier_2_high') {
//           autoDiscountPercentage = 60;
//           autoFinancialAssistance = {
//             type: 'auto_high',
//             tier: 'tier_2_high',
//             financial_score: parent.financial_score,
//             discount_reason: 'حاجة مالية مرتفعة - تطبيق خصم تلقائي بنسبة 60%'
//           };
//         } else if (parent.financial_tier === 'tier_3_medium') {
//           autoDiscountPercentage = 40;
//           autoFinancialAssistance = {
//             type: 'auto_medium',
//             tier: 'tier_3_medium',
//             financial_score: parent.financial_score,
//             discount_reason: 'حاجة مالية متوسطة - تطبيق خصم تلقائي بنسبة 40%'
//           };
//         } else if (parent.financial_tier === 'tier_4_low') {
//           autoDiscountPercentage = 20;
//           autoFinancialAssistance = {
//             type: 'auto_low',
//             tier: 'tier_4_low',
//             financial_score: parent.financial_score,
//             discount_reason: 'حاجة مالية منخفضة - تطبيق خصم تلقائي بنسبة 20%'
//           };
//         }
        
//         console.log(`✅ تم تحديد خصم تلقائي: ${autoDiscountPercentage}% للوالد ID: ${parentId}`);
//       }
//     } catch (financialError) {
//       console.error('⚠️ خطأ في التحقق من الحالة المالية:', financialError);
//       // نواصل حتى لو حدث خطأ
//     }

//     if (decision === 'reject') {
//       await session.update({
//         status: 'Rejected',
//         parent_approved: false,
//         is_pending: false,
//         is_visible: false
//       });

//       return res.status(200).json({
//         success: true,
//         message: 'Session rejected by parent',
//         session_id: session.session_id,
//         new_status: 'Rejected'
//       });
//     }

//     // إذا طلب الأهل المساعدة المالية أو تم تحديد خصم تلقائي
//     if (decision === 'request_aid' || autoFinancialAssistance) {
//       // 🎯 استخدام الخصم التلقائي إذا كان متاحاً، وإلا استخدام النسبة التي طلبها الأهل
//       const finalDiscountPercentage = autoFinancialAssistance ? 
//         autoDiscountPercentage : 
//         (requested_percentage != null ? parseFloat(requested_percentage) : 0);
      
//       const discountReason = autoFinancialAssistance ? 
//         autoFinancialAssistance.discount_reason : 
//         'طلب مساعدة مالية من الأهل';

//       // إنشاء طلب مساعدة مالية
//       let lastFinancialRequest = null;
//       try {
//         lastFinancialRequest = await FinancialAssistanceRequest.findOne({
//           where: {
//             child_id: session.child.child_id,
//             institution_id: session.institution_id,
//             status: { [Op.in]: ['approved', 'partially_approved', 'submitted', 'under_review', 'auto_generated'] }
//           },
//           order: [['created_at', 'DESC']]
//         });
//       } catch (e) {
//         // تجاهل الخطأ
//       }

//       const aidRequest = await SessionFinancialAidRequest.create({
//         session_id: session.session_id,
//         parent_id: parentId,
//         child_id: session.child.child_id,
//         institution_id: session.institution_id,
//         parent_financial_request_id: lastFinancialRequest ? lastFinancialRequest.request_id : null,
//         status: 'submitted',
//         requested_percentage: finalDiscountPercentage,
//         requested_amount: requested_amount != null ? parseFloat(requested_amount) : null,
//         decision_notes: notes || null,
//         auto_applied: !!autoFinancialAssistance,
//         auto_discount_details: autoFinancialAssistance
//       });

//       // ================== Auto Rules مع تعديل لاستخدام الخصم التلقائي ==================
//       const institutionBalance = parseFloat(session.institution?.donation_balance) || 0;
//       const tier = autoFinancialAssistance ? autoFinancialAssistance.tier : 
//                    (lastFinancialRequest?.parent_financial_tier || null);
//       const score = autoFinancialAssistance ? autoFinancialAssistance.financial_score : 
//                    (lastFinancialRequest?.parent_financial_score || null);

//       // حساب نسبة الخصم النهائية
//       let suggestedPercent = finalDiscountPercentage;
//       if (autoFinancialAssistance && suggestedPercent <= 0) {
//         suggestedPercent = score >= 40 ? Math.min(100, Math.floor(score * 1.5)) : 0;
//       }
      
//       if (!Number.isFinite(suggestedPercent) || suggestedPercent < 0) suggestedPercent = 0;
//       if (suggestedPercent > 100) suggestedPercent = 100;

//       // If tier indicates no assistance
//       if (tier === 'tier_5_no_assistance' && !autoFinancialAssistance) {
//         await aidRequest.update({
//           status: 'rejected',
//           decision_date: new Date(),
//           decision_notes: aidRequest.decision_notes
//             ? `${aidRequest.decision_notes}`
//             : null
//         });

//         return res.status(200).json({
//           success: true,
//           message: 'Financial aid request submitted but auto-rejected by institution policy',
//           session_id: session.session_id,
//           aid_request_id: aidRequest.request_id,
//           aid_status: 'rejected',
//           next_action: 'parent_decision_required'
//         });
//       }

//       // Calculate max affordable discount from donation balance
//       const percentDiscountAmount = (baseAmount * suggestedPercent) / 100;
//       const capAmount = Number.isFinite(requested_amount) && requested_amount > 0 ? requested_amount : percentDiscountAmount;
//       const desiredDiscountCap = Math.min(percentDiscountAmount, capAmount);
//       const approvedDiscount = Math.min(desiredDiscountCap, institutionBalance);

//       if (approvedDiscount <= 0) {
//         await aidRequest.update({ status: 'under_review' });
//         return res.status(200).json({
//           success: true,
//           message: 'Financial aid request submitted and pending manager review',
//           session_id: session.session_id,
//           aid_request_id: aidRequest.request_id,
//           aid_status: 'under_review'
//         });
//       }

//       const desiredDiscount = approvedDiscount;

//       let invoice;
//       let discountAmount = 0;
//       let finalAmount = baseAmount;
//       let approvedPercent = 0;
//       let newStatus = 'under_review';

//       await sequelize.transaction(async (t) => {
//         const inst = await Institution.findByPk(session.institution_id, {
//           transaction: t,
//           lock: t.LOCK.UPDATE,
//         });

//         const currentBalance = parseFloat(inst?.donation_balance || 0);
//         const approvedDiscountTxn = Math.min(desiredDiscount, currentBalance);

//         discountAmount = Math.max(0, Math.min(baseAmount, approvedDiscountTxn));
//         finalAmount = Math.max(0, baseAmount - discountAmount);
//         approvedPercent =
//             baseAmount > 0 ? Math.min(100, (discountAmount / baseAmount) * 100) : 0;
//         newStatus = discountAmount >= baseAmount ? 'approved' : 'partial_approved';

//         await aidRequest.update(
//           {
//             status: newStatus,
//             approved_amount: discountAmount,
//             approved_percentage: approvedPercent,
//             decision_date: new Date(),
//           },
//           { transaction: t }
//         );

//         const existingInvoice = await Invoice.findOne({
//           where: { session_id: session.session_id },
//           transaction: t,
//           lock: t.LOCK.UPDATE,
//         });

//         invoice = existingInvoice
//           ? existingInvoice
//           : await Invoice.create(
//               {
//                 session_id: session.session_id,
//                 parent_id: parentId,
//                 institution_id: session.institution_id,
//                 invoice_number: `INV-${Date.now()}-${session.session_id}`,
//                 amount: finalAmount,
//                 tax_amount: 0,
//                 total_amount: finalAmount,
//                 status: 'Pending',
//                 due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
//                 issued_date: new Date(),
//                 notes:
//                   finalAmount === 0
//                     ? `Free session funded by financial aid (request ${aidRequest.request_id}).`
//                     : `Invoice for session with financial aid discount applied (request ${aidRequest.request_id}).`,
//               },
//               { transaction: t }
//             );

//         if (existingInvoice) {
//           await existingInvoice.update(
//             {
//               amount: finalAmount,
//               total_amount: finalAmount,
//               status: finalAmount === 0 ? 'Paid' : existingInvoice.status,
//             },
//             { transaction: t }
//           );
//         }

//         if (discountAmount > 0 && inst) {
//           const allocations = await DonationAllocation.findAll({
//             where: {
//               institution_id: inst.institution_id,
//               invoice_id: invoice.invoice_id,
//             },
//             transaction: t,
//             lock: t.LOCK.UPDATE,
//           });

//           const alreadyAllocated = allocations.reduce(
//             (sum, a) => sum + (parseFloat(a.amount_allocated) || 0),
//             0
//           );

//           const remainingToAllocate = Math.max(0, discountAmount - alreadyAllocated);
//           const deltaAllocate = Math.min(remainingToAllocate, currentBalance);

//           if (deltaAllocate > 0) {
//             await DonationAllocation.create(
//               {
//                 institution_id: inst.institution_id,
//                 donation_id: null,
//                 invoice_id: invoice.invoice_id,
//                 financial_assistance_request_id: aidRequest.parent_financial_request_id,
//                 amount_allocated: deltaAllocate,
//               },
//               { transaction: t }
//             );

//             await inst.update(
//               { donation_balance: Math.max(0, currentBalance - deltaAllocate) },
//               { transaction: t }
//             );
//           }
//         }

//         await session.update(
//           {
//             status: 'Scheduled',
//             parent_approved: true,
//             is_pending: false,
//             is_paid: false,
//             payment_status: finalAmount === 0 ? 'Paid' : 'Pending',
//             original_price: baseAmount,
//             applied_discount_percentage: approvedPercent,
//             final_price: finalAmount,
//             financial_assistance_applied: discountAmount > 0,
//             financial_assistance_request_id: aidRequest.parent_financial_request_id,
//             discount_reason: discountReason,
//             auto_financial_assistance: !!autoFinancialAssistance,
//             auto_discount_details: autoFinancialAssistance
//           },
//           { transaction: t }
//         );
//       });

//       // إشعار الأهل بالتخفيض التلقائي (إذا تم تطبيقه)
//       if (autoFinancialAssistance) {
//         const Notification = require('../model/Notification');
//         await Notification.create({
//           user_id: parentId,
//           title: 'تم تطبيق تخفيض تلقائي على الجلسة',
//           message: `تم تطبيق خصم تلقائي بنسبة ${autoDiscountPercentage}% على جلسة ${session.child.full_name} بناءً على حالتك المالية المسجلة.`,
//           type: 'auto_discount_applied',
//           related_id: session.session_id,
//           is_read: false
//         });
//       }

//       return res.status(200).json({
//         success: true,
//         message: autoFinancialAssistance 
//           ? `تم تطبيق خصم تلقائي بنسبة ${autoDiscountPercentage}% على الجلسة بناءً على حالتك المالية`
//           : (finalAmount === 0
//             ? 'Financial aid approved (free session) and invoice created'
//             : 'Financial aid approved and invoice created'),
//         session_id: session.session_id,
//         new_status: 'Scheduled',
//         invoice_id: invoice.invoice_id,
//         aid_request_id: aidRequest.request_id,
//         aid_status: newStatus,
//         auto_discount_applied: !!autoFinancialAssistance,
//         discount_details: autoFinancialAssistance || null,
//         pricing: {
//           original: baseAmount,
//           discount: discountAmount,
//           discount_percentage: approvedPercent,
//           final: finalAmount
//         }
//       });
//     }

//     // إذا اختار الأهل الدفع الكامل
//     if (decision === 'pay_full') {
//       const existingInvoice = await Invoice.findOne({ where: { session_id: session.session_id } });
//       const invoice = existingInvoice
//         ? existingInvoice
//         : await Invoice.create({
//             session_id: session.session_id,
//             parent_id: parentId,
//             institution_id: session.institution_id,
//             invoice_number: `INV-${Date.now()}-${session.session_id}`,
//             amount: baseAmount,
//             tax_amount: 0,
//             total_amount: baseAmount,
//             status: 'Pending',
//             due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
//             issued_date: new Date(),
//             notes: `Invoice for session ${session.session_id}`
//           });

//       await session.update({
//         status: 'Scheduled',
//         parent_approved: true,
//         is_pending: false,
//         is_paid: false,
//         payment_status: 'Pending',
//         original_price: baseAmount,
//         applied_discount_percentage: 0,
//         final_price: baseAmount,
//         financial_assistance_applied: false,
//         discount_reason: null
//       });

//       return res.status(200).json({
//         success: true,
//         message: 'Session approved by parent (full payment) and invoice created',
//         session_id: session.session_id,
//         new_status: 'Scheduled',
//         invoice_id: invoice.invoice_id
//       });
//     }

//   } catch (err) {
//     console.error('Parent session decision error:', err);
//     return res.status(500).json({
//       success: false,
//       message: 'Server error',
//       error: err.message
//     });
//   }
// };




// 🔧 وظيفة جديدة: إنشاء جلسة مع التحقق التلقائي للمساعدة المالية
const createSessionWithAutoFinancialAid = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { 
      child_id, 
      session_type_id, 
      date, 
      time, 
      session_type,
      notes 
    } = req.body;

    // 1. التحقق من بيانات الجلسة
    if (!child_id || !session_type_id || !date || !time) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields'
      });
    }

    // 2. التحقق من أن الطفل تابع للأهل
    const child = await Child.findOne({
      where: { 
        child_id,
        parent_id: parentId,
        registration_status: 'Approved'
      }
    });

    if (!child) {
      return res.status(403).json({
        success: false,
        message: 'Access denied or child not registered'
      });
    }

    // 3. التحقق من نوع الجلسة
    const sessionType = await SessionType.findByPk(session_type_id);
    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'Session type not found'
      });
    }

    // 4. التحقق من المؤسسة
    const institution = await Institution.findByPk(sessionType.institution_id);
    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    // 5. التحقق السريع من المساعدة المالية (للعرض للأهل)
    const quickCheck = await AutoFinancialAidService.quickCheckFinancialAid(
      child_id,
      institution.institution_id,
      session_type_id
    );

    // 6. إنشاء الجلسة
    const session = await Session.create({
      child_id,
      session_type_id,
      institution_id: institution.institution_id,
      date,
      time,
      session_type: session_type || 'Onsite',
      status: 'Pending Approval',
      notes: notes || null,
      parent_notes: notes || null,
      is_first_booking: false,
      original_price: sessionType.price,
      final_price: sessionType.price,
      applied_discount_percentage: 0,
      financial_assistance_applied: false,
      payment_status: 'Pending'
    });

    // 7. التحقق التلقائي وتطبيق المساعدة المالية
    const financialAidResult = await AutoFinancialAidService.autoApplyFinancialAid(session.session_id);

    // 8. إرسال الإجابة
    return res.status(201).json({
      success: true,
      message: 'Session created with auto financial aid check',
      session_id: session.session_id,
      financial_aid: {
        applied: financialAidResult.auto_applied,
        discount_percentage: financialAidResult.discount_percentage || 0,
        discount_amount: financialAidResult.discount_amount || 0,
        final_price: financialAidResult.final_price || sessionType.price,
        estimated_from_quick_check: quickCheck
      },
      next_steps: financialAidResult.auto_applied 
        ? ['تم تطبيق الخصم تلقائياً', 'سيتم مراجعة الجلسة من قبل المؤسسة']
        : ['الرجاء مراجعة الجلسة والدفع']
    });

  } catch (error) {
    console.error('Error creating session with auto financial aid:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create session',
      error: error.message
    });
  }
};

// 🔧 وظيفة جديدة: التحقق من المساعدة المالية لجلسة موجودة
const checkSessionFinancialAid = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { session_id } = req.params;

    const session = await Session.findOne({
      where: { 
        session_id,
        child_id: {
          [Op.in]: sequelize.literal(`(
            SELECT child_id FROM Children 
            WHERE parent_id = ${parentId}
          )`)
        }
      },
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'full_name']
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'name', 'price']
        }
      ]
    });

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'Session not found or access denied'
      });
    }

    // التحقق السريع من المساعدة المالية
    const quickCheck = await AutoFinancialAidService.quickCheckFinancialAid(
      session.child.child_id,
      session.institution_id,
      session.session_type_id
    );

    // إذا كانت الجلسة في حالة "Pending Approval" ولم يتم تطبيق المساعدة بعد
    if (session.status === 'Pending Approval' && !session.financial_assistance_applied) {
      // يمكننا تطبيق المساعدة التلقائية مباشرة
      const applyResult = await AutoFinancialAidService.autoApplyFinancialAid(session_id);
      
      return res.status(200).json({
        success: true,
        message: 'Auto financial aid applied',
        session: {
          session_id: session.session_id,
          child_name: session.child.full_name,
          session_type: session.SessionType.name,
          base_price: session.SessionType.price
        },
        financial_aid: {
          applied: true,
          discount_percentage: applyResult.discount_percentage,
          discount_amount: applyResult.discount_amount,
          final_price: applyResult.final_price,
          financial_tier: applyResult.financial_tier
        },
        status: 'auto_applied'
      });
    }

    // إذا كانت المساعدة مطبقة بالفعل
    if (session.financial_assistance_applied) {
      return res.status(200).json({
        success: true,
        message: 'Financial aid already applied',
        financial_aid: {
          applied: true,
          discount_percentage: session.applied_discount_percentage,
          discount_amount: session.original_price - session.final_price,
          final_price: session.final_price,
          auto_applied: session.auto_financial_assistance
        },
        status: 'already_applied'
      });
    }

    // إذا لم يمكن تطبيق المساعدة
    return res.status(200).json({
      success: true,
      message: 'Financial aid check completed',
      financial_aid: quickCheck,
      status: 'check_only'
    });

  } catch (error) {
    console.error('Error checking session financial aid:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to check financial aid',
      error: error.message
    });
  }
};

// 🔧 تعديل وظيفة parentSessionDecision لتتجنب الخلط
const parentSessionDecision = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { id } = req.params;
    const { decision } = req.body;

    if (!decision || !['approve', 'reject'].includes(decision)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid decision. Use approve or reject'
      });
    }

    const session = await Session.findByPk(id, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'parent_id']
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

    if (!session || !session.child) {
      return res.status(404).json({
        success: false,
        message: 'Session not found'
      });
    }

    if (session.child.parent_id !== parentId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      });
    }

    if (session.status !== 'Pending Approval') {
      return res.status(400).json({
        success: false,
        message: 'Session is not pending parent decision',
        current_status: session.status
      });
    }

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

    // decision === 'approve'
    // Always allow approval; apply auto financial aid if not applied (this also creates invoice)
    if (!session.financial_assistance_applied) {
      await AutoFinancialAidService.autoApplyFinancialAid(session.session_id);
      await session.reload();
    }

    // Ensure invoice exists (autoApplyFinancialAid should create it even with no discount)
    const invoice = await Invoice.findOne({
      where: { session_id: session.session_id }
    });

    const finalPrice = parseFloat(session.final_price ?? 0);
    const originalPrice = parseFloat(session.original_price ?? (session.SessionType?.price || 0));

    await session.update({
      status: 'Scheduled',
      parent_approved: true,
      is_pending: false,
      payment_status: finalPrice === 0 ? 'Paid' : 'Pending'
    });

    return res.status(200).json({
      success: true,
      message: 'Session approved by parent',
      session_id: session.session_id,
      new_status: 'Scheduled',
      invoice_id: invoice?.invoice_id,
      financial_aid: {
        applied: !!session.financial_assistance_applied,
        discount_percentage: parseFloat(session.applied_discount_percentage ?? 0),
        original_price: originalPrice,
        final_price: finalPrice,
        auto_applied: !!session.auto_financial_assistance
      }
    });
  } catch (error) {
    console.error('Error in parent decision:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// 🔧 تعديل وظيفة تأكيد الجلسة التلقائية
const parentConfirmAutoSession = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { id } = req.params;

    const session = await Session.findByPk(id, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'parent_id']
        },
        {
          model: SessionType,
          attributes: ['session_type_id', 'price']
        }
      ]
    });

    if (!session || session.child.parent_id !== parentId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      });
    }

    // 🔴 جديد: التحقق من المساعدة المالية التلقائية
    if (!session.financial_assistance_applied) {
      // تطبيق المساعدة المالية التلقائية إذا لم تكن مطبقة
      await AutoFinancialAidService.autoApplyFinancialAid(id);
      
      // إعادة تحميل بيانات الجلسة
      await session.reload();
    }

    // إذا كانت الجلسة مجانية بالكامل، نغير الحالة مباشرة
    if (session.final_price === 0) {
      await session.update({
        status: 'Scheduled',
        payment_status: 'Paid'
      });

      return res.status(200).json({
        success: true,
        message: 'Session confirmed and fully funded by auto financial aid',
        session_id: session.session_id,
        status: 'Scheduled',
        payment_status: 'Paid',
        financial_aid: {
          applied: true,
          discount_percentage: session.applied_discount_percentage,
          final_price: 0,
          free_session: true
        }
      });
    }

    // إذا كان هناك سعر نهائي، ننشئ الفاتورة
    const invoice = await Invoice.create({
      session_id: session.session_id,
      parent_id: parentId,
      institution_id: session.institution_id,
      invoice_number: `INV-${Date.now()}-${session.session_id}`,
      amount: session.final_price,
      tax_amount: 0,
      total_amount: session.final_price,
      status: 'Pending',
      due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      issued_date: new Date(),
      notes: session.final_price === session.original_price 
        ? 'فاتورة الجلسة بدون خصم'
        : `فاتورة الجلسة مع خصم ${session.applied_discount_percentage}%`
    });

    await session.update({
      status: 'Scheduled',
      payment_status: 'Pending'
    });

    return res.status(200).json({
      success: true,
      message: 'Session confirmed',
      session_id: session.session_id,
      status: 'Scheduled',
      invoice_id: invoice.invoice_id,
      financial_aid: {
        applied: session.financial_assistance_applied,
        discount_percentage: session.applied_discount_percentage,
        original_price: session.original_price,
        final_price: session.final_price
      }
    });

  } catch (error) {
    console.error('Error confirming auto session:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to confirm session',
      error: error.message
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
  processPayment,
  checkAutoFinancialAssistance,
  applyAutoDiscount,
  createSessionWithAutoFinancialAid,
  checkSessionFinancialAid
};

