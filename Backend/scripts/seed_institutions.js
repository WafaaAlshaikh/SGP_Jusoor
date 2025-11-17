// Script to seed institutions with sample data
const sequelize = require('../config/db');
const Institution = require('../model/Institution');

async function seedInstitutions() {
  try {
    await sequelize.sync();
    
    // Update or create sample institutions
    const institutions = [
      {
        name: 'Yasmeen Charity',
        description: 'Leading autism center providing comprehensive therapy and support services for children with special needs.',
        location: 'Queen Rania Street, Amman',
        city: 'Amman',
        region: 'Central',
        website: 'www.yasmeencharity.org',
        contact_info: '+962 6 123 4567',
        services_offered: 'Speech Therapy, Occupational Therapy, Behavioral Therapy, Physical Therapy, Educational Support',
        conditions_supported: 'Autism, ADHD, Down Syndrome, Speech Delay, Learning Disabilities',
        rating: 4.8,
        price_range: '50-150 JD',
        capacity: 120,
        available_slots: 25,
        location_lat: 31.9454,
        location_lng: 35.9284
      },
      {
        name: 'Sanad Center',
        description: 'Specialized center for ADHD and behavioral therapy with experienced psychologists and therapists.',
        location: 'University Street, Irbid',
        city: 'Irbid',
        region: 'North',
        website: 'www.sanadcenter.jo',
        contact_info: '+962 2 789 1234',
        services_offered: 'Behavioral Therapy, Educational Support, Psychological Counseling, Speech Therapy',
        conditions_supported: 'ADHD, Behavioral Issues, Learning Disabilities, Autism',
        rating: 4.5,
        price_range: '40-120 JD',
        capacity: 80,
        available_slots: 15,
        location_lat: 32.5556,
        location_lng: 35.8469
      },
      {
        name: 'Hope Rehabilitation Center',
        description: 'Comprehensive rehabilitation center offering physical and occupational therapy for children with cerebral palsy.',
        location: 'Medical City Road, Zarqa',
        city: 'Zarqa',
        region: 'Central',
        website: 'www.hopecenter.jo',
        contact_info: '+962 5 456 7890',
        services_offered: 'Physical Therapy, Occupational Therapy, Speech Therapy, Educational Support',
        conditions_supported: 'Cerebral Palsy, Down Syndrome, Physical Disabilities, Speech Delay',
        rating: 4.3,
        price_range: '60-180 JD',
        capacity: 60,
        available_slots: 10,
        location_lat: 32.0728,
        location_lng: 36.0881
      },
      {
        name: 'Bright Minds Learning Center',
        description: 'Educational support center specializing in learning disabilities and academic support for special needs children.',
        location: 'Gardens Street, Amman',
        city: 'Amman',
        region: 'Central',
        website: 'www.brightminds.jo',
        contact_info: '+962 6 333 2222',
        services_offered: 'Educational Support, Speech Therapy, Psychological Counseling, Behavioral Therapy',
        conditions_supported: 'Learning Disabilities, ADHD, Autism, Speech Delay',
        rating: 4.6,
        price_range: '45-130 JD',
        capacity: 100,
        available_slots: 30,
        location_lat: 31.9539,
        location_lng: 35.9106
      },
      {
        name: 'Aqaba Special Needs Center',
        description: 'Modern facility providing integrated services for children with various special needs.',
        location: 'King Hussein Street, Aqaba',
        city: 'Aqaba',
        region: 'South',
        website: 'www.aqabasnc.jo',
        contact_info: '+962 3 201 5678',
        services_offered: 'Speech Therapy, Occupational Therapy, Behavioral Therapy, Physical Therapy, Psychological Counseling',
        conditions_supported: 'Autism, Down Syndrome, ADHD, Speech Delay, Behavioral Issues',
        rating: 4.4,
        price_range: '55-140 JD',
        capacity: 70,
        available_slots: 20,
        location_lat: 29.5267,
        location_lng: 35.0063
      }
    ];

    for (const instData of institutions) {
      const [institution, created] = await Institution.findOrCreate({
        where: { name: instData.name },
        defaults: instData
      });

      if (!created) {
        // Update existing institution
        await institution.update(instData);
        console.log(`✅ Updated: ${instData.name}`);
      } else {
        console.log(`✅ Created: ${instData.name}`);
      }
    }

    console.log('\n🎉 Successfully seeded institutions with sample data!');
    console.log(`📊 Total institutions: ${institutions.length}`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding institutions:', error);
    process.exit(1);
  }
}

seedInstitutions();
