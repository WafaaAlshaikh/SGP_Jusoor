const { Institution, Report, ReportMessage } = require('../model/index');

async function getApprovedInstitutionOrNull(institutionId) {
  return Institution.findOne({
    where: {
      institution_id: institutionId,
      is_active: true,
      approval_status: 'Approved',
    },
  });
}

exports.createInstitutionContact = async (req, res) => {
  try {
    const { institutionId } = req.params;
    const userId = req.user.user_id;

    const subject = (req.body?.subject ?? '').toString().trim();
    const message = (req.body?.message ?? '').toString().trim();
    const preferredContactMethod = (req.body?.preferred_contact_method ?? '').toString().trim();
    const contactPhone = (req.body?.contact_phone ?? '').toString().trim();

    if (!subject || !message) {
      return res.status(400).json({ success: false, message: 'subject and message are required' });
    }

    const inst = await getApprovedInstitutionOrNull(institutionId);
    if (!inst) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const enrichedDescriptionParts = [
      message,
      preferredContactMethod ? `Preferred contact: ${preferredContactMethod}` : '',
      contactPhone ? `Contact phone: ${contactPhone}` : '',
    ].filter(Boolean);

    const description = enrichedDescriptionParts.join('\n');

    const report = await Report.create({
      reporter_user_id: userId,
      institution_id: institutionId,
      target_type: 'institution',
      target_id: String(institutionId),
      category: 'InstitutionContact',
      title: subject,
      description,
      priority: 'medium',
      status: 'forwarded_to_institution',
      created_at: new Date(),
      updated_at: new Date(),
    });

    await ReportMessage.create({
      report_id: report.report_id,
      sender_type: 'user',
      sender_id: userId,
      message: description,
      created_at: new Date(),
    });

    return res.status(201).json({
      success: true,
      data: report,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to create contact request', error: error.message });
  }
};
