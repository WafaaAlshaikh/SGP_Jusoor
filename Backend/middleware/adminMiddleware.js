const adminMiddleware = (req, res, next) => {
  try {
    console.log('🔐 التحقق من صلاحية Admin:', {
      userId: req.user.user_id,
      role: req.user.role,
      status: req.user.status 
    });

    if (req.user.role !== 'Admin') {
      return res.status(403).json({
        success: false,
        message: 'غير مصرح بالوصول. صلاحية Admin مطلوبة.'
      });
    }

    // ⭐ تعليق التحقق من الـ status مؤقتاً للتجربة
    // if (req.user.status !== 'Approved') {
    //   return res.status(403).json({
    //     success: false,
    //     message: 'حسابك غير مفعل. يرجى التواصل مع الدعم.'
    //   });
    // }

    console.log('✅ صلاحية Admin مؤكدة');
    next();
  } catch (error) {
    console.error('❌ خطأ في middleware الـ Admin:', error);
    return res.status(500).json({
      success: false,
      message: 'خطأ في التحقق من الصلاحيات'
    });
  }
};

module.exports = adminMiddleware;