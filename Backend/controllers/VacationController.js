const { Op } = require('sequelize');
const VacationRequest = require('../model/VacationRequest');
const Session = require('../model/Session');
const Specialist = require('../model/Specialist');
const User = require('../model/User');
const Notification = require('../model/Notification');

exports.createVacation = async (req, res) => {
  try {
    const { start_date, end_date, reason } = req.body;
    const specialist_id = req.user.user_id;


    const specialist = await Specialist.findOne({ 
      where: { specialist_id },
      include: [{ model: User, as: 'User' }] 
    });
    if (!specialist) return res.status(403).json({ message: 'Not a specialist' });

    const today = new Date().toISOString().split('T')[0];
    if (start_date < today) return res.status(400).json({ message: 'Start date cannot be in the past' });

    const vacation = await VacationRequest.create({
      specialist_id,
      institution_id: specialist.institution_id,
      start_date,
      end_date,
      reason
    });

    const manager = await User.findOne({
      where: { 
        institution_id: specialist.institution_id,
        role: 'Manager'
      }
    });

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
      notification_sent: !!manager 
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

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


exports.updateVacation = async (req, res) => {
  try {
    const { id } = req.params;
    const { start_date, end_date, reason } = req.body;
    const specialist_id = req.user.user_id;

    const vacation = await VacationRequest.findOne({ where: { request_id: id, specialist_id } });
    if (!vacation) return res.status(404).json({ message: 'Vacation not found' });
    if (vacation.status !== 'Pending') return res.status(400).json({ message: 'Cannot modify an approved or rejected vacation' });

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


exports.deleteVacation = async (req, res) => {
  try {
    const { id } = req.params;
    const specialist_id = req.user.user_id;

    const vacation = await VacationRequest.findOne({ where: { request_id: id, specialist_id } });
    if (!vacation) return res.status(404).json({ message: 'Vacation not found' });
    if (vacation.status !== 'Pending') return res.status(400).json({ message: 'Cannot delete an approved or rejected vacation' });

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

    const today = new Date().toISOString().split('T')[0];
    const pastDates = [];

    res.status(200).json({
      unavailableDates,
      today 
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

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

exports.updateVacationStatus = async (req, res) => {
  try {
    const manager = await User.findByPk(req.user.user_id);
    if (manager.role !== 'Manager') return res.status(403).json({ message: 'Not authorized' });

    const { id } = req.params;
    const { status } = req.body; 

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