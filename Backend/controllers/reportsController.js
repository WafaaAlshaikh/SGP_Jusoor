const { Op } = require('sequelize');
const { Report, ReportMessage, User } = require('../model/index');

function normalizePagination(req) {
  const page = Math.max(parseInt(req.query.page || '1', 10), 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
  const offset = (page - 1) * limit;
  return { page, limit, offset };
}

async function getReportOr404(reportId, res) {
  const report = await Report.findByPk(reportId);
  if (!report) {
    res.status(404).json({ success: false, message: 'Report not found' });
    return null;
  }
  return report;
}

function canUserAccessReport({ user, report, institutionId }) {
  if (!user) return false;

  if (user.role === 'Admin') return true;

  if (user.role === 'Manager') {
    return institutionId && report.institution_id && Number(report.institution_id) === Number(institutionId);
  }

  return Number(report.reporter_user_id) === Number(user.user_id);
}

exports.createReport = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { institution_id, target_type, target_id, category, title, description, priority } = req.body;

    if (!title || !description) {
      return res.status(400).json({ success: false, message: 'title and description are required' });
    }

    const report = await Report.create({
      reporter_user_id: userId,
      institution_id: institution_id || null,
      target_type: target_type || null,
      target_id: target_id || null,
      category: category || 'Other',
      title,
      description,
      priority: priority || 'medium',
      status: 'open',
      created_at: new Date(),
      updated_at: new Date()
    });

    await ReportMessage.create({
      report_id: report.report_id,
      sender_type: 'user',
      sender_id: userId,
      message: description,
      created_at: new Date()
    });

    return res.status(201).json({ success: true, data: report });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to create report', error: error.message });
  }
};

exports.listMyReports = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { page, limit, offset } = normalizePagination(req);

    const where = { reporter_user_id: userId };
    if (req.query.status) where.status = req.query.status;

    const { rows, count } = await Report.findAndCountAll({
      where,
      order: [['updated_at', 'DESC']],
      limit,
      offset
    });

    return res.json({ success: true, data: rows, meta: { page, limit, total: count } });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch reports', error: error.message });
  }
};

exports.listInstitutionReportsForManager = async (req, res) => {
  try {
    const institutionId = req.institution_id;
    const { page, limit, offset } = normalizePagination(req);

    const where = { institution_id: institutionId };
    if (req.query.status) where.status = req.query.status;
    if (req.query.priority) where.priority = req.query.priority;

    const { rows, count } = await Report.findAndCountAll({
      where,
      order: [['updated_at', 'DESC']],
      limit,
      offset
    });

    return res.json({ success: true, data: rows, meta: { page, limit, total: count } });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch institution reports', error: error.message });
  }
};

exports.listAllReportsForAdmin = async (req, res) => {
  try {
    const { page, limit, offset } = normalizePagination(req);

    const where = {};
    if (req.query.status) where.status = req.query.status;
    if (req.query.priority) where.priority = req.query.priority;
    if (req.query.institution_id) where.institution_id = req.query.institution_id;

    const { rows, count } = await Report.findAndCountAll({
      where,
      order: [['updated_at', 'DESC']],
      limit,
      offset
    });

    return res.json({ success: true, data: rows, meta: { page, limit, total: count } });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch reports', error: error.message });
  }
};

exports.getReportDetails = async (req, res) => {
  try {
    const reportId = req.params.id;
    const report = await getReportOr404(reportId, res);
    if (!report) return;

    const institutionId = req.institution_id;
    if (!canUserAccessReport({ user: req.user, report, institutionId })) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const messages = await ReportMessage.findAll({
      where: { report_id: report.report_id },
      order: [['created_at', 'ASC']]
    });

    return res.json({ success: true, data: { report, messages } });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch report details', error: error.message });
  }
};

exports.addMessage = async (req, res) => {
  try {
    const reportId = req.params.id;
    const report = await getReportOr404(reportId, res);
    if (!report) return;

    const institutionId = req.institution_id;
    if (!canUserAccessReport({ user: req.user, report, institutionId })) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const { message } = req.body;
    if (!message || !String(message).trim()) {
      return res.status(400).json({ success: false, message: 'message is required' });
    }

    let sender_type = 'user';
    if (req.user.role === 'Admin') sender_type = 'admin';
    else if (req.user.role === 'Manager') sender_type = 'manager';

    const created = await ReportMessage.create({
      report_id: report.report_id,
      sender_type,
      sender_id: req.user.user_id,
      message,
      created_at: new Date()
    });

    await Report.update(
      { updated_at: new Date() },
      { where: { report_id: report.report_id } }
    );

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to add message', error: error.message });
  }
};

exports.managerCreateReport = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const institutionId = req.institution_id;

    const { target_type, target_id, category, title, description, priority } = req.body;

    if (!title || !description) {
      return res.status(400).json({ success: false, message: 'title and description are required' });
    }

    const report = await Report.create({
      reporter_user_id: managerId,
      institution_id: institutionId,
      target_type: target_type || null,
      target_id: target_id || null,
      category: category || 'Other',
      title,
      description,
      priority: priority || 'medium',
      status: 'open',
      created_at: new Date(),
      updated_at: new Date()
    });

    await ReportMessage.create({
      report_id: report.report_id,
      sender_type: 'manager',
      sender_id: managerId,
      message: description,
      created_at: new Date()
    });

    return res.status(201).json({ success: true, data: report });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to create report', error: error.message });
  }
};

exports.adminUpdateReport = async (req, res) => {
  try {
    const reportId = req.params.id;
    const report = await getReportOr404(reportId, res);
    if (!report) return;

    const updates = {};
    const allowed = ['status', 'priority', 'assigned_admin_id'];
    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    updates.updated_at = new Date();

    await Report.update(updates, { where: { report_id: report.report_id } });

    const updated = await Report.findByPk(report.report_id);
    return res.json({ success: true, data: updated });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to update report', error: error.message });
  }
};
