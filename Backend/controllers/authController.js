const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../model/User');
const Parent = require('../model/Parent');
require('dotenv').config();

const signup = async (req, res) => {
  const { full_name, email, password, phone, profile_picture, address, occupation, role } = req.body;

  if (!full_name || !email || !password || !role) {
    return res.status(400).json({ message: 'Full name, email, password, and role are required' });
  }

  try {
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    let status = 'Approved';
    if (role === 'Admin' || role === 'Specialist') {
      status = 'Pending';
    }

    const user = await User.create({
      full_name,
      email,
      password: hashedPassword,
      phone: phone || null,
      profile_picture: profile_picture || null,
      role,
      status
    });

    if (role === 'Parent') {
      await Parent.create({
        parent_id: user.user_id,
        address: address || null,
        occupation: occupation || null
      });
    }

    res.status(201).json({ 
      message: status === 'Approved' 
        ? 'User registered successfully' 
        : 'User registered, waiting for admin approval',
      user 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { signup };
