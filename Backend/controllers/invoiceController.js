// controllers/invoiceController.js
const Invoice = require('../model/Invoice');
const Session = require('../model/Session');
const SessionType = require('../model/SessionType');
const Payment = require('../model/Payment');
const Child = require('../model/Child');
const User = require('../model/User');
const Institution = require('../model/Institution');
const { Op } = require('sequelize');

exports.getParentInvoices = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { status, page = 1, limit = 10 } = req.query;

    const where = { parent_id: parentId };
    if (status && status !== 'All') {
      where.status = status;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    // جلب الفواتير فقط بدون include
    const invoices = await Invoice.findAll({
      where,
      order: [['issued_date', 'DESC']],
      offset,
      limit: parseInt(limit),
      raw: true // ⬅️ مهم: عشان نتفادى مشاكل العلاقات
    });

    // معالجة كل فاتورة على حدة
    const processedInvoices = await Promise.all(
      invoices.map(async (invoice) => {
        // جلب بيانات الجلسة
        const session = await Session.findByPk(invoice.session_id, {
          include: [
            {
              model: SessionType,
              attributes: ['name', 'duration']
            },
            {
              model: Child,
              as: 'child',
              attributes: ['full_name']
            }
          ],
          raw: true,
          nest: true
        });

        // جلب بيانات المؤسسة
        const institution = await Institution.findByPk(invoice.institution_id, {
          attributes: ['name'],
          raw: true
        });

        return {
          ...invoice,
          Session: session,
          institution: institution
        };
      })
    );

    const totalInvoices = await Invoice.count({ where });

    res.status(200).json({
      success: true,
      data: processedInvoices,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalInvoices,
        pages: Math.ceil(totalInvoices / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('Error fetching invoices:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch invoices',
      error: error.message
    });
  }
};

// جلب تفاصيل فاتورة محددة
exports.getInvoiceDetails = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { invoiceId } = req.params;

    console.log('🔍 Fetching invoice details for:', { invoiceId, parentId });

    // جلب الفاتورة الأساسية
    const invoice = await Invoice.findOne({
      where: {
        invoice_id: invoiceId,
        parent_id: parentId
      },
      raw: true
    });

    if (!invoice) {
      return res.status(404).json({
        success: false,
        message: 'Invoice not found'
      });
    }

    // جلب جميع البيانات المرتبطة بشكل منفصل
    const [session, institution, payments] = await Promise.all([
      // 1. بيانات الجلسة
      Session.findByPk(invoice.session_id, {
        include: [
          {
            model: SessionType,
            attributes: ['name', 'duration', 'price']
          },
          {
            model: Child,
            as: 'child',
            attributes: ['full_name', 'child_id']
          },
          {
            model: User,
            as: 'specialist',
            attributes: ['full_name']
          }
        ],
        raw: true,
        nest: true
      }),
      
      // 2. بيانات المؤسسة
      Institution.findByPk(invoice.institution_id, {
        attributes: ['name', 'contact_info'],
        raw: true
      }),
      
      // 3. بيانات المدفوعات
      Payment.findAll({
        where: { invoice_id: invoiceId },
        attributes: ['payment_id', 'amount', 'payment_method', 'status', 'payment_date'],
        raw: true
      })
    ]);

    // بناء الـ response
    const response = {
      ...invoice,
      Session: session,
      institution: institution,
      Payments: payments || []
    };

    console.log('✅ Invoice details fetched successfully');

    res.status(200).json({
      success: true,
      data: response
    });

  } catch (error) {
    console.error('❌ Error fetching invoice details:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch invoice details',
      error: error.message
    });
  }
};

// إنشاء فاتورة تلقائياً عند موافقة الإدارة على الجلسة
// controllers/invoiceController.js
// تعديل دالة createInvoiceForSession لاستخدام السعر من الجلسة
exports.createInvoiceForSession = async (sessionId, price) => {
  try {
    const session = await Session.findByPk(sessionId, {
      include: [
        {
          model: require('../model/SessionType'),
          attributes: ['price', 'name']
        },
        {
          model: require('../model/Child'),
          as: 'child',
          attributes: ['parent_id']
        }
      ],
      raw: true,
      nest: true
    });

    if (!session) {
      throw new Error('Session not found');
    }

    // استخدام السعر من SessionType
    const sessionPrice = price || session.SessionType.price;
    
    const invoiceNumber = `INV-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    const taxRate = 0;
    const taxAmount = sessionPrice * taxRate;
    const totalAmount = sessionPrice + taxAmount;

    const invoice = await Invoice.create({
      session_id: sessionId,
      parent_id: session.child.parent_id,
      institution_id: session.institution_id,
      invoice_number: invoiceNumber,
      amount: sessionPrice,
      tax_amount: taxAmount,
      total_amount: totalAmount,
      status: 'Pending',
      due_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      notes: `Invoice for ${session.SessionType.name} session`
    });

    return invoice;
  } catch (error) {
    console.error('Error creating invoice:', error);
    throw error;
  }
};