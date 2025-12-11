const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const groqService = require('../services/GroqService');
const Child = require('../model/Child');
const Diagnosis = require('../model/Diagnosis');
const { 
  getParentDashboard,
  rescheduleSession,
  updateParentProfile,
  getChildEvaluations,
  uploadParentProfilePicture // ✅ إضافة الدالة الجديدة
} = require('../controllers/parentController');

// ========== Multer Configuration for Parent Profile Pictures ==========
const parentStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = 'uploads/parents/';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const userId = req.user.user_id;
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `parent_${userId}_${uniqueSuffix}${ext}`);
  }
});

const parentUpload = multer({
  storage: parentStorage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: function (req, file, cb) {
    const allowedTypes =[
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/gif',
      'image/webp',
      'image/bmp',
      'image/svg+xml',
      'application/octet-stream' // إضافة هذا!
    ];
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    const ext = path.extname(file.originalname).toLowerCase();
    
    if (allowedTypes.includes(file.mimetype) && allowedExtensions.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed (JPG, PNG, GIF, WEBP)'), false);
    }
  }
});

// ========== Routes ==========

// 🔹 رفع صورة الأهل
router.post('/upload-profile-picture', 
  authMiddleware, 
  parentUpload.single('profile_picture'),
  uploadParentProfilePicture
);

// 🔹 داشبورد الأهل
router.get('/dashboard', authMiddleware, getParentDashboard);

// 🔹 تحديث بروفايل الأهل
router.put('/profile', authMiddleware, updateParentProfile);

// 🔹 تغيير موعد الجلسة
router.patch('/sessions/:sessionId/reschedule', authMiddleware, rescheduleSession);

// 🔹 تقييمات الأطفال
router.get('/child-evaluations', authMiddleware, getChildEvaluations);

// 🔹 النصائح اليومية (AI)
router.get('/daily-tip', authMiddleware, async (req, res) => {
  try {
    const parentId = req.user.user_id;

    // Fetch parent's children with diagnoses
    const children = await Child.findAll({
      where: { 
        parent_id: parentId,
        deleted_at: null 
      },
      include: [{
        model: Diagnosis,
        as: 'Diagnosis',
        attributes: ['diagnosis_id', 'name', 'description']
      }]
    });

    // No children yet
    if (!children || children.length === 0) {
      return res.json({
        success: true,
        tip: 'Welcome! Start by adding your child\'s information to receive personalized tips.',
        isGeneric: true,
        aiGenerated: false
      });
    }

    // Extract unique conditions
    const conditions = children
      .map(child => child.Diagnosis)
      .filter(diagnosis => diagnosis !== null)
      .reduce((acc, diagnosis) => {
        if (!acc.find(d => d.diagnosis_id === diagnosis.diagnosis_id)) {
          acc.push({
            diagnosis_id: diagnosis.diagnosis_id,
            name: diagnosis.name,
            description: diagnosis.description
          });
        }
        return acc;
      }, []);

    // No diagnoses yet
    if (conditions.length === 0) {
      return res.json({
        success: true,
        tip: 'Spend 15 minutes in play with your child today—play is a wonderful way to build trust and skills.',
        isGeneric: true,
        aiGenerated: false
      });
    }

    // Generate AI tip
    console.log('🤖 Generating AI tip for conditions:', conditions.map(c => c.name));
    const result = await groqService.generateDailyTip(conditions);

    res.json({
      success: result.success,
      tip: result.tip,
      conditions: conditions.map(c => c.name),
      aiGenerated: result.success,
      provider: result.provider,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error in /daily-tip:', error);
    res.status(500).json({
      success: false,
      tip: 'Give your child special attention today—every moment with them is an investment in their future.',
      aiGenerated: false,
      error: 'Failed to generate tip'
    });
  }
});

// 🔹 اختبار Groq API
router.get('/test-groq', authMiddleware, async (req, res) => {
  try {
    console.log('🧪 Testing Groq API...');
    
    // 1. تحقق من API key
    if (!process.env.GROQ_API_KEY) {
      return res.json({ error: 'GROQ_API_KEY not found in environment' });
    }
    
    console.log('🔑 API Key exists, testing connection...');
    
    // 2. جرب الحصول على النماذج المتاحة
    const modelsResponse = await axios.get('https://api.groq.com/openai/v1/models', {
      headers: {
        'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
        'Content-Type': 'application/json'
      }
    });
    
    const availableModels = modelsResponse.data.data.map(m => m.id);
    console.log('📋 Available models:', availableModels);
    
    // 3. جرب طلب بسيط
    const testPrompt = "Say 'Hello World' in Arabic";
    const chatResponse = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'llama3-8b-8192',
        messages: [{ role: 'user', content: testPrompt }],
        max_tokens: 20
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );
    
    res.json({
      success: true,
      apiKey: process.env.GROQ_API_KEY ? 'Exists' : 'Missing',
      models: availableModels,
      testResponse: chatResponse.data.choices[0].message.content,
      status: 'Groq API is working correctly'
    });
    
  } catch (error) {
    console.error('❌ Test failed:', error.response?.data || error.message);
    res.json({
      success: false,
      error: error.response?.data?.error?.message || error.message,
      statusCode: error.response?.status
    });
  }
});

// 🔹 قائمة نماذج Groq
router.get('/groq-models', authMiddleware, async (req, res) => {
  try {
    const models = await groqService.getAvailableModels();
    res.json({
      success: true,
      models: models,
      currentModel: groqService.model,
      total: models.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 🔹 النصائح الأسبوعية (AI)
router.get('/weekly-tips', authMiddleware, async (req, res) => {
  try {
    const parentId = req.user.user_id;

    const children = await Child.findAll({
      where: { parent_id: parentId, deleted_at: null },
      include: [{
        model: Diagnosis,
        as: 'Diagnosis',
        attributes: ['diagnosis_id', 'name']
      }]
    });

    const conditions = children
      .map(child => child.Diagnosis)
      .filter(d => d !== null)
      .reduce((acc, d) => {
        if (!acc.find(item => item.diagnosis_id === d.diagnosis_id)) {
          acc.push({ diagnosis_id: d.diagnosis_id, name: d.name });
        }
        return acc;
      }, []);

    if (conditions.length === 0) {
      return res.json({
        success: true,
        tips: [
          'Spend quality play time together each day.',
          'Create consistent daily routines.',
          'Celebrate small wins and progress.'
        ],
        isGeneric: true
      });
    }

    const result = await groqService.generateMultipleTips(conditions, 5);

    res.json({
      success: result.success,
      tips: result.tips,
      conditions: conditions.map(c => c.name),
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error in /weekly-tips:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to generate tips'
    });
  }
});

// 🔹 التحقق من صحة خدمة AI
router.get('/ai-health', authMiddleware, async (req, res) => {
  try {
    const health = await groqService.healthCheck();
    res.json(health);
  } catch (error) {
    res.status(500).json({ 
      healthy: false, 
      error: error.message 
    });
  }
});

module.exports = router;