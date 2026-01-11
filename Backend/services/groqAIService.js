// services/groqAIService.js - GROQ AI Integration
const axios = require('axios');
require('dotenv').config();

class GroqAIService {
  
  static async analyzeSymptoms(symptomsText, medicalHistory = '', previousServices = '') {
    try {
      console.log('🤖 [GROQ AI] Starting real AI analysis...');
      
      // Check if API key exists
      if (!process.env.GROQ_API_KEY) {
        console.warn('⚠️ [GROQ AI] No API key found, falling back to local AI');
        return null;
      }

      // Prepare the prompt
      const prompt = this.buildAnalysisPrompt(symptomsText, medicalHistory, previousServices);

      console.log('📤 [GROQ AI] Sending request to GROQ API...');
      
      // Call GROQ API
      const response = await axios.post(
        'https://api.groq.com/openai/v1/chat/completions',
        {
          model: 'llama-3.1-8b-instant', // Fast and reliable model
          messages: [
            {
              role: 'system',
              content: 'You are a pediatric developmental specialist AI assistant. Analyze symptoms and provide structured medical assessments in JSON format only.'
            },
            {
              role: 'user',
              content: prompt
            }
          ],
          temperature: 0.2,
          max_tokens: 800
        },
        {
          headers: {
            'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
            'Content-Type': 'application/json'
          }
        }
      );

      console.log('📥 [GROQ AI] Received response from GROQ');
      
      const aiResponse = response.data.choices[0].message.content;
      console.log('📄 Raw response:', aiResponse);

      // Parse the response
      const analysis = this.parseGroqResponse(aiResponse);

      console.log('✅ [GROQ AI] Analysis complete:', {
        conditions: analysis.suggested_conditions.length,
        risk_level: analysis.risk_level
      });

      return analysis;

    } catch (error) {
      console.error('❌ [GROQ AI] Error:', error.message);
      if (error.response) {
        console.error('📄 Error details:', error.response.data);
      }
      return null; // Return null to fallback to local AI
    }
  }

  static buildAnalysisPrompt(symptoms, medicalHistory, previousServices) {
    return `Analyze the following child's symptoms and provide a structured medical assessment.

**Child's Symptoms:**
${symptoms}

${medicalHistory ? `**Medical History:**\n${medicalHistory}\n` : ''}
${previousServices ? `**Previous Services:**\n${previousServices}\n` : ''}

**Important Instructions:**
1. Focus ONLY on these conditions: ASD (Autism Spectrum Disorder), ADHD (Attention Deficit Hyperactivity Disorder), Down Syndrome, Speech & Language Disorders
2. Provide confidence scores (0.0 to 1.0) for each condition
3. Identify matching keywords from the symptoms
4. Assess severity level (low, medium, high)
5. Determine overall risk level

**Required Output Format (JSON ONLY - no other text):**
{
  "suggested_conditions": [
    {
      "name": "ASD",
      "english_name": "Autism Spectrum Disorder",
      "confidence": 0.85,
      "matching_keywords": ["eye contact", "repetitive movements", "isolation"],
      "severity_level": "medium",
      "reasoning": "Brief explanation"
    }
  ],
  "risk_level": "Medium",
  "analysis_confidence": 0.85,
  "analyzed_keywords": ["eye contact", "repetitive", "social"],
  "recommendations": "Brief recommendation for parents"
}

**Analysis Rules:**
- Only include conditions with confidence > 0.3
- Sort by confidence (highest first)
- Risk level: Low (<0.4), Medium (0.4-0.7), High (>0.7)
- Be specific with keywords
- Consider child development context

Provide ONLY the JSON output, no additional text.`;
  }

  static parseGroqResponse(text) {
    try {
      // Extract JSON if wrapped in markdown or other text
      let jsonText = text;
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        jsonText = jsonMatch[0];
      }
      
      // Parse JSON response
      const parsed = JSON.parse(jsonText);

      // Validate and format
      return {
        suggested_conditions: (parsed.suggested_conditions || []).map(c => ({
          name: c.name || 'Unknown',
          english_name: c.english_name || c.name,
          arabic_name: this.getArabicName(c.name),
          confidence: parseFloat(c.confidence) || 0,
          matching_keywords: c.matching_keywords || [],
          severity_level: c.severity_level || 'low',
          reasoning: c.reasoning || ''
        })),
        risk_level: parsed.risk_level || 'Low',
        analysis_confidence: parseFloat(parsed.analysis_confidence) || 0,
        analyzed_keywords: parsed.analyzed_keywords || [],
        recommendations: parsed.recommendations || '',
        source: 'groq_ai',
        model: 'llama-3.1-8b-instant'
      };
    } catch (error) {
      console.error('❌ [GROQ AI] Parse error:', error.message);
      return this.createFallbackResponse();
    }
  }

  static getArabicName(englishName) {
    const arabicNames = {
      'ASD': 'اضطراب طيف التوحد',
      'Autism Spectrum Disorder': 'اضطراب طيف التوحد',
      'ADHD': 'اضطراب فرط الحركة ونقص الانتباه',
      'Attention Deficit Hyperactivity Disorder': 'اضطراب فرط الحركة ونقص الانتباه',
      'Down Syndrome': 'متلازمة داون',
      'Speech & Language Disorder': 'اضطراب النطق واللغة',
      'Speech and Language Disorders': 'اضطراب النطق واللغة'
    };
    return arabicNames[englishName] || englishName;
  }

  static createFallbackResponse() {
    return {
      suggested_conditions: [],
      risk_level: 'Low',
      analysis_confidence: 0,
      analyzed_keywords: [],
      recommendations: 'Unable to analyze. Please provide more details.',
      source: 'fallback',
      error: true
    };
  }

  // Health check for API
  static async checkAPIHealth() {
    try {
      if (!process.env.GROQ_API_KEY) {
        return { 
          status: 'disabled', 
          message: 'API key not configured' 
        };
      }

      const response = await axios.post(
        'https://api.groq.com/openai/v1/chat/completions',
        {
          model: 'llama-3.1-8b-instant',
          messages: [{ role: 'user', content: 'Hello' }],
          max_tokens: 10
        },
        {
          headers: {
            'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
            'Content-Type': 'application/json'
          }
        }
      );
      
      if (response.status === 200) {
        return { 
          status: 'healthy', 
          message: 'External AI is working',
          model: 'llama-3.1-8b-instant'
        };
      }
      
      return { 
        status: 'error', 
        message: 'No response from API' 
      };
    } catch (error) {
      return { 
        status: 'error', 
        message: error.message 
      };
    }
  }

  // في groqAIService.js - إضافة دالة خاصة لأنشطة الأطفال

static async generateActivities(prompt) {
  try {
    console.log('🤖 [GROQ AI] Generating activities...');
    
    if (!process.env.GROQ_API_KEY) {
      throw new Error('GROQ_API_KEY is missing');
    }

    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'llama-3.1-8b-instant',
        messages: [
          {
            role: 'system',
            content: 'You are an occupational therapist. Always return valid JSON only. No explanations, no markdown, no extra text.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.2,
        max_tokens: 1500,
        response_format: { type: "json_object" } // ⬅️ هذا مهم!
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 15000
      }
    );

    const aiResponse = response.data.choices[0].message.content;
    console.log('✅ [GROQ AI] Activities generated');
    
    return aiResponse;
    
  } catch (error) {
    console.error('❌ [GROQ AI] Error generating activities:', error.message);
    if (error.response) {
      console.error('📄 Error details:', error.response.data);
    }
    throw error;
  }
}

// services/groqAIService.js

/**
 * تحليل CV باستخدام AI
 */
static async analyzeCV(text) {
  try {
    const prompt = 'You are a CV/resume analyzer specialized in healthcare and special needs education. ' +
      'Extract ONLY employment information from the following CV text.\n\n' +
      'CV Text to analyze:\n' +
      text.substring(0, 3500) + '\n\n' +
      'IMPORTANT: Return ONLY CV analysis, NOT medical analysis.\n\n' +
      'Extract and provide the following information in Arabic and English:\n\n' +
      'Personal Information:\n' +
      '- Full name (الاسم الكامل): Extract the candidate\'s name. It is typically the most prominent text at the top of the document.\n' +
      '- Email address: Actively search for and extract the professional email address.\n' +
      '  1. Search through the entire document text, not just the beginning.\n' +
      '  2. Look for common email patterns such as name@domain.com, first.last@company.org.\n' +
      '  3. Prioritize addresses that appear professional (e.g., based on the person\'s name, like razan.dwekat@email.com).\n' +
      '  4. Check near other contact details like the phone number and physical address.\n' +
      '- Phone number: Look for sequences of 10 or more digits, possibly with country or area codes (e.g., +962, 041).\n' +
      '- Location/City: Often listed alongside or near the contact information.\n\n' +
      'Professional Information:\n' +
      '- Specialization/Field (التخصص)\n' +
      '- Years of experience (سنوات الخبرة)\n' +
      '- Current/previous job title\n' +
      '- Key skills and qualifications\n\n' +
      'Education:\n' +
      '- Highest degree\n' +
      '- University/Institution\n' +
      '- Graduation year\n\n' +
      'Certifications & Licenses (if any)\n' +
      'Languages spoken\n\n' +
      'Return ONLY valid JSON for CV analysis (NOT medical analysis) with the following structure:\n' +
      '{"personal_info": {"full_name_ar": "", "full_name_en": "", "email": "", "phone": "", "location": ""}, ' +
      '"professional_info": {"specialization_ar": "", "specialization_en": "", "years_experience": 0, "current_position": "", "key_skills": []}, ' +
      '"education": {"highest_degree": "", "institution": "", "graduation_year": ""}, ' +
      '"certifications": [], "languages": [], "confidence_score": 0.85}';

    console.log('🤖 [GROQ AI CV] Sending CV text for analysis...');
    console.log('📋 [GROQ AI CV] Text sample:', text.substring(0, 200));
    
    // استخدم نفس دالة chatCompletion لكن مع prompt مختلف
    const response = await this.chatCompletion(prompt);
    
    console.log('✅ [GROQ AI CV] Received response');
    console.log('📝 [GROQ AI CV] Response:', response.substring(0, 500));

    let parsedData;
    
    try {
      // حاول تحليل JSON مباشرة
      parsedData = JSON.parse(response);
      console.log('✅ [GROQ AI CV] Successfully parsed JSON');
    } catch (parseError) {
      console.log('⚠️ [GROQ AI CV] JSON parse error, trying to extract JSON...');
      
      // محاولة استخراج JSON من النص
      const jsonMatch = response.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        try {
          parsedData = JSON.parse(jsonMatch[0]);
          console.log('✅ [GROQ AI CV] Extracted JSON from response');
        } catch (e) {
          console.error('❌ [GROQ AI CV] Could not parse extracted JSON:', e.message);
          parsedData = {
            error: 'Failed to parse AI response',
            raw_response: response.substring(0, 1000)
          };
        }
      } else {
        console.error('❌ [GROQ AI CV] No JSON found in response');
        parsedData = {
          error: 'No valid JSON in AI response',
          raw_response: response.substring(0, 1000)
        };
      }
    }

    console.log('✅ [GROQ AI CV] Analysis complete');
    return parsedData;

  } catch (error) {
    console.error('❌ [GROQ AI CV] Error:', error.message);
    return {
      error: error.message,
      confidence_score: 0,
      source: 'groq_cv_error'
    };
  }
}

// في groqAIService.js
static async chatCompletion(prompt) {
  try {
    const requestBody = {
      messages: [
        {
          role: "system",
          content: "You are a helpful assistant. Return ONLY valid JSON."
        },
        {
          role: "user",
          content: prompt
        }
      ],
      model: "llama-3.1-8b-instant",
      temperature: 0.3,
      max_tokens: 2000,
      top_p: 1,
      stream: false,
      response_format: { type: "json_object" }
    };

    const response = await axios.post(
      "https://api.groq.com/openai/v1/chat/completions",
      requestBody,
      {
        headers: {
          "Authorization": `Bearer ${process.env.GROQ_API_KEY}`,
          "Content-Type": "application/json"
        }
      }
    );

    return response.data.choices[0].message.content;
  } catch (error) {
    console.error('❌ [GROQ AI] Error:', error.response?.data || error.message);
    throw error;
  }
}
}

module.exports = GroqAIService;
