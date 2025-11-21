// services/aiAnalysisServiceAddEvaluation.js
const Groq = require('groq-sdk');
const { SessionType } = require('../model');

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY 
});

class aiAnalysisServiceAddEvaluation {
  static async analyzeEvaluationNotes(notes, institutionId) {
    try {
      console.log('🔍 Starting AI analysis for institution:', institutionId);
      
      if (!institutionId) {
        console.log('❌ No institutionId provided');
        return [];
      }

      // جلب جميع أسماء أنواع الجلسات من قاعدة البيانات
      const sessionTypes = await SessionType.findAll({
        where: { 
          institution_id: institutionId,
          approval_status: 'Approved'
        },
        attributes: ['name', 'category'],
        raw: true
      });

      if (sessionTypes.length === 0) {
        console.log('❌ No session types found in database for institution:', institutionId);
        return [];
      }

      // استخراج الأسماء فقط
      const sessionTypeNames = sessionTypes.map(st => st.name);

      console.log('✅ Available session types:', sessionTypeNames);

      const prompt = `
You are a medical analysis expert. Analyze the child's evaluation notes and determine which therapy sessions are required.

CHILD'S NOTES:
"${notes}"

AVAILABLE SESSION TYPES:
${sessionTypeNames.map(name => `- ${name}`).join('\n')}

INSTRUCTIONS:
1. Analyze the problems mentioned in the notes
2. Ignore negative phrases like "does not require", "no need for", "but not"
3. Focus only on the actual problems described
4. Return ONLY a valid JSON array of session type names
5. Use only the exact session type names from the list above

EXAMPLES:
- Input: "speech difficulties" → Output: ["Speech Therapy"]
- Input: "attention issues and behavior problems" → Output: ["Behavioral Therapy"]
- Input: "speech delays and attention problems" → Output: ["Speech Therapy", "Behavioral Therapy"]

RETURN ONLY JSON, NO EXPLANATIONS:
`;

      const completion = await groq.chat.completions.create({
        messages: [
          {
            role: "system",
            content: "You are a medical specialist. Return ONLY a valid JSON array. Do not include any explanations, text, or code formatting."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        model: "llama-3.1-8b-instant",
        temperature: 0.1,
        max_tokens: 512,
        stream: false
      });

      const response = completion.choices[0]?.message?.content?.trim();
      console.log('🤖 AI Raw Response:', response);

      try {
        // تنظيف شامل للرد
        const cleanedResponse = this.cleanAIResponse(response);
        console.log('🧹 Cleaned Response:', cleanedResponse);
        
        const sessions = JSON.parse(cleanedResponse);
        
        // التحقق من أن الجلسات المختارة موجودة فعلاً في النظام
        const validSessions = sessions.filter(session => 
          sessionTypeNames.includes(session)
        );
        
        console.log('✅ Valid sessions after filtering:', validSessions);
        return Array.isArray(validSessions) ? validSessions : [];
      } catch (parseError) {
        console.error('❌ Error parsing AI response:', parseError);
        console.log('🔄 Using improved fallback analysis');
        return this.improvedFallbackAnalysis(notes, sessionTypes);
      }
    } catch (error) {
      console.error('❌ AI Analysis error:', error);
      return this.improvedFallbackAnalysis(notes, []);
    }
  }

  // دالة محسنة لتنظيف رد الـ AI
  static cleanAIResponse(response) {
    if (!response) return '[]';
    
    console.log('🔧 Cleaning response:', response);
    
    // إزالة أي نص غير JSON
    let cleaned = response
      .replace(/```json/g, '')
      .replace(/```/g, '')
      .replace(/JSON:/g, '')
      .trim();

    // إصلاح الـ JSON غير الصالح - تحويل {value} إلى "value"
    cleaned = cleaned.replace(/\{([^}]+)\}/g, '"$1"');
    
    // إزالة فواصل زائدة
    cleaned = cleaned.replace(/,(\s*])/g, '$1');
    
    // إذا لم يبدأ بـ [، أضفه
    if (!cleaned.startsWith('[')) {
      const arrayStart = cleaned.indexOf('[');
      const arrayEnd = cleaned.lastIndexOf(']');
      if (arrayStart !== -1 && arrayEnd !== -1) {
        cleaned = cleaned.substring(arrayStart, arrayEnd + 1);
      } else {
        // إذا لم نجد مصفوفة، نرجع مصفوفة فارغة
        cleaned = '[]';
      }
    }

    console.log('🧼 Final cleaned:', cleaned);
    return cleaned || '[]';
  }

  static improvedFallbackAnalysis(notes, sessionTypes) {
    const sessions = [];
    const text = notes.toLowerCase();
    
    console.log('🔄 Using improved fallback analysis for text:', text);
    
    // تجاهل العبارات النافية
    const ignoredPhrases = [
      'does not require', 'no need for', 'but not', 'without', 'excluding',
      'not required', 'not needed', 'no support', 'but does not'
    ];
    
    let analysisText = text;
    ignoredPhrases.forEach(phrase => {
      analysisText = analysisText.replace(phrase, '');
    });
    
    console.log('📝 Text after removing negative phrases:', analysisText);
    
    // إذا ما عندنا بيانات من قاعدة البيانات، نستخدم القيم الافتراضية
    if (sessionTypes.length === 0) {
      if (analysisText.includes('speech') || analysisText.includes('talk') || analysisText.includes('pronunciation') || analysisText.includes('language')) {
        sessions.push('Speech Therapy');
      }
      if (analysisText.includes('behavior') || analysisText.includes('behavioral') || analysisText.includes('attention') || analysisText.includes('adhd') || analysisText.includes('focus')) {
        sessions.push('Behavioral Therapy');
      }
      if (analysisText.includes('occupational') || analysisText.includes('motor') || analysisText.includes('sensory') || analysisText.includes('fine motor')) {
        sessions.push('Occupational Therapy');
      }
      if (analysisText.includes('educational') || analysisText.includes('academic') || analysisText.includes('learning') || analysisText.includes('school')) {
        sessions.push('Educational Therapy');
      }
      if (analysisText.includes('initial') || analysisText.includes('assessment') || analysisText.includes('evaluation') || analysisText.includes('diagnosis')) {
        sessions.push('Initial Assessment');
      }
      console.log('🔧 Improved fallback sessions (no DB):', sessions);
      return sessions;
    }

    // إذا عندنا بيانات من قاعدة البيانات، نستخدمها للتحليل
    const sessionTypeNames = sessionTypes.map(st => st.name.toLowerCase());
    
    sessionTypes.forEach(sessionType => {
      const nameLower = sessionType.name.toLowerCase();
      const categoryLower = sessionType.category.toLowerCase();
      
      // البحث في النص (بعد إزالة العبارات النافية) عن كلمات مفتاحية
      if (
        analysisText.includes(nameLower) ||
        analysisText.includes(categoryLower) ||
        this.checkKeywords(analysisText, sessionType.name)
      ) {
        sessions.push(sessionType.name);
      }
    });

    console.log('🔧 Improved fallback sessions (with DB):', sessions);
    return sessions;
  }

  static checkKeywords(text, sessionName) {
    const keywordMap = {
      'Speech Therapy': ['speech', 'talk', 'language', 'pronunciation', 'communication', 'verbal', 'articulation', 'delayed talking'],
      'Occupational Therapy': ['occupational', 'motor', 'sensory', 'fine motor', 'activities', 'sensory processing', 'motor skills'],
      'Behavioral Therapy': ['behavior', 'behavioral', 'attention', 'focus', 'adhd', 'hyperactivity', 'impulsivity', 'conduct', 'general behavior'],
      'Educational Therapy': ['educational', 'academic', 'learning', 'school', 'study', 'reading', 'writing', 'math'],
      'Initial Assessment': ['assessment', 'evaluation', 'initial', 'diagnosis', 'screening', 'appraisal', 'examination'],
      'Psychological Support': ['psychological', 'mental', 'emotional', 'counseling', 'therapy', 'support']
    };

    const keywords = keywordMap[sessionName] || [];
    return keywords.some(keyword => text.includes(keyword));
  }
}

module.exports = aiAnalysisServiceAddEvaluation;