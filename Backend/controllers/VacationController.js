// controllers/VacationController.js
const { Op } = require('sequelize');
const VacationRequest = require('../model/VacationRequest');
const Session = require('../model/Session');
const Specialist = require('../model/Specialist');
const User = require('../model/User');
const Notification = require('../model/Notification');
// ✅ إنشاء طلب إجازة جديد
exports.createVacation = async (req, res) => {
  try {
    const { start_date, end_date, reason } = req.body;
    const specialist_id = req.user.user_id;

    // تحقق من صلاحية المستخدم
    const specialist = await Specialist.findOne({ 
      where: { specialist_id },
      include: [{ model: User, as: 'User' }] // ⭐ تضمين بيانات المستخدم
    });
    if (!specialist) return res.status(403).json({ message: 'Not a specialist' });

    // لا يسمح بتاريخ ماضي
    const today = new Date().toISOString().split('T')[0];
    if (start_date < today) return res.status(400).json({ message: 'Start date cannot be in the past' });

    const vacation = await VacationRequest.create({
      specialist_id,
      institution_id: specialist.institution_id,
      start_date,
      end_date,
      reason
    });

    // ⭐ البحث عن المدير في نفس المؤسسة
    const manager = await User.findOne({
      where: { 
        institution_id: specialist.institution_id,
        role: 'Manager'
      }
    });

    // ⭐ إرسال إشعار للمدير إذا وجد
    if (manager) {
      await Notification.create({
        user_id: manager.user_id,
        title: 'New Vacation Request',
        message: `${specialist.User.full_name} has requested vacation from ${start_date} to ${end_date}. ${reason ? `Reason: ${reason}` : ''}`,
        type: 'vacation_request',
        related_id: vacation.request_id,
        is_read: false
      });
    }

    res.status(201).json({ 
      message: 'Vacation request created', 
      vacation,
      notification_sent: !!manager // ⭐ إرجاع حالة الإشعار
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

// ✅ عرض جميع الإجازات للمختص
exports.getMyVacations = async (req, res) => {
  try {
    const specialist_id = req.user.user_id;

    const vacations = await VacationRequest.findAll({
      where: { specialist_id },
      order: [['start_date', 'DESC']]
    });

    res.status(200).json(vacations);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

// ✅ تعديل طلب إجازة (فقط إذا status = Pending)
exports.updateVacation = async (req, res) => {
  try {
    const { id } = req.params;
    const { start_date, end_date, reason } = req.body;
    const specialist_id = req.user.user_id;

    const vacation = await VacationRequest.findOne({ where: { request_id: id, specialist_id } });
    if (!vacation) return res.status(404).json({ message: 'Vacation not found' });
    if (vacation.status !== 'Pending') return res.status(400).json({ message: 'Cannot modify an approved or rejected vacation' });

    // تحقق من الجلسات والتاريخ
    const today = new Date().toISOString().split('T')[0];
    if (start_date < today) return res.status(400).json({ message: 'Start date cannot be in the past' });

    
    vacation.start_date = start_date;
    vacation.end_date = end_date;
    vacation.reason = reason;
    await vacation.save();

    res.status(200).json({ message: 'Vacation updated successfully', vacation });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};


// ✅ حذف طلب إجازة (فقط إذا Pending) مع حذف الإشعار
exports.deleteVacation = async (req, res) => {
  try {
    const { id } = req.params;
    const specialist_id = req.user.user_id;

    const vacation = await VacationRequest.findOne({ where: { request_id: id, specialist_id } });
    if (!vacation) return res.status(404).json({ message: 'Vacation not found' });
    if (vacation.status !== 'Pending') return res.status(400).json({ message: 'Cannot delete an approved or rejected vacation' });

    // ⭐ حذف الإشعار المرتبط بهذا الطلب
    await Notification.destroy({
      where: { 
        related_id: id,
        type: 'vacation_request'
      }
    });

    await vacation.destroy();
    res.status(200).json({ message: 'Vacation deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

// ✅ عرض جميع الطلبات للمدير (نفس المؤسسة فقط)
exports.getInstitutionVacations = async (req, res) => {
  try {
    const manager = await User.findByPk(req.user.user_id);
    if (manager.role !== 'Manager') return res.status(403).json({ message: 'Not authorized' });

    const vacations = await VacationRequest.findAll({
      where: { institution_id: manager.institution_id },
      include: [{ model: Specialist, as: 'specialist' }]
    });

    res.status(200).json(vacations);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

// ✅ جلب الأيام المحجوزة (فيها جلسات)
exports.getUnavailableDates = async (req, res) => {
  try {
    const specialist_id = req.user.user_id;

    const sessions = await require('../model/Session').findAll({
      where: {
        specialist_id,
        status: 'Scheduled'
      },
      attributes: ['date']
    });

    const unavailableDates = sessions.map(s => s.date);

    // كمان نمنع الأيام الماضية
    const today = new Date().toISOString().split('T')[0];
    const pastDates = [];

    // بتقدري من الفرونت تمنعي الأيام الماضية بنفسك، بس هون بنخليها جاهزة لو بدك
    res.status(200).json({
      unavailableDates,
      today // عشان تعرفي من وين تبدأي
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};
// ✅ جلب طلبات الإجازة مع الإشعارات للمدير
exports.getManagerVacationNotifications = async (req, res) => {
  try {
    const manager = await User.findByPk(req.user.user_id);
    if (manager.role !== 'Manager') return res.status(403).json({ message: 'Not authorized' });

    const notifications = await Notification.findAll({
      where: { 
        user_id: manager.user_id,
        type: 'vacation_request'
      },
      include: [
        {
          model: VacationRequest,
          as: 'vacationRequest',
          include: [{ model: Specialist, as: 'specialist', include: ['User'] }]
        }
      ],
      order: [['created_at', 'DESC']]
    });

    res.status(200).json(notifications);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};
// ✅ تحديث حالة الطلب من قبل المدير
exports.updateVacationStatus = async (req, res) => {
  try {
    const manager = await User.findByPk(req.user.user_id);
    if (manager.role !== 'Manager') return res.status(403).json({ message: 'Not authorized' });

    const { id } = req.params;
    const { status } = req.body; // Approved أو Rejected

    const vacation = await VacationRequest.findOne({
      where: { request_id: id, institution_id: manager.institution_id }
    });

    if (!vacation) return res.status(404).json({ message: 'Vacation not found' });
    vacation.status = status;
    await vacation.save();

    res.status(200).json({ message: 'Vacation status updated', vacation });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};