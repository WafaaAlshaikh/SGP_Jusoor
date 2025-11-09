    const jwt = require('jsonwebtoken');

    require('dotenv').config();

    const authMiddleware = (req, res, next) => {
      const authHeader = req.headers['authorization'];
      const token = authHeader && authHeader.split(' ')[1];

      if (!token) return res.status(401).json({ message: 'No token provided' });

      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded; // user_id و role موجودين هنا
        next();
      } catch (err) {
        return res.status(401).json({ message: 'Invalid token' });
      }
    };



    // middleware/paymentValidation.js
const Joi = require('joi');

// التحقق من صحة بيانات الدفع
exports.validatePayment = (req, res, next) => {
  const schema = Joi.object({
    invoice_id: Joi.number().integer().required(),
    payment_method: Joi.string().valid('credit_card', 'cash', 'bank_transfer').required(),
    card_token: Joi.when('payment_method', {
      is: 'credit_card',
      then: Joi.string().required(),
      otherwise: Joi.optional()
    }),
    payment_details: Joi.object().optional()
  });

  const { error } = schema.validate(req.body);
  if (error) {
    return res.status(400).json({
      success: false,
      message: 'Invalid payment data',
      error: error.details[0].message
    });
  }

  next();
};

// التحقق من بيانات البطاقة
exports.validateCard = (req, res, next) => {
  const schema = Joi.object({
    card_number: Joi.string().creditCard().required(),
    expiry_month: Joi.number().integer().min(1).max(12).required(),
    expiry_year: Joi.number().integer().min(new Date().getFullYear()).required(),
    cvv: Joi.string().length(3).pattern(/^[0-9]+$/).required(),
    card_holder: Joi.string().min(2).max(100).required()
  });

  const { error } = schema.validate(req.body);
  if (error) {
    return res.status(400).json({
      success: false,
      message: 'Invalid card data',
      error: error.details[0].message
    });
  }

  next();
};

    module.exports = authMiddleware;
