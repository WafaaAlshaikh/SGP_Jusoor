const GroqAIService = require('./groqAIService');
const AIAnalysisService = require('./aiAnalysisService');
const { Op } = require('sequelize');

class ActivityAnalysisService {
  
 
static async analyzeForActivities(childId, documentText, childInfo = {}) {
  try {
    console.log('🎮 بدء تحليل الأنشطة للطفل:', childId);
    
    const conditionAnalysis = await this.analyzeChildCondition(documentText);
    
    // 2. ثانياً: توليد الأنشطة بناءً على التحليل
    const activities = await this.generateActivities(
      conditionAnalysis, 
      childInfo
    );
    
    // 3. ثالثاً: إضافة أنشطة اقتراحية إضافية (مرة واحدة فقط)
    let additionalActivities = [];
    
    // ✅ استخدم primary_condition من conditionAnalysis مباشرة
    if (conditionAnalysis.primary_condition) {
      const conditionName = conditionAnalysis.primary_condition.name_en || 
                           conditionAnalysis.primary_condition.name;
      
      console.log(`🔍 Looking for additional suggestions for: ${conditionName}`);
      
      // استدعاء مرة واحدة فقط
      additionalActivities = await this.getAdditionalSuggestions(conditionName);
      console.log(`✅ Found ${additionalActivities.length} additional activities`);
    }
    
    const allActivities = [...activities, ...additionalActivities];
    
    console.log(`✅ تم توليد ${allActivities.length} نشاط مخصص`);
    
    return {
      success: true,
      child_condition: conditionAnalysis,
      activities: allActivities,
      total_activities: allActivities.length,
      analysis_timestamp: new Date()
    };
    
  } catch (error) {
    console.error('❌ خطأ في تحليل الأنشطة:', error);
    return {
      success: false,
      error: error.message,
      activities: this.getFallbackActivities(childInfo),
      child_condition: this.getBasicConditionAnalysis()
    };
  }
}
  
  /**
   * تحليل حالة الطفل من نص المستند
   */
  // في ActivityAnalysisService.js - إصلاح دالة analyzeChildCondition

static async analyzeChildCondition(documentText) {
  try {
    console.log('🔍 Analyzing child condition from document...');
    
    // استخدام GROQ AI للتحليل
    const prompt = this.buildConditionAnalysisPrompt(documentText);
    
    const GroqAIService = require('./groqAIService');
    const response = await GroqAIService.analyzeSymptoms(prompt, '', '');
    
    console.log('📊 AI analysis response received');
    
    if (response && response.suggested_conditions) {
      console.log(`   Found ${response.suggested_conditions.length} conditions`);
      return this.parseConditionAnalysis(response);
    }
    
    // Fallback إذا فشل الـ AI
    console.log('⚠️ AI analysis failed, using fallback');
    return this.getBasicConditionAnalysis(documentText);
    
  } catch (error) {
    console.error('❌ خطأ في تحليل الحالة:', error);
    return this.getBasicConditionAnalysis(documentText);
  }
}
  
  /**
   * بناء برومبت التحليل (عربي/إنجليزي)
   */
  static buildConditionAnalysisPrompt(documentText) {
    const limitedText = documentText.substring(0, 3000);
    
    return `
أنت أخصائي علاج وظيفي وتنمية مهارات للأطفال ذوي الاحتياجات الخاصة.
Please analyze the following medical/assessment document and provide structured analysis:

**Document Text:**
${limitedText}

**Instructions (English/Arabic):**
1. Identify the primary condition/disability (ASD, ADHD, Down Syndrome, etc.)
2. List key challenges mentioned (motor, social, cognitive, communication)
3. Note the child's age if mentioned
4. Identify strengths and interests if mentioned
5. Assess severity level (mild, moderate, severe)

**Required Output Format (JSON only):**
{
  "primary_condition": {
    "name_ar": "اسم الحالة بالعربية",
    "name_en": "Condition name in English",
    "confidence": 0.85
  },
  "key_challenges": {
    "motor_skills": ["تحدي 1", "تحدي 2"],
    "social_skills": ["challenge 1", "challenge 2"],
    "cognitive_skills": [],
    "communication_skills": []
  },
  "child_age": 5,
  "strengths": ["قوة 1", "strength 2"],
  "severity_level": "moderate",
  "recommended_focus_areas": ["منطقة تركيز 1", "focus area 2"]
}

Provide only valid JSON, no additional text.`;
  }
  
  /**
   * توليد الأنشطة بناءً على تحليل الحالة
   */
  // In ActivityAnalysisService.js - update the generateActivities method

// في ActivityAnalysisService.js - تحديث دالة generateActivities

static async generateActivities(conditionAnalysis, childInfo) {
  try {
    const prompt = this.buildActivityGenerationPrompt(conditionAnalysis, childInfo);
    console.log('📤 Sending activity generation prompt to AI...');
    
    const GroqAIService = require('./groqAIService');
    
    // استخدام الدالة الجديدة
    const aiResponse = await GroqAIService.generateActivities(prompt);
    
    console.log('📄 AI Response length:', aiResponse.length);
    console.log('📄 First 500 chars:', aiResponse.substring(0, 500));
    
    // محاولة تحليل JSON
    let activities = [];
    
    try {
      const parsed = JSON.parse(aiResponse);
      
      // تحقق من الأشكال المختلفة للرد
      if (Array.isArray(parsed)) {
        activities = parsed;
      } else if (parsed.activities && Array.isArray(parsed.activities)) {
        activities = parsed.activities;
      } else if (parsed.data && Array.isArray(parsed.data)) {
        activities = parsed.data;
      } else if (parsed.recommendations && Array.isArray(parsed.recommendations)) {
        activities = parsed.recommendations;
      } else {
        // البحث عن أي array في الـ object
        for (const key in parsed) {
          if (Array.isArray(parsed[key])) {
            activities = parsed[key];
            break;
          }
        }
      }
      
      console.log(`✅ Found ${activities.length} activities in AI response`);
      
    } catch (parseError) {
      console.error('❌ Failed to parse JSON:', parseError.message);
      
      // بديل: استخدام الأنشطة الافتراضية
      return this.getFallbackActivities(childInfo);
    }

    // التحقق من صحة الأنشطة
    const validActivities = activities.filter(activity => {
      if (!activity || typeof activity !== 'object') return false;
      
      // يجب أن يحتوي على عنوان على الأقل
      const hasTitle = activity.title_ar || activity.title_en;
      const hasType = activity.activity_type;
      
      return hasTitle && hasType;
    });
    
    if (validActivities.length === 0) {
      console.log('⚠️ No valid activities found, using fallback');
      return this.getFallbackActivities(childInfo);
    }

    console.log(`✅ Returning ${validActivities.length} valid activities`);
    
    // إضافة أنشطة إضافية
    const additionalActivities = await this.getAdditionalSuggestions(
      conditionAnalysis.primary_condition
    );
    
    return [...validActivities, ...additionalActivities];

  } catch (error) {
    console.error('❌ Error generating activities:', error);
    return this.getFallbackActivities(childInfo);
  }
}

// ✅ تحديث بناء البرومبت ليكون أكثر وضوحاً
static buildActivityGenerationPrompt(conditionAnalysis, childInfo) {
  const age = childInfo.age || conditionAnalysis.child_age || 4;
  const condition = conditionAnalysis.primary_condition?.name_en || 'developmental delay';
  const conditionAr = conditionAnalysis.primary_condition?.name_ar || 'تأخر نمائي';
  
  // جعل البرومبت أكثر صرامة
  return `Generate EXACTLY 5 activity recommendations for a child. Return ONLY JSON.

**Child Information:**
- Age: ${age} years
- Condition: ${condition} (${conditionAr})

**Requirements:**
- Activities must be suitable for age ${age}
- Each activity 5-15 minutes
- Use simple household materials
- Beginner difficulty

**Activity Types to use (choose from these):**
1. motor_skills
2. social_skills  
3. cognitive_skills
4. communication_skills
5. sensory_activities

**Format for EACH activity:**
{
  "activity_type": "motor_skills",
  "title_ar": "عنوان عربي واضح",
  "title_en": "Clear English title",
  "description_ar": "وصف عربي مفصل للنشاط",
  "description_en": "Detailed English description",
  "materials_ar": "قائمة المواد بالعربية",
  "materials_en": "List of materials in English",
  "duration_minutes": 10,
  "difficulty_level": "beginner",
  "target_skills_ar": "المهارات المستهدفة",
  "target_skills_en": "Target skills"
}

**IMPORTANT:**
- Return ONLY the JSON array with 5 activities
- No explanations, no extra text
- Valid JSON only

Example of correct response:
[
  { "activity_type": "motor_skills", "title_ar": "...", ... },
  { "activity_type": "social_skills", "title_ar": "...", ... }
]`;
}
  
  /**
   * تحليل استجابة الأنشطة من AI
   */
  static parseActivityResponse(aiResponse) {
    try {
      // البحث عن JSON في النص
      const jsonMatch = aiResponse.recommendations?.match(/\{[\s\S]*\}/) || 
                       aiResponse.suggested_conditions?.find(sc => sc.reasoning?.includes('{'));
      
      let activities = [];
      
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0] || jsonMatch);
        activities = parsed.activities || [];
      }
      
      // إذا لم توجد أنشطة، نعيد الأنشطة الافتراضية
      if (activities.length === 0) {
        return this.getFallbackActivities();
      }
      
      return activities.slice(0, 10); // حد أقصى 10 أنشطة
      
    } catch (error) {
      console.error('❌ خطأ في تحليل استجابة الأنشطة:', error);
      return this.getFallbackActivities();
    }
  }
  
  /**
   * أنشطة افتراضية (Fallback)
   */
  static getFallbackActivities(childInfo = {}) {
    const age = childInfo.age || 4;
    
    return [
      {
        activity_type: "motor_skills",
        title_ar: "لعبة تركيب الخرز",
        title_en: "Bead Threading Game",
        description_ar: `ساعد طفلك على تركيب خرز كبير في خيط. هذا النشاط ممتع ويعزز التنسيق بين العين واليد والمهارات الحركية الدقيقة المناسبة لعمر ${age} سنوات.`,
        description_en: `Help your child thread large beads onto a string. This fun activity enhances hand-eye coordination and fine motor skills suitable for age ${age}.`,
        materials_ar: "خرز كبير ملون، خيط قوي، مقص",
        materials_en: "Large colored beads, strong string, scissors",
        duration_minutes: 10,
        difficulty_level: "beginner",
        target_skills_ar: "التنسيق بين العين واليد، المهارات الحركية الدقيقة، التعرف على الألوان",
        target_skills_en: "Hand-eye coordination, fine motor skills, color recognition",
        tips_ar: "ابدأ بخرز كبير جداً ثم قلل الحجم تدريجياً. كافئ المحاولات الناجحة.",
        tips_en: "Start with very large beads, then gradually reduce size. Reward successful attempts."
      },
      {
        activity_type: "social_skills",
        title_ar: "لعبة التناوب بالكرة",
        title_en: "Ball Turn-Taking Game",
        description_ar: "اجلس مع طفلك على الأرض ومرر كرة ناعمة بينكما. قل 'دوري' ثم 'دورك' لتعلم مفهوم التناوب.",
        description_en: "Sit on the floor with your child and pass a soft ball back and forth. Say 'my turn' then 'your turn' to teach turn-taking concept.",
        materials_ar: "كرة ناعمة أو وسادة صغيرة",
        materials_en: "Soft ball or small pillow",
        duration_minutes: 8,
        difficulty_level: "beginner",
        target_skills_ar: "مهارات التناوب، الانتباه المشترك، التفاعل الاجتماعي",
        target_skills_en: "Turn-taking skills, joint attention, social interaction",
        tips_ar: "استخدم مؤقت مرئي إذا لزم الأمر. حافظ على الجلسات قصيرة وممتعة.",
        tips_en: "Use visual timer if needed. Keep sessions short and fun."
      }
    ];
  }
  
  /**
   * أنشطة إضافية بناءً على الحالة
   */
  // في ActivityAnalysisService.js - إصلاح دالة getAdditionalSuggestions

static async getAdditionalSuggestions(condition) {
  console.log(`🔍 Looking for additional suggestions for: ${condition}`);
  
  // إذا كان condition كائن، استخرج الاسم منه
  let conditionName = '';
  
  if (typeof condition === 'object') {
    conditionName = condition.name_en || condition.name || condition;
    console.log(`   Extracted condition name: ${conditionName}`);
  } else {
    conditionName = condition;
  }
  
  const conditionMap = {
    'ASD': 'getASDActivities',
    'Autism Spectrum Disorder': 'getASDActivities',
    'ADHD': 'getADHDActivities',
    'Attention Deficit Hyperactivity Disorder': 'getADHDActivities',
    'Down Syndrome': 'getDownSyndromeActivities',
    'Down syndrome': 'getDownSyndromeActivities',
    'Speech Delay': 'getSpeechDelayActivities',
    'Speech & Language Disorder': 'getSpeechDelayActivities',
    'Expressive Language Disorder': 'getSpeechDelayActivities',
    'Language Disorder': 'getSpeechDelayActivities'
  };
  
  console.log(`   Looking for function: ${conditionMap[conditionName] || 'general'}`);
  
  // تحقق مما إذا كان هناك دالة محددة
  if (conditionMap[conditionName] && this[conditionMap[conditionName]]) {
    try {
      console.log(`   Calling ${conditionMap[conditionName]} function`);
      return this[conditionMap[conditionName]]();
    } catch (error) {
      console.error(`❌ Error in ${conditionMap[conditionName]}:`, error);
      return this.getGeneralActivities();
    }
  } else {
    console.log(`ℹ️ No specific function for ${conditionName}, using general activities`);
    return this.getGeneralActivities();
  }
}

// ✅ تأكد من وجود جميع الدوال
static getASDActivities() {
  console.log('   Returning ASD-specific activities');
  return [
    {
      activity_type: "sensory_activities",
      title_ar: "صندوق الأحاسيس",
      title_en: "Sensory Exploration Box",
      description_ar: "جهز صندوقاً يحتوي على مواد ذات قوام مختلفة (قطن، رمل، معجون، أزرار). دع الطفل يستكشف بالقدر الذي يريحه.",
      description_en: "Prepare a box with different textured materials (cotton, sand, paste, buttons). Let child explore at their comfort level.",
      materials_ar: "صندوق، مواد متنوعة القوام، أدوات للاستكشاف",
      materials_en: "Box, various textured materials, exploration tools",
      duration_minutes: 15,
      difficulty_level: "beginner",
      target_skills_ar: "التكامل الحسي، التحفيز الحسي، الاستكشاف",
      target_skills_en: "Sensory integration, sensory stimulation, exploration"
    },
    {
      activity_type: "social_skills",
      title_ar: "محادثة بالصور",
      title_en: "Picture Conversation",
      description_ar: "استخدم صوراً لأشخاص يعبرون عن مشاعر مختلفة. اطلب من الطفل أن يصف ما يشعر به الشخص في الصورة.",
      description_en: "Use pictures of people expressing different emotions. Ask child to describe what the person in the picture is feeling.",
      materials_ar: "صور تعابير وجه، بطاقات عاطفية",
      materials_en: "Facial expression pictures, emotion cards",
      duration_minutes: 10,
      difficulty_level: "beginner",
      target_skills_ar: "التعرف على المشاعر، مهارات المحادثة، التواصل غير اللفظي",
      target_skills_en: "Emotion recognition, conversation skills, nonverbal communication"
    }
  ];
}

static getADHDActivities() {
  console.log('   Returning ADHD-specific activities');
  return [
    {
      activity_type: "cognitive_skills",
      title_ar: "مسار العقبات المنزلي",
      title_en: "Home Obstacle Course",
      description_ar: "أنشئ مساراً بسيطاً باستخدام وسائد وأقمشة. يساعد على تنظيم الطاقة وتحسين التركيز.",
      description_en: "Create simple course using pillows and fabrics. Helps regulate energy and improve focus.",
      materials_ar: "وسائد، بطانيات، أقمشة، مخاريط ورقية",
      materials_en: "Pillows, blankets, fabrics, paper cones",
      duration_minutes: 12,
      difficulty_level: "intermediate",
      target_skills_ar: "تنظيم الطاقة، التحكم في الحركة، التركيز",
      target_skills_en: "Energy regulation, motor control, focus"
    }
  ];
}

static getDownSyndromeActivities() {
  console.log('   Returning Down Syndrome activities');
  return [
    {
      activity_type: "motor_skills",
      title_ar: "تمارين تقوية العضلات",
      title_en: "Muscle Strengthening Exercises",
      description_ar: "تمارين بسيطة لتقوية العضلات باستخدام كرات ناعمة ووسائد.",
      description_en: "Simple exercises to strengthen muscles using soft balls and pillows.",
      materials_ar: "كرات ناعمة، وسائد، بساط تمرين",
      materials_en: "Soft balls, pillows, exercise mat",
      duration_minutes: 15,
      difficulty_level: "beginner",
      target_skills_ar: "تقوية العضلات، التوازن، التنسيق",
      target_skills_en: "Muscle strengthening, balance, coordination"
    }
  ];
}

static getSpeechDelayActivities() {
  console.log('   Returning Speech Delay activities');
  return [
    {
      activity_type: "communication_skills",
      title_ar: "لعبة الكلمات البسيطة",
      title_en: "Simple Words Game",
      description_ar: "تقطيع الكلمات إلى مقاطع وتكرارها مع الطفل.",
      description_en: "Break words into syllables and repeat them with the child.",
      materials_ar: "صور توضيحية، بطاقات كلمات",
      materials_en: "Illustrative pictures, word cards",
      duration_minutes: 10,
      difficulty_level: "beginner",
      target_skills_ar: "النطق، التعبير اللغوي، الذاكرة السمعية",
      target_skills_en: "Pronunciation, language expression, auditory memory"
    }
  ];
}

static getGeneralActivities() {
  console.log('   Returning general activities');
  return [
    {
      activity_type: "daily_living_skills",
      title_ar: "ترتيب الألعاب",
      title_en: "Toy Organization",
      description_ar: "ساعد طفلك على ترتيب ألعابه حسب اللون أو النوع. يعزز مهارات التنظيم والتصنيف.",
      description_en: "Help your child organize toys by color or type. Enhances organization and categorization skills.",
      materials_ar: "ألعاب مختلفة، صناديق أو سلال",
      materials_en: "Various toys, boxes or baskets",
      duration_minutes: 10,
      difficulty_level: "beginner",
      target_skills_ar: "مهارات التنظيم، التصنيف، المسؤولية",
      target_skills_en: "Organization skills, categorization, responsibility"
    }
  ];
}
  
  /**
   * معالجة تحليل الحالة
   */
  static parseConditionAnalysis(aiResponse) {
  try {
    console.log('📝 Parsing condition analysis...');
    
    let analysis = {
      primary_condition: { 
        name_ar: 'غير محدد', 
        name_en: 'Undetermined', 
        confidence: 0 
      },
      key_challenges: { 
        motor_skills: [], 
        social_skills: [], 
        cognitive_skills: [], 
        communication_skills: [] 
      },
      child_age: 4,
      strengths: [],
      severity_level: 'mild',
      recommended_focus_areas: []
    };
    
    // استخراج المعلومات من الاستجابة
    const suggestions = aiResponse.suggested_conditions || [];
    
    if (suggestions.length > 0) {
      const topCondition = suggestions[0];
      
      analysis.primary_condition = {
        name_ar: topCondition.arabic_name || this.getArabicName(topCondition.name) || 'اضطراب نمائي',
        name_en: topCondition.english_name || topCondition.name || 'Developmental Disorder',
        confidence: topCondition.confidence || 0.5
      };
      
      console.log(`   Primary condition: ${analysis.primary_condition.name_en} (${analysis.primary_condition.confidence})`);
      
      // استخراج التحديات
      if (topCondition.matching_keywords) {
        analysis.key_challenges = this.categorizeChallenges(topCondition.matching_keywords);
        console.log(`   Key challenges: ${Object.keys(analysis.key_challenges).filter(k => analysis.key_challenges[k].length > 0).join(', ')}`);
      }
    }
    
    // إضافة معلومات إضافية من الـ response
    if (aiResponse.risk_level) {
      analysis.severity_level = aiResponse.risk_level.toLowerCase();
    }
    
    if (aiResponse.analyzed_keywords) {
      analysis.recommended_focus_areas = aiResponse.analyzed_keywords.slice(0, 5);
    }
    
    console.log('✅ Condition analysis parsed successfully');
    return analysis;
    
  } catch (error) {
    console.error('❌ خطأ في معالجة تحليل الحالة:', error);
    return this.getBasicConditionAnalysis();
  }
}

// دالة مساعدة للحصول على الاسم العربي
static getArabicName(englishName) {
  const arabicNames = {
    'ASD': 'اضطراب طيف التوحد',
    'Autism Spectrum Disorder': 'اضطراب طيف التوحد',
    'ADHD': 'اضطراب فرط الحركة ونقص الانتباه',
    'Attention Deficit Hyperactivity Disorder': 'اضطراب فرط الحركة ونقص الانتباه',
    'Down Syndrome': 'متلازمة داون',
    'Speech & Language Disorder': 'اضطراب النطق واللغة',
    'Speech and Language Disorders': 'اضطراب النطق واللغة',
    'Expressive Language Disorder': 'اضطراب اللغة التعبيرية',
    'Language Disorder': 'اضطراب اللغة'
  };
  
  return arabicNames[englishName] || englishName;
}
  
  static categorizeChallenges(keywords) {
    const challenges = {
      motor_skills: [],
      social_skills: [],
      cognitive_skills: [],
      communication_skills: []
    };
    
    const motorKeywords = ['حركي', 'motor', 'walking', 'running', 'coordination', 'يدوي'];
    const socialKeywords = ['اجتماعي', 'social', 'interaction', 'eye contact', 'play', 'تواصل'];
    const cognitiveKeywords = ['إدراكي', 'cognitive', 'attention', 'focus', 'thinking', 'ذاكرة'];
    const communicationKeywords = ['تواصل', 'communication', 'speech', 'language', 'كلام', 'تعبير'];
    
    keywords.forEach(keyword => {
      const kw = keyword.toLowerCase();
      if (motorKeywords.some(mk => kw.includes(mk))) challenges.motor_skills.push(keyword);
      if (socialKeywords.some(sk => kw.includes(sk))) challenges.social_skills.push(keyword);
      if (cognitiveKeywords.some(ck => kw.includes(ck))) challenges.cognitive_skills.push(keyword);
      if (communicationKeywords.some(ck => kw.includes(ck))) challenges.communication_skills.push(keyword);
    });
    
    return challenges;
  }
  
  static getBasicConditionAnalysis() {
    return {
      primary_condition: { name_ar: 'تأخر نمائي', name_en: 'Developmental Delay', confidence: 0.3 },
      key_challenges: { motor_skills: [], social_skills: [], cognitive_skills: [], communication_skills: [] },
      child_age: 4,
      strengths: ['فضولي', 'يحب اللعب'],
      severity_level: 'mild',
      recommended_focus_areas: ['المهارات الأساسية', 'التفاعل الاجتماعي']
    };
  }
}

module.exports = ActivityAnalysisService;