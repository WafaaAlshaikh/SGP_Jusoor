const express = require('express');
const router = express.Router();
const teamController = require('../controllers/teamController'); // تأكد من المسار
const jwt = require('jsonwebtoken');

// Middleware للمصادقة (نفس الموجود)
const authenticate = (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ 
        success: false,
        message: 'No token provided' 
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; 
    next();
  } catch (err) {
    return res.status(401).json({ 
      success: false,
      message: 'Invalid token' 
    });
  }
};

// Middleware للتفويض - المدير فقط (نفس الموجود)
const authorizeManager = (req, res, next) => {
  if (!req.user || req.user.role !== 'Manager') {
    return res.status(403).json({
      success: false,
      message: 'Access denied - manager role required'
    });
  }
  next();
};

// استخدام الـ middleware (نفس الموجود)
router.use(authenticate);
router.use(authorizeManager);

// ==================== ROUTES ====================

// نظرة عامة على فريق الطفل
router.get('/children/:child_id/team', teamController.getChildTeamOverview);

module.exports = router;