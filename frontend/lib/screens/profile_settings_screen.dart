import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../l10n/app_localizations.dart';
import '../services/language_service.dart';
import '../main.dart';
import '../theme/app_colors.dart'; // تأكد من استيراد ملف الألوان

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  // حالة الإعدادات
  bool _twoFactorAuth = true;
  bool _loginNotifications = true;
  bool _showOnlineStatus = false;
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _sessionReminders = true;
  bool _progressReports = true;
  bool _promotionalEmails = false;
  bool _autoDeleteData = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.get('profileSettings'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textWhite,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Security & Privacy
            _buildSecuritySection(l10n),
            const SizedBox(height: 20),

            // Notifications
            _buildNotificationsSection(l10n),
            const SizedBox(height: 20),

            // Preferences
            _buildPreferencesSection(l10n),
            const SizedBox(height: 20),

            // Data & Storage
            _buildDataSection(l10n),
            const SizedBox(height: 20),

            // Account
            _buildAccountSection(l10n),
            const SizedBox(height: 20),

            // Help & Support
            _buildHelpSection(l10n),
            const SizedBox(height: 20),

            // About
            _buildAboutSection(l10n),
            const SizedBox(height: 30),

            // Action Buttons
            _buildActionButtons(l10n),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ========== Security & Privacy Section ==========
  Widget _buildSecuritySection(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.get('securityPrivacy')),

            _buildSettingsSwitch(
              icon: Icons.security,
              title: l10n.get('twoFactorAuth'),
              subtitle: l10n.get('twoFactorAuthDesc'),
              value: _twoFactorAuth,
              onChanged: (value) {
                setState(() => _twoFactorAuth = value);
                _showSuccessMessage(l10n.get(value ? 'enabled' : 'disabled'));
              },
            ),

            _buildSettingsSwitch(
              icon: Icons.notifications_active,
              title: l10n.get('loginNotifications'),
              subtitle: l10n.get('loginNotificationsDesc'),
              value: _loginNotifications,
              onChanged: (value) {
                setState(() => _loginNotifications = value);
              },
            ),

            _buildSettingsSwitch(
              icon: Icons.visibility,
              title: l10n.get('showOnlineStatus'),
              subtitle: l10n.get('showOnlineStatusDesc'),
              value: _showOnlineStatus,
              onChanged: (value) {
                setState(() => _showOnlineStatus = value);
              },
            ),

            _buildSettingsItem(
              icon: Icons.lock,
              title: l10n.get('changePassword'),
              subtitle: l10n.get('changePasswordDesc'),
              onTap: () => _changePassword(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.visibility_off,
              title: l10n.get('privacySettings'),
              subtitle: l10n.get('privacySettingsDesc'),
              onTap: () => _showPrivacySettings(l10n),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Notifications Section ==========
  Widget _buildNotificationsSection(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.get('notifications')),

            _buildSettingsSwitch(
              icon: Icons.notifications,
              title: l10n.get('pushNotifications'),
              subtitle: l10n.get('pushNotificationsDesc'),
              value: _pushNotifications,
              onChanged: (value) {
                setState(() => _pushNotifications = value);
              },
            ),

            _buildSettingsSwitch(
              icon: Icons.email,
              title: l10n.get('emailNotifications'),
              subtitle: l10n.get('emailNotificationsDesc'),
              value: _emailNotifications,
              onChanged: (value) {
                setState(() => _emailNotifications = value);
              },
            ),

            _buildSettingsSwitch(
              icon: Icons.calendar_today,
              title: l10n.get('sessionReminders'),
              subtitle: l10n.get('sessionRemindersDesc'),
              value: _sessionReminders,
              onChanged: (value) {
                setState(() => _sessionReminders = value);
              },
            ),

            _buildSettingsSwitch(
              icon: Icons.assessment,
              title: l10n.get('progressReports'),
              subtitle: l10n.get('progressReportsDesc'),
              value: _progressReports,
              onChanged: (value) {
                setState(() => _progressReports = value);
              },
            ),

            _buildSettingsSwitch(
              icon: Icons.local_offer,
              title: l10n.get('promotionalEmails'),
              subtitle: l10n.get('promotionalEmailsDesc'),
              value: _promotionalEmails,
              onChanged: (value) {
                setState(() => _promotionalEmails = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ========== Preferences Section ==========
  Widget _buildPreferencesSection(AppLocalizations l10n) {
    final currentLanguage = Localizations.localeOf(context).languageCode == 'ar'
        ? l10n.get('arabic')
        : l10n.get('english');

    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.get('preferences')),

            _buildSettingsItem(
              icon: Icons.language,
              title: l10n.get('language'),
              subtitle: currentLanguage,
              onTap: () => _changeLanguage(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.access_time,
              title: l10n.get('timeZone'),
              subtitle: 'Asia/Amman (GMT+3)',
              onTap: () => _changeTimeZone(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.format_size,
              title: l10n.get('textSize'),
              subtitle: l10n.get('medium'),
              onTap: () => _changeTextSize(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.palette,
              title: l10n.get('theme'),
              subtitle: l10n.get('light'),
              onTap: () => _changeTheme(l10n),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Data & Storage Section ==========
  Widget _buildDataSection(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.get('dataStorage')),

            _buildSettingsItem(
              icon: Icons.cloud_download,
              title: l10n.get('downloadMyData'),
              subtitle: l10n.get('downloadMyDataDesc'),
              onTap: () => _downloadData(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.storage,
              title: l10n.get('storageUsage'),
              subtitle: '245 MB ${l10n.get('used')}',
              onTap: () => _showStorageDetails(l10n),
            ),

            _buildSettingsSwitch(
              icon: Icons.auto_delete,
              title: l10n.get('autoDeleteData'),
              subtitle: l10n.get('autoDeleteDataDesc'),
              value: _autoDeleteData,
              onChanged: (value) {
                setState(() => _autoDeleteData = value);
                _showSuccessMessage('${l10n.get('autoDeleteData')} ${l10n.get(value ? 'enabled' : 'disabled')}');
              },
            ),

            _buildSettingsItem(
              icon: Icons.delete_sweep,
              title: l10n.get('clearCache'),
              subtitle: l10n.get('clearCacheDesc'),
              onTap: () => _clearCache(l10n),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Account Section ==========
  Widget _buildAccountSection(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.get('account')),

            _buildSettingsItem(
              icon: Icons.email,
              title: l10n.get('emailAddress'),
              subtitle: 'parent@example.com',
              onTap: () => _changeEmail(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.phone,
              title: l10n.get('phoneNumber'),
              subtitle: '+962 7X XXX XXXX',
              onTap: () => _changePhone(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.family_restroom,
              title: l10n.get('familyMembers'),
              subtitle: l10n.get('manageFamilyAccess'),
              onTap: () => _manageFamily(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.subscriptions,
              title: l10n.get('subscription'),
              subtitle: l10n.get('freePlan'),
              onTap: () => _manageSubscription(l10n),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Help & Support Section ==========
  Widget _buildHelpSection(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.get('helpSupport')),

            _buildSettingsItem(
              icon: Icons.help,
              title: l10n.get('helpCenter'),
              subtitle: l10n.get('helpCenterDesc'),
              onTap: () => _openHelpCenter(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.contact_support,
              title: l10n.get('contactSupport'),
              subtitle: l10n.get('contactSupportDesc'),
              onTap: () => _contactSupport(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.feedback,
              title: l10n.get('sendFeedback'),
              subtitle: l10n.get('sendFeedbackDesc'),
              onTap: () => _sendFeedback(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.star,
              title: l10n.get('rateApp'),
              subtitle: l10n.get('rateAppDesc'),
              onTap: () => _rateApp(l10n),
            ),
          ],
        ),
      ),
    );
  }

  // ========== About Section ==========
  Widget _buildAboutSection(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.get('about')),

            _buildSettingsItem(
              icon: Icons.info,
              title: l10n.get('appVersion'),
              subtitle: '1.2.3 (Build 456)',
              onTap: () {},
            ),

            _buildSettingsItem(
              icon: Icons.description,
              title: l10n.get('termsOfService'),
              subtitle: l10n.get('termsOfServiceDesc'),
              onTap: () => _showTerms(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.security,
              title: l10n.get('privacyPolicy'),
              subtitle: l10n.get('privacyPolicyDesc'),
              onTap: () => _showPrivacyPolicy(l10n),
            ),

            _buildSettingsItem(
              icon: Icons.copyright,
              title: l10n.get('copyright'),
              subtitle: '© 2024 Jusoor App. ${l10n.get('allRightsReserved')}',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  // ========== Action Buttons ==========
  Widget _buildActionButtons(AppLocalizations l10n) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _exportData(l10n),
            icon: Icon(Icons.download, color: AppColors.textWhite),
            label: Text(l10n.get('exportAllData')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showDeleteAccountDialog(l10n),
            icon: Icon(Icons.delete_outline, color: AppColors.error),
            label: Text(l10n.get('deleteAccount'), style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== Helper Widgets ==========
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textGray),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
      onTap: onTap,
    );
  }

  Widget _buildSettingsSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textGray),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withOpacity(0.5),
      ),
    );
  }

  // ========== Action Methods ==========
  void _changePassword(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('changePassword'), style: TextStyle(color: AppColors.textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: l10n.get('currentPassword'),
                labelStyle: TextStyle(color: AppColors.textGray),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: l10n.get('newPassword'),
                labelStyle: TextStyle(color: AppColors.textGray),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: l10n.get('confirmNewPassword'),
                labelStyle: TextStyle(color: AppColors.textGray),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel'), style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage(l10n.get('passwordChangedSuccessfully'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.get('changePassword'), style: TextStyle(color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettings(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('privacySettings'), style: TextStyle(color: AppColors.textDark)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.get('privacySettingsContent'), style: TextStyle(color: AppColors.textGray)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.public, color: AppColors.primary),
                title: Text(l10n.get('public'), style: TextStyle(color: AppColors.textDark)),
                subtitle: Text(l10n.get('publicDesc'), style: TextStyle(color: AppColors.textGray)),
              ),
              ListTile(
                leading: Icon(Icons.people, color: AppColors.primary),
                title: Text(l10n.get('communityOnly'), style: TextStyle(color: AppColors.textDark)),
                subtitle: Text(l10n.get('communityOnlyDesc'), style: TextStyle(color: AppColors.textGray)),
              ),
              ListTile(
                leading: Icon(Icons.lock, color: AppColors.primary),
                title: Text(l10n.get('private'), style: TextStyle(color: AppColors.textDark)),
                subtitle: Text(l10n.get('privateDesc'), style: TextStyle(color: AppColors.textGray)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('close'), style: TextStyle(color: AppColors.textGray)),
          ),
        ],
      ),
    );
  }

  void _changeLanguage(AppLocalizations l10n) {
    final currentLocale = Localizations.localeOf(context);
    final isArabic = currentLocale.languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.get('selectLanguage'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),
            _buildLanguageOption(l10n.get('english'), !isArabic, 'en', l10n),
            _buildLanguageOption(l10n.get('arabic'), isArabic, 'ar', l10n),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(l10n.get('apply'), style: TextStyle(color: AppColors.textWhite)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, bool isSelected, String languageCode, AppLocalizations l10n) {
    return ListTile(
      title: Text(language, style: TextStyle(color: AppColors.textDark)),
      trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
      tileColor: isSelected ? AppColors.accent1 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () async {
        final newLocale = Locale(languageCode);
        MyApp.of(context).setLocale(newLocale);
        await LanguageService.setLanguage(languageCode);

        Navigator.pop(context);
        _showSuccessMessage(l10n.get('languageChanged'));
      },
    );
  }

  void _changeTimeZone(AppLocalizations l10n) {
    _showSuccessMessage(l10n.get('timeZoneSettingsOpened'));
  }

  void _changeTextSize(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('textSize'), style: TextStyle(color: AppColors.textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextSizeOption(l10n.get('small'), false),
            _buildTextSizeOption(l10n.get('medium'), true),
            _buildTextSizeOption(l10n.get('large'), false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel'), style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage(l10n.get('textSizeUpdated'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.get('apply'), style: TextStyle(color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSizeOption(String size, bool isSelected) {
    return ListTile(
      title: Text(size, style: TextStyle(color: AppColors.textDark)),
      trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
      tileColor: isSelected ? AppColors.accent1 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        // Handle text size selection
      },
    );
  }

  void _changeTheme(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('selectTheme'), style: TextStyle(color: AppColors.textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(l10n.get('light'), Icons.light_mode, true),
            _buildThemeOption(l10n.get('dark'), Icons.dark_mode, false),
            _buildThemeOption(l10n.get('systemDefault'), Icons.settings, false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel'), style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage(l10n.get('themeChanged'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.get('apply'), style: TextStyle(color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String theme, IconData icon, bool isSelected) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(theme, style: TextStyle(color: AppColors.textDark)),
      trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
      tileColor: isSelected ? AppColors.accent1 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        // Handle theme selection
      },
    );
  }

  void _downloadData(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('downloadYourData'), style: TextStyle(color: AppColors.textDark)),
        content: Text(l10n.get('downloadDataContent'), style: TextStyle(color: AppColors.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel'), style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage(l10n.get('dataExportStarted'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.get('download'), style: TextStyle(color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  void _showStorageDetails(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('storageUsage'), style: TextStyle(color: AppColors.textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStorageItem(l10n.get('photosVideos'), '120 MB'),
            _buildStorageItem(l10n.get('documents'), '45 MB'),
            _buildStorageItem(l10n.get('cache'), '45 MB'),
            _buildStorageItem(l10n.get('appData'), '35 MB'),
            const SizedBox(height: 16),
            Text('${l10n.get('total')}: 245 MB',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('close'), style: TextStyle(color: AppColors.textGray)),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageItem(String type, String size) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(type, style: TextStyle(color: AppColors.textDark)),
          Text(size, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textDark)),
        ],
      ),
    );
  }

  void _clearCache(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('clearCache'), style: TextStyle(color: AppColors.textDark)),
        content: Text(l10n.get('clearCacheContent'), style: TextStyle(color: AppColors.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel'), style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage(l10n.get('cacheClearedSuccessfully'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.get('clearCache'), style: TextStyle(color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  void _changeEmail(AppLocalizations l10n) {
    _showSuccessMessage(l10n.get('emailChangeFeature'));
  }

  void _changePhone(AppLocalizations l10n) {
    _showSuccessMessage(l10n.get('phoneChangeFeature'));
  }

  void _manageFamily(AppLocalizations l10n) {
    _showSuccessMessage(l10n.get('familyManagement'));
  }

  void _manageSubscription(AppLocalizations l10n) {
    _showSuccessMessage(l10n.get('subscriptionManagement'));
  }

  void _openHelpCenter(AppLocalizations l10n) {
    _showSuccessMessage(l10n.get('helpCenterOpened'));
  }

  void _contactSupport(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('contactSupport'), style: TextStyle(color: AppColors.textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.get('contactSupportContent'), style: TextStyle(color: AppColors.textGray)),
            const SizedBox(height: 16),
            _buildContactOption(Icons.email, l10n.get('emailSupport'), 'support@jusoor.com', l10n),
            _buildContactOption(Icons.phone, l10n.get('phoneSupport'), '+962 6 123 4567', l10n),
            _buildContactOption(Icons.chat, l10n.get('liveChat'), l10n.get('available9to5'), l10n),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('close'), style: TextStyle(color: AppColors.textGray)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String title, String subtitle, AppLocalizations l10n) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: TextStyle(color: AppColors.textDark)),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.textGray)),
      onTap: () {
        Navigator.pop(context);
        _showSuccessMessage('${l10n.get('opening')} $title');
      },
    );
  }

  void _sendFeedback(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('sendFeedback'), style: TextStyle(color: AppColors.textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: l10n.get('subject'),
                labelStyle: TextStyle(color: AppColors.textGray),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: l10n.get('yourFeedback'),
                labelStyle: TextStyle(color: AppColors.textGray),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.star_border, color: Colors.amber[600]),
                Icon(Icons.star_border, color: Colors.amber[600]),
                Icon(Icons.star_border, color: Colors.amber[600]),
                Icon(Icons.star_border, color: Colors.amber[600]),
                Icon(Icons.star_border, color: Colors.amber[600]),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel'), style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage(l10n.get('thankYouForFeedback'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.get('sendFeedback'), style: TextStyle(color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  void _rateApp(AppLocalizations l10n) {
    _showSuccessMessage(l10n.get('openingAppStoreForRating'));
  }

  void _showTerms(AppLocalizations l10n) {
    _showSuccessMessage(l10n.get('termsOfService'));
  }

  void _showPrivacyPolicy(AppLocalizations l10n) {
    _showSuccessMessage(l10n.get('privacyPolicy'));
  }

  void _exportData(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('exportAllData'), style: TextStyle(color: AppColors.textDark)),
        content: Text(l10n.get('exportDataContent'), style: TextStyle(color: AppColors.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel'), style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage(l10n.get('dataExportStartedEmail'));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.get('exportData'), style: TextStyle(color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.get('deleteAccount'), style: TextStyle(color: AppColors.textDark)),
        content: Text(l10n.get('deleteAccountContent'), style: TextStyle(color: AppColors.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel'), style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () => _deleteAccount(l10n),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.get('deleteAccount'), style: TextStyle(color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(AppLocalizations l10n) {
    Navigator.pop(context); // Close dialog
    _showSuccessMessage(l10n.get('accountDeletionStarted'));
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}