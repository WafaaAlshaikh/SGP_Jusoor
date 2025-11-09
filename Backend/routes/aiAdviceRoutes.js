const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const Specialist = require('../model/Specialist');
const Groq = require('groq-sdk');

// Initialize Groq
const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY
});

/**
 * GET /api/ai/specialist-advice
 * يجيب نصائح علمية محدثة مع مصادر ودراسات للأخصائي
 */
router.get('/specialist-advice', authMiddleware, async (req, res) => {
  try {
    // تحقق أن المستخدم أخصائي
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({ 
        success: false,
        message: 'Access denied. Specialists only.' 
      });
    }

    // جيب بيانات الأخصائي من قاعدة البيانات
    const specialist = await Specialist.findOne({
      where: { specialist_id: req.user.user_id }
    });

    if (!specialist) {
      return res.status(404).json({ 
        success: false,
        message: 'Specialist profile not found' 
      });
    }

    console.log(`Generating evidence-based advice for: ${specialist.specialization} (${specialist.years_experience} years)`);

    // ولّد النصائح العلمية المحدثة من Groq AI
    const chatCompletion = await groq.chat.completions.create({
      messages: [
        {
          role: "system",
          content: `You are an expert advisor specializing in special education and evidence-based practices. 
You provide advice based on recent research, studies, and proven methodologies. 
Always include specific exercises, techniques, recent findings, and practical applications.
Focus on actionable, research-backed recommendations.`
        },
        {
          role: "user",
          content: `Generate 5 evidence-based professional tips for a ${specialist.specialization} with ${specialist.years_experience} years of experience working with children with special needs.

For each tip, include:
1. A recent study or research finding (mention year if possible)
2. Specific exercises or techniques they can use
3. How it helps children with special needs
4. Practical implementation steps

Focus on:
- Recent research findings (2020-2025)
- Specific therapeutic exercises and activities
- Evidence-based intervention strategies
- Practical tools and methods that improve outcomes
- Latest best practices in ${specialist.specialization}

Return ONLY a JSON array with this EXACT structure:
[
  {
    "title": "Clear, specific title",
    "description": "Detailed explanation including: recent research/study, specific exercises or techniques, how it helps, and practical steps to implement. Be specific with names of techniques and methods.",
    "priority": "high",
    "research_basis": "Brief mention of the research or evidence supporting this (e.g., 'Studies from 2023 show...' or 'According to recent research...')",
    "practical_exercise": "One specific exercise or technique they can use immediately"
  }
]

Make sure each advice is:
- Backed by research or evidence
- Contains specific exercises/techniques
- Includes practical implementation steps
- Relevant to ${specialist.specialization} for children with special needs
- Professional and actionable

Generate 5 tips following this format.`
        }
      ],
      model: "llama-3.3-70b-versatile",
      temperature: 0.6,
      max_tokens: 2500
    });

    const content = chatCompletion.choices[0]?.message?.content || '[]';
    
    // استخراج JSON من الرد
    const jsonMatch = content.match(/\[[\s\S]*\]/);
    
    if (jsonMatch) {
      const advice = JSON.parse(jsonMatch[0]);
      
      return res.json({
        success: true,
        specialist: {
          specialization: specialist.specialization,
          years_experience: specialist.years_experience,
          specialist_name: specialist.specialist_id
        },
        advice: advice,
        generated_at: new Date().toISOString(),
        note: "These tips are based on evidence-based practices and recent research in special education."
      });
    }
    
    throw new Error('Failed to parse AI response');

  } catch (error) {
    console.error('Error fetching AI advice:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to generate advice',
      error: error.message 
    });
  }
});

/**
 * GET /api/ai/daily-tip
 * يجيب نصيحة يومية علمية مع مصدر أو دراسة
 */
router.get('/daily-tip', authMiddleware, async (req, res) => {
  try {
    // تحقق أن المستخدم أخصائي
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({ 
        success: false,
        message: 'Access denied. Specialists only.' 
      });
    }

    // جيب بيانات الأخصائي
    const specialist = await Specialist.findOne({
      where: { specialist_id: req.user.user_id }
    });

    if (!specialist) {
      return res.status(404).json({ 
        success: false,
        message: 'Specialist profile not found' 
      });
    }

    console.log(`Generating evidence-based daily tip for: ${specialist.specialization}`);

    // ولّد نصيحة يومية علمية
    const chatCompletion = await groq.chat.completions.create({
      messages: [
        {
          role: "system",
          content: "You are an expert in special education. Provide research-backed, practical daily tips."
        },
        {
          role: "user",
          content: `Generate ONE evidence-based daily tip for a ${specialist.specialization} specialist working with children with special needs.

Include:
- A specific recent finding or research insight
- One practical exercise or technique
- Keep it motivating and actionable

Format: 3-4 sentences. Start with a research finding, then give a practical tip.

Example format: "Recent studies show that [finding]. Try [specific technique]: [brief description]. This can help improve [specific outcome]."

Make it specific to ${specialist.specialization}.`
        }
      ],
      model: "llama-3.3-70b-versatile",
      temperature: 0.7,
      max_tokens: 250
    });

    const tip = chatCompletion.choices[0]?.message?.content?.trim() || 
                'Stay updated with the latest research in your field. Evidence-based practice improves outcomes for children with special needs.';

    res.json({
      success: true,
      tip: tip,
      specialization: specialist.specialization,
      generated_at: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error fetching daily tip:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to generate tip',
      error: error.message 
    });
  }
});

/**
 * GET /api/ai/specialized-exercise
 * يجيب تمرين محدد حسب التخصص مع خطوات التنفيذ
 */
router.get('/specialized-exercise', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== 'Specialist') {
      return res.status(403).json({ 
        success: false,
        message: 'Access denied. Specialists only.' 
      });
    }

    const specialist = await Specialist.findOne({
      where: { specialist_id: req.user.user_id }
    });

    if (!specialist) {
      return res.status(404).json({ 
        success: false,
        message: 'Specialist profile not found' 
      });
    }

    const { focus_area } = req.query; // مثلاً: 'speech', 'motor skills', 'social skills'

    const chatCompletion = await groq.chat.completions.create({
      messages: [
        {
          role: "system",
          content: "You are an expert in therapeutic exercises for children with special needs. Provide detailed, step-by-step exercises."
        },
        {
          role: "user",
          content: `Generate a detailed therapeutic exercise for a ${specialist.specialization} specialist${focus_area ? ` focusing on ${focus_area}` : ''}.

Return a JSON object with this structure:
{
  "exercise_name": "Specific name of the exercise",
  "target_skills": ["skill1", "skill2"],
  "age_range": "e.g., 3-6 years",
  "materials_needed": ["item1", "item2"],
  "step_by_step": [
    "Step 1: detailed instruction",
    "Step 2: detailed instruction",
    "Step 3: detailed instruction"
  ],
  "duration": "e.g., 10-15 minutes",
  "frequency": "e.g., 3 times per week",
  "expected_outcomes": "What improvements to expect",
  "research_basis": "Brief mention of evidence supporting this exercise",
  "tips_for_success": ["tip1", "tip2"]
}

Make it practical, detailed, and evidence-based.`
        }
      ],
      model: "llama-3.3-70b-versatile",
      temperature: 0.5,
      max_tokens: 1500
    });

    const content = chatCompletion.choices[0]?.message?.content || '{}';
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    
    if (jsonMatch) {
      const exercise = JSON.parse(jsonMatch[0]);
      
      return res.json({
        success: true,
        exercise: exercise,
        specialist: {
          specialization: specialist.specialization
        },
        generated_at: new Date().toISOString()
      });
    }
    
    throw new Error('Failed to parse exercise');

  } catch (error) {
    console.error('Error generating exercise:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to generate exercise',
      error: error.message 
    });
  }
});

/**
 * GET /api/ai/test
 * endpoint للاختبار السريع (بدون authentication)
 */
router.get('/test', async (req, res) => {
  try {
    const chatCompletion = await groq.chat.completions.create({
      messages: [
        {
          role: "user",
          content: "Say 'Groq AI is working!' in a professional way."
        }
      ],
      model: "llama-3.3-70b-versatile",
      max_tokens: 100
    });

    res.json({
      success: true,
      message: 'Groq AI is connected successfully!',
      response: chatCompletion.choices[0]?.message?.content,
      model: "llama-3.3-70b-versatile"
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Groq AI connection failed',
      error: error.message
    });
  }
});

module.exports = router;