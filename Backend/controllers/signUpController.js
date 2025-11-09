const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const sequelize = require('../config/db');
const User = require('../model/User');
const Parent = require('../model/Parent');
const Specialist = require('../model/Specialist');
const { sendEmail } = require('../utils/emailService');
const { generateOTP, storeOTP, verifyOTP } = require('../utils/otpService');

// التسجيل الأولي (إرسال OTP)
// controllers/signUpController.js - استبدل signupInitial بالكامل

const signupInitial = async (req, res) => {
  // ✅ استخراج جميع البيانات من req.body
  const {
    full_name,
    email,
    password,
    phone,
    profile_picture,
    role,
    // ✅ البيانات الجغرافية - CRITICAL
    location_lat,
    location_lng,
    location_address,
    city,
    region,
    // بيانات إضافية
    address,
    occupation,
    specialization,
    years_experience,
    institution_id
  } = req.body;

  // ✅ طباعة شاملة للتأكد من استلام البيانات
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📥 [SIGNUP INITIAL] RECEIVED FROM CLIENT:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📍 GEOGRAPHIC DATA:');
  console.log('   ├─ location_lat:', location_lat, `(type: ${typeof location_lat})`);
  console.log('   ├─ location_lng:', location_lng, `(type: ${typeof location_lng})`);
  console.log('   ├─ location_address:', location_address);
  console.log('   ├─ city:', city);
  console.log('   └─ region:', region);
  console.log('👤 USER DATA:');
  console.log('   ├─ full_name:', full_name);
  console.log('   ├─ email:', email);
  console.log('   └─ role:', role);
  console.log('📦 Complete req.body:', JSON.stringify(req.body, null, 2));
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    // التحقق من البيانات الأساسية
    if (!full_name || !email || !password || !role) {
      return res.status(400).json({ 
        success: false,
        message: 'Full name, email, password, and role are required' 
      });
    }

    // التحقق من صحة البريد الإلكتروني
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ 
        success: false,
        message: 'Invalid email format' 
      });
    }

    // التحقق من قوة كلمة المرور
    if (password.length < 6) {
      return res.status(400).json({ 
        success: false,
        message: 'Password must be at least 6 characters' 
      });
    }

    // التحقق من الأدوار المسموحة
    const allowedRoles = ['Admin', 'Parent', 'Specialist', 'Donor', 'Manager'];
    if (!allowedRoles.includes(role)) {
      return res.status(400).json({ 
        success: false,
        message: 'Invalid role' 
      });
    }

    // التحقق من عدم وجود البريد الإلكتروني مسبقاً
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ 
        success: false,
        message: 'Email already registered' 
      });
    }

    // ✅ معالجة البيانات الجغرافية بعناية
    const processedLocationLat = location_lat !== undefined && location_lat !== null 
      ? parseFloat(location_lat) 
      : null;
    
    const processedLocationLng = location_lng !== undefined && location_lng !== null 
      ? parseFloat(location_lng) 
      : null;

    console.log('🔄 [SIGNUP] PROCESSED LOCATION:');
    console.log('   ├─ Original lat:', location_lat, 'Processed:', processedLocationLat);
    console.log('   └─ Original lng:', location_lng, 'Processed:', processedLocationLng);

    // ✅ إنشاء tempData مع جميع البيانات الجغرافية
    const tempData = {
      full_name,
      email,
      password,
      phone: phone || null,
      profile_picture: profile_picture || null,
      role,
      address: address || null,
      occupation: occupation || null,
      specialization: specialization || null,
      years_experience: years_experience || null,
      institution_id: institution_id || null,
      
      // ✅ البيانات الجغرافية المعالجة - MUST BE INCLUDED
      location_lat: processedLocationLat,
      location_lng: processedLocationLng,
      location_address: location_address || null,
      city: city || null,
      region: region || null
    };

    console.log('🎫 [SIGNUP] TEMP TOKEN PAYLOAD:');
    console.log('   Geographic data in token:', {
      location_lat: tempData.location_lat,
      location_lng: tempData.location_lng,
      location_address: tempData.location_address,
      city: tempData.city,
      region: tempData.region
    });

    // إنشاء token مؤقت
    const tempToken = jwt.sign(
      { ...tempData, temp: true },
      process.env.JWT_SECRET,
      { expiresIn: '15m' }
    );

    // إنشاء وإرسال OTP
    const otp = generateOTP();
    await storeOTP(tempToken, otp);
    
    // إرسال OTP للبريد الإلكتروني
    await sendEmail(
      email,
      'Verify Your Email - OTP Code',
      `Your verification code is: ${otp}. This code will expire in 15 minutes.`
    );

    console.log('✅ [SIGNUP] OTP SENT WITH LOCATION DATA');
    console.log('   Confirmed location in token: lat=' + tempData.location_lat + ', lng=' + tempData.location_lng);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    res.status(200).json({
      success: true,
      message: 'OTP sent successfully to your email',
      tempToken
    });

  } catch (error) {
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.error('❌ [SIGNUP] CRITICAL ERROR:');
    console.error('   Message:', error.message);
    console.error('   Stack:', error.stack);
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    res.status(500).json({ 
      success: false,
      message: 'Server error during signup' 
    });
  }
};


// controllers/signUpController.js - استبدل verifySignup بالكامل

const verifySignup = async (req, res) => {
  const { otp } = req.body;
  const tempToken = req.headers.authorization?.split(' ')[1];

  if (!tempToken) {
    return res.status(400).json({ 
      success: false,
      message: 'Token is required' 
    });
  }

  const transaction = await sequelize.transaction();

  try {
    // التحقق من الـ OTP
    const isValidOTP = await verifyOTP(tempToken, otp);
    if (!isValidOTP) {
      await transaction.rollback();
      return res.status(400).json({ 
        success: false,
        message: 'Invalid or expired OTP' 
      });
    }

    // فك تشفير الـ tempToken
    const decoded = jwt.verify(tempToken, process.env.JWT_SECRET);

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📦 [VERIFY] DECODED TOKEN DATA:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📍 Geographic data from token:');
    console.log('   ├─ location_lat:', decoded.location_lat, `(${typeof decoded.location_lat})`);
    console.log('   ├─ location_lng:', decoded.location_lng, `(${typeof decoded.location_lng})`);
    console.log('   ├─ location_address:', decoded.location_address);
    console.log('   ├─ city:', decoded.city);
    console.log('   └─ region:', decoded.region);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // تشفير كلمة المرور
    const hashedPassword = await bcrypt.hash(decoded.password, 10);

    // تحديد حالة المستخدم
    let status = 'Approved';
    if (decoded.role === 'Admin' || decoded.role === 'Specialist') {
      status = 'Pending';
    }

    // ✅ معالجة البيانات الجغرافية بدقة
    const finalLocationLat = decoded.location_lat !== undefined && decoded.location_lat !== null
      ? parseFloat(decoded.location_lat)
      : null;
    
    const finalLocationLng = decoded.location_lng !== undefined && decoded.location_lng !== null
      ? parseFloat(decoded.location_lng)
      : null;

    console.log('🔄 [VERIFY] FINAL PROCESSING:');
    console.log('   ├─ Final lat:', finalLocationLat, `(${typeof finalLocationLat}, isNaN: ${isNaN(finalLocationLat)})`);
    console.log('   ├─ Final lng:', finalLocationLng, `(${typeof finalLocationLng}, isNaN: ${isNaN(finalLocationLng)})`);
    console.log('   ├─ Address:', decoded.location_address);
    console.log('   ├─ City:', decoded.city);
    console.log('   └─ Region:', decoded.region);

    // ✅ بناء object المستخدم بشكل صريح
    const userCreateData = {
      full_name: decoded.full_name,
      email: decoded.email,
      password: hashedPassword,
      phone: decoded.phone,
      profile_picture: decoded.profile_picture,
      role: decoded.role,
      status: status,
      institution_id: decoded.institution_id,
      
      // ✅ البيانات الجغرافية - تأكد من التمرير الصحيح
      location_lat: finalLocationLat,
      location_lng: finalLocationLng,
      location_address: decoded.location_address,
      city: decoded.city,
      region: decoded.region
    };

    console.log('🔍 [VERIFY] USER CREATE DATA OBJECT:');
    console.log(JSON.stringify(userCreateData, null, 2));

    // ✅ إنشاء المستخدم
    const user = await User.create(userCreateData, { transaction });

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ [VERIFY] USER CREATED IN DATABASE:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📍 Saved geographic data:');
    console.log('   ├─ location_lat:', user.location_lat, `(${typeof user.location_lat})`);
    console.log('   ├─ location_lng:', user.location_lng, `(${typeof user.location_lng})`);
    console.log('   ├─ location_address:', user.location_address);
    console.log('   ├─ city:', user.city);
    console.log('   └─ region:', user.region);
    console.log('👤 User info:');
    console.log('   ├─ user_id:', user.user_id);
    console.log('   ├─ full_name:', user.full_name);
    console.log('   ├─ email:', user.email);
    console.log('   └─ role:', user.role);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // إنشاء سجلات إضافية حسب الدور
    if (decoded.role === 'Parent') {
      const parentData = {
        parent_id: user.user_id,
        address: decoded.address || decoded.location_address,
        occupation: decoded.occupation
      };
      
      console.log('👨‍👩‍👧 [VERIFY] Creating Parent record:', parentData);
      await Parent.create(parentData, { transaction });
      console.log('✅ Parent record created');
    }

    if (decoded.role === 'Specialist') {
      await Specialist.create({
        specialist_id: user.user_id,
        specialization: decoded.specialization,
        years_experience: decoded.years_experience,
        institution_id: decoded.institution_id,
        approval_status: 'Pending'
      }, { transaction });
      console.log('✅ Specialist record created');
    }

    // إنشاء token دائم
    const permanentToken = jwt.sign(
      { 
        user_id: user.user_id, 
        role: user.role,
        email: user.email 
      },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    // إرسال إشعار للمسؤول إذا كان الحالة Pending
    if (status === 'Pending') {
      await sendAdminNotification(user);
    }

    await transaction.commit();
    console.log('✅ [VERIFY] TRANSACTION COMMITTED SUCCESSFULLY');

    // ✅ إرجاع بيانات المستخدم الكاملة
    const userResponse = {
      user_id: user.user_id,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      status: user.status,
      location_lat: user.location_lat,
      location_lng: user.location_lng,
      location_address: user.location_address,
      city: user.city,
      region: user.region,
      created_at: user.created_at
    };

    console.log('📤 [VERIFY] SENDING RESPONSE WITH USER DATA:');
    console.log('   Geographic data in response:', {
      lat: userResponse.location_lat,
      lng: userResponse.location_lng,
      address: userResponse.location_address,
      city: userResponse.city,
      region: userResponse.region
    });
    console.log('🎉 [VERIFY] SIGNUP COMPLETED SUCCESSFULLY');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    res.status(201).json({
      success: true,
      message: status === 'Approved' 
        ? 'User registered successfully' 
        : 'User registered, waiting for admin approval',
      user: userResponse,
      token: permanentToken
    });

  } catch (error) {
    await transaction.rollback();
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.error('❌ [VERIFY] CRITICAL ERROR:');
    console.error('   Name:', error.name);
    console.error('   Message:', error.message);
    console.error('   Stack:', error.stack);
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(400).json({ 
        success: false,
        message: 'Invalid token' 
      });
    }
    
    if (error.name === 'SequelizeValidationError') {
      return res.status(400).json({ 
        success: false,
        message: 'Database validation error: ' + error.message 
      });
    }
    
    res.status(500).json({ 
      success: false,
      message: 'Server error during verification' 
    });
  }
};

module.exports = {
  signupInitial,
  verifySignup
};

// إشعار المسؤول
const sendAdminNotification = async (user) => {
  try {
    const adminUsers = await User.findAll({ 
      where: { role: 'Admin', status: 'Approved' } 
    });

    for (const admin of adminUsers) {
      await sendEmail(
        admin.email,
        'New User Registration Requires Approval',
        `A new ${user.role} has registered and is waiting for approval.\n\nUser Details:\nName: ${user.full_name}\nEmail: ${user.email}\nRole: ${user.role}`
      );
    }
  } catch (error) {
    console.error('Admin notification error:', error);
  }
};

module.exports = {
  signupInitial,
  verifySignup
};