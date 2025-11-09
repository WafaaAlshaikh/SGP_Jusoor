const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { User, Institution, Specialist } = require('../model/index');

// الحصول على معلومات المستخدم الحالي
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.user_id;

    const user = await User.findOne({
      where: { user_id: userId },
      include: [
        {
          model: Institution,
          as: 'institution',
          attributes: ['institution_id', 'name', 'location', 'contact_info']
        }
      ]
    });

    if (!user) {
      return res.status(404).json({ message: 'المستخدم غير موجود' });
    }

    // إذا كان المستخدم أخصائي، أحضر معلوماته الإضافية
    let specialistInfo = null;
    if (user.role === 'Specialist') {
      specialistInfo = await Specialist.findOne({
        where: { specialist_id: userId },
        include: [
          {
            model: Institution,
            attributes: ['institution_id', 'name']
          }
        ]
      });
    }

    const userProfile = {
      user_id: user.user_id,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      profile_picture: user.profile_picture,
      status: user.status,
      created_at: user.created_at,
      institution: user.institution,
      specialist_info: specialistInfo
    };

    res.json({
      success: true,
      data: userProfile
    });

  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في الخادم',
      error: error.message 
    });
  }
});

// الحصول على معلومات مستخدم معين (للمسؤولين)
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const currentUser = req.user;

    // التحقق من الصلاحيات (مسؤول أو مدير المؤسسة)
    if (currentUser.role !== 'Admin' && currentUser.role !== 'Manager') {
      return res.status(403).json({ 
        success: false,
        message: 'غير مصرح لك بالوصول إلى هذه البيانات' 
      });
    }

    const user = await User.findOne({
      where: { user_id: id },
      include: [
        {
          model: Institution,
          as: 'institution',
          attributes: ['institution_id', 'name', 'location', 'contact_info']
        }
      ]
    });

    if (!user) {
      return res.status(404).json({ 
        success: false,
        message: 'المستخدم غير موجود' 
      });
    }

    let specialistInfo = null;
    if (user.role === 'Specialist') {
      specialistInfo = await Specialist.findOne({
        where: { specialist_id: id }
      });
    }

    const userData = {
      user_id: user.user_id,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      profile_picture: user.profile_picture,
      status: user.status,
      created_at: user.created_at,
      institution: user.institution,
      specialist_info: specialistInfo
    };

    res.json({
      success: true,
      data: userData
    });

  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في الخادم',
      error: error.message 
    });
  }
});

// تحديث معلومات المستخدم
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { full_name, phone, profile_picture } = req.body;

    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({ 
        success: false,
        message: 'المستخدم غير موجود' 
      });
    }

    // البيانات المسموح بتحديثها
    const allowedUpdates = {};
    if (full_name !== undefined) allowedUpdates.full_name = full_name;
    if (phone !== undefined) allowedUpdates.phone = phone;
    if (profile_picture !== undefined) allowedUpdates.profile_picture = profile_picture;

    // إضافة updated_at
    allowedUpdates.updated_at = new Date();

    await User.update(allowedUpdates, {
      where: { user_id: userId }
    });

    // إرجاع البيانات المحدثة
    const updatedUser = await User.findOne({
      where: { user_id: userId },
      include: [
        {
          model: Institution,
          as: 'institution',
          attributes: ['institution_id', 'name', 'location', 'contact_info']
        }
      ]
    });

    res.json({
      success: true,
      message: 'تم تحديث الملف الشخصي بنجاح',
      data: updatedUser
    });

  } catch (error) {
    console.error('Error updating user profile:', error);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في تحديث البيانات',
      error: error.message 
    });
  }
});

// تحديث معلومات الأخصائي
router.put('/specialist-info', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { specialization, years_experience, salary } = req.body;

    // التحقق من أن المستخدم أخصائي
    const user = await User.findByPk(userId);
    if (!user || user.role !== 'Specialist') {
      return res.status(403).json({ 
        success: false,
        message: 'هذه الخدمة مخصصة للأخصائيين فقط' 
      });
    }

    const specialist = await Specialist.findOne({ where: { specialist_id: userId } });
    if (!specialist) {
      return res.status(404).json({ 
        success: false,
        message: 'بيانات الأخصائي غير موجودة' 
      });
    }

    const allowedUpdates = {};
    if (specialization !== undefined) allowedUpdates.specialization = specialization;
    if (years_experience !== undefined) allowedUpdates.years_experience = years_experience;
    if (salary !== undefined) allowedUpdates.salary = salary;

    await Specialist.update(allowedUpdates, {
      where: { specialist_id: userId }
    });

    const updatedSpecialist = await Specialist.findOne({
      where: { specialist_id: userId },
      include: [
        {
          model: Institution,
          attributes: ['institution_id', 'name']
        }
      ]
    });

    res.json({
      success: true,
      message: 'تم تحديث معلومات الأخصائي بنجاح',
      data: updatedSpecialist
    });

  } catch (error) {
    console.error('Error updating specialist info:', error);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في تحديث البيانات',
      error: error.message 
    });
  }
});

// تحديث كلمة المرور
router.put('/change-password', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ 
        success: false,
        message: 'كلمة المرور الحالية والجديدة مطلوبة' 
      });
    }

    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({ 
        success: false,
        message: 'المستخدم غير موجود' 
      });
    }

    // التحقق من كلمة المرور الحالية (يجب تطبيق التشفير المناسب)
    const isPasswordValid = await bcrypt.compare(currentPassword, user.password);
    if (!isPasswordValid) {
      return res.status(400).json({ 
        success: false,
        message: 'كلمة المرور الحالية غير صحيحة' 
      });
    }

    // تشفير كلمة المرور الجديدة
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);

    await User.update(
      { 
        password: hashedPassword,
        updated_at: new Date()
      },
      { where: { user_id: userId } }
    );

    res.json({
      success: true,
      message: 'تم تغيير كلمة المرور بنجاح'
    });

  } catch (error) {
    console.error('Error changing password:', error);
    res.status(500).json({ 
      success: false,
      message: 'خطأ في تغيير كلمة المرور',
      error: error.message 
    });
  }
});

module.exports = router;