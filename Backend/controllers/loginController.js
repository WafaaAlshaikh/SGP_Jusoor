const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../model/User');
require('dotenv').config();

const login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: 'Email and password are required' });
  }

  try {
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    console.log('📋 User data before token generation:', {
      user_id: user.user_id,
      role: user.role,
      status: user.status,
      email: user.email
    });

    if (user.status !== 'Approved') {
      return res.status(403).json({ message: 'Account not approved yet. Please wait for admin approval.' });
    }

    console.log("🔍 Password from request:", password);
console.log("🔍 Password from database:", user.password);

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const tokenPayload = {
      user_id: user.user_id,
      role: user.role,
      status: user.status,
      email: user.email
    };

    console.log('🔐 Token payload:', tokenPayload);

    const token = jwt.sign(
      tokenPayload,
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    const decodedToken = jwt.decode(token);
    console.log('🔐 Decoded token after generation:', decodedToken);
    console.log('🔐 Full token:', token);

    res.status(200).json({ 
      success: true,
      message: 'Login successful', 
      token, 
      user: {
        user_id: user.user_id,
        role: user.role,
        status: user.status,
        email: user.email,
        full_name: user.full_name
      }
    });
  } catch (error) {
    console.error('❌ Login error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { login };