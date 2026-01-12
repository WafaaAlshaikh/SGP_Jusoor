const Session = require('../model/Session');
const Child = require('../model/Child');
const Institution = require('../model/Institution');
const User = require('../model/User');
const SessionType = require('../model/SessionType');
const Invoice = require('../model/Invoice');
const Payment = require('../model/Payment');
const Notification = require('../model/Notification');
const UserDeviceToken = require('../model/UserDeviceToken');
const NotificationService = require('../services/notificationService');
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

    const sessionIds = sessions.map((s) => s.session_id);
    const invoices = sessionIds.length
      ? await Invoice.findAll({
          where: { session_id: { [Op.in]: sessionIds } },
          attributes: [
            'session_id',
            'amount',
            'original_amount',
            'discount_amount',
            'discount_percentage',
            'total_amount',
            'refund_amount',
            'status',
          ],
          raw: true,
        })
      : [];
    const invoiceBySessionId = new Map((invoices || []).map((inv) => [inv.session_id, inv]));

    const formatted = sessions.map((s) => {
      const inv = invoiceBySessionId.get(s.session_id);
      return {
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
        paymentStatus: s.payment_status,
        is_paid: s.is_paid,
        payment_status: s.payment_status,
        original_price: s.original_price,
        final_price: s.final_price,
        applied_discount_percentage: s.applied_discount_percentage,
        discount_amount: inv ? inv.discount_amount : null,
        discount_percentage: inv ? inv.discount_percentage : null,
        refund_amount: inv ? inv.refund_amount : null,
        invoice_status: inv ? inv.status : null,
        invoice_total_amount: inv ? inv.total_amount : null,
      };
    });

    res.status(200).json({ sessions: formatted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};



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

    const Parent = require('../model/Parent');
    const parent = await Parent.findOne({ 
      where: { parent_id: parentId } 
    });

    let financialAssessment = null;
    let discountPercentage = 0;
    let tierLabel = '';

    if (parent && parent.financial_score) {
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

const applyAutoDiscount = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { session_id } = req.params;

    console.log('💰 تطبيق خصم تلقائي للجلسة:', session_id);

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

    const sessionIds = sessions.map((s) => s.session_id);
    const invoices = sessionIds.length
      ? await Invoice.findAll({
          where: { session_id: { [Op.in]: sessionIds } },
          attributes: ['session_id', 'discount_amount', 'discount_percentage', 'total_amount', 'refund_amount', 'status'],
          raw: true,
        })
      : [];
    const invoiceBySessionId = new Map((invoices || []).map((inv) => [inv.session_id, inv]));

    const formatted = sessions.map((s) => {
      const inv = invoiceBySessionId.get(s.session_id);
      return {
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
        isPaid: s.is_paid,
        paymentStatus: s.payment_status,
        is_paid: s.is_paid,
        payment_status: s.payment_status,
        original_price: s.original_price,
        final_price: s.final_price,
        applied_discount_percentage: s.applied_discount_percentage,
        discount_amount: inv ? inv.discount_amount : null,
        discount_percentage: inv ? inv.discount_percentage : null,
        refund_amount: inv ? inv.refund_amount : null,
        invoice_status: inv ? inv.status : null,
        invoice_total_amount: inv ? inv.total_amount : null,
      };
    });

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
  const { id } = req.params;
  const { reason } = req.body;

  try {
    const session = await Session.findByPk(id, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'full_name', 'parent_id']
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['user_id', 'full_name']
        }
      ]
    });

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'Session not found'
      });
    }

    const parentId = req.user.user_id;
    const child = await Child.findOne({
      where: { child_id: session.child_id, parent_id: parentId }
    });

    if (!child) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      });
    }

    let refundProcessed = false;
    let refundAmount = 0;

    await sequelize.transaction(async (t) => {
      await session.update(
        {
          status: 'Cancelled',
          reason: reason || 'Cancelled by parent'
        },
        { transaction: t }
      );

      const specialistUserId = session.specialist.user_id;
      const childName = session.child?.full_name || 'Unknown child';
      const specialistName = session.specialist?.full_name || 'Specialist';

      const notificationTitle = '❌ Session Cancelled';
      const notificationBody =
        `The session for ${childName} scheduled on ${session.date} at ${session.time}` +
        `${reason ? ` was cancelled. Reason: ${reason}` : ' was cancelled.'}`;

      await sendNotificationToSpecialist(
        specialistUserId,
        notificationTitle,
        notificationBody,
        {
          type: 'session_cancelled',
          session_id: id,
          child_name: childName,
          date: session.date,
          time: session.time,
          reason: reason || '',
          status: 'Cancelled',
          cancelled_by: 'parent',
          action: 'view_schedule'
        }
      );

      await Notification.create(
        {
          user_id: specialistUserId,
          title: 'Session Cancelled',
          message: notificationBody,
          type: 'session_cancelled',
          related_id: session.session_id,
          is_read: false
        },
        { transaction: t }
      );

      const specialistTokens = await UserDeviceToken.findAll({
        where: {
          user_id: specialistUserId,
          is_active: true
        },
        attributes: ['token'],
        transaction: t
      });

      await Promise.allSettled(
        (specialistTokens || [])
          .map((x) => (x?.token || '').toString().trim())
          .filter(Boolean)
          .map((token) =>
            NotificationService.sendToToken(
              token,
              notificationTitle,
              notificationBody,
              {
                type: 'session_cancelled',
                sessionId: session.session_id,
                childName,
                date: session.date,
                time: session.time,
                specialistName,
                reason: reason || '',
                action: 'view_schedule',
                channel: 'session_channel'
              }
            )
          )
      );

      const invoice = await Invoice.findOne({
        where: { session_id: session.session_id },
        transaction: t,
        lock: t.LOCK.UPDATE
      });

      const isPaid = Boolean(session.is_paid) && session.payment_status === 'Paid';
      const isInvoicePaid = Boolean(invoice) && invoice.status === 'Paid';

      if (invoice && (isPaid || isInvoicePaid)) {
        refundAmount = parseFloat(invoice.total_amount || 0) || 0;
        refundProcessed = refundAmount > 0;

        await invoice.update(
          {
            status: 'Cancelled',
            refund_amount: refundAmount,
            refund_reason: reason || 'Cancelled by parent',
            refunded_at: new Date()
          },
          { transaction: t }
        );

        const payment = await Payment.findOne({
          where: {
            invoice_id: invoice.invoice_id,
            status: 'Completed'
          },
          order: [['payment_date', 'DESC']],
          transaction: t,
          lock: t.LOCK.UPDATE
        });

        if (payment) {
          await payment.update(
            {
              status: 'Refunded',
              refund_amount: refundAmount
            },
            { transaction: t }
          );
        }

        await session.update(
          {
            is_paid: false,
            payment_status: 'Refunded'
          },
          { transaction: t }
        );
      }
    });

    res.json({
      success: true,
      message: 'Session cancelled successfully',
      refundProcessed,
      refundAmount,
      notification_sent: true
    });
  } catch (err) {
    console.error('Cancel session error:', err);
    res.status(500).json({
      success: false,
      message: 'Server error'
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

    const sessionIds = sessions.map((s) => s.session_id);
    const invoices = sessionIds.length
      ? await Invoice.findAll({
          where: { session_id: { [Op.in]: sessionIds } },
          attributes: ['session_id', 'discount_amount', 'discount_percentage', 'total_amount', 'refund_amount', 'status'],
          raw: true,
        })
      : [];
    const invoiceBySessionId = new Map((invoices || []).map((inv) => [inv.session_id, inv]));

    const formatted = sessions.map((s) => {
      const inv = invoiceBySessionId.get(s.session_id);
      return {
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
        isPaid: s.is_paid,
        paymentStatus: s.payment_status,
        is_paid: s.is_paid,
        payment_status: s.payment_status,
        original_price: s.original_price,
        final_price: s.final_price,
        applied_discount_percentage: s.applied_discount_percentage,
        discount_amount: inv ? inv.discount_amount : null,
        discount_percentage: inv ? inv.discount_percentage : null,
        refund_amount: inv ? inv.refund_amount : null,
        invoice_status: inv ? inv.status : null,
        invoice_total_amount: inv ? inv.total_amount : null,
      };
    });

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

    const sessionIds = sessions.map((s) => s.session_id);
    const invoices = sessionIds.length
      ? await Invoice.findAll({
          where: { session_id: { [Op.in]: sessionIds } },
          attributes: ['session_id', 'discount_amount', 'discount_percentage', 'total_amount', 'refund_amount', 'status'],
          raw: true,
        })
      : [];
    const invoiceBySessionId = new Map((invoices || []).map((inv) => [inv.session_id, inv]));

    const formatted = sessions.map((s) => {
      const inv = invoiceBySessionId.get(s.session_id);
      return {
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
        isPaid: s.is_paid,
        paymentStatus: s.payment_status,
        is_paid: s.is_paid,
        payment_status: s.payment_status,
        original_price: s.original_price,
        final_price: s.final_price,
        applied_discount_percentage: s.applied_discount_percentage,
        discount_amount: inv ? inv.discount_amount : null,
        discount_percentage: inv ? inv.discount_percentage : null,
        refund_amount: inv ? inv.refund_amount : null,
        invoice_status: inv ? inv.status : null,
        invoice_total_amount: inv ? inv.total_amount : null,
      };
    });

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
          attributes: ['child_id', 'full_name']
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['user_id', 'full_name']
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

      await sendNotificationToSpecialist(
        session.specialist.user_id,
        '💰 Payment Received',
        `The payment for the session of ${session.child.full_name} scheduled on ${session.date} has been completed`,
        {
          type: 'payment_received',
          session_id: id,
          child_name: session.child.full_name,
          date: session.date,
          time: session.time,
          amount: invoice.total_amount,
          payment_status: 'Paid',
          action: 'view_session'
        }
      );

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
        },
        notification_sent: true
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

    if (!child_id || !session_type_id || !date || !time) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields'
      });
    }

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

    const sessionType = await SessionType.findByPk(session_type_id, {
      include: [
        {
          model: Institution,
          attributes: ['institution_id', 'name']
        },
        {
          model: Specialist,
          include: [
            {
              model: User,
              attributes: ['user_id', 'full_name']
            }
          ]
        }
      ]
    });
    
    if (!sessionType) {
      return res.status(404).json({
        success: false,
        message: 'Session type not found'
      });
    }

    const session = await Session.create({
      child_id,
      session_type_id,
      institution_id: sessionType.institution_id,
      specialist_id: sessionType.specialist_id,
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

    const financialAidResult = await AutoFinancialAidService.autoApplyFinancialAid(session.session_id);

    await session.reload();

    if (sessionType.specialist && sessionType.specialist.User) {
      await sendNotificationToSpecialist(
        sessionType.specialist.User.user_id,
        '📅 New session pending approval',
        `A new session for ${child.full_name} on ${session.date} requires your approval`,
        {
          type: 'new_session_pending',
          session_id: session.session_id,
          child_name: child.full_name,
          date: session.date,
          time: session.time,
          session_type: sessionType.name,
          status: 'Pending Approval',
          has_financial_aid: session.financial_assistance_applied,
          action: 'view_pending_sessions'
        }
      );
    }

    return res.status(201).json({
      success: true,
      message: 'Session created with auto financial aid check',
      session_id: session.session_id,
      financial_aid: {
        applied: financialAidResult.auto_applied,
        discount_percentage: financialAidResult.discount_percentage || 0,
        discount_amount: financialAidResult.discount_amount || 0,
        final_price: financialAidResult.final_price || sessionType.price,
      },
      notification_sent: true,
      next_steps: financialAidResult.auto_applied 
        ? ['Discount applied automatically', 'The session will be reviewed by the institution']
        : ['Please review the session and proceed with payment']
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

    const quickCheck = await AutoFinancialAidService.quickCheckFinancialAid(
      session.child.child_id,
      session.institution_id,
      session.session_type_id
    );

    if (session.status === 'Pending Approval' && !session.financial_assistance_applied) {
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
          attributes: ['child_id', 'parent_id', 'full_name']
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['user_id', 'full_name']
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

      await sendNotificationToSpecialist(
        session.specialist.user_id,
        '❌ Session Rejected',
        `The session for ${session.child.full_name} was rejected by the parent`,
        {
          type: 'session_rejected',
          session_id: id,
          child_name: session.child.full_name,
          date: session.date,
          time: session.time,
          status: 'Rejected',
          action: 'view_schedule'
        }
      );

      return res.status(200).json({
        success: true,
        message: 'Session rejected by parent',
        session_id: session.session_id,
        new_status: 'Rejected',
        notification_sent: true
      });
    }

    if (!session.financial_assistance_applied) {
      await AutoFinancialAidService.autoApplyFinancialAid(session.session_id);
      await session.reload();
    }

    const invoice = await Invoice.findOne({
      where: { session_id: session.session_id }
    });

    const finalPrice = parseFloat(session.final_price ?? 0);
    const originalPrice = parseFloat(
      session.original_price ?? (session.SessionType?.price || 0)
    );

    await session.update({
      status: 'Scheduled',
      parent_approved: true,
      is_pending: false,
      payment_status: finalPrice === 0 ? 'Paid' : 'Pending'
    });

    let notificationTitle = '✅ Session Approved';
    let notificationBody = `The session for ${session.child.full_name} has been approved`;

    if (session.financial_assistance_applied) {
      notificationBody += ` with a ${session.applied_discount_percentage}% discount`;
      if (finalPrice === 0) {
        notificationBody += ' (Free session)';
      }
    }

    await sendNotificationToSpecialist(
      session.specialist.user_id,
      notificationTitle,
      notificationBody,
      {
        type: 'session_approved',
        session_id: id,
        child_name: session.child.full_name,
        date: session.date,
        time: session.time,
        status: 'Scheduled',
        financial_aid_applied: session.financial_assistance_applied,
        discount_percentage: session.applied_discount_percentage || 0,
        final_price: finalPrice,
        action: 'view_session'
      }
    );

    return res.status(200).json({
      success: true,
      message: 'Session approved by parent',
      session_id: session.session_id,
      new_status: 'Scheduled',
      invoice_id: invoice?.invoice_id,
      notification_sent: true,
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


const parentConfirmAutoSession = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { id } = req.params;

    const session = await Session.findByPk(id, {
      include: [
        {
          model: Child,
          as: 'child',
          attributes: ['child_id', 'parent_id', 'full_name']
        },
        {
          model: User,
          as: 'specialist',
          attributes: ['user_id', 'full_name']
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

    if (!session.financial_assistance_applied) {
      await AutoFinancialAidService.autoApplyFinancialAid(id);

      await session.reload();
    }

    if (session.final_price === 0) {
      await session.update({
        status: 'Scheduled',
        payment_status: 'Paid'
      });

      await sendNotificationToSpecialist(
        session.specialist.user_id,
        '✅ Free Session Confirmed',
        `The free session for ${session.child.full_name} scheduled on ${session.date} has been confirmed`,
        {
          type: 'session_confirmed',
          session_id: id,
          child_name: session.child.full_name,
          date: session.date,
          time: session.time,
          status: 'Scheduled',
          free_session: true,
          action: 'view_session'
        }
      );

      return res.status(200).json({
        success: true,
        message: 'Session confirmed and fully funded by automatic financial aid',
        session_id: session.session_id,
        status: 'Scheduled',
        payment_status: 'Paid',
        notification_sent: true,
        financial_aid: {
          applied: true,
          discount_percentage: session.applied_discount_percentage,
          final_price: 0,
          free_session: true
        }
      });
    }

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
      notes:
        session.final_price === session.original_price
          ? 'Session invoice without discount'
          : `Session invoice with ${session.applied_discount_percentage}% discount`
    });

    await session.update({
      status: 'Scheduled',
      payment_status: 'Pending'
    });

    await sendNotificationToSpecialist(
      session.specialist.user_id,
      '✅ Session Confirmed',
      `The session for ${session.child.full_name} scheduled on ${session.date} has been confirmed`,
      {
        type: 'session_confirmed',
        session_id: id,
        child_name: session.child.full_name,
        date: session.date,
        time: session.time,
        status: 'Scheduled',
        has_financial_aid: session.financial_assistance_applied,
        discount_percentage: session.applied_discount_percentage || 0,
        action: 'view_session'
      }
    );

    return res.status(200).json({
      success: true,
      message: 'Session confirmed',
      session_id: session.session_id,
      status: 'Scheduled',
      invoice_id: invoice.invoice_id,
      notification_sent: true,
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


const sendNotificationToSpecialist = async (specialistId, title, body, data = {}) => {
  try {
    if (!specialistId) {
      console.log('⚠️ No specialist ID provided for notification');
      return;
    }

    const [tokenResult] = await sequelize.query(`
      SELECT token 
      FROM UserDeviceTokens 
      WHERE user_id = ? 
        AND is_active = 1
      ORDER BY updated_at DESC 
      LIMIT 1
    `, { replacements: [specialistId] });

    if (!tokenResult.length || !tokenResult[0].token) {
      console.log(`⚠️ No token found for specialist ${specialistId}`);
      
      await Notification.create({
        user_id: specialistId,
        title: title,
        message: body,
        type: data.type || 'session_notification',
        related_id: data.session_id || null,
        is_read: false,
        metadata: JSON.stringify(data)
      });
      
      return;
    }

    const token = tokenResult[0].token.trim();
    
    const notificationData = {
      type: data.type || 'session_notification',
      session_id: data.session_id?.toString() || '',
      child_name: data.child_name || '',
      date: data.date || '',
      time: data.time || '',
      status: data.status || '',
      action: data.action || 'view_schedule',
      channel: 'session_channel',
      ...data
    };

    await NotificationService.sendToToken(
      token,
      title,
      body,
      notificationData
    );

    await Notification.create({
      user_id: specialistId,
      title: title,
      message: body,
      type: data.type || 'session_notification',
      related_id: data.session_id || null,
      is_read: false,
      metadata: JSON.stringify(notificationData)
    });

    console.log(`✅ Notification sent to specialist ${specialistId}: ${title}`);

  } catch (error) {
    console.error('❌ Error sending notification to specialist:', error);
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

