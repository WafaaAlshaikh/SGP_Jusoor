// services/externalAIService.js - External AI Integration (Google Gemini)
const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config();

class ExternalAIService {
  
  static async analyzeSymptoms(symptomsText, medicalHistory = '', previousServices = '') {
    try {
      console.log('🤖 [EXTERNAL AI] Starting real AI analysis...');
      
      // Check if API key exists
      if (!process.env.GEMINI_API_KEY) {
        console.warn('⚠️ [EXTERNAL AI] No API key found, falling back to local AI');
        return null;
      }

      // Initialize Gemini
      const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash-latest' });

      // Prepare the prompt
      const prompt = this.buildAnalysisPrompt(symptomsText, medicalHistory, previousServices);

      console.log('📤 [EXTERNAL AI] Sending request to Gemini...');
      
      // Call Gemini API
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();

      console.log('📥 [EXTERNAL AI] Received response from Gemini');
      console.log('📄 Raw response:', text);

      // Parse the response
      const analysis = this.parseGeminiResponse(text);

      console.log('✅ [EXTERNAL AI] Analysis complete:', {
        conditions: analysis.suggested_conditions.length,
        risk_level: analysis.risk_level
      });

      return analysis;

    } catch (error) {
      console.error('❌ [EXTERNAL AI] Error:', error.message);
      return null; // Return null to fallback to local AI
    }
  }

  static buildAnalysisPrompt(symptoms, medicalHistory, previousServices) {
    return `You are a pediatric developmental specialist AI assistant. Analyze the following child's symptoms and provide a structured medical assessment.

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

**Required Output Format (JSON):**
\`\`\`json
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
\`\`\`

**Analysis Rules:**
- Only include conditions with confidence > 0.3
- Sort by confidence (highest first)
- Risk level: Low (<0.4), Medium (0.4-0.7), High (>0.7)
- Be specific with keywords
- Consider child development context

Provide ONLY the JSON output, no additional text.`;
  }

  static parseGeminiResponse(text) {
    try {
      // Extract JSON from response
      const jsonMatch = text.match(/```json\n([\s\S]*?)\n```/) || text.match(/\{[\s\S]*\}/);
      
      if (jsonMatch) {
        const jsonText = jsonMatch[1] || jsonMatch[0];
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
          source: 'external_ai',
          model: 'gemini-pro'
        };
      } else {
        console.warn('⚠️ [EXTERNAL AI] Could not parse JSON from response');
        return this.createFallbackResponse();
      }
    } catch (error) {
      console.error('❌ [EXTERNAL AI] Parse error:', error.message);
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
      if (!process.env.GEMINI_API_KEY) {
        return { 
          status: 'disabled', 
          message: 'API key not configured' 
        };
      }

      const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash-latest' });
      
      const result = await model.generateContent('Hello');
      const response = await result.response;
      
      if (response) {
        return { 
          status: 'healthy', 
          message: 'External AI is working',
          model: 'gemini-1.5-flash-latest'
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
}

module.exports = ExternalAIService;
