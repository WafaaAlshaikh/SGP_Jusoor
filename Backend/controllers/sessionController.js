const Session = require('../model/Session');
const Child = require('../model/Child');
const Institution = require('../model/Institution');
const User = require('../model/User');
const SessionType = require('../model/SessionType');
const Invoice = require('../model/Invoice');
const Payment = require('../model/Payment');
const Notification = require('../model/Notification');
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

    // ✅ عرض فقط الجلسات التي تمت موافقة الأهل عليها (Scheduled)
    const sessions = await Session.findAll({
      where: {
        child_id: { [Op.in]: childIds },
        status: ['Scheduled', 'Rescheduled'] // فقط الجلسات المقررة
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
      isPaid: s.is_paid, // ✅ إضافة حالة الدفع
      paymentStatus: s.payment_status // ✅ إضافة حالة الدفع
    }));

    res.status(200).json({ sessions: formatted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
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
      rating: null, // سيتم إضافته بعد migration
      review: null, // سيتم إضافته بعد migration
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

    // التحقق من أن الجلسة مملوكة للـ parent
    const parentId = req.user.user_id;
    const child = await Child.findOne({
      where: { child_id: session.child_id, parent_id: parentId }
    });

    if (!child) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    // ✅ تحديث حالة الجلسة إلى "Cancelled" فقط
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
const getChildSessions = async (req, res) => {
  try {
    const { childId } = req.params; 
    const userId = req.user.user_id;
    const userRole = req.user.role;

    if (!childId) return res.status(400).json({ message: 'Child ID is required' });

    // التحقق من أن الـ parent يملك هذا الطفل (إذا كان المستخدم parent)
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

// ✅ جلب الجلسات المعلقة (Pending Approval)
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

// ✅ جلب الجلسات الملغاة
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
      cancellationReason: s.reason || null, // استخدام reason الموجود بدلاً من cancellation_reason
    }));

    res.status(200).json({ sessions: formatted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

// ✅ تقييم الجلسة من قبل الأهل
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

    // التحقق من أن الجلسة مملوكة للـ parent
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

    // تحديث التقييم - سيتم تفعيله بعد إضافة الحقول إلى قاعدة البيانات
    // await session.update({
    //   parent_rating: rating,
    //   parent_review: review || null
    // });
    
    // مؤقتاً: حفظ التقييم في parent_notes أو جدول منفصل
    await session.update({
      parent_notes: review || session.parent_notes || null
    });

    // حساب تقييم الأخصائي - سيتم تفعيله بعد إضافة الحقول
    // const allSessionsForSpecialist = await Session.findAll({
    //   where: {
    //     specialist_id: session.specialist_id,
    //     status: 'Completed',
    //     parent_rating: { [Op.not]: null }
    //   },
    //   attributes: ['parent_rating']
    // });

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

// في controllers/sessionController.js - أضف هذه الدالة
const processPayment = async (req, res) => {
  try {
      const { id } = req.params;
      const { paymentMethod, paymentDetails } = req.body;
      const parentId = req.user.user_id;

      console.log('💳 Processing payment for session:', { id, paymentMethod });

      // التحقق من أن الجلسة تابعة للوالد
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
            model: Invoice,  // ✅ إضافة العلاقة
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

    // التحقق من أن الجلسة بحاجة للدفع
    if (session.is_paid && session.payment_status === 'Paid') {
      return res.status(400).json({
        success: false,
        message: 'Session is already paid'
      });
    }

    // محاكاة عملية الدفع الناجحة
    // في التطبيق الحقيقي، هنا ستتكامل مع بوابة الدفع
    const paymentSuccess = true; // محاكاة نجاح الدفع

    if (paymentSuccess) {
      // تحديث حالة الجلسة بعد الدفع الناجح
      await session.update({
        is_paid: true,
        payment_status: 'Paid',
        payment_date: new Date(),
        status: 'Scheduled' // تأكيد الجلسة بعد الدفع
      });

      // إنشاء أو تحديث الفاتورة
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
          due_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // بعد أسبوع
          issued_date: new Date(),
          paid_date: new Date()
        });
      } else {
        await invoice.update({
          status: 'Paid',
          paid_date: new Date()
        });
      }

      // إنشاء سجل الدفع
      await Payment.create({
        invoice_id: invoice.invoice_id,
        amount: invoice.total_amount,
        payment_method: paymentMethod || 'Credit Card',
        payment_gateway: 'Mock Gateway',
        transaction_id: `TXN-${Date.now()}-${id}`,
        status: 'Completed',
        payment_date: new Date()
      });

      // إرسال إشعار للمختص
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
  rateSession,
  getChildSessions,
  getAllSessions,
  processPayment
};

