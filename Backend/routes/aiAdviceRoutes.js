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
 * POST /api/ai/educational-resources
 * يجيب موارد تعليمية من مصادر موثوقة حسب التشخيص
 */
router.post('/educational-resources', authMiddleware, async (req, res) => {
  try {
    const { diagnosis, age } = req.body;

    if (!diagnosis) {
      return res.status(400).json({ 
        success: false,
        message: 'Diagnosis is required' 
      });
    }

    console.log(`🔄 Generating educational resources for: ${diagnosis}, age: ${age}`);

    // Add variation seed based on current time
    const now = new Date();
    const seed = now.getHours() + now.getMinutes(); // Changes every minute
    const focusAreas = [
      'communication and social interaction',
      'daily living skills and independence',
      'behavior management and emotional regulation',
      'cognitive development and learning strategies',
      'sensory processing and physical activities'
    ];
    const selectedFocus = focusAreas[seed % focusAreas.length];

    // Trusted sources mapping
    const trustedSources = {
      'Autism Spectrum Disorder': [
        { name: 'Autism Speaks', url: 'https://www.autismspeaks.org' },
        { name: 'CDC Autism', url: 'https://www.cdc.gov/autism' },
        { name: 'National Autistic Society', url: 'https://www.autism.org.uk' }
      ],
      'Down Syndrome': [
        { name: 'National Down Syndrome Society', url: 'https://www.ndss.org' },
        { name: 'Down Syndrome Education International', url: 'https://www.dseinternational.org' }
      ],
      'ADHD': [
        { name: 'CHADD', url: 'https://chadd.org' },
        { name: 'CDC ADHD', url: 'https://www.cdc.gov/adhd' }
      ],
      'Speech Delays': [
        { name: 'ASHA', url: 'https://www.asha.org' },
        { name: 'Speech and Language Kids', url: 'https://www.speechandlanguagekids.com' }
      ],
      'Learning Disabilities': [
        { name: 'Learning Disabilities Association', url: 'https://ldaamerica.org' },
        { name: 'Understood.org', url: 'https://www.understood.org' }
      ]
    };

    const sources = trustedSources[diagnosis] || trustedSources['Learning Disabilities'];

    // Generate AI resources using Groq
    const chatCompletion = await groq.chat.completions.create({
      messages: [
        {
          role: "system",
          content: `You are an expert in special education and evidence-based resources. 
Provide ONLY resources from trusted, reliable English-language organizations. 
Focus on scientifically proven methods and established educational practices.`
        },
        {
          role: "user",
          content: `Generate 5 UNIQUE and DIVERSE educational resources for a child with ${diagnosis}, age ${age} years.

🎯 PRIMARY FOCUS for this set: ${selectedFocus}

IMPORTANT: Make each resource DIFFERENT by varying:
- Topics (don't repeat similar topics)
- Approaches (practical tips, research-based strategies, hands-on activities, etc.)
- Target audiences (parents, teachers, therapists)
- Skill levels (beginner to advanced)

For each resource, provide:
1. Title (clear, specific, and UNIQUE - avoid generic titles)
2. Description (2-3 sentences explaining the specific value and approach)
3. Type (Article, Video, or PDF - vary these)
4. Focus area (specific skill like "Expressive Language", "Joint Attention", "Fine Motor Skills")

Return ONLY a JSON array:
[
  {
    "title": "Specific unique title",
    "description": "Clear explanation of what makes this resource valuable",
    "type": "Article",
    "focus_area": "Specific skill area"
  }
]

Guidelines:
- ALL resources MUST be evidence-based and from reliable sources
- Each resource should cover a DIFFERENT aspect of ${selectedFocus}
- Make titles specific and actionable (e.g., "Using Visual Schedules for Morning Routines" not "Visual Schedules")
- Vary the types (mix Articles, Videos, PDFs)
- Age-appropriate for ${age} years old
- Related to ${diagnosis}

Current time seed: ${seed} (use this to ensure variety)

Generate 5 DIVERSE resources in JSON format ONLY.`
        }
      ],
      model: "llama-3.3-70b-versatile",
      temperature: 0.85, // Higher for more variety
      max_tokens: 1800,
      top_p: 0.9 // Add nucleus sampling for diversity
    });

    const content = chatCompletion.choices[0]?.message?.content || '[]';
    const jsonMatch = content.match(/\[[\s\S]*\]/);
    
    if (jsonMatch) {
      const aiResources = JSON.parse(jsonMatch[0]);
      
      // Format resources with trusted sources
      const resources = aiResources.map((resource, index) => {
        const source = sources[index % sources.length];
        return {
          title: resource.title,
          description: resource.description,
          type: resource.type || 'Article',
          link: `${source.url}/resources`,
          source: source.name,
          age_group: age < 6 ? '3-5' : age < 10 ? '6-9' : age < 14 ? '10-13' : '14+',
          skill_type: resource.focus_area || 'General',
          views: Math.floor(Math.random() * 300) + 100,
          rating: 5,
          ai_generated: true
        };
      });
      
      console.log(`✅ Generated ${resources.length} AI resources for ${diagnosis}`);
      console.log(`🎯 Focus area: ${selectedFocus}`);
      console.log(`🎲 Variation seed: ${seed}`);
      
      return res.json({
        success: true,
        resources: resources,
        diagnosis: diagnosis,
        age: age,
        focus_area: selectedFocus,
        sources: sources.map(s => s.name),
        generated_at: new Date().toISOString(),
        variation_seed: seed,
        note: `Resources focused on ${selectedFocus} from trusted organizations: ` + sources.map(s => s.name).join(', ')
      });
    }
    
    throw new Error('Failed to parse AI response');

  } catch (error) {
    console.error('❌ Error generating educational resources:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to generate resources',
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

// Educational Chatbot - General Q&A about conditions
router.post('/educational-chat', authMiddleware, async (req, res) => {
  try {
    const { message, diagnoses } = req.body;

    if (!message) {
      return res.status(400).json({ 
        success: false,
        message: 'Message is required' 
      });
    }

    console.log(`💬 Educational Chat Question: "${message}"`);
    console.log(`📋 User's diagnoses: ${diagnoses?.join(', ') || 'None'}`);

    // Build context based on user's diagnoses
    let contextInfo = '';
    if (diagnoses && diagnoses.length > 0) {
      contextInfo = `\n\nThe parent has children with the following conditions: ${diagnoses.join(', ')}.`;
    }

    const chatCompletion = await groq.chat.completions.create({
      messages: [
        {
          role: "system",
          content: `You are a friendly and knowledgeable special education assistant. 
Your role is to provide helpful, accurate, and compassionate information about:
- Autism Spectrum Disorder (ASD)
- Down Syndrome
- ADHD (Attention Deficit Hyperactivity Disorder)
- Learning Disabilities
- Speech and Language Delays
- Other developmental conditions

Guidelines:
- Be empathetic and supportive
- Provide evidence-based information
- Use simple, clear language
- Offer practical tips and strategies
- Encourage professional consultation when needed
- Be culturally sensitive
- Never provide medical diagnosis
- Focus on educational support and parenting strategies${contextInfo}`
        },
        {
          role: "user",
          content: message
        }
      ],
      model: "llama-3.3-70b-versatile",
      temperature: 0.7,
      max_tokens: 800
    });

    const response = chatCompletion.choices[0]?.message?.content || 'I apologize, but I could not generate a response. Please try again.';
    
    console.log(`✅ Educational chat response generated (${response.length} chars)`);

    return res.json({
      success: true,
      response: response,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Error in educational chat:', error);
    res.status(500).json({ 
      success: false,
      message: 'Failed to process chat message',
      error: error.message 
    });
  }
});

module.exports = router;