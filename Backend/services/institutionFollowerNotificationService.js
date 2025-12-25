const { Op } = require('sequelize');
const NotificationService = require('./notificationService');

const { InstitutionFollower, UserDeviceToken, Notification } = require('../model/index');

async function notifyInstitutionFollowers({
  institutionId,
  title,
  body,
  data,
  notificationType,
  relatedId,
}) {
  const followers = await InstitutionFollower.findAll({
    where: {
      institution_id: institutionId,
      is_active: true,
    },
    attributes: ['user_id'],
    raw: true,
  });

  const userIds = Array.from(new Set((followers || []).map((f) => f.user_id).filter(Boolean)));
  if (!userIds.length) return { followers: 0, tokens: 0, sent: 0 };

  await Notification.bulkCreate(
    userIds.map((userId) => ({
      user_id: userId,
      title,
      message: body,
      type: notificationType || 'institution_update',
      related_id: relatedId ?? null,
      is_read: false,
    })),
    { validate: false }
  );

  const tokens = await UserDeviceToken.findAll({
    where: {
      user_id: { [Op.in]: userIds },
      is_active: true,
    },
    attributes: ['token'],
    raw: true,
  });

  const uniqueTokens = Array.from(new Set((tokens || []).map((t) => t.token).filter(Boolean)));

  const results = await Promise.allSettled(
    uniqueTokens.map((token) => NotificationService.sendToToken(token, title, body, data || {}))
  );

  const sent = results.filter((r) => r.status === 'fulfilled' && r.value && r.value.success).length;
  return { followers: userIds.length, tokens: uniqueTokens.length, sent };
}

module.exports = {
  notifyInstitutionFollowers,
};
