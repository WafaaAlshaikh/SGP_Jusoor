// Quick test script to verify Groq AI
require('dotenv').config();
const axios = require('axios');

async function testGroqAI() {
  console.log('🔍 Testing Groq AI connection...');
  console.log('🔑 API Key:', process.env.GROQ_API_KEY ? 'Found ✅' : 'Missing ❌');
  
  try {
    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: 'llama-3.3-70b-versatile',
        messages: [
          {
            role: 'user',
            content: 'Generate ONE educational resource title for autism. Reply with just the title, nothing else.'
          }
        ],
        max_tokens: 50
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.GROQ_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );
    
    console.log('✅ Groq AI is WORKING!');
    console.log('📤 Model:', response.data.model);
    console.log('💬 Response:', response.data.choices[0].message.content);
    console.log('✨ AI-powered educational resources endpoint is ready!');
    
  } catch (error) {
    console.error('❌ Groq AI connection FAILED:');
    console.error('Error:', error.response?.data || error.message);
  }
}

testGroqAI();
