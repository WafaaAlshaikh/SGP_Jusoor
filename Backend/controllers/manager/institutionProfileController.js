const Institution = require('../../model/Institution');
const User = require('../../model/User');
const Manager = require('../../model/Manager');
const fs = require('fs');
const path = require('path');
const InstitutionReview = require('../../model/InstitutionReview');
const Groq = require('groq-sdk');
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });
const { Op } = require('sequelize');
exports.getInstitutionProfile = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const manager = await Manager.findOne({
      where: { manager_id: managerId }
    });

    if (!manager) {
      return res.status(404).json({
        success: false,
        message: 'Manager not found'
      });
    }

    const institutionId = manager.institution_id;

    const institution = await Institution.findOne({
      where: { institution_id: institutionId }
    });

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      });
    }

    const managerUser = await User.findOne({
      where: { user_id: managerId, role: 'Manager' },
      attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture', 'created_at']
    });

    const profileData = {
      institution: {
        institution_id: institution.institution_id,
        name: institution.name,
        description: institution.description,
        location: institution.location,
        location_address: institution.location_address,
        city: institution.city,
        region: institution.region,
        contact_info: institution.contact_info,
        contact_email: institution.contact_email,
        contact_phone: institution.contact_phone,
        license_number: institution.license_number,
        established_year: institution.established_year,
        services_offered: institution.services_offered ? institution.services_offered.split(',').map(s => s.trim()) : [],
        conditions_supported: institution.conditions_supported ? institution.conditions_supported.split(',').map(s => s.trim()) : [],
      },
      manager: {
        user_id: managerUser.user_id,
        full_name: managerUser.full_name,
        email: managerUser.email,
        phone: managerUser.phone,
        profile_picture: managerUser.profile_picture,
        created_at: managerUser.created_at
      }
    };

    res.status(200).json({
      success: true,
      data: profileData
    });

  } catch (error) {
    console.error('Error fetching institution profile:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred while fetching institution data',
      error: error.message
    });
  }
};

// Validation for institution update data
const validateInstitutionUpdateData = (updateData) => {
  const errors = [];

  if (updateData.description !== undefined && typeof updateData.description !== 'string') {
    errors.push('Description must be a string');
  }

  if (updateData.location !== undefined && typeof updateData.location !== 'string') {
    errors.push('Location must be a string');
  }

  if (updateData.location_address !== undefined && typeof updateData.location_address !== 'string') {
    errors.push('Address must be a string');
  }

  if (updateData.city !== undefined && typeof updateData.city !== 'string') {
    errors.push('City must be a string');
  }

  if (updateData.region !== undefined && typeof updateData.region !== 'string') {
    errors.push('Region must be a string');
  }

  if (updateData.contact_email !== undefined) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(updateData.contact_email)) {
      errors.push('Invalid email address');
    }
  }

  if (updateData.contact_phone !== undefined) {
    const phoneRegex = /^[0-9+\-\s()]{8,20}$/;
    if (!phoneRegex.test(updateData.contact_phone)) {
      errors.push('Invalid phone number');
    }
  }

  if (updateData.services_offered !== undefined) {
    if (Array.isArray(updateData.services_offered)) {
      if (updateData.services_offered.length > 20) {
        errors.push('You cannot add more than 20 services');
      }
    } else if (typeof updateData.services_offered !== 'string') {
      errors.push('Services offered must be a string or an array');
    }
  }

  if (updateData.conditions_supported !== undefined) {
    if (Array.isArray(updateData.conditions_supported)) {
      if (updateData.conditions_supported.length > 20) {
        errors.push('You cannot add more than 20 conditions');
      }
    } else if (typeof updateData.conditions_supported !== 'string') {
      errors.push('Supported conditions must be a string or an array');
    }
  }

  const forbiddenInstitutionFields = [
    'institution_id', 'name', 'website', 'price_range', 'capacity',
    'available_slots', 'approval_status', 'is_active', 'rating',
    'created_at', 'updated_at', 'contact_info'
  ];

  forbiddenInstitutionFields.forEach(field => {
    if (updateData[field] !== undefined) {
      errors.push(`Field ${field} cannot be updated`);
    }
  });

  return errors;
};

// Validation for manager update data
const validateManagerUpdateData = (updateData) => {
  const errors = [];

  if (updateData.manager_full_name !== undefined && typeof updateData.manager_full_name !== 'string') {
    errors.push('Manager name must be a string');
  }

  if (updateData.manager_phone !== undefined) {
    const phoneRegex = /^[0-9+\-\s()]{8,20}$/;
    if (!phoneRegex.test(updateData.manager_phone)) {
      errors.push('Invalid manager phone number');
    }
  }

  if (updateData.manager_email !== undefined) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(updateData.manager_email)) {
      errors.push('Invalid manager email');
    }
  }

  const forbiddenManagerFields = [
    'user_id', 'role', 'institution_id', 'status',
    'created_at', 'updated_at', 'password'
  ];

  forbiddenManagerFields.forEach(field => {
    if (updateData[field] !== undefined) {
      errors.push(`Field ${field} cannot be updated`);
    }
  });

  return errors;
};

exports.updateInstitutionProfile = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const updateData = req.body;

    console.log('Update request received:', updateData);
    console.log('Manager ID:', managerId);

    const manager = await Manager.findOne({
      where: { manager_id: managerId }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to update institution data'
      });
    }

    const institutionId = manager.institution_id;

    const institutionValidationErrors = validateInstitutionUpdateData(updateData);
    const managerValidationErrors = validateManagerUpdateData(updateData);

    const allErrors = [...institutionValidationErrors, ...managerValidationErrors];

    if (allErrors.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid data',
        errors: allErrors
      });
    }

    const institutionUpdates = {};
    const managerUpdates = {};
    let hasInstitutionUpdates = false;
    let hasManagerUpdates = false;

    const allowedInstitutionUpdates = [
      'description', 'location', 'location_address', 'city', 'region',
      'contact_email', 'contact_phone', 'services_offered',
      'conditions_supported'
    ];

    allowedInstitutionUpdates.forEach(field => {
      if (updateData[field] !== undefined) {
        hasInstitutionUpdates = true;
        if (field === 'services_offered' || field === 'conditions_supported') {
          institutionUpdates[field] = Array.isArray(updateData[field])
            ? updateData[field].join(', ')
            : updateData[field];
        } else {
          institutionUpdates[field] = updateData[field];
        }
      }
    });

    if (updateData.managerFullName !== undefined) {
      hasManagerUpdates = true;
      managerUpdates.full_name = updateData.managerFullName;
    }
    if (updateData.managerPhone !== undefined) {
      hasManagerUpdates = true;
      managerUpdates.phone = updateData.managerPhone;
    }
    if (updateData.managerEmail !== undefined) {
      hasManagerUpdates = true;
      managerUpdates.email = updateData.managerEmail;
    }

    if (updateData.manager_full_name !== undefined) {
      hasManagerUpdates = true;
      managerUpdates.full_name = updateData.manager_full_name;
    }
    if (updateData.manager_phone !== undefined) {
      hasManagerUpdates = true;
      managerUpdates.phone = updateData.manager_phone;
    }
    if (updateData.manager_email !== undefined) {
      hasManagerUpdates = true;
      managerUpdates.email = updateData.manager_email;
    }

    if (!hasInstitutionUpdates && !hasManagerUpdates) {
      return res.status(400).json({
        success: false,
        message: 'No update data provided'
      });
    }

    if (hasInstitutionUpdates) {
      const institution = await Institution.findOne({
        where: { institution_id: institutionId }
      });

      if (!institution) {
        return res.status(404).json({
          success: false,
          message: 'Institution not found'
        });
      }

      institutionUpdates.updated_at = new Date();
      console.log('Updating institution with:', institutionUpdates);
      await institution.update(institutionUpdates);
    }

    if (hasManagerUpdates) {
      const managerUser = await User.findOne({
        where: { user_id: managerId, role: 'Manager' }
      });

      if (!managerUser) {
        return res.status(404).json({
          success: false,
          message: 'Manager not found'
        });
      }

      console.log('Current manager data:', {
        id: managerUser.user_id,
        email: managerUser.email,
        phone: managerUser.phone,
        full_name: managerUser.full_name
      });
      console.log('Updates for manager:', managerUpdates);

      if (managerUpdates.email && managerUpdates.email !== managerUser.email) {
        const existingUser = await User.findOne({
          where: { email: managerUpdates.email }
        });

        if (existingUser && existingUser.user_id !== managerId) {
          return res.status(400).json({
            success: false,
            message: 'Email is already in use'
          });
        }
      }

      managerUpdates.updated_at = new Date();

      try {
        await managerUser.update(managerUpdates);
        console.log('Manager updated successfully');

        const updatedManager = await User.findOne({
          where: { user_id: managerId, role: 'Manager' },
          attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture', 'created_at', 'updated_at']
        });
        console.log('Updated manager data:', updatedManager.toJSON());
      } catch (updateError) {
        console.error('Error updating manager:', updateError);
        throw updateError;
      }
    }

    const updatedInstitution = await Institution.findOne({
      where: { institution_id: institutionId }
    });

    const updatedManager = await User.findOne({
      where: { user_id: managerId, role: 'Manager' },
      attributes: ['user_id', 'full_name', 'email', 'phone', 'profile_picture', 'created_at', 'updated_at']
    });

    const responseData = {
      success: true,
      message: 'Data updated successfully',
      data: {}
    };

    if (hasInstitutionUpdates) {
      responseData.data.institution = {
        institution_id: updatedInstitution.institution_id,
        name: updatedInstitution.name,
        description: updatedInstitution.description,
        location: updatedInstitution.location,
        location_address: updatedInstitution.location_address,
        city: updatedInstitution.city,
        region: updatedInstitution.region,
        contact_email: updatedInstitution.contact_email,
        contact_phone: updatedInstitution.contact_phone,
        services_offered: updatedInstitution.services_offered ?
          updatedInstitution.services_offered.split(',').map(s => s.trim()) : [],
        conditions_supported: updatedInstitution.conditions_supported ?
          updatedInstitution.conditions_supported.split(',').map(s => s.trim()) : [],
        updated_at: updatedInstitution.updated_at
      };
    }

    if (hasManagerUpdates) {
      responseData.data.manager = {
        user_id: updatedManager.user_id,
        full_name: updatedManager.full_name,
        email: updatedManager.email,
        phone: updatedManager.phone,
        profile_picture: updatedManager.profile_picture,
        created_at: updatedManager.created_at,
        updated_at: updatedManager.updated_at
      };
    }

    console.log('Response data:', responseData);

    res.status(200).json(responseData);

  } catch (error) {
    console.error('Error updating institution profile:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred while updating data',
      error: error.message
    });
  }
};

exports.uploadProfilePicture = async (req, res) => {
  try {
    console.log('=== UPLOAD PROFILE PICTURE START ===');
    
    if (!req.file) {
      console.log('❌ No file in request');
      return res.status(400).json({
        success: false,
        message: 'No file uploaded'
      });
    }

    // طباعة معلومات الملف كاملة
    console.log('File details:', {
      filename: req.file.filename,
      originalname: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size,
      path: req.file.path,
      destination: req.file.destination
    });

    const managerId = req.user.user_id;
    console.log('Manager ID:', managerId);

    // التحقق من أن الملف موجود فعلياً
    if (!fs.existsSync(req.file.path)) {
      console.log('❌ File does not exist on disk:', req.file.path);
      return res.status(500).json({
        success: false,
        message: 'File upload failed - file not saved'
      });
    }

    // التحقق من نوع الملف بناءً على الامتداد (بدلاً من MIME type)
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    const fileExtension = path.extname(req.file.originalname).toLowerCase();
    
    console.log('File extension check:', fileExtension);
    console.log('Is extension allowed:', allowedExtensions.includes(fileExtension));
    
    if (!allowedExtensions.includes(fileExtension)) {
      console.log('❌ Invalid file extension:', fileExtension);
      // حذف الملف المؤقت
      fs.unlinkSync(req.file.path);
      return res.status(400).json({
        success: false,
        message: `Invalid file type. Allowed extensions: ${allowedExtensions.join(', ')}`
      });
    }

    // إنشاء رابط الصورة
    const protocol = req.protocol;
    const host = req.get('host');
    const profilePictureUrl = `${protocol}://${host}/uploads/profiles/${req.file.filename}`;
    
    console.log('Generated URL:', profilePictureUrl);

    // تحديث قاعدة البيانات
    const managerUser = await User.findOne({
      where: { user_id: managerId, role: 'Manager' }
    });

    if (!managerUser) {
      console.log('❌ Manager not found in database');
      // حذف الملف المرفوع
      fs.unlinkSync(req.file.path);
      return res.status(404).json({
        success: false,
        message: 'Manager not found'
      });
    }

    // حذف الصورة القديمة إذا كانت موجودة
    if (managerUser.profile_picture) {
      try {
        const oldFilename = managerUser.profile_picture.split('/').pop();
        const oldPath = path.join(__dirname, '../../uploads/profiles/', oldFilename);
        if (fs.existsSync(oldPath)) {
          fs.unlinkSync(oldPath);
          console.log('✅ Old image deleted:', oldFilename);
        }
      } catch (oldFileError) {
        console.log('⚠️ Could not delete old image:', oldFileError.message);
        // نستمر حتى لو لم نستطع حذف الصورة القديمة
      }
    }

    // تحديث الرابط في قاعدة البيانات
    console.log('Updating database with new image URL...');
    await managerUser.update({
      profile_picture: profilePictureUrl,
      updated_at: new Date()
    });

    console.log('✅ Database updated successfully');

    // تحقق من أن الملف يمكن الوصول إليه
    console.log('Verifying file accessibility...');
    const fileStats = fs.statSync(req.file.path);
    console.log('File size on disk:', fileStats.size, 'bytes');

    res.status(200).json({
      success: true,
      message: 'Profile picture uploaded successfully',
      data: {
        profile_picture: profilePictureUrl,
        filename: req.file.filename,
        size: fileStats.size,
        mimetype: req.file.mimetype
      }
    });

    console.log('=== UPLOAD PROFILE PICTURE END ===');

  } catch (error) {
    console.error('❌ Error in uploadProfilePicture:', error);
    
    // حذف الملف إذا كان هناك خطأ
    if (req.file && req.file.path && fs.existsSync(req.file.path)) {
      try {
        fs.unlinkSync(req.file.path);
        console.log('Deleted uploaded file due to error');
      } catch (deleteError) {
        console.log('Could not delete file:', deleteError.message);
      }
    }
    
    res.status(500).json({
      success: false,
      message: 'Error uploading profile picture',
      error: error.message,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};

// Update manager profile picture
exports.updateManagerProfilePicture = async (req, res) => {
  try {
    const managerId = req.user.user_id;
    const { profile_picture } = req.body;

    if (!profile_picture) {
      return res.status(400).json({
        success: false,
        message: 'Profile picture URL is required'
      });
    }

    const manager = await Manager.findOne({
      where: { manager_id: managerId }
    });

    if (!manager) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to update the picture'
      });
    }

    const managerUser = await User.findOne({
      where: { user_id: managerId, role: 'Manager' }
    });

    if (!managerUser) {
      return res.status(404).json({
        success: false,
        message: 'Manager not found'
      });
    }

    await managerUser.update({
      profile_picture: profile_picture,
      updated_at: new Date()
    });

    res.status(200).json({
      success: true,
      message: 'Manager profile picture updated successfully',
      data: {
        profile_picture: profile_picture,
        updated_at: new Date()
      }
    });

  } catch (error) {
    console.error('Error updating manager profile picture:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred while updating the picture',
      error: error.message
    });
  }
};

// ============================
// Get institution reviews with AI analysis
// ============================
exports.getInstitutionReviews = async (req, res) => {
  try {
    const managerId = req.user.user_id;

    const manager = await Manager.findOne({
      where: { manager_id: managerId }
    });

    if (!manager) {
      return res.status(404).json({
        success: false,
        message: 'Manager not found'
      });
    }

    const institutionId = manager.institution_id;

    const reviews = await InstitutionReview.findAll({
      where: { institution_id: institutionId },
      include: [{
        model: User,
        as: 'parent',
        attributes: ['user_id', 'full_name', 'profile_picture']
      }],
      order: [['created_at', 'DESC']]
    });

    // ============================
    // Statistics
    // ============================
    const totalReviews = reviews.length;

    let overallAvg = 0,
      facilitiesAvg = 0,
      staffAvg = 0,
      cleanlinessAvg = 0,
      accessibilityAvg = 0,
      recommendationRate = 0;

    if (totalReviews > 0) {
      const sums = reviews.reduce((acc, r) => {
        acc.overall += parseFloat(r.overall_rating);
        acc.facilities += r.facilities_rating;
        acc.staff += r.staff_rating;
        acc.cleanliness += r.cleanliness_rating;
        acc.accessibility += r.accessibility_rating;
        acc.recommendations += r.would_recommend ? 1 : 0;
        return acc;
      }, {
        overall: 0,
        facilities: 0,
        staff: 0,
        cleanliness: 0,
        accessibility: 0,
        recommendations: 0
      });

      overallAvg = (sums.overall / totalReviews).toFixed(2);
      facilitiesAvg = (sums.facilities / totalReviews).toFixed(2);
      staffAvg = (sums.staff / totalReviews).toFixed(2);
      cleanlinessAvg = (sums.cleanliness / totalReviews).toFixed(2);
      accessibilityAvg = (sums.accessibility / totalReviews).toFixed(2);
      recommendationRate = ((sums.recommendations / totalReviews) * 100).toFixed(0);
    }

    // ============================
    // Star distribution
    // ============================
    const starDistribution = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };

    reviews.forEach(r => {
      const star = Math.round(parseFloat(r.overall_rating));
      if (starDistribution[star] !== undefined) starDistribution[star]++;
    });

    // ============================
    // Format reviews
    // ============================
    const formattedReviews = reviews.map(r => ({
      review_id: r.institution_review_id,
      parent: {
        user_id: r.parent?.user_id,
        full_name: r.parent?.full_name,
        profile_picture: r.parent?.profile_picture
      },
      ratings: {
        overall: parseFloat(r.overall_rating).toFixed(1),
        facilities: r.facilities_rating,
        staff: r.staff_rating,
        cleanliness: r.cleanliness_rating,
        accessibility: r.accessibility_rating
      },
      review_text: r.review_text,
      would_recommend: r.would_recommend,
      based_on_visits: r.based_on_visits,
      created_at: r.created_at
    }));

    // ============================
    // Category classification (3 groups)
    // ============================
    const categoryScores = {
      facilities: parseFloat(facilitiesAvg),
      staff: parseFloat(staffAvg),
      cleanliness: parseFloat(cleanlinessAvg),
      accessibility: parseFloat(accessibilityAvg)
    };

    const groups = {
      strength: [],
      good: [],
      need_improve: []
    };

    Object.entries(categoryScores).forEach(([category, score]) => {
      const item = {
        category,
        label: getCategoryLabel(category),
        score: score.toFixed(2)
      };

      if (score >= 4) groups.strength.push(item);
      else if (score >= 3) groups.good.push(item);
      else groups.need_improve.push(item);
    });

    const strengths = groups.strength;
    const good = groups.good;
    const weaknesses = groups.need_improve;

    // ============================
    // AI Analysis
    // ============================
    let aiAnalysis = null;

    const textReviews = reviews
      .filter(r => r.review_text && r.review_text.length > 10)
      .slice(0, 20)
      .map(r => r.review_text);

    if (textReviews.length > 0) {
      aiAnalysis = await analyzeReviewsWithAI({
        reviews: textReviews,
        statistics: {
          totalReviews,
          averageRatings: {
            overall: overallAvg,
            facilities: facilitiesAvg,
            staff: staffAvg,
            cleanliness: cleanlinessAvg,
            accessibility: accessibilityAvg
          },
          recommendationRate,
          starDistribution
        },
        strengths,
        good,
        weaknesses
      });
    }

    // ============================
    // Response
    // ============================
    res.status(200).json({
      success: true,
      data: {
        institution_id: institutionId,
        statistics: {
          total_reviews: totalReviews,
          average_ratings: {
            overall: parseFloat(overallAvg),
            facilities: parseFloat(facilitiesAvg),
            staff: parseFloat(staffAvg),
            cleanliness: parseFloat(cleanlinessAvg),
            accessibility: parseFloat(accessibilityAvg)
          },
          recommendation_rate: `${recommendationRate}%`,
          star_distribution: starDistribution,
          performance_summary: {
            strength: strengths,
            good,
            need_improve: weaknesses
          },
          recent_reviews: formattedReviews.slice(0, 10)
        },
        ai_analysis: aiAnalysis,
        all_reviews: formattedReviews
      }
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({
      success: false,
      message: 'Error fetching reviews',
      error: error.message
    });
  }
};

// ============================
// Helper functions
// ============================
function getCategoryLabel(category) {
  const labels = {
    facilities: 'Facilities & Equipment',
    staff: 'Staff & Service',
    cleanliness: 'Cleanliness & Hygiene',
    accessibility: 'Accessibility & Location'
  };
  return labels[category] || category;
}

async function analyzeReviewsWithAI(data) {
  const prompt = `
Analyze institution performance and return ONLY valid JSON.

STRENGTH AREAS:
${data.strengths.map(s => `- ${s.label} (${s.score}/5)`).join('\n')}

GOOD AREAS:
${data.good.map(g => `- ${g.label} (${g.score}/5)`).join('\n')}

NEEDS IMPROVEMENT:
${data.weaknesses.map(w => `- ${w.label} (${w.score}/5)`).join('\n')}

Return JSON:
{
  "summary": "overall summary",
  "what_to_maintain": ["item1"],
  "what_to_improve": ["item1"],
  "urgent_actions": [
    {
      "category": "category name",
      "problem": "description",
      "action": "clear action",
      "priority": "high"
    }
  ]
}
`;

  const completion = await groq.chat.completions.create({
    messages: [
      { role: "system", content: "Return ONLY JSON" },
      { role: "user", content: prompt }
    ],
    model: "llama-3.1-8b-instant",
    temperature: 0.2,
    max_tokens: 700
  });

  return extractJSONFromText(completion.choices[0]?.message?.content);
}

// ============================
// JSON Extractor
// ============================
function extractJSONFromText(text) {
  try {
    return JSON.parse(text);
  } catch {
    const match = text.match(/\{[\s\S]*\}/);
    return match ? JSON.parse(match[0]) : null;
  }
}
