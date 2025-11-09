const axios = require('axios');

class GroqService {
  constructor() {
    this.apiKey = process.env.GROQ_API_KEY;
    this.baseURL = 'https://api.groq.com/openai/v1';
    
    // ✅ النماذج الجديدة المؤكدة (بدون النماذج القديمة)
    this.availableModels = [
      'llama-3.2-3b-preview',      // ✅ جديد وسريع
      'llama-3.2-1b-preview',      // ✅ سريع جداً
      'llama-3.2-90b-vision-preview', // ✅ قوي جداً
      'llama-3.2-11b-vision-preview', // ✅ متوازن
      'llama-3.1-8b-instant',      // ✅ سريع ومستقر
      'llama-3.1-70b-versatile',   // ⚠️ ممكن يكون متوقف
      'mixtral-8x7b-32768',        // ✅ بديل ممتاز
      'gemma2-9b-it'               // ✅ جديد
    ];
    
    this.model = 'llama-3.1-8b-instant'; // ⬅️ استخدم هذا النموذج المؤكد
  }

  async generateDailyTip(childrenConditions) {
    try {
      console.log('🔑 Checking API key...');
      
      if (!this.apiKey) {
        throw new Error('GROQ_API_KEY is missing in environment variables');
      }

      if (!this.apiKey.startsWith('gsk_')) {
        throw new Error('GROQ_API_KEY format is invalid');
      }

      const prompt = this._buildPrompt(childrenConditions);
      console.log(`📤 Using model: ${this.model}`);
      
      const requestBody = {
        model: this.model,
        messages: [
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 150
      };

      console.log('📤 Sending request to Groq API...');
      const response = await axios.post(
        `${this.baseURL}/chat/completions`,
        requestBody,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          },
          timeout: 15000
        }
      );

      console.log('✅ Groq API response status:', response.status);
      
      if (response.data?.choices?.[0]?.message?.content) {
        const tip = this._cleanResponse(response.data.choices[0].message.content);
        console.log('🤖 AI Tip generated successfully');
        
        return {
          success: true,
          tip: tip,
          conditions: childrenConditions,
          model: this.model,
          provider: 'Groq'
        };
      }

      throw new Error('No content in response');

    } catch (error) {
      console.error('❌ Groq API Error:');
      console.error(' - Message:', error.message);
      
      if (error.response?.data?.error) {
        console.error(' - API Error:', error.response.data.error.message);
      }
      
      // إذا كان النموذج متوقف، جرب نماذج بديلة
      if (error.response?.status === 400 || error.message.includes('decommissioned')) {
        console.log('🔄 Model deprecated, trying alternatives...');
        return await this._tryAlternativeModels(childrenConditions);
      }
      
      return {
        success: false,
        tip: this._getFallbackTip(childrenConditions),
        error: error.message,
        provider: 'Fallback'
      };
    }
  }

  /**
   * جرب نماذج بديلة
   */
  async _tryAlternativeModels(childrenConditions) {
    console.log('🔄 Trying alternative models...');
    
    // النماذج البديلة المؤكدة
    const alternativeModels = [
      'llama-3.1-8b-instant',
      'mixtral-8x7b-32768', 
      'llama-3.2-3b-preview',
      'gemma2-9b-it'
    ];
    
    for (const model of alternativeModels) {
      console.log(`🔄 Trying model: ${model}`);
      
      try {
        const prompt = this._buildPrompt(childrenConditions);
        
        const response = await axios.post(
          `${this.baseURL}/chat/completions`,
          {
            model: model,
            messages: [{ role: "user", content: prompt }],
            max_tokens: 150,
            temperature: 0.7
          },
          {
            headers: {
              'Authorization': `Bearer ${this.apiKey}`,
              'Content-Type': 'application/json'
            },
            timeout: 10000
          }
        );

        if (response.data?.choices?.[0]?.message?.content) {
          const tip = this._cleanResponse(response.data.choices[0].message.content);
          console.log(`✅ Success with model: ${model}`);
          
          // تحديث النموذج الناجح
          this.model = model;
          
          return {
            success: true,
            tip: tip,
            conditions: childrenConditions,
            model: this.model,
            provider: 'Groq'
          };
        }
      } catch (error) {
        console.log(`❌ Model ${model} failed:`, error.response?.data?.error?.message || error.message);
        // استمر في المحاولة مع النموذج التالي
      }
    }

    console.error('❌ All models failed, using fallback');
    return {
      success: false,
      tip: this._getFallbackTip(childrenConditions),
      error: 'All models failed',
      provider: 'Fallback'
    };
  }

  _buildPrompt(conditions) {
    const conditionsList = conditions.map(c => c.name).join(', ');
    
    return `Provide one practical daily tip for parents of children with ${conditionsList}. 
    Make it:
    - Specific and actionable (10-20 minutes)
    - Encouraging and supportive  
    - Focused on connection and skill-building
    - Appropriate for the mentioned conditions
    
    Respond with just the tip text, no explanations or introductions.`;
  }

  _cleanResponse(text) {
    return text
      .trim()
      .replace(/^(Tip:|Daily Tip:|Here's a tip:|"|')/gi, '')
      .replace(/("|')$/g, '')
      .trim();
  }

  _getFallbackTip(conditions) {
    const tips = {
      'ASD': 'Spend 15 minutes in a calm, predictable activity with your child today—like drawing or building blocks. Consistent routines build trust and security.',
      'ADHD': 'Try a "movement break"—10 minutes of jumping, dancing, or stretching before homework time. Movement helps focus and self-regulation.',
      'Down Syndrome': 'Use picture cues for one daily routine today (like getting dressed). Visual supports build independence and confidence.',
      'Speech & Language Disorder': 'Read a short story together and ask your child to retell just one part. Playful repetition builds language skills naturally.'
    };

    const firstCondition = conditions[0]?.name;
    return tips[firstCondition] || 
      'Spend 15 minutes of focused play time with your child today. Connection through play builds trust and supports development.';
  }

  async healthCheck() {
    try {
      console.log('🏥 Performing Groq health check...');
      
      const response = await axios.get(
        `${this.baseURL}/models`,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          },
          timeout: 8000
        }
      );

      const models = response.data.data.map(m => m.id);
      console.log('✅ Available models:', models);
      
      return {
        healthy: true,
        provider: 'Groq',
        models: models,
        status: 'operational'
      };

    } catch (error) {
      console.error('❌ Groq health check failed:', error.message);
      
      return {
        healthy: false,
        provider: 'Groq',
        error: error.response?.data?.error?.message || error.message,
        status: 'failed'
      };
    }
  }

  /**
   * دالة لمعرفة النماذج المتاحة حالياً
   */
  async getAvailableModels() {
    try {
      const response = await axios.get(`${this.baseURL}/models`, {
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json'
        }
      });
      
      return response.data.data.map(model => ({
        id: model.id,
        active: model.active,
        created: model.created
      }));
    } catch (error) {
      console.error('Error fetching models:', error.message);
      return [];
    }
  }
}

module.exports = new GroqService();