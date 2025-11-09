const otpStore = {};

const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const storeOTP = async (token, otp) => {
  otpStore[token] = otp;
  setTimeout(() => delete otpStore[token], 900000); 
};

const verifyOTP = async (token, otp) => {
  return otpStore[token] === otp;
};

module.exports = {
  generateOTP,
  storeOTP,
  verifyOTP
};
