const { UserDeviceToken } = require('../model/index');

exports.registerDeviceToken = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const token = (req.body?.token ?? '').toString().trim();
    const platform = (req.body?.platform ?? '').toString().trim();

    if (!token) {
      return res.status(400).json({ success: false, message: 'token is required' });
    }

    const existing = await UserDeviceToken.findOne({
      where: {
        user_id: userId,
        token,
      },
    });

    if (existing) {
      await existing.update({
        is_active: true,
        platform: platform || existing.platform,
      });

      return res.status(200).json({ success: true, data: existing });
    }

    const created = await UserDeviceToken.create({
      user_id: userId,
      token,
      platform: platform || null,
      is_active: true,
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to register token', error: error.message });
  }
};

exports.unregisterDeviceToken = async (req, res) => {
  try {
    const userId = req.user.user_id;
    const token = (req.body?.token ?? '').toString().trim();

    if (!token) {
      return res.status(400).json({ success: false, message: 'token is required' });
    }

    const existing = await UserDeviceToken.findOne({
      where: {
        user_id: userId,
        token,
      },
    });

    if (!existing) {
      return res.status(200).json({ success: true, data: null });
    }

    await existing.update({ is_active: false });

    return res.status(200).json({ success: true, data: existing });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Failed to unregister token', error: error.message });
  }
};
