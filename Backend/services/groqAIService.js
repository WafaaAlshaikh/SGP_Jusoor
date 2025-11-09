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
}

module.exports = GroqAIService;
