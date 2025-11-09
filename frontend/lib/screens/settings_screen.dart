import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/profile_screen.dart';
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoPlayVideos = false;
  bool _saveToGallery = true;
  String _language = 'English';
  String _fontSize = 'Medium';

  final List<String> languages = ['English', 'Arabic', 'Spanish', 'French'];
  final List<String> fontSizes = ['Small', 'Medium', 'Large', 'Extra Large'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _darkModeEnabled = prefs.getBool('darkMode') ?? false;
      _autoPlayVideos = prefs.getBool('autoPlay') ?? false;
      _saveToGallery = prefs.getBool('saveToGallery') ?? true;
      _language = prefs.getString('language') ?? 'English';
      _fontSize = prefs.getString('fontSize') ?? 'Medium';
    });
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setBool('darkMode', _darkModeEnabled);
    await prefs.setBool('autoPlay', _autoPlayVideos);
    await prefs.setBool('saveToGallery', _saveToGallery);
    await prefs.setString('language', _language);
    await prefs.setString('fontSize', _fontSize);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Color(0xFF7815A0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF5FF),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF7815A0),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Settings
            _buildSection(
              title: 'Profile Settings',
              icon: Icons.person,
              children: [
                _buildSettingItem(
                  icon: Icons.person,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfileScreen()),
                    );
                  },
                ),
                _buildSettingItem(
                  icon: Icons.visibility,
                  title: 'Privacy Settings',
                  subtitle: 'Control who can see your content',
                  onTap: () {
                    // Navigate to privacy settings
                  },
                ),
                _buildSettingItem(
                  icon: Icons.security,
                  title: 'Account Security',
                  subtitle: 'Change password and security options',
                  onTap: () {
                    // Navigate to security settings
                  },
                ),
              ],
            ),
            SizedBox(height: 25),

            // Notification Settings
            _buildSection(
              title: 'Notifications',
              icon: Icons.notifications,
              children: [
                _buildSwitchSetting(
                  icon: Icons.notifications_active,
                  title: 'Push Notifications',
                  subtitle: 'Receive app notifications',
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.email,
                  title: 'Email Notifications',
                  subtitle: 'Receive email updates',
                  value: true,
                  onChanged: (value) {
                    // Handle email notifications
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.video_library,
                  title: 'Post Updates',
                  subtitle: 'Notifications for new posts',
                  value: true,
                  onChanged: (value) {
                    // Handle post updates
                  },
                ),
              ],
            ),
            SizedBox(height: 25),

            // App Preferences
            _buildSection(
              title: 'App Preferences',
              icon: Icons.settings_applications,
              children: [
                _buildDropdownSetting(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'App language',
                  value: _language,
                  items: languages,
                  onChanged: (value) {
                    setState(() {
                      _language = value!;
                    });
                  },
                ),
                _buildDropdownSetting(
                  icon: Icons.text_fields,
                  title: 'Font Size',
                  subtitle: 'Text size in app',
                  value: _fontSize,
                  items: fontSizes,
                  onChanged: (value) {
                    setState(() {
                      _fontSize = value!;
                    });
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.dark_mode,
                  title: 'Dark Mode',
                  subtitle: 'Use dark theme',
                  value: _darkModeEnabled,
                  onChanged: (value) {
                    setState(() {
                      _darkModeEnabled = value;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 25),

            // Media & Content
            _buildSection(
              title: 'Media & Content',
              icon: Icons.photo_library,
              children: [
                _buildSwitchSetting(
                  icon: Icons.play_arrow,
                  title: 'Auto-play Videos',
                  subtitle: 'Play videos automatically',
                  value: _autoPlayVideos,
                  onChanged: (value) {
                    setState(() {
                      _autoPlayVideos = value;
                    });
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.save_alt,
                  title: 'Save to Gallery',
                  subtitle: 'Automatically save media',
                  value: _saveToGallery,
                  onChanged: (value) {
                    setState(() {
                      _saveToGallery = value;
                    });
                  },
                ),
                _buildSettingItem(
                  icon: Icons.storage,
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  onTap: () {
                    _showClearCacheDialog();
                  },
                ),
              ],
            ),
            SizedBox(height: 25),

            // Support & About
            _buildSection(
              title: 'Support & About',
              icon: Icons.help_outline,
              children: [
                _buildSettingItem(
                  icon: Icons.help,
                  title: 'Help & Support',
                  subtitle: 'Get help using the app',
                  onTap: () {
                    // Navigate to help screen
                  },
                ),
                _buildSettingItem(
                  icon: Icons.info,
                  title: 'About App',
                  subtitle: 'Version and app information',
                  onTap: () {
                    // Navigate to about screen
                  },
                ),
                _buildSettingItem(
                  icon: Icons.star,
                  title: 'Rate App',
                  subtitle: 'Share your feedback',
                  onTap: () {
                    // Open app store for rating
                  },
                ),
                _buildSettingItem(
                  icon: Icons.share,
                  title: 'Share App',
                  subtitle: 'Share with friends',
                  onTap: () {
                    // Share app functionality
                  },
                ),
              ],
            ),
            SizedBox(height: 25),

            // Account Actions
            _buildSection(
              title: 'Account',
              icon: Icons.account_circle,
              children: [
                _buildSettingItem(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  subtitle: 'Sign out of your account',
                  isDestructive: true,
                  onTap: () {
                    _showSignOutDialog();
                  },
                ),
                _buildSettingItem(
                  icon: Icons.delete,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account',
                  isDestructive: true,
                  onTap: () {
                    _showDeleteAccountDialog();
                  },
                ),
              ],
            ),
            SizedBox(height: 30),

            // Save Button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF7815A0),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Save All Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Color(0xFF7815A0),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : Color(0xFF7815A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : Color(0xFF7815A0),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : Color(0xFF2D3748),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Color(0xFF718096),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFFA0AEC0),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF7815A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Color(0xFF7815A0),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Color(0xFF2D3748),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Color(0xFF718096),
            fontSize: 12,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Color(0xFF7815A0),
        ),
      ),
    );
  }

  Widget _buildDropdownSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF7815A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Color(0xFF7815A0),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Color(0xFF2D3748),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Color(0xFF718096),
            fontSize: 12,
          ),
        ),
        trailing: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Cache'),
        content: Text('This will free up storage space by removing temporary files. Your personal data will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement sign out logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Signed out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Text('This action cannot be undone. All your data will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement delete account logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Account deletion request sent'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}