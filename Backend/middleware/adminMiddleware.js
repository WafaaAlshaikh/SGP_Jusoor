// middleware/adminMiddleware.js
const jwt = require('jsonwebtoken');
const User = require('../model/User');
const AdminUser = require('../model/AdminUser');
const AuditLog = require('../model/AuditLog');

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

// middleware/adminMiddleware.js

// ... الكود الحالي ...

// تحقق من صلاحية إدارة المحتوى
const checkContentPermission = (action) => {
  return (req, res, next) => {
    if (!req.adminPermissions) {
      return next();
    }

    // صلاحية شاملة لإدارة المحتوى
    if (req.adminPermissions.can_manage_content) {
      return next();
    }

    // أو صلاحيات محددة لكل إجراء
    const permissionMap = {
      'view': 'can_view_content',
      'create': 'can_create_content',
      'edit': 'can_edit_content',
      'delete': 'can_delete_content',
      'reorder': 'can_reorder_content',
    };

    const requiredPermission = permissionMap[action];
    if (requiredPermission && req.adminPermissions[requiredPermission]) {
      return next();
    }

    return res.status(403).json({
      success: false,
      message: `Permission required for ${action} content`
    });
  };
};

// تحقق من مستوى الادمن
const requireAdminLevel = (...levels) => {
  return (req, res, next) => {
    if (!req.adminLevel) {
      return res.status(403).json({
        success: false,
        message: 'Admin level not found'
      });
    }

    if (!levels.includes(req.adminLevel)) {
      return res.status(403).json({
        success: false,
        message: `Required admin level: ${levels.join(' or ')}`
      });
    }

    next();
  };
};

// تحقق من أن المستخدم ليس أدمن آخر (للحماية من التعديلات المتبادلة)
const preventSelfModification = (paramKey = 'user_id') => {
  return (req, res, next) => {
    const targetId = req.params[paramKey] || req.body[paramKey];
    
    if (targetId && parseInt(targetId) === req.user.user_id) {
      return res.status(403).json({
        success: false,
        message: 'Cannot modify your own admin account'
      });
    }
    
    next();
  };
};

// تسجيل طلبات الادمن
const auditAdminRequests = (actionType) => {
  return async (req, res, next) => {
    const originalSend = res.send;
    
    res.send = function(data) {
      // تأخير التسجيل حتى بعد إرسال الرد
      setTimeout(async () => {
        try {
          await AuditLog.create({
            admin_id: req.user.user_id,
            action_type: actionType || req.method + '_' + req.route?.path,
            target_type: req.route?.path?.split('/')[2] || 'unknown',
            target_id: req.params.id || req.body.id || null,
            details: JSON.stringify({
              method: req.method,
              path: req.path,
              params: req.params,
              query: req.query,
              body: req.body,
              status_code: res.statusCode,
              response: typeof data === 'string' ? data.substring(0, 500) : 'non-text response'
            }),
            ip_address: req.ip,
            user_agent: req.headers['user-agent'],
            created_at: new Date()
          });
        } catch (error) {
          console.error('Audit log error:', error);
        }
      }, 100);
      
      return originalSend.call(this, data);
    };
    
    next();
  };
};

module.exports = {
  adminMiddleware,
  requirePermission,
  checkContentPermission,
  requireAdminLevel,
  preventSelfModification,
  auditAdminRequests
};