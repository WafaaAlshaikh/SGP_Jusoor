const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../model/User');
const Institution = require('../model/Institution'); // ✅ إضافة هذا الـ import
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

    // ✅ جلب بيانات المؤسسة إذا كان المستخدم مديراً
    let institutionData = null;
    if (user.role === 'Manager' && user.institution_id) {
      institutionData = await Institution.findByPk(user.institution_id);
      console.log('🏢 Institution data for manager:', institutionData);
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

    // ✅ بناء response مع إضافة بيانات المؤسسة للمدير
    const responseData = {
      success: true,
      message: 'Login successful', 
      token, 
      user: {
        user_id: user.user_id,
        role: user.role,
        status: user.status,
        email: user.email,
        full_name: user.full_name,
        institution_id: user.institution_id
      }
    };

    // ✅ إضافة بيانات المؤسسة إذا كان مديراً
    if (user.role === 'Manager' && institutionData) {
      responseData.institution = {
        institution_id: institutionData.institution_id,
        name: institutionData.name,
        contact_email: institutionData.contact_email,
        contact_phone: institutionData.contact_phone,
        approval_status: institutionData.approval_status,
        is_active: institutionData.is_active,
        location_address: institutionData.location_address,
        city: institutionData.city,
        region: institutionData.region
      };
    }

    res.status(200).json(responseData);
  } catch (error) {
    console.error('❌ Login error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { login };