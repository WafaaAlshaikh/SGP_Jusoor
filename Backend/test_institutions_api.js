// Quick test for institutions API
const http = require('http');

const options = {
  hostname: 'localhost',
  port: 5000,
  path: '/api/institutions',
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer fake-token-for-test'
  }
};

const req = http.request(options, (res) => {
  let data = '';

  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    console.log('Status Code:', res.statusCode);
    console.log('Response Length:', data.length);
    
    if (res.statusCode === 200) {
      const institutions = JSON.parse(data);
      console.log('✅ Total Institutions:', institutions.length);
      console.log('\n📋 Sample Institutions:');
      institutions.slice(0, 3).forEach(inst => {
        console.log(`  - ${inst.name} (${inst.city}) - Rating: ${inst.rating}`);
        console.log(`    Services: ${inst.services_offered || 'N/A'}`);
        console.log(`    Price: ${inst.price_range || 'N/A'}`);
      });
    } else {
      console.log('❌ Error Response:', data);
    }
  });
});

req.on('error', (error) => {
  console.error('❌ Request Error:', error.message);
});

req.end();
