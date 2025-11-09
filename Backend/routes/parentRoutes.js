const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const groqService = require('../services/GroqService');
const Child = require('../model/Child');
const Diagnosis = require('../model/Diagnosis');
const { getParentDashboard,
        rescheduleSession,
        updateParentProfile,
        getChildEvaluations
 } = require('../controllers/parentController');

router.get('/dashboard', authMiddleware, getParentDashboard);
router.put('/profile', authMiddleware, updateParentProfile); // ⬅️ أضف هذا الراوت
router.patch('/sessions/:sessionId/reschedule', authMiddleware, rescheduleSession);
router.get('/child-evaluations', authMiddleware, getChildEvaluations);










/**
 * GET /api/parent/daily-tip
 * Get AI-generated daily tip
 */
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


// أضف في parentRoutes.js
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


// في parentRoutes.js أضف:
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
/**
 * GET /api/parent/weekly-tips
 * Get multiple tips for the week
 */
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

/**
 * GET /api/parent/ai-health
 * Check AI service health
 */
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
