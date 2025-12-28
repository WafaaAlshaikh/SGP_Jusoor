// middleware/adminMiddleware.js
const jwt = require('jsonwebtoken');
const User = require('../model/User');
const AdminUser = require('../model/AdminUser');

const adminMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      return res.status(401).json({ 
        success: false, 
        message: 'No token provided' 
      });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const user = await User.findByPk(decoded.user_id);
    if (!user) {
      return res.status(401).json({ 
        success: false, 
        message: 'User not found' 
      });
    }

    const role = String(user.role || '').trim().toLowerCase();
    if (role !== 'admin' && role !== 'admon') {
      return res.status(403).json({ 
        success: false, 
        message: 'Access denied. Admin privileges required.' 
      });
    }

    if (user.status !== 'Approved') {
      return res.status(403).json({ 
        success: false, 
        message: 'Admin account not approved' 
      });
    }

    // تحقق إذا كان هناك صلاحيات محددة
    const adminRecord = await AdminUser.findByPk(decoded.user_id);
    if (adminRecord) {
      req.adminPermissions = adminRecord.permissions;
      req.adminLevel = adminRecord.admin_level;
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('Admin middleware error:', error);
    return res.status(401).json({ 
      success: false, 
      message: 'Invalid token' 
    });
  }
};

// middleware للتحقق من صلاحيات محددة
const requirePermission = (permission) => {
  return (req, res, next) => {
    if (!req.adminPermissions) {
      return next();
    }
    if (!req.adminPermissions[permission]) {
      return res.status(403).json({ 
        success: false, 
        message: `Permission '${permission}' required` 
      });
    }
    next();
  };
};

module.exports = { adminMiddleware, requirePermission };