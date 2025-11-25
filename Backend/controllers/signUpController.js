const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const sequelize = require('../config/db');
const User = require('../model/User');
const Parent = require('../model/Parent');
const Specialist = require('../model/Specialist');
const Institution = require('../model/Institution');
const { sendEmail } = require('../utils/emailService');
const { generateOTP, storeOTP, verifyOTP } = require('../utils/otpService');

// التسجيل الأولي (إرسال OTP)
const signupInitial = async (req, res) => {
  // ✅ استخراج جميع البيانات من req.body
  const {
    full_name,
    email,
    password,
    phone,
    profile_picture,
    role,
    // ✅ البيانات الجغرافية
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
    institution_id,
    
    // ✅ بيانات المؤسسة الجديدة (للمدير فقط)
    institution_name,
    institution_location,
    institution_contact_email,
    institution_contact_phone,
    institution_license,
    institution_established_year,
    institution_city,
    institution_region
  } = req.body;

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📥 [SIGNUP INITIAL] RECEIVED FROM CLIENT:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('👤 USER DATA:');
  console.log('   ├─ full_name:', full_name);
  console.log('   ├─ email:', email);
  console.log('   └─ role:', role);
  
  // ✅ طباعة بيانات المؤسسة إذا كان المدير
  if (role === 'Manager') {
    console.log('🏢 INSTITUTION DATA:');
    console.log('   ├─ institution_name:', institution_name);
    console.log('   ├─ institution_contact_email:', institution_contact_email);
    console.log('   ├─ institution_contact_phone:', institution_contact_phone);
    console.log('   ├─ institution_license:', institution_license);
    console.log('   ├─ institution_established_year:', institution_established_year);
    console.log('   ├─ institution_city:', institution_city);
    console.log('   └─ institution_region:', institution_region);
  }
  
  console.log('📍 GEOGRAPHIC DATA:');
  console.log('   ├─ location_lat:', location_lat, `(type: ${typeof location_lat})`);
  console.log('   ├─ location_lng:', location_lng, `(type: ${typeof location_lng})`);
  console.log('   ├─ location_address:', location_address);
  console.log('   ├─ city:', city);
  console.log('   └─ region:', region);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    // التحقق من البيانات الأساسية
    if (!full_name || !email || !password || !role) {
      return res.status(400).json({ 
        success: false,
        message: 'Full name, email, password, and role are required' 
      });
    }

    // ✅ التحقق من بيانات المؤسسة إذا كان المدير
    if (role === 'Manager') {
      if (!institution_name || !institution_contact_email || !institution_contact_phone) {
        return res.status(400).json({ 
          success: false,
          message: 'Institution name, contact email, and contact phone are required for Manager role' 
        });
      }
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

    // ✅ معالجة البيانات الجغرافية
    const processedLocationLat = location_lat !== undefined && location_lat !== null 
      ? parseFloat(location_lat) 
      : null;
    
    const processedLocationLng = location_lng !== undefined && location_lng !== null 
      ? parseFloat(location_lng) 
      : null;

    console.log('🔄 [SIGNUP] PROCESSED LOCATION:');
    console.log('   ├─ Original lat:', location_lat, 'Processed:', processedLocationLat);
    console.log('   └─ Original lng:', location_lng, 'Processed:', processedLocationLng);

    // ✅ إنشاء tempData مع جميع البيانات
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
      
      // ✅ البيانات الجغرافية
      location_lat: processedLocationLat,
      location_lng: processedLocationLng,
      location_address: location_address || null,
      city: city || null,
      region: region || null,
      
      // ✅ بيانات المؤسسة (للمدير فقط)
      institution_name: institution_name || null,
      institution_contact_email: institution_contact_email || null,
      institution_contact_phone: institution_contact_phone || null,
      institution_license: institution_license || null,
      institution_established_year: institution_established_year || null,
      institution_city: institution_city || null,
      institution_region: institution_region || null
    };

    console.log('🎫 [SIGNUP] TEMP TOKEN PAYLOAD:');
    console.log('   Geographic data in token:', {
      location_lat: tempData.location_lat,
      location_lng: tempData.location_lng,
      location_address: tempData.location_address,
      city: tempData.city,
      region: tempData.region
    });

    if (role === 'Manager') {
      console.log('   Institution data in token:', {
        name: tempData.institution_name,
        email: tempData.institution_contact_email,
        phone: tempData.institution_contact_phone
      });
    }

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

    console.log('✅ [SIGNUP] OTP SENT SUCCESSFULLY');
    if (role === 'Manager') {
      console.log('🏢 Institution data included in token');
    }
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

// التحقق من OTP وإكمال التسجيل
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
    console.log('📦 [VERIFY] PROCESSING USER:', decoded.role);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📍 Geographic data from token:');
    console.log('   ├─ location_lat:', decoded.location_lat, `(${typeof decoded.location_lat})`);
    console.log('   ├─ location_lng:', decoded.location_lng, `(${typeof decoded.location_lng})`);
    console.log('   ├─ location_address:', decoded.location_address);
    console.log('   ├─ city:', decoded.city);
    console.log('   └─ region:', decoded.region);

    if (decoded.role === 'Manager') {
      console.log('🏢 Institution data from token:');
      console.log('   ├─ name:', decoded.institution_name);
      console.log('   ├─ contact_email:', decoded.institution_contact_email);
      console.log('   ├─ contact_phone:', decoded.institution_contact_phone);
      console.log('   ├─ license:', decoded.institution_license);
      console.log('   ├─ established_year:', decoded.institution_established_year);
      console.log('   ├─ city:', decoded.institution_city);
      console.log('   └─ region:', decoded.institution_region);
    }
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    let institutionId = decoded.institution_id;

    // ✅ إذا كان المدير، إنشاء مؤسسة جديدة
    if (decoded.role === 'Manager' && decoded.institution_name) {
      console.log('🏢 [VERIFY] CREATING NEW INSTITUTION...');
      
      const institution = await Institution.create({
        name: decoded.institution_name,
        description: null,
        location: decoded.location_address || decoded.institution_location,
        website: null,
        contact_info: decoded.institution_contact_phone,
        location_lat: decoded.location_lat,
        location_lng: decoded.location_lng,
        location_address: decoded.location_address || decoded.institution_location,
        city: decoded.institution_city || decoded.city,
        region: decoded.institution_region || decoded.region,
        services_offered: null,
        conditions_supported: null,
        rating: 0.00,
        price_range: null,
        capacity: null,
        available_slots: null,
        review_count: 0,
        approval_status: 'Pending',
        rejection_reason: null,
        is_active: false,
        contact_email: decoded.institution_contact_email,
        contact_phone: decoded.institution_contact_phone,
        license_number: decoded.institution_license,
        established_year: decoded.institution_established_year,
        created_at: new Date(),
        updated_at: new Date()
      }, { transaction });

      institutionId = institution.institution_id;
      
      console.log('✅ [VERIFY] INSTITUTION CREATED:', institution.institution_id);
      console.log('   ├─ Name:', institution.name);
      console.log('   ├─ Status:', institution.approval_status);
      console.log('   ├─ Contact Email:', institution.contact_email);
      console.log('   └─ Contact Phone:', institution.contact_phone);
    }

    // تشفير كلمة المرور
    const hashedPassword = await bcrypt.hash(decoded.password, 10);

    // تحديد حالة المستخدم
    let status = 'Approved';
    if (decoded.role === 'Admin' || decoded.role === 'Specialist' || decoded.role === 'Manager') {
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
      institution_id: institutionId,
      
      // ✅ البيانات الجغرافية - تأكد من التمرير الصحيح
      location_lat: finalLocationLat,
      location_lng: finalLocationLng,
      location_address: decoded.location_address,
      city: decoded.city,
      region: decoded.region,
      created_at: new Date(),
      updated_at: new Date()
    };

    console.log('🔍 [VERIFY] USER CREATE DATA OBJECT:');
    console.log(JSON.stringify(userCreateData, null, 2));

    // ✅ إنشاء المستخدم
    console.log('👤 [VERIFY] CREATING USER...');
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
    console.log('   ├─ role:', user.role);
    console.log('   ├─ status:', user.status);
    console.log('   └─ institution_id:', user.institution_id);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // إنشاء سجلات إضافية حسب الدور
    if (decoded.role === 'Parent') {
      const parentData = {
        parent_id: user.user_id,
        address: decoded.address || decoded.location_address,
        occupation: decoded.occupation,
        created_at: new Date(),
        updated_at: new Date()
      };
      
      console.log('👨‍👩‍👧 [VERIFY] Creating Parent record:', parentData);
      await Parent.create(parentData, { transaction });
      console.log('✅ Parent record created');
    }

    if (decoded.role === 'Specialist') {
      const specialistData = {
        specialist_id: user.user_id,
        specialization: decoded.specialization,
        years_experience: decoded.years_experience,
        institution_id: institutionId,
        approval_status: 'Pending',
        created_at: new Date(),
        updated_at: new Date()
      };
      
      console.log('🎓 [VERIFY] Creating Specialist record:', specialistData);
      await Specialist.create(specialistData, { transaction });
      console.log('✅ Specialist record created');
    }

    // ✅ إذا كان المدير، إرسال إشعار للإدمن بطلب مؤسسة جديدة
    if (decoded.role === 'Manager') {
      await sendInstitutionApprovalNotification(user, institutionId);
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
      institution_id: user.institution_id,
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
    
    if (user.role === 'Manager') {
      console.log('   Institution ID:', userResponse.institution_id);
    }
    
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
    
    if (error.name === 'SequelizeUniqueConstraintError') {
      return res.status(400).json({ 
        success: false,
        message: 'Email already exists' 
      });
    }
    
    res.status(500).json({ 
      success: false,
      message: 'Server error during verification' 
    });
  }
};

// إشعار المسؤول بالمستخدمين الجدد
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
    
    console.log(`📧 Admin notification sent for new ${user.role}`);
  } catch (error) {
    console.error('Admin notification error:', error);
  }
};

// إشعار المسؤول بالمؤسسة الجديدة
const sendInstitutionApprovalNotification = async (manager, institutionId) => {
  try {
    const institution = await Institution.findByPk(institutionId);
    
    const adminUsers = await User.findAll({ 
      where: { role: 'Admin', status: 'Approved' } 
    });

    for (const admin of adminUsers) {
      await sendEmail(
        admin.email,
        'New Institution Registration Requires Approval',
        `A new institution has been registered and is waiting for approval.\n\n
        🏢 Institution Details:
        Name: ${institution.name}
        Contact Email: ${institution.contact_email}
        Contact Phone: ${institution.contact_phone}
        License: ${institution.license_number}
        Established Year: ${institution.established_year}
        City: ${institution.city}
        Region: ${institution.region}
        
        👤 Manager Details:
        Name: ${manager.full_name}
        Email: ${manager.email}
        Phone: ${manager.phone}
        
        Please review and approve the institution in the admin panel.`
      );
    }
    
    console.log('📧 Institution approval notification sent to admins');
  } catch (error) {
    console.error('Institution notification error:', error);
  }
};

module.exports = {
  signupInitial,
  verifySignup
};