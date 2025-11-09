// seeders/questionSeeder.js
const { Question } = require('../model');
const sequelize = require('../config/db');

async function seedQuestions() {
  try {
    console.log('🌱 Starting questions seeding...');

    // التحقق إذا فيه أسئلة موجودة مسبقاً
    const existingQuestions = await Question.count();
    if (existingQuestions > 0) {
      console.log('✅ Questions already exist, skipping seeding.');
      return;
    }

    const initialQuestions = [
      // 🔍 Attention & Focus - ADHD Related
      {
        category: 'Attention & Focus',
        question_text: 'كم مرة يجد طفلك صعوبة في الحفاظ على الانتباه في المهام أو أنشطة اللعب؟',
        question_type: 'Multiple Choice',
        options: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
        weight: 1.2,
        target_conditions: ['ADHD'],
        min_age: 3,
        max_age: 18,
        next_question_logic: {
          depends_on_question: null,
          required_value: null
        }
      },
      {
        category: 'Attention & Focus', 
        question_text: 'هل يميل طفلك إلى فقدان الأشياء الضرورية للمهام والأنشطة (مثل الأقلام، الكتب، الأدوات)؟',
        question_type: 'Multiple Choice',
        options: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
        weight: 1.1,
        target_conditions: ['ADHD'],
        min_age: 4,
        max_age: 18
      },
      {
        category: 'Attention & Focus',
        question_text: 'كم مرة يبدو طفلك وكأنه لا يستمع عندما تتحدث إليه مباشرة؟',
        question_type: 'Multiple Choice',
        options: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
        weight: 1.3,
        target_conditions: ['ADHD'],
        min_age: 3,
        max_age: 18
      },

      // 🤝 Social Interaction - Autism Related
      {
        category: 'Social Interaction',
        question_text: 'هل يصنع طفلك تواصلًا بصريًا عند التفاعل مع الآخرين؟',
        question_type: 'Multiple Choice',
        options: ['دائماً', 'غالباً', 'أحياناً', 'نادراً', 'أبداً'],
        weight: 1.5,
        target_conditions: ['ASD'],
        min_age: 2,
        max_age: 18
      },
      {
        category: 'Social Interaction',
        question_text: 'هل يشارك طفلك في اللعب التخيلي أو التظاهر (مثل التظاهر بالطبخ، قيادة السيارة)؟',
        question_type: 'Multiple Choice',
        options: ['دائماً', 'غالباً', 'أحياناً', 'نادراً', 'أبداً'],
        weight: 1.4,
        target_conditions: ['ASD'],
        min_age: 2,
        max_age: 10
      },
      {
        category: 'Social Interaction',
        question_text: 'هل يبدي طفلك اهتمامًا باللعب مع أطفال آخرين؟',
        question_type: 'Multiple Choice',
        options: ['دائماً', 'غالباً', 'أحياناً', 'نادراً', 'أبداً'],
        weight: 1.3,
        target_conditions: ['ASD'],
        min_age: 3,
        max_age: 12
      },

      // 💬 Communication - Speech & Language
      {
        category: 'Communication',
        question_text: 'كم عدد الكلمات التي يستخدمها طفلك بشكل منتظم؟',
        question_type: 'Multiple Choice',
        options: ['أكثر من 50 كلمة', '20-50 كلمة', '10-20 كلمة', 'أقل من 10 كلمات', 'لا يستخدم كلمات'],
        weight: 1.6,
        target_conditions: ['Speech & Language Disorder'],
        min_age: 2,
        max_age: 6
      },
      {
        category: 'Communication',
        question_text: 'هل يستخدم طفلك جمل مكونة من كلمتين أو أكثر؟',
        question_type: 'Multiple Choice',
        options: ['نعم، بطلاقة', 'أحياناً', 'نادراً', 'لا'],
        weight: 1.4,
        target_conditions: ['Speech & Language Disorder'],
        min_age: 2,
        max_age: 8
      },
      {
        category: 'Communication',
        question_text: 'هل يواجه طفلك صعوبة في فهم التعليمات البسيطة؟',
        question_type: 'Multiple Choice',
        options: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
        weight: 1.2,
        target_conditions: ['Speech & Language Disorder'],
        min_age: 3,
        max_age: 12
      },

      // 🔄 Behavior Patterns - ASD & ADHD
      {
        category: 'Behavior Patterns',
        question_text: 'هل يكرر طفلك حركات أو سلوكيات معينة (مثل الرفرفة، الدوران، الهز)؟',
        question_type: 'Multiple Choice',
        options: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
        weight: 1.7,
        target_conditions: ['ASD'],
        min_age: 2,
        max_age: 18
      },
      {
        category: 'Behavior Patterns',
        question_text: 'هل يظهر طفلك اهتمامات شديدة أو غير عادية بموضوعات معينة؟',
        question_type: 'Multiple Choice',
        options: ['لا', 'قليلاً', 'نعم، بشكل ملحوظ', 'نعم، بشكل مكثف'],
        weight: 1.4,
        target_conditions: ['ASD'],
        min_age: 3,
        max_age: 18
      },
      {
        category: 'Behavior Patterns',
        question_text: 'كم مرة يتحرك طفلك بعصبية أو يتلوى في مقعده؟',
        question_type: 'Multiple Choice',
        options: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
        weight: 1.3,
        target_conditions: ['ADHD'],
        min_age: 4,
        max_age: 18
      },

      // 🏃‍♂️ Motor Skills - General Development
      {
        category: 'Motor Skills',
        question_text: 'كيف تقيم مهارات طفلك الحركية الدقيقة (مثل مسك القلم، استخدام المقص)؟',
        question_type: 'Multiple Choice',
        options: ['ممتازة', 'جيدة', 'متوسطة', 'ضعيفة', 'ضعيفة جداً'],
        weight: 1.1,
        target_conditions: ['Down Syndrome'],
        min_age: 3,
        max_age: 12
      },
      {
        category: 'Motor Skills',
        question_text: 'هل يواجه طفلك صعوبة في تنظيم حركاته أو يبدو أخرق؟',
        question_type: 'Multiple Choice',
        options: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
        weight: 1.2,
        target_conditions: ['ASD', 'Down Syndrome'],
        min_age: 3,
        max_age: 15
      },

      // 📚 Academic Performance - School Age
      {
        category: 'Academic Performance',
        question_text: 'كيف هو أداء طفلك الأكاديمي مقارنة بأقرانه؟',
        question_type: 'Multiple Choice',
        options: ['أفضل من أقرانه', 'مماثل لأقرانه', 'أقل قليلاً', 'أقل بشكل ملحوظ', 'أقل بكثير'],
        weight: 1.3,
        target_conditions: ['ADHD', 'ASD'],
        min_age: 6,
        max_age: 18
      },
      {
        category: 'Academic Performance',
        question_text: 'هل يواجه طفلك صعوبة في إكمال الواجبات المدرسية؟',
        question_type: 'Multiple Choice',
        options: ['أبداً', 'نادراً', 'أحياناً', 'غالباً', 'دائماً'],
        weight: 1.2,
        target_conditions: ['ADHD'],
        min_age: 6,
        max_age: 18
      },

      // 🏠 Daily Living Skills - Independence
      {
        category: 'Daily Living Skills',
        question_text: 'كيف تقيم قدرة طفلك على الاعتناء بنفسه (ارتداء الملابس، الأكل، النظافة)؟',
        question_type: 'Multiple Choice',
        options: ['مستقل تماماً', 'شبه مستقل', 'بحاجة لبعض المساعدة', 'بحاجة لكثير من المساعدة', 'غير قادر'],
        weight: 1.4,
        target_conditions: ['ASD', 'Down Syndrome'],
        min_age: 4,
        max_age: 18
      },
      {
        category: 'Daily Living Skills',
        question_text: 'هل يتبع طفلك الروتين اليومي بسهولة؟',
        question_type: 'Multiple Choice',
        options: ['دائماً', 'غالباً', 'أحياناً', 'نادراً', 'أبداً'],
        weight: 1.3,
        target_conditions: ['ASD', 'ADHD'],
        min_age: 3,
        max_age: 18
      }
    ];

    // إدخال الأسئلة في قاعدة البيانات
    await Question.bulkCreate(initialQuestions);
    
    console.log(`✅ Successfully seeded ${initialQuestions.length} questions!`);
    
  } catch (error) {
    console.error('❌ Error seeding questions:', error);
  }
}

// إذا تم تشغيل الملف مباشرة
if (require.main === module) {
  seedQuestions()
    .then(() => {
      console.log('🎉 Seeding completed!');
      process.exit(0);
    })
    .catch(error => {
      console.error('💥 Seeding failed:', error);
      process.exit(1);
    });
}

module.exports = seedQuestions;