// services/zoomService.js
const axios = require('axios');
require('dotenv').config();

let zoomAccessToken = null;
let tokenExpiresAt = null;

async function getZoomAccessToken() {
  const now = new Date();
  if (zoomAccessToken && tokenExpiresAt && now < tokenExpiresAt) {
    return zoomAccessToken;
  }

  const res = await axios.post(`https://zoom.us/oauth/token?grant_type=account_credentials&account_id=${process.env.ZOOM_ACCOUNT_ID}`, {}, {
    auth: {
      username: process.env.ZOOM_CLIENT_ID,
      password: process.env.ZOOM_CLIENT_SECRET
    }
  });

  zoomAccessToken = res.data.access_token;
  tokenExpiresAt = new Date(now.getTime() + res.data.expires_in * 1000 - 60000); // خصم دقيقة للسلامة
  return zoomAccessToken;
}

async function createZoomMeeting(topic, startTime) {
  const token = await getZoomAccessToken();

  const res = await axios.post('https://api.zoom.us/v2/users/me/meetings', {
    topic: topic,
    type: 2, // Scheduled meeting
    start_time: startTime,
    duration: 60,
    timezone: 'Asia/Jerusalem',
    settings: {
      join_before_host: true,
      waiting_room: false
    }
  }, {
    headers: { Authorization: `Bearer ${token}` }
  });

  return {
    id: res.data.id.toString(),
    join_url: res.data.join_url,
    start_time: res.data.start_time,
    topic: res.data.topic
  };
}

module.exports = { getZoomAccessToken, createZoomMeeting };