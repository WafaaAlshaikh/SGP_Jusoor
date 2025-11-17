const axios = require('axios');

// Test Educational Chatbot Endpoint
async function testChatbot() {
  try {
    console.log('🧪 Testing Educational Chatbot...\n');

    // IMPORTANT: Replace with a real token from your login
    const token = 'YOUR_TOKEN_HERE'; // ⚠️ Get this from login response

    const testData = {
      message: "What are the early signs of autism in toddlers?",
      diagnoses: ["Autism Spectrum Disorder", "Learning Disabilities"]
    };

    console.log('📤 Request:');
    console.log('   Message:', testData.message);
    console.log('   Diagnoses:', testData.diagnoses.join(', '));
    console.log('');

    const response = await axios.post(
      'http://localhost:5000/api/ai/educational-chat',
      testData,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      }
    );

    console.log('✅ Success!');
    console.log('📥 Response:', response.data.success);
    console.log('');
    console.log('🤖 AI Answer:');
    console.log('─'.repeat(60));
    console.log(response.data.response);
    console.log('─'.repeat(60));
    console.log('');
    console.log('⏱️  Timestamp:', response.data.timestamp);

  } catch (error) {
    console.error('❌ Error:', error.response?.data || error.message);
    
    if (error.response?.status === 401) {
      console.log('\n⚠️  Authentication failed!');
      console.log('📝 To fix:');
      console.log('   1. Login via the app');
      console.log('   2. Copy the token from response');
      console.log('   3. Replace YOUR_TOKEN_HERE in this script');
    }
  }
}

// Run the test
testChatbot();

console.log('\n💡 More test questions:');
console.log('   - How to improve speech at home?');
console.log('   - Tips for managing ADHD behavior');
console.log('   - Activities for motor skills development');
console.log('   - Best communication strategies for non-verbal children');
console.log('   - Social skills training ideas');
