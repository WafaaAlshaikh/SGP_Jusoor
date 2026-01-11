const express = require('express');
const router = express.Router();
const { Op } = require('sequelize');
const sequelize = require('../config/db');
const multer = require('multer');
const FileUploadService = require('../services/fileUploadService');
const DocumentAnalysisService = require('../services/documentAnalysisService');
const path = require('path');
const fs = require('fs').promises;
const crypto = require('crypto');
const User = require('../model/User');
const Specialist = require('../model/Specialist');
const SpecialistRegistrationRequest = require('../model/SpecialistRegistrationRequest');
const Institution = require('../model/Institution');

// إعداد Multer مخصص للـ CV
const cvStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/cv_temporary/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = crypto.randomBytes(8).toString('hex');
    cb(null, `${Date.now()}_${uniqueSuffix}_${file.originalname}`);
  }
});

const cvUpload = multer({
  storage: cvStorage,
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExtensions = ['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png'];
    
    if (!allowedExtensions.includes(ext)) {
      return cb(new Error('Invalid file type. Only CV documents allowed.'));
    }
    cb(null, true);
  },
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB
});

// تحليل الـ CV باستخدام AI
// في routes/employmentRoutes.js
// تحليل الـ CV باستخدام AI
router.post('/cv/analyze', cvUpload.single('cv_file'), async (req, res) => {
  console.log('🌐 =======================================');
  console.log('🌐 CV ANALYZE API CALLED');
  console.log('🌐 =======================================');
  
  try {
    if (!req.file) {
      console.log('❌ No file uploaded');
      return res.status(400).json({ 
        success: false, 
        message: 'No file uploaded' 
      });
    }

    console.log(`📁 File received: ${req.file.originalname}`);
    console.log(`📁 File size: ${req.file.size} bytes`);
    console.log(`📁 File path: ${req.file.path}`);
    console.log(`📁 MIME type: ${req.file.mimetype}`);

    const filePath = req.file.path;
    const fileExt = path.extname(req.file.originalname).toLowerCase();

    // تحليل المستند باستخدام الدالة الجديدة المخصصة للـ CV
    console.log('🔄 Calling DocumentAnalysisService.analyzeCV...');
    const analysisResult = await DocumentAnalysisService.analyzeCV(
      filePath,
      req.file.mimetype,
      fileExt
    );

    console.log('📊 Analysis Result from Service:', {
      success: analysisResult.success,
      hasCvAnalysis: !!analysisResult.cv_analysis,
      hasError: !!analysisResult.error
    });

    if (!analysisResult.success) {
      console.log('❌ CV analysis failed:', analysisResult.message || analysisResult.error);
      
      // حذف الملف المؤقت في حالة الفشل
      await fs.unlink(filePath).catch(() => {
        console.log('⚠️ Could not delete temp file');
      });
      
      return res.status(400).json({
        success: false,
        message: 'Failed to analyze CV document',
        error: analysisResult.message || analysisResult.error,
        details: analysisResult
      });
    }

    // استخراج معلومات التوظيف من تحليل AI
    console.log('🔄 Extracting employment info from AI analysis...');
    const extractedInfo = extractEmploymentInfo(analysisResult.cv_analysis || analysisResult.ai_analysis);
    
    console.log('✅ Extracted Info:', JSON.stringify(extractedInfo, null, 2));

    // حذف الملف المؤقت بعد التحليل الناجح
    await fs.unlink(filePath).catch(() => {
      console.log('⚠️ Could not delete temp file after success');
    });

    console.log('✅ CV analysis successful! Sending response...');
    
    const response = {
      success: true,
      extracted_info: extractedInfo,
      cv_analysis: analysisResult.cv_analysis || analysisResult.ai_analysis,
      extracted_text_preview: analysisResult.extracted_text,
      debug_info: {
        file_type: req.file.mimetype,
        file_size: req.file.size,
        analysis_time: new Date()
      }
    };
    
    console.log('📤 Final Response:', JSON.stringify(response, null, 2));
    console.log('🌐 =======================================');
    console.log('🌐 CV ANALYZE API COMPLETE');
    console.log('🌐 =======================================');
    
    res.json(response);

  } catch (error) {
    console.error('❌ CV analysis route error:', error);
    console.error('❌ Error details:', error.message);
    console.error('❌ Stack trace:', error.stack);
    
    // حذف الملف المؤقت في حالة الخطأ
    if (req.file && req.file.path) {
      await fs.unlink(req.file.path).catch((unlinkError) => {
        console.error('❌ Could not delete temp file:', unlinkError);
      });
    }
    
    res.status(500).json({ 
      success: false, 
      message: error.message,
      error_details: error.stack,
      timestamp: new Date()
    });
  }
});

// تقديم طلب التوظيف
router.post('/apply', cvUpload.single('cv_file'), async (req, res) => {
  const transaction = await sequelize.transaction();
  
  try {
    const { 
      full_name, 
      email, 
      phone, 
      specialization, 
      years_experience,
      institution_ids 
    } = req.body;

    const cvFile = req.file;

    if (!cvFile) {
      await transaction.rollback();
      return res.status(400).json({ success: false, message: 'CV file is required' });
    }

    // 1️⃣ التحقق من وجود مستخدم بنفس الإيميل
    const existingUser = await User.findOne({ where: { email }, transaction });
    if (existingUser) {
      await transaction.rollback();
      return res.status(400).json({ 
        success: false, 
        message: 'Email already exists. Please use a different email or login.' 
      });
    }

    // 2️⃣ إنشاء كلمة سر مؤقتة
    const temporaryPassword = crypto.randomBytes(8).toString('hex');

    // 3️⃣ إنشاء حساب المستخدم
    const newUser = await User.create({
      full_name,
      email,
      password: temporaryPassword, // في الواقع، يجب تشفيرها قبل الحفظ
      phone,
      role: 'Specialist',
      status: 'Pending',
      institution_id: null,
      profile_picture: null,
      created_at: new Date(),
      updated_at: new Date()
    }, { transaction });

    // 4️⃣ إنشاء سجل في جدول Specialists
    const newSpecialist = await Specialist.create({
      specialist_id: newUser.user_id,
      specialization,
      years_experience: parseInt(years_experience) || 0,
      institution_id: null,
      approval_status: 'Pending',
      average_rating: 0,
      total_ratings: 0,
      rating_summary: {},
      rating_badge: 'new',
      salary: null
    }, { transaction });

    // 5️⃣ إنشاء طلبات توظيف لكل مؤسسة
    const institutionIdsArray = institution_ids.split(',').map(id => parseInt(id.trim()));
    
    for (const institutionId of institutionIdsArray) {
      // التحقق من وجود المؤسسة
      const institution = await Institution.findByPk(institutionId, { transaction });
      if (!institution) continue;

      await SpecialistRegistrationRequest.create({
        user_id: newUser.user_id,
        institution_id: institutionId,
        specialization,
        years_experience: parseInt(years_experience) || 0,
        cv_url: `/uploads/cv/${newUser.user_id}/${cvFile.filename}`,
        status: 'Pending',
        requested_at: new Date(),
        reviewed_by: null,
        reviewed_at: null
      }, { transaction });
    }

    // 6️⃣ نقل ملف الـ CV إلى المسار الدائم
    const permanentPath = `uploads/cv/${newUser.user_id}`;
    await fs.mkdir(permanentPath, { recursive: true });
    await fs.copyFile(cvFile.path, path.join(permanentPath, cvFile.filename));
    await fs.unlink(cvFile.path); // حذف الملف المؤقت

    // 7️⃣ إرسال إيميل تأكيد (اختياري)
    // await sendConfirmationEmail(email, full_name, temporaryPassword);

    await transaction.commit();

    res.json({
      success: true,
      message: 'Application submitted successfully',
      user_id: newUser.user_id,
      specialist_id: newSpecialist.specialist_id,
      temporary_password: temporaryPassword, // فقط لأغراض العرض
      applied_institutions_count: institutionIdsArray.length
    });

  } catch (error) {
    await transaction.rollback();
    console.error('Employment application error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// دالة مساعدة لاستخراج معلومات التوظيف من تحليل AI
function extractEmploymentInfo(aiAnalysis) {
  const info = {
    full_name: '',
    email: '',
    phone: '',
    specialization: '',
    years_experience: '0',
    skills: [],
    education: []
  };

  try {
    if (!aiAnalysis || typeof aiAnalysis !== 'object') {
      console.log('⚠️ No AI analysis data provided');
      return info;
    }

    console.log('🔍 Extracting from AI analysis:', JSON.stringify(aiAnalysis, null, 2));

    // استخراج المعلومات من تحليل AI الجديد للـ CV
    if (aiAnalysis.personal_info) {
      // استخدم الاسم الإنجليزي أو العربي
      info.full_name = aiAnalysis.personal_info.full_name_en || 
                      aiAnalysis.personal_info.full_name_ar || 
                      aiAnalysis.personal_info.full_name || '';
      info.email = aiAnalysis.personal_info.email || '';
      info.phone = aiAnalysis.personal_info.phone || '';
      
      console.log('📝 Personal info extracted:', {
        name: info.full_name,
        email: info.email,
        phone: info.phone
      });
    }

    if (aiAnalysis.professional_info) {
      info.specialization = aiAnalysis.professional_info.specialization_en ||
                           aiAnalysis.professional_info.specialization_ar ||
                           aiAnalysis.professional_info.specialization ||
                           aiAnalysis.professional_info.current_position || '';
      
      info.years_experience = aiAnalysis.professional_info.years_experience?.toString() || '0';
      info.skills = aiAnalysis.professional_info.key_skills || [];
      
      console.log('📝 Professional info extracted:', {
        specialization: info.specialization,
        years_experience: info.years_experience,
        skills_count: info.skills.length
      });
    }

    if (aiAnalysis.education) {
      if (aiAnalysis.education.highest_degree) {
        info.education.push(aiAnalysis.education.highest_degree);
      }
      if (aiAnalysis.education.institution) {
        info.education.push(aiAnalysis.education.institution);
      }
      if (aiAnalysis.education.graduation_year) {
        info.education.push(`Graduated: ${aiAnalysis.education.graduation_year}`);
      }
      
      console.log('📝 Education extracted:', info.education);
    }

    // إذا لم نجد معلومات، جرب استخراج من النص الخام
    if (!info.full_name && aiAnalysis.raw_response) {
      const rawText = aiAnalysis.raw_response;
      
      console.log('🔍 Falling back to raw text extraction');
      
      // استخراج الاسم (من أول سطر أو من patterns معينة)
      const nameMatch = rawText.match(/(?:Name|Full Name|الاسم)[:\s]*([A-Za-z\u0600-\u06FF\s]+)/i);
      if (nameMatch && !info.full_name) {
        info.full_name = nameMatch[1].trim();
        console.log('📝 Name from raw text:', info.full_name);
      }

      // استخراج الإيميل
      const emailMatch = rawText.match(/[\w._%+-]+@[\w.-]+\.[a-zA-Z]{2,}/);
      if (emailMatch && !info.email) {
        info.email = emailMatch[0];
        console.log('📝 Email from raw text:', info.email);
      }

      // استخراج الهاتف
      const phoneMatch = rawText.match(/(?:\+?[\d\s\-()]{10,})/);
      if (phoneMatch && !info.phone) {
        info.phone = phoneMatch[0].trim();
        console.log('📝 Phone from raw text:', info.phone);
      }

      // استخراج التخصص
      const specMatch = rawText.match(/(?:Specialization|Field|التخصص)[:\s]*([A-Za-z\u0600-\u06FF\s]+)/i);
      if (specMatch && !info.specialization) {
        info.specialization = specMatch[1].trim();
        console.log('📝 Specialization from raw text:', info.specialization);
      }
      
      // استخراج سنوات الخبرة
      const expMatch = rawText.match(/(?:Experience|Years|خبرة)[:\s]*(\d+)/i);
      if (expMatch && !info.years_experience) {
        info.years_experience = expMatch[1];
        console.log('📝 Years experience from raw text:', info.years_experience);
      }
    }

    // إذا لم نجد أي شيء، استخدم النص المستخرج مباشرة
    if (!info.full_name && aiAnalysis.extracted_text) {
      const lines = aiAnalysis.extracted_text.split('\n').filter(line => line.trim().length > 2);
      if (lines.length > 0) {
        info.full_name = lines[0].trim();
        console.log('📝 Name from extracted text (first line):', info.full_name);
      }
    }

    // تنظيف البيانات
    info.full_name = info.full_name.trim();
    info.email = info.email.trim();
    info.phone = info.phone.trim().replace(/\s+/g, '');
    info.specialization = info.specialization.trim();
    info.years_experience = info.years_experience.toString().trim();
    
    console.log('✅ Final extracted info:', info);
    return info;

  } catch (error) {
    console.error('❌ Error extracting employment info:', error);
    console.error('❌ Error details:', error.message);
    console.error('❌ AI Analysis was:', JSON.stringify(aiAnalysis, null, 2));
    return info;
  }
}

// إرسال إيميل تأكيد (وظيفة مساعدة)
async function sendConfirmationEmail(email, name, tempPassword) {
  // قم بتنفيذ إرسال الإيميل هنا
  // يمكن استخدام nodemailer أو أي خدمة أخرى
  console.log(`Confirmation email would be sent to ${email}`);
  console.log(`Temporary password: ${tempPassword}`);
}

module.exports = router;