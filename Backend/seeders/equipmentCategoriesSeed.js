const { EquipmentCategory } = require('../model');

const equipmentCategories = [
  {
    name_ar: 'كراسي متحركة',
    name_en: 'Wheelchairs',
    description: 'كراسي متحركة يدوية وكهربائية',
    icon: 'wheelchair',
    is_active: true
  },
  {
    name_ar: 'أطراف صناعية',
    name_en: 'Prosthetics',
    description: 'أطراف صناعية لأعضاء الجسم المختلفة',
    icon: 'prosthetic',
    is_active: true
  },
  {
    name_ar: 'أجهزة تنفس',
    name_en: 'Breathing Devices',
    description: 'أجهزة تنفس وأوكسجين',
    icon: 'breathing',
    is_active: true
  },
  {
    name_ar: 'معينات سمعية',
    name_en: 'Hearing Aids',
    description: 'سماعات وأجهزة مساعدة على السمع',
    icon: 'hearing-aid',
    is_active: true
  },
  {
    name_ar: 'أجهزة كمبيوتر خاصة',
    name_en: 'Special Computers',
    description: 'أجهزة كمبيوتر مزودة بتقنيات خاصة للمكفوفين',
    icon: 'computer',
    is_active: true
  },
  {
    name_ar: 'أجهزة علاج طبيعي',
    name_en: 'Physical Therapy Equipment',
    description: 'أجهزة وأدوات للعلاج الطبيعي',
    icon: 'therapy',
    is_active: true
  },
  {
    name_ar: 'معدات تعليمية',
    name_en: 'Educational Equipment',
    description: 'أجهزة ومعدات للتعليم والتواصل',
    icon: 'education',
    is_active: true
  },
  {
    name_ar: 'أخرى',
    name_en: 'Other',
    description: 'أجهزة ومعدات أخرى',
    icon: 'other',
    is_active: true
  }
];

async function seedEquipmentCategories() {
  try {
    for (const category of equipmentCategories) {
      const exists = await EquipmentCategory.findOne({
        where: { name_ar: category.name_ar }
      });
      
      if (!exists) {
        await EquipmentCategory.create(category);
        console.log(`✅ تم إنشاء فئة: ${category.name_ar}`);
      }
    }
    
    console.log('✅ تم إنشاء فئات الأجهزة بنجاح');
  } catch (error) {
    console.error('❌ خطأ في إنشاء فئات الأجهزة:', error);
  }
}

module.exports = seedEquipmentCategories;