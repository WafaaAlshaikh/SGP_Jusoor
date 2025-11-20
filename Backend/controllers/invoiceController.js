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

    const invoices = await Invoice.findAll({
      where,
      order: [['issued_date', 'DESC']],
      offset,
      limit: parseInt(limit),
      raw: true 
    });

    const processedInvoices = await Promise.all(
      invoices.map(async (invoice) => {
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

exports.getChildInvoices = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { childId } = req.params;
    const { status, page = 1, limit = 100 } = req.query;

    const child = await Child.findOne({
      where: { 
        child_id: childId,
        parent_id: parentId
      }
    });

    if (!child) {
      return res.status(403).json({ 
        success: false,
        message: 'Access denied. This child does not belong to you.' 
      });
    }

    const sessions = await Session.findAll({
      where: { child_id: childId },
      attributes: ['session_id'],
      raw: true
    });

    const sessionIds = sessions.map(s => s.session_id);
    
    if (sessionIds.length === 0) {
      return res.status(200).json({
        success: true,
        data: [],
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: 0,
          pages: 0
        }
      });
    }

    const where = { 
      parent_id: parentId,
      session_id: { [require('sequelize').Op.in]: sessionIds }
    };
    
    if (status && status !== 'All') {
      where.status = status;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const invoices = await Invoice.findAll({
      where,
      order: [['issued_date', 'DESC']],
      offset,
      limit: parseInt(limit),
      raw: true
    });

    const processedInvoices = await Promise.all(
      invoices.map(async (invoice) => {
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
    console.error('Error fetching child invoices:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch child invoices',
      error: error.message
    });
  }
};

exports.getInvoiceDetails = async (req, res) => {
  try {
    const parentId = req.user.user_id;
    const { invoiceId } = req.params;

    console.log('🔍 Fetching invoice details for:', { invoiceId, parentId });

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

    const [session, institution, payments] = await Promise.all([
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
      
      Institution.findByPk(invoice.institution_id, {
        attributes: ['name', 'contact_info'],
        raw: true
      }),
      
      Payment.findAll({
        where: { invoice_id: invoiceId },
        attributes: ['payment_id', 'amount', 'payment_method', 'status', 'payment_date'],
        raw: true
      })
    ]);

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