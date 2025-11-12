// Test educational resources endpoint
require('dotenv').config();
const axios = require('axios');

async function testEducationalResources() {
  console.log('🧪 Testing Educational Resources Endpoint...\n');
  
  // You need to replace this with a real JWT token from your app
  // Get it from: SharedPreferences or login response
  const token = 'YOUR_JWT_TOKEN_HERE';
  
  try {
    const response = await axios.post(
      'http://localhost:5000/api/ai/educational-resources',
      {
        diagnosis: 'Autism Spectrum Disorder',
        age: 7
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        }
      }
    );
    
    console.log('✅ Educational Resources Generated Successfully!\n');
    console.log('📚 Total Resources:', response.data.resources.length);
    console.log('🏥 Diagnosis:', response.data.diagnosis);
    console.log('👶 Age:', response.data.age);
    console.log('🔗 Trusted Sources:', response.data.sources.join(', '));
    console.log('\n📖 Sample Resources:\n');
    
    response.data.resources.slice(0, 3).forEach((resource, index) => {
      console.log(`${index + 1}. ${resource.title}`);
      console.log(`   Source: ${resource.source}`);
      console.log(`   Type: ${resource.type}`);
      console.log(`   Link: ${resource.link}`);
      console.log(`   AI Generated: ${resource.ai_generated ? '✅ Yes' : '❌ No'}`);
      console.log('');
    });
    
  } catch (error) {
    if (error.response?.status === 401) {
      console.error('❌ Authentication required!');
      console.log('\n📝 To test this endpoint:');
      console.log('1. Login to the app');
      console.log('2. Get your JWT token from SharedPreferences');
      console.log('3. Replace YOUR_JWT_TOKEN_HERE in this script');
      console.log('4. Run: node test-educational-resources.js');
    } else {
      console.error('❌ Error:', error.response?.data || error.message);
    }
  }
}

console.log('🔑 Groq API Key:', process.env.GROQ_API_KEY ? 'Found ✅' : 'Missing ❌');
console.log('');

testEducationalResources();
