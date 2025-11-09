// controllers/specialistApprovalController.js
const Session = require('../model/Session');
const SessionType = require('../model/SessionType');
const Invoice = require('../model/Invoice');

// موافقة الأخصائي على الجلسة
exports.approveSession = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { sessionId } = req.params;

    // التحقق من أن الجلسة تابعة للأخصائي
    const session = await Session.findOne({
      where: { 
        session_id: sessionId,
        specialist_id: specialistId,
        status: 'Pending Approval'
      },
      include: [{
        model: SessionType,
        attributes: ['price', 'name']
      }]
    });

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'Session not found or already processed'
      });
    }

    // تحديث حالة الجلسة
    await session.update({ status: 'Pending Payment' });

    // إنشاء الفاتورة تلقائياً
    const invoice = await createInvoiceForSession(sessionId, session.SessionType.price);

    res.json({
      success: true,
      message: 'Session approved and invoice generated',
      session: {
        session_id: session.session_id,
        status: 'Pending Payment'
      },
      invoice: {
        invoice_id: invoice.invoice_id,
        amount: invoice.amount,
        invoice_number: invoice.invoice_number
      }
    });

  } catch (error) {
    console.error('Error approving session:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to approve session', 
      error: error.message 
    });
  }
};

// رفض الجلسة من قبل الأخصائي
exports.rejectSession = async (req, res) => {
  try {
    const specialistId = req.user.user_id;
    const { sessionId } = req.params;
    const { rejection_reason } = req.body;

    const session = await Session.findOne({
      where: { 
        session_id: sessionId,
        specialist_id: specialistId,
        status: 'Pending Approval'
      }
    });

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'Session not found or already processed'
      });
    }

    await session.update({ 
      status: 'Cancelled',
      cancellation_reason: rejection_reason || 'Rejected by specialist'
    });

    res.json({
      success: true,
      message: 'Session rejected successfully'
    });

  } catch (error) {
    console.error('Error rejecting session:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to reject session', 
      error: error.message 
    });
  }
};

// دالة مساعدة لإنشاء الفاتورة
const createInvoiceForSession = async (sessionId, price) => {
  const session = await Session.findByPk(sessionId, {
    include: [{
      model: require('../model/Child'),
      as: 'child',
      attributes: ['parent_id']
    }]
  });

  const invoiceNumber = `INV-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  
  const invoice = await Invoice.create({
    session_id: sessionId,
    parent_id: session.child.parent_id,
    institution_id: session.institution_id,
    invoice_number: invoiceNumber,
    amount: price,
    tax_amount: 0,
    total_amount: price,
    status: 'Pending',
    due_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    notes: `Invoice for session #${sessionId}`
  });

  return invoice;
};