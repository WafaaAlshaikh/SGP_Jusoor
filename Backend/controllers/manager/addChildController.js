const { 
  Child, 
  Parent,
  User, 
  Session,
  Specialist,
  SpecialistSchedule,
  SessionType,
  Institution,
  Manager,
  Diagnosis,
  Evaluation
} = require('../../model/index');
const { Op } = require('sequelize');
const sequelize = require('../../config/db');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
if (process.env.NODE_ENV !== 'production') {
  require('dotenv').config();
}

console.log('Email config check:');
console.log('SMTP_USER exists:', !!process.env.SMTP_USER);
console.log('EMAIL_USER exists:', !!process.env.EMAIL_USER);

// دالة مساعدة لإنشاء كلمة سر عشوائية
const generateRandomPassword = () => {
  return crypto.randomBytes(8).toString('hex');
};

const sendParentCredentials = async (email, password, parentName) => {
  try {
    const nodemailer = require('nodemailer');
    
    // إنشاء transporter
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: parseInt(process.env.SMTP_PORT) || 587,
      secure: false,
      auth: {
        user: process.env.SMTP_USER || process.env.EMAIL_USER,
        pass: process.env.SMTP_PASS || process.env.EMAIL_PASS
      }
    });

    // تأكد من وجود البيانات المطلوبة
    if (!process.env.SMTP_USER && !process.env.EMAIL_USER) {
      console.error('Email user not configured');
      return false;
    }

    // HTML content (بالإنجليزية فقط)
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
          <meta charset="UTF-8">
          <title>New Account - Jusoor App</title>
          <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; }
              .content { background-color: #f9f9f9; padding: 30px; border-radius: 5px; margin: 20px 0; }
              .credentials { background-color: #e8f5e9; padding: 20px; border-radius: 5px; margin: 20px 0; }
              .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
      </head>
      <body>
          <div class="container">
              <div class="header">
                  <h1>Jusoor App</h1>
              </div>
              <div class="content">
                  <h2>Hello ${parentName},</h2>
                  <p>A new account has been created for you on Jusoor App.</p>
                  <p>You can now login to the system using the following credentials:</p>
                  
                  <div class="credentials">
                      <p><strong>Email:</strong> ${email}</p>
                      <p><strong>Password:</strong> ${password}</p>
                  </div>
                  
                  <p><strong>Important:</strong> For security reasons, please change your password after logging in.</p>
                  
                  <p>Best regards,<br>The Jusoor Team</p>
              </div>
              <div class="footer">
                  <p>This is an automated message, please do not reply to this email.</p>
                  <p>&copy; ${new Date().getFullYear()} Jusoor App. All rights reserved.</p>
              </div>
          </div>
      </body>
      </html>
    `;

    // إعداد خيارات الإيميل
    const mailOptions = {
      from: process.env.SMTP_FROM || `"Jusoor App" <${process.env.SMTP_USER || process.env.EMAIL_USER}>`,
      to: email,
      subject: 'Your New Account - Jusoor App',
      html: html,
      text: `Hello ${parentName},\n\nA new account has been created for you on Jusoor App.\n\nEmail: ${email}\nPassword: ${password}\n\nPlease change your password after logging in.\n\nBest regards,\nThe Jusoor Team`
    };

    // إرسال الإيميل
    const info = await transporter.sendMail(mailOptions);
    console.log('✅ Email sent to parent:', info.messageId);
    return true;

  } catch (error) {
    console.error('❌ Error sending email to parent:', error.message);
    
    // طباعة معلومات مفيدة لل debugging
    console.log('Email configuration check:');
    console.log('- SMTP_HOST:', process.env.SMTP_HOST || 'Not set');
    console.log('- SMTP_PORT:', process.env.SMTP_PORT || 'Not set');
    console.log('- SMTP_USER:', process.env.SMTP_USER ? 'Set' : 'Not set');
    console.log('- SMTP_PASS:', process.env.SMTP_PASS ? 'Set' : 'Not set');
    console.log('- EMAIL_USER:', process.env.EMAIL_USER ? 'Set' : 'Not set');
    
    return false;
  }
};

// 1. جلب قائمة الآباء الموجودين في المؤسسة
exports.getParentsList = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    
    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    });

    if (!manager || !manager.Institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;
    
    // جلب جميع الآباء الذين لديهم أطفال في المؤسسة
    const parents = await Parent.findAll({
      include: [
        {
          model: User,
          attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture']
        },
        {
          model: Child,
          as: 'Children',
          where: {
            current_institution_id: institutionId
          },
          attributes: ['child_id', 'full_name']
        }
      ],
      attributes: ['parent_id', 'address', 'occupation'],
      distinct: true
    });

    // تنسيق البيانات
    const formattedParents = parents.map(parent => ({
      parent_id: parent.parent_id,
      user: parent.User,
      address: parent.address,
      occupation: parent.occupation,
      children: parent.Children.map(child => ({
        child_id: child.child_id,
        full_name: child.full_name
      }))
    }));

    res.status(200).json({
      success: true,
      data: {
        institution: {
          id: manager.Institution.institution_id,
          name: manager.Institution.name
        },
        parents: formattedParents,
        total: formattedParents.length
      }
    });

  } catch (error) {
    console.error('Error getting parents list:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// 2. إضافة طفل جديد
exports.addNewChild = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const managerId = req.user.user_id;
    const {
      // معلومات الأب
      parentData,
      // معلومات الطفل
      childData,
      // معلومات الجلسة (اختيارية - يمكن حجزها لاحقاً)
      sessionData
    } = req.body;

    // التحقق من البيانات المطلوبة
    if (!childData || !childData.full_name || !childData.date_of_birth || !childData.gender) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Child information is required'
      });
    }

    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id', 'name']
      }]
    }, { transaction });

    if (!manager || !manager.Institution) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;
    let parentId;

    // الحالة 1: إذا كان الأب موجود (تم اختياره من القائمة)
    if (parentData && parentData.parent_id) {
      // التحقق من وجود الأب
      const existingParent = await Parent.findOne({
        where: { parent_id: parentData.parent_id },
        include: [{
          model: User,
          attributes: ['user_id', 'email']
        }]
      }, { transaction });

      if (!existingParent) {
        await transaction.rollback();
        return res.status(404).json({
          success: false,
          message: 'Parent not found'
        });
      }

      parentId = existingParent.parent_id;

      // إرسال إشعار للأب (اختياري)
      // يمكن إضافة إرسال إشعار هنا إذا رغبت

    } else if (parentData && parentData.email) {
      // الحالة 2: إضافة أب جديد
      
      // التحقق من عدم وجود مستخدم بهذا الإيميل
      const existingUser = await User.findOne({
        where: { email: parentData.email }
      }, { transaction });

      if (existingUser) {
        await transaction.rollback();
        return res.status(400).json({
          success: false,
          message: 'Email already exists'
        });
      }

      // إنشاء كلمة سر عشوائية
      const randomPassword = generateRandomPassword();
      const hashedPassword = await bcrypt.hash(randomPassword, 10);

      // إنشاء حساب المستخدم (الأب)
      const newUser = await User.create({
        full_name: parentData.full_name,
        email: parentData.email,
        password: hashedPassword,
        phone: parentData.phone || null,
        role: 'Parent',
        status: 'Approved',
        city: parentData.city || null,
        region: parentData.region || null
      }, { transaction });

      // إنشاء سجل الأب
      const newParent = await Parent.create({
        parent_id: newUser.user_id,
        address: parentData.address || null,
        occupation: parentData.occupation || null
      }, { transaction });

      parentId = newParent.parent_id;

      // إرسال الإيميل بالمعلومات
      const emailSent = await sendParentCredentials(
        parentData.email,
        randomPassword,
        parentData.full_name
      );

      if (!emailSent) {
        console.warn('Failed to send email to parent, but account was created');
        // لا نوقف العملية إذا فشل الإيميل
      }

    } else {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Parent information is required'
      });
    }

    // إنشاء معرف فريد للطفل
    const childIdentifier = `CH${Date.now()}${Math.floor(Math.random() * 1000)}`;

    // إنشاء الطفل
    const newChild = await Child.create({
      parent_id: parentId,
      full_name: childData.full_name,
      date_of_birth: childData.date_of_birth,
      gender: childData.gender,
      diagnosis_id: childData.diagnosis_id || null,
      suspected_condition: childData.suspected_condition || null,
      symptoms_description: childData.symptoms_description || null,
      medical_history: childData.medical_history || null,
      current_institution_id: institutionId,
      registration_status: 'Approved', // مباشرة يكون معتمد
      child_identifier: childIdentifier,
      city: childData.city || null,
      address: childData.address || null,
      parent_phone: childData.parent_phone || null,
      school_info: childData.school_info || null,
      previous_services: childData.previous_services || null,
      additional_notes: childData.additional_notes || null,
      consent_given: true // بما أن المدير هو من أضافه
    }, { transaction });

    // إذا كانت هناك بيانات جلسة، نحجز جلسة General
    let sessionResult = null;
    if (sessionData && sessionData.book_session) {
      sessionResult = await bookGeneralSessionInternal(
        newChild.child_id,
        sessionData,
        managerId,
        institutionId,
        transaction
      );
    }

    await transaction.commit();

    // تحضير الرد
    const response = {
      success: true,
      message: 'Child added successfully',
      data: {
        child: {
          child_id: newChild.child_id,
          full_name: newChild.full_name,
          child_identifier: newChild.child_identifier,
          registration_status: newChild.registration_status
        },
        parent: {
          parent_id: parentId,
          is_new: !parentData.parent_id // إذا كان أب جديد
        },
        session: sessionResult
      }
    };

    // إذا تم حجز جلسة
    if (sessionResult) {
      response.data.session = sessionResult;
      response.message += ' and General session booked';
    }

    res.status(201).json(response);

  } catch (error) {
    await transaction.rollback();
    console.error('Error adding new child:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// 3. جلب الأخصائيين المتاحين لجلسة General
exports.getAvailableSpecialists = async (req, res) => {
  console.log('=== START getAvailableSpecialists ===');
  
  try {
    const managerId = req.user.user_id;
    const { date } = req.query; // التاريخ المطلوب (اختياري)

    console.log('1. Manager ID:', managerId);
    console.log('2. Requested date:', date);

    // إذا لم يتم تمرير تاريخ، استخدم التاريخ الحالي
    const requestDate = date ? new Date(date) : new Date();
    requestDate.setHours(0, 0, 0, 0);
    
    console.log('3. Using date:', requestDate.toISOString().split('T')[0]);

    // الحصول على مؤسسة المدير
    console.log('4. Fetching manager with institution...');
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    });

    if (!manager || !manager.Institution) {
      console.log('❌ ERROR: Manager or institution not found');
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;
    console.log('5. Institution ID:', institutionId);

    // جلب نوع الجلسة General
    console.log('6. Fetching General session type...');
    const generalSessionType = await SessionType.findOne({
      where: {
        name: 'General'
      }
    });

    if (!generalSessionType) {
      console.log('❌ ERROR: General session type not found');
      return res.status(404).json({
        success: false,
        message: 'General session type not found'
      });
    }

    console.log('7. General Session Type found:', {
      id: generalSessionType.session_type_id,
      name: generalSessionType.name,
      duration: generalSessionType.duration
    });

    // جلب الأخصائيين بتخصص General
    console.log('8. Fetching specialists with General specialization...');
    const specialists = await Specialist.findAll({
      where: {
        institution_id: institutionId,
        approval_status: 'Approved',
        specialization: 'General'
      },
      include: [
        {
          model: User,
          where: { status: 'Approved' },
          attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture']
        }
      ]
    });

    console.log('9. Found specialists count:', specialists.length);

    // إذا ما في أخصائيين
    if (specialists.length === 0) {
      console.log('⚠️ WARNING: No General specialists found');
      return res.status(200).json({
        success: true,
        message: 'No General specialists found in your institution',
        data: {
          session_type: {
            id: generalSessionType.session_type_id,
            name: generalSessionType.name,
            duration: generalSessionType.duration
          },
          requested_date: requestDate.toISOString().split('T')[0],
          closest_available_slot: null,
          available_days: [],
          total_available_slots: 0,
          specialists: [],
          total_available_days: 0
        }
      });
    }

    const specialistIds = specialists.map(spec => spec.specialist_id);
    const now = new Date();
    
    // ====== دالة مساعدة: تحويل الوقت إلى تنسيق مناسب ======
    const formatTime = (timeString) => {
      const [hours, minutes] = timeString.split(':');
      const hour = parseInt(hours);
      const ampm = hour >= 12 ? 'PM' : 'AM';
      const displayHour = hour % 12 || 12;
      return `${displayHour}:${minutes} ${ampm}`;
    };

    // ====== دالة مساعدة: البحث عن جميع المواعيد المتاحة خلال 14 يوم ======
    const findAllAvailableSlots = async (specialistIds, startDate, daysToCheck = 14) => {
      const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      const results = [];
      
      for (let i = 0; i < daysToCheck; i++) {
        const checkDate = new Date(startDate);
        checkDate.setDate(checkDate.getDate() + i);
        const dateStr = checkDate.toISOString().split('T')[0];
        const dayOfWeek = days[checkDate.getDay()];
        
        console.log(`   Checking date ${dateStr} (${dayOfWeek})...`);
        
        // جلب جداول الأخصائيين لهذا اليوم
        const schedules = await SpecialistSchedule.findAll({
          where: {
            specialist_id: specialistIds,
            day_of_week: dayOfWeek
          }
        });
        
        if (schedules.length > 0) {
          console.log(`   ✅ Found ${schedules.length} schedules for date ${dateStr}`);
          
          // جلب الجلسات الموجودة في هذا التاريخ
          const existingSessions = await Session.findAll({
            where: {
              institution_id: institutionId,
              date: dateStr,
              status: {
                [Op.notIn]: ['Cancelled', 'Rejected']
              }
            },
            attributes: ['specialist_id', 'time']
          });

          // تحليل كل جدول لإيجاد المواعيد الفاضية
          const availableSlotsForDate = [];
          
          for (const schedule of schedules) {
            const scheduleStartTime = new Date(`${dateStr} ${schedule.start_time}`);
            const scheduleEndTime = new Date(`${dateStr} ${schedule.end_time}`);
            
            // جلسات هذا الأخصائي في هذا اليوم
            const specialistSessions = existingSessions.filter(
              session => session.specialist_id === schedule.specialist_id
            );
            
            // إيجاد الأخصائي
            const specialist = specialists.find(s => s.specialist_id === schedule.specialist_id);
            if (!specialist) continue;
            
            // توليد المواعيد الفاضية
            let currentTime = new Date(scheduleStartTime);
            
            while (currentTime < scheduleEndTime) {
              const slotEnd = new Date(currentTime);
              slotEnd.setMinutes(slotEnd.getMinutes() + generalSessionType.duration);
              
              // التحقق إذا كان الوقت متاحاً
              const isOccupied = specialistSessions.some(session => {
                const sessionTime = new Date(`${dateStr} ${session.time}`);
                const sessionEndTime = new Date(sessionTime);
                sessionEndTime.setMinutes(sessionEndTime.getMinutes() + generalSessionType.duration);
                
                return (
                  (currentTime >= sessionTime && currentTime < sessionEndTime) ||
                  (slotEnd > sessionTime && slotEnd <= sessionEndTime) ||
                  (currentTime <= sessionTime && slotEnd >= sessionEndTime)
                );
              });
              
              // التحقق إذا كان الوقت في المستقبل
              const isSameDay = currentTime.getDate() === now.getDate() && 
                               currentTime.getMonth() === now.getMonth() && 
                               currentTime.getFullYear() === now.getFullYear();
              
              let isFuture = true;
              if (isSameDay) {
                isFuture = currentTime > now;
              }
              
              if (!isOccupied && slotEnd <= scheduleEndTime && isFuture) {
                availableSlotsForDate.push({
                  date: dateStr,
                  display_date: checkDate.toLocaleDateString('en-US', { 
                    weekday: 'long', 
                    month: 'long', 
                    day: 'numeric' 
                  }),
                  day_of_week: dayOfWeek,
                  start_time: currentTime.toTimeString().slice(0, 5),
                  end_time: slotEnd.toTimeString().slice(0, 5),
                  display_start_time: formatTime(currentTime.toTimeString().slice(0, 5)),
                  display_end_time: formatTime(slotEnd.toTimeString().slice(0, 5)),
                  specialist_id: schedule.specialist_id,
                  specialist_name: specialist.User.full_name,
                  specialist_specialization: specialist.specialization,
                  profile_picture: specialist.User.profile_picture,
                  schedule_start: schedule.start_time,
                  schedule_end: schedule.end_time,
                  date_time: new Date(currentTime),
                  is_today: i === 0,
                  is_tomorrow: i === 1,
                  is_this_week: i < 7
                });
              }
              
              // التقدم بمقدار 15 دقيقة
              currentTime.setMinutes(currentTime.getMinutes() + 15);
            }
          }
          
          if (availableSlotsForDate.length > 0) {
            // ترتيب المواعيد حسب الوقت
            availableSlotsForDate.sort((a, b) => a.date_time - b.date_time);
            
            // تجميع المواعيد حسب الأخصائي
            const slotsBySpecialist = availableSlotsForDate.reduce((acc, slot) => {
              const specialistKey = slot.specialist_id;
              if (!acc[specialistKey]) {
                acc[specialistKey] = {
                  specialist_id: slot.specialist_id,
                  specialist_name: slot.specialist_name,
                  specialization: slot.specialist_specialization,
                  profile_picture: slot.profile_picture,
                  slots: []
                };
              }
              acc[specialistKey].slots.push({
                start_time: slot.start_time,
                end_time: slot.end_time,
                display_start_time: slot.display_start_time,
                display_end_time: slot.display_end_time,
                date_time: slot.date_time,
                is_today: slot.is_today,
                is_tomorrow: slot.is_tomorrow,
                is_this_week: slot.is_this_week
              });
              return acc;
            }, {});

            // تحويل إلى مصفوفة
            const specialistsArray = Object.values(slotsBySpecialist).map(spec => ({
              id: spec.specialist_id,
              name: spec.specialist_name,
              specialization: spec.specialization,
              profile_picture: spec.profile_picture,
              available_slots: spec.slots.map(slot => ({
                start_time: slot.start_time,
                end_time: slot.end_time,
                display_start_time: slot.display_start_time,
                display_end_time: slot.display_end_time,
                date_time: slot.date_time,
                is_today: slot.is_today,
                is_tomorrow: slot.is_tomorrow,
                is_this_week: slot.is_this_week
              }))
            }));

            results.push({
              date: dateStr,
              display_date: checkDate.toLocaleDateString('en-US', { 
                weekday: 'long', 
                month: 'long', 
                day: 'numeric',
                year: 'numeric'
              }),
              day_of_week: dayOfWeek,
              available_slots_count: availableSlotsForDate.length,
              all_slots: availableSlotsForDate,
              closest_slot: availableSlotsForDate[0],
              specialists: specialistsArray
            });
          } else {
            console.log(`   ⚠️ Date ${dateStr} has schedules but no available slots`);
          }
        }
      }
      
      return results;
    };

    // البحث عن جميع المواعيد المتاحة خلال 14 يوم
    console.log('10. Searching for available slots in next 14 days...');
    const allAvailableDays = await findAllAvailableSlots(specialistIds, requestDate, 14);
    
    console.log('11. Found days with available slots:', allAvailableDays.length);
    
    // إيجاد أقرب موعد متاح (بين جميع الأيام)
    let closestSlotInfo = null;
    allAvailableDays.forEach(day => {
      if (day.closest_slot && (!closestSlotInfo || day.closest_slot.date_time < closestSlotInfo.date_time)) {
        closestSlotInfo = {
          date: day.date,
          display_date: day.display_date,
          day_of_week: day.day_of_week,
          start_time: day.closest_slot.start_time,
          end_time: day.closest_slot.end_time,
          display_start_time: day.closest_slot.display_start_time,
          display_end_time: day.closest_slot.display_end_time,
          specialist_id: day.closest_slot.specialist_id,
          specialist_name: day.closest_slot.specialist_name,
          specialist_specialization: day.closest_slot.specialist_specialization,
          profile_picture: day.closest_slot.profile_picture,
          date_time: day.closest_slot.date_time
        };
      }
    });
    
    console.log('12. Closest slot overall:', closestSlotInfo);

    // تجميع البيانات للإرجاع
    const response = {
      success: true,
      data: {
        session_type: {
          id: generalSessionType.session_type_id,
          name: generalSessionType.name,
          duration: generalSessionType.duration
        },
        requested_date: requestDate.toISOString().split('T')[0],
        closest_available_slot: closestSlotInfo,
        available_days: allAvailableDays,
        total_available_days: allAvailableDays.length,
        total_available_slots: allAvailableDays.reduce((sum, day) => sum + day.available_slots_count, 0),
        specialists: specialists.map(spec => ({
          id: spec.specialist_id,
          name: spec.User.full_name,
          specialization: spec.specialization,
          years_experience: spec.years_experience,
          profile_picture: spec.User.profile_picture,
          phone: spec.User.phone,
          email: spec.User.email
        })),
        current_time: now.toISOString(),
        debug_info: {
          specialists_count: specialists.length,
          days_searched: 14,
          days_with_slots: allAvailableDays.length,
          request_timestamp: now.toISOString()
        }
      }
    };

    console.log('=== END getAvailableSpecialists ===');
    console.log('Response summary:', {
      success: response.success,
      available_days: response.data.total_available_days,
      total_slots: response.data.total_available_slots,
      closest_date: closestSlotInfo?.date,
      closest_time: closestSlotInfo?.display_start_time,
      closest_specialist: closestSlotInfo?.specialist_name
    });
    
    res.status(200).json(response);

  } catch (error) {
    console.error('❌ ERROR in getAvailableSpecialists:', error);
    console.error('Stack trace:', error.stack);
    
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
      stack: error.stack
    });
  }
};
// 4. حجز جلسة General للطفل
exports.bookGeneralSession = async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const managerId = req.user.user_id;
    const {
      child_id,
      specialist_id,
      date,
      start_time,
      notes
    } = req.body;

    // التحقق من البيانات المطلوبة
    if (!child_id || !specialist_id || !date || !start_time) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'Child ID, specialist ID, date, and start time are required'
      });
    }

    // الحصول على مؤسسة المدير
    const manager = await Manager.findOne({
      where: { manager_id: managerId },
      include: [{
        model: Institution,
        attributes: ['institution_id']
      }]
    }, { transaction });

    if (!manager || !manager.Institution) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Institution not found for manager'
      });
    }

    const institutionId = manager.Institution.institution_id;

    // التحقق من وجود الطفل
    const child = await Child.findOne({
      where: {
        child_id: child_id,
        current_institution_id: institutionId
      }
    }, { transaction });

    if (!child) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'Child not found in your institution'
      });
    }

    // جلب نوع الجلسة General
    const generalSessionType = await SessionType.findOne({
      where: {
        // category: 'General',
        name: 'General'
      }
    }, { transaction });

    if (!generalSessionType) {
      await transaction.rollback();
      return res.status(404).json({
        success: false,
        message: 'General session type not found'
      });
    }

    // التحقق من توفر الموعد
    const existingSession = await Session.findOne({
      where: {
        specialist_id: specialist_id,
        date: date,
        time: start_time,
        status: {
          [Op.notIn]: ['Cancelled', 'Rejected']
        }
      }
    }, { transaction });

    if (existingSession) {
      await transaction.rollback();
      return res.status(400).json({
        success: false,
        message: 'This time slot is already booked'
      });
    }

    // حساب وقت نهاية الجلسة
    const startDateTime = new Date(`${date} ${start_time}`);
    const endDateTime = new Date(startDateTime);
    endDateTime.setMinutes(endDateTime.getMinutes() + generalSessionType.duration);
    const end_time = endDateTime.toTimeString().slice(0, 5);

    // إنشاء الجلسة
    const newSession = await Session.create({
      child_id: child_id,
      specialist_id: specialist_id,
      institution_id: institutionId,
      session_type_id: generalSessionType.session_type_id,
      date: date,
      time: start_time,
      status: 'Scheduled', // مباشرة معتمدة لأن المدير يحجز
      is_first_booking: true,
      approved_by_manager_id: managerId,
      manager_approval_date: new Date(),
      manager_notes: notes || null,
      requested_by_parent: false,
      is_pending: false,
      parent_approved: true,
      is_paid: false,
      payment_status: 'Pending'
    }, { transaction });

    // تحديث حالة الطفل إذا كان جديداً
    if (child.registration_status === 'Approved') {
      await child.update({
        registration_status: 'Active' // أو أي حالة تناسب نظامك
      }, { transaction });
    }

    await transaction.commit();

    res.status(201).json({
      success: true,
      message: 'General session booked successfully',
      data: {
        session: {
          session_id: newSession.session_id,
          child_id: newSession.child_id,
          child_name: child.full_name,
          specialist_id: newSession.specialist_id,
          date: newSession.date,
          time: newSession.time,
          end_time: end_time,
          status: newSession.status,
          is_first_booking: newSession.is_first_booking
        },
        session_type: {
          id: generalSessionType.session_type_id,
          name: generalSessionType.name,
          duration: generalSessionType.duration
        }
      }
    });

  } catch (error) {
    await transaction.rollback();
    console.error('Error booking general session:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
};

// دالة مساعدة داخلية لحجز جلسة General
// دالة مساعدة داخلية لحجز جلسة General - معدلة
const bookGeneralSessionInternal = async (childId, sessionData, managerId, institutionId, transaction) => {
  try {
    const { specialist_id, date, start_time, notes } = sessionData;

    if (!specialist_id || !date || !start_time) {
      return null;
    }

    // التحقق من توفر الموعد
    const existingSession = await Session.findOne({
      where: {
        specialist_id: specialist_id,
        date: date,
        time: start_time,
        status: {
          [Op.notIn]: ['Cancelled', 'Rejected']
        }
      }
    }, { transaction });

    if (existingSession) {
      console.log('❌ Time slot already booked for specialist', specialist_id, 'at', date, start_time);
      return null;
    }

    // جلب نوع الجلسة General
    const generalSessionType = await SessionType.findOne({
      where: {
        name: 'General'
      }
    }, { transaction });

    if (!generalSessionType) {
      console.log('❌ General session type not found');
      return null;
    }

    // حساب وقت نهاية الجلسة
    const startDateTime = new Date(`${date} ${start_time}`);
    const endDateTime = new Date(startDateTime);
    endDateTime.setMinutes(endDateTime.getMinutes() + generalSessionType.duration);
    const end_time = endDateTime.toTimeString().slice(0, 5);

    // إنشاء الجلسة - استخدم 'Scheduled' بدلاً من 'Approved'
    const newSession = await Session.create({
      child_id: childId,
      specialist_id: specialist_id,
      institution_id: institutionId,
      session_type_id: generalSessionType.session_type_id,
      date: date,
      time: start_time,
      status: 'Scheduled', // غيرت من 'Approved' إلى 'Scheduled'
      is_first_booking: true,
      approved_by_manager_id: managerId,
      manager_approval_date: new Date(),
      manager_notes: notes || null,
      requested_by_parent: false,
      is_pending: false,
      parent_approved: true,
      is_paid: false,
      payment_status: 'Pending',
      session_type: 'Onsite' // أضفت هذا الحقل المطلوب في الـ INSERT
    }, { transaction });

    console.log('✅ Session created successfully for child', childId, 'at', date, start_time);

    return {
      session_id: newSession.session_id,
      date: newSession.date,
      time: newSession.time,
      end_time: end_time,
      specialist_id: newSession.specialist_id,
      status: newSession.status
    };

  } catch (error) {
    console.error('❌ Error in internal session booking:', error.message);
    console.error('Stack trace:', error.stack);
    return null;
  }
};