// seeders/seed_diagnoses.js
const sequelize = require('../config/db');
const Diagnosis = require('../model/Diagnosis');

async function seedDiagnoses() {
  try {
    console.log('🌱 Starting diagnoses seeding...');

    // تحديث الـ model من ENUM إلى VARCHAR
    await sequelize.query(`
      ALTER TABLE Diagnoses 
      MODIFY name VARCHAR(255) NOT NULL
    `);
    
    // إضافة عمود name_ar و category إذا لم يكونوا موجودين
    await sequelize.query(`
      ALTER TABLE Diagnoses 
      ADD COLUMN IF NOT EXISTS name_ar VARCHAR(255) NULL,
      ADD COLUMN IF NOT EXISTS category ENUM(
        'Developmental', 'Neurological', 'Genetic', 
        'Sensory', 'Learning', 'Behavioral', 
        'Physical', 'Multiple'
      ) DEFAULT 'Developmental',
      ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE
    `).catch(() => {
      console.log('⚠️ Columns may already exist, continuing...');
    });

    console.log('✅ Table structure updated');

    // حذف البيانات القديمة
    await Diagnosis.destroy({ where: {}, truncate: true });
    console.log('🗑️ Old data cleared');

    // البيانات الجديدة الشاملة
    const diagnoses = [
      // Developmental Disorders
      {
        name: 'Autism Spectrum Disorder (ASD)',
        name_ar: 'اضطراب طيف التوحد',
        description: 'A developmental disorder affecting communication and behavior',
        category: 'Developmental'
      },
      {
        name: 'Global Developmental Delay',
        name_ar: 'تأخر النمو الشامل',
        description: 'Significant delay in two or more developmental areas',
        category: 'Developmental'
      },
      {
        name: 'Developmental Language Disorder',
        name_ar: 'اضطراب اللغة النمائي',
        description: 'Difficulty with language development',
        category: 'Developmental'
      },

      // Neurological Disorders
      {
        name: 'ADHD (Attention Deficit Hyperactivity Disorder)',
        name_ar: 'فرط الحركة وتشتت الانتباه',
        description: 'A neurodevelopmental disorder affecting focus and impulse control',
        category: 'Neurological'
      },
      {
        name: 'Cerebral Palsy',
        name_ar: 'الشلل الدماغي',
        description: 'A group of disorders affecting movement and muscle tone',
        category: 'Neurological'
      },
      {
        name: 'Epilepsy',
        name_ar: 'الصرع',
        description: 'A neurological disorder causing recurrent seizures',
        category: 'Neurological'
      },

      // Genetic Disorders
      {
        name: 'Down Syndrome',
        name_ar: 'متلازمة داون',
        description: 'A genetic chromosome disorder causing developmental delays',
        category: 'Genetic'
      },
      {
        name: 'Fragile X Syndrome',
        name_ar: 'متلازمة الكروموسوم X الهش',
        description: 'A genetic condition causing intellectual disability',
        category: 'Genetic'
      },
      {
        name: 'Rett Syndrome',
        name_ar: 'متلازمة ريت',
        description: 'A rare genetic neurological disorder',
        category: 'Genetic'
      },

      // Sensory Disorders
      {
        name: 'Hearing Impairment',
        name_ar: 'ضعف السمع',
        description: 'Partial or total inability to hear',
        category: 'Sensory'
      },
      {
        name: 'Visual Impairment',
        name_ar: 'ضعف البصر',
        description: 'Decreased ability to see',
        category: 'Sensory'
      },
      {
        name: 'Sensory Processing Disorder',
        name_ar: 'اضطراب المعالجة الحسية',
        description: 'Difficulty processing sensory information',
        category: 'Sensory'
      },

      // Learning Disorders
      {
        name: 'Learning Disability (General)',
        name_ar: 'صعوبات التعلم',
        description: 'General learning difficulties',
        category: 'Learning'
      },
      {
        name: 'Dyslexia',
        name_ar: 'عسر القراءة',
        description: 'Reading disorder affecting decoding and comprehension',
        category: 'Learning'
      },
      {
        name: 'Dysgraphia',
        name_ar: 'عسر الكتابة',
        description: 'Writing disorder affecting handwriting and composition',
        category: 'Learning'
      },
      {
        name: 'Dyscalculia',
        name_ar: 'عسر الحساب',
        description: 'Math learning disorder',
        category: 'Learning'
      },

      // Behavioral Disorders
      {
        name: 'Oppositional Defiant Disorder (ODD)',
        name_ar: 'اضطراب التحدي المعارض',
        description: 'A pattern of angry/irritable mood and defiant behavior',
        category: 'Behavioral'
      },
      {
        name: 'Conduct Disorder',
        name_ar: 'اضطراب السلوك',
        description: 'Antisocial behavior violating rights of others',
        category: 'Behavioral'
      },

      // Physical Disorders
      {
        name: 'Muscular Dystrophy',
        name_ar: 'الحثل العضلي',
        description: 'Progressive muscle weakness and loss',
        category: 'Physical'
      },
      {
        name: 'Spina Bifida',
        name_ar: 'السنسنة المشقوقة',
        description: 'Birth defect affecting the spine',
        category: 'Physical'
      },

      // Speech & Language
      {
        name: 'Speech & Language Disorder',
        name_ar: 'اضطرابات النطق واللغة',
        description: 'Difficulty with speech production or language understanding',
        category: 'Developmental'
      },
      {
        name: 'Apraxia of Speech',
        name_ar: 'عسر الأداء النطقي',
        description: 'Motor speech disorder',
        category: 'Developmental'
      },
      {
        name: 'Stuttering',
        name_ar: 'التأتأة',
        description: 'Speech fluency disorder',
        category: 'Developmental'
      },

      // Intellectual Disabilities
      {
        name: 'Intellectual Disability (Mild)',
        name_ar: 'إعاقة ذهنية بسيطة',
        description: 'IQ 50-70',
        category: 'Developmental'
      },
      {
        name: 'Intellectual Disability (Moderate)',
        name_ar: 'إعاقة ذهنية متوسطة',
        description: 'IQ 35-49',
        category: 'Developmental'
      },
      {
        name: 'Intellectual Disability (Severe)',
        name_ar: 'إعاقة ذهنية شديدة',
        description: 'IQ 20-34',
        category: 'Developmental'
      },

      // Multiple/Complex
      {
        name: 'Multiple Disabilities',
        name_ar: 'إعاقات متعددة',
        description: 'Combination of two or more disabilities',
        category: 'Multiple'
      },
      {
        name: 'Complex Needs',
        name_ar: 'احتياجات معقدة',
        description: 'Multiple complex health and developmental needs',
        category: 'Multiple'
      },

      // Other
      {
        name: 'Dyspraxia (Developmental Coordination Disorder)',
        name_ar: 'عسر الأداء الحركي',
        description: 'Motor coordination difficulties',
        category: 'Physical'
      },
      {
        name: 'Tourette Syndrome',
        name_ar: 'متلازمة توريت',
        description: 'Neurological disorder with tics',
        category: 'Neurological'
      },
      {
        name: 'Fetal Alcohol Spectrum Disorder (FASD)',
        name_ar: 'اضطراب طيف الكحول الجنيني',
        description: 'Range of effects from prenatal alcohol exposure',
        category: 'Developmental'
      },
    ];

    // إدراج البيانات
    await Diagnosis.bulkCreate(diagnoses);

    const count = await Diagnosis.count();
    console.log(`✅ Successfully seeded ${count} diagnoses`);
    
    // عرض البيانات
    const allDiagnoses = await Diagnosis.findAll({
      attributes: ['diagnosis_id', 'name', 'name_ar', 'category']
    });
    
    console.log('\n📋 Diagnoses by category:');
    const byCategory = {};
    allDiagnoses.forEach(d => {
      if (!byCategory[d.category]) byCategory[d.category] = [];
      byCategory[d.category].push(d.name);
    });
    
    Object.entries(byCategory).forEach(([cat, items]) => {
      console.log(`\n${cat} (${items.length}):`);
      items.forEach(item => console.log(`  - ${item}`));
    });

    return count;
  } catch (error) {
    console.error('❌ Error seeding diagnoses:', error);
    throw error;
  }
}

// تشغيل الـ seeder
if (require.main === module) {
  seedDiagnoses()
    .then((count) => {
      console.log(`\n🎉 Seeding complete! ${count} diagnoses added.`);
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Seeding failed:', error);
      process.exit(1);
    });
}

module.exports = seedDiagnoses;
