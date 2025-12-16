// middleware/managerAuth.js
const Manager = require('../model/Manager');

const authorizeManager = async (req, res, next) => {
  try {
    const manager = await Manager.findOne({
      where: { manager_id: req.user.user_id, is_active: true }
    });
    
    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'غير مصرح. هذا المسار للمديرين فقط'
      });
    }
    
    // إضافة معلومات المؤسسة إلى request
    req.institution_id = manager.institution_id;
    next();
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'خطأ في التحقق من صلاحيات المدير',
      error: error.message
    });
  }
};

module.exports = authorizeManager;