// utils/initSystemSettings.js
const SystemSettings = require('../model/SystemSettings');

const defaultSettings = [
  {
    setting_key: 'Jusoor',
    setting_value: 'Special Needs Platform',
    setting_type: 'string',
    category: 'general',
    description: ' Jusoor',
    is_editable: true
  },
  {
    setting_key: 'app_version',
    setting_value: '1.0.0',
    setting_type: 'string',
    category: 'general',
    description: 'نسخة التطبيق',
    is_editable: true
  },
  {
    setting_key: 'commission_rate',
    setting_value: '5',
    setting_type: 'number',
    category: 'financial',
    description: 'نسبة العمولة على التبرعات (%)',
    is_editable: true
  },
  {
    setting_key: 'min_donation_amount',
    setting_value: '10',
    setting_type: 'number',
    category: 'financial',
    description: 'الحد الأدنى للتبرع (دولار)',
    is_editable: true
  },
  {
    setting_key: 'session_cancel_hours',
    setting_value: '24',
    setting_type: 'number',
    category: 'sessions',
    description: 'عدد الساعات المسموح بها لإلغاء الجلسة',
    is_editable: true
  },
  {
    setting_key: 'institution_approval_required',
    setting_value: 'true',
    setting_type: 'boolean',
    category: 'institutions',
    description: 'هل تحتاج المؤسسات لموافقة الأدمن؟',
    is_editable: true
  },
  {
    setting_key: 'specialist_approval_required',
    setting_value: 'true',
    setting_type: 'boolean',
    category: 'users',
    description: 'هل يحتاج الأخصائيون لموافقة الأدمن؟',
    is_editable: true
  },
  {
    setting_key: 'auto_suspend_failed_payments',
    setting_value: '3',
    setting_type: 'number',
    category: 'financial',
    description: 'عدد محاولات الدفع الفاشلة قبل التعليق التلقائي',
    is_editable: true
  },
  {
    setting_key: 'support_email',
    setting_value: 'support@specialneeds.com',
    setting_type: 'string',
    category: 'contact',
    description: 'بريد الدعم الفني',
    is_editable: true
  },
  {
    setting_key: 'terms_url',
    setting_value: 'https://example.com/terms',
    setting_type: 'string',
    category: 'legal',
    description: 'رابط شروط الاستخدام',
    is_editable: true
  },
  {
    setting_key: 'privacy_url',
    setting_value: 'https://example.com/privacy',
    setting_type: 'string',
    category: 'legal',
    description: 'رابط سياسة الخصوصية',
    is_editable: true
  }
];

const initializeSettings = async () => {
  try {
    const count = await SystemSettings.count();
    if (count === 0) {
      await SystemSettings.bulkCreate(defaultSettings);
      console.log('✅ System settings initialized');
    }
  } catch (error) {
    console.error('❌ Error initializing settings:', error);
  }
};

module.exports = initializeSettings;