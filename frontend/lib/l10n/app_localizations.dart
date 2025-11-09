import 'package:flutter/material.dart';

class AppLocalizations {
  static const LocalizationsDelegate<AppLocalizations> delegate =
  _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  final Locale _currentLocale;

  AppLocalizations(this._currentLocale);

  String get(String key) {
    final translations = _currentLocale.languageCode == 'ar'
        ? _arabicTranslations
        : _englishTranslations;

    return translations[key] ?? key;
  }

  static const Map<String, String> _englishTranslations = {
    'profileSettings': 'Profile Settings',
    'securityPrivacy': 'Security & Privacy',
    'twoFactorAuth': 'Two-Factor Authentication',
    'twoFactorAuthDesc': 'Add extra security to your account',
    'loginNotifications': 'Login Notifications',
    'loginNotificationsDesc': 'Get notified for new logins',
    'showOnlineStatus': 'Show Online Status',
    'showOnlineStatusDesc': 'Let others see when you\'re online',
    'changePassword': 'Change Password',
    'changePasswordDesc': 'Update your password regularly',
    'privacySettings': 'Privacy Settings',
    'privacySettingsDesc': 'Control who sees your information',
    'notifications': 'Notifications',
    'pushNotifications': 'Push Notifications',
    'pushNotificationsDesc': 'Receive alerts on your device',
    'emailNotifications': 'Email Notifications',
    'emailNotificationsDesc': 'Get updates via email',
    'enabled': 'enabled',
    'disabled': 'disabled',
    'cancel': 'Cancel',
    'apply': 'Apply',
    'save': 'Save',
    'language': 'Language',
    'english': 'English',
    'arabic': 'Arabic',
    'selectLanguage': 'Select Language',
    'languageChanged': 'Language changed successfully',
  };

  static const Map<String, String> _arabicTranslations = {
    'profileSettings': 'إعدادات الملف الشخصي',
    'securityPrivacy': 'الأمان والخصوصية',
    'twoFactorAuth': 'المصادقة الثنائية',
    'twoFactorAuthDesc': 'أضف أمانًا إضافيًا لحسابك',
    'loginNotifications': 'إشعارات تسجيل الدخول',
    'loginNotificationsDesc': 'احصل على إشعارات بتسجيلات الدخول الجديدة',
    'showOnlineStatus': 'إظهار حالة الاتصال',
    'showOnlineStatusDesc': 'السماح للآخرين برؤية عندما تكون متصلًا',
    'changePassword': 'تغيير كلمة المرور',
    'changePasswordDesc': 'قم بتحديث كلمة المرور بانتظام',
    'privacySettings': 'إعدادات الخصوصية',
    'privacySettingsDesc': 'التحكم في من يرى معلوماتك',
    'notifications': 'الإشعارات',
    'pushNotifications': 'الإشعارات المنبثقة',
    'pushNotificationsDesc': 'تلقي التنبيهات على جهازك',
    'emailNotifications': 'إشعارات البريد الإلكتروني',
    'emailNotificationsDesc': 'الحصول على التحديثات عبر البريد الإلكتروني',
    'enabled': 'مفعل',
    'disabled': 'معطل',
    'cancel': 'إلغاء',
    'apply': 'تطبيق',
    'save': 'حفظ',
    'language': 'اللغة',
    'english': 'الإنجليزية',
    'arabic': 'العربية',
    'selectLanguage': 'اختر اللغة',
    'languageChanged': 'تم تغيير اللغة بنجاح',
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}