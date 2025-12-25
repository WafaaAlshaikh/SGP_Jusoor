const { Institution, InstitutionFollower } = require('../model/index');

async function getApprovedInstitutionOrNull(institutionId) {
  return Institution.findOne({
    where: {
      institution_id: institutionId,
      is_active: true,
      approval_status: 'Approved',
    },
  });
}

exports.followInstitution = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { institutionId } = req.params;

    const inst = await getApprovedInstitutionOrNull(institutionId);
    if (!inst) {
      return res.status(404).json({ success: false, message: 'Institution not found' });
    }

    const existing = await InstitutionFollower.findOne({
      where: {
        institution_id: institutionId,
        user_id: userId,
      },
    });

    if (existing) {
      await existing.update({ is_active: true });
      return res.status(200).json({ success: true, data: existing });
    }

    const created = await InstitutionFollower.create({
      institution_id: institutionId,
      user_id: userId,
      is_active: true,
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to follow institution', error: error.message });
  }
};

exports.unfollowInstitution = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { institutionId } = req.params;

    const existing = await InstitutionFollower.findOne({
      where: {
        institution_id: institutionId,
        user_id: userId,
      },
    });

    if (!existing) {
      return res.status(200).json({ success: true, data: null });
    }

    await existing.update({ is_active: false });

    return res.status(200).json({ success: true, data: existing });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to unfollow institution', error: error.message });
  }
};

exports.getFollowStatus = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const { institutionId } = req.params;

    const row = await InstitutionFollower.findOne({
      where: {
        institution_id: institutionId,
        user_id: userId,
      },
    });

    return res.status(200).json({
      success: true,
      data: {
        is_following: !!(row && row.is_active),
      },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to fetch follow status', error: error.message });
  }
};
