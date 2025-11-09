import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF5FF),
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF7815A0),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeaderSection(),
            SizedBox(height: 30),

            // Quick Help Section
            _buildQuickHelpSection(),
            SizedBox(height: 25),

            // FAQ Section
            _buildFAQSection(),
            SizedBox(height: 25),

            // Contact Support Section
            _buildContactSupportSection(),
            SizedBox(height: 25),

            // Resources Section
            _buildResourcesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7815A0), Color(0xFF9F7AEA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.help_center,
            color: Colors.white,
            size: 50,
          ),
          SizedBox(height: 15),
          Text(
            'How Can We Help You?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Find answers to common questions or get in touch with our support team',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickHelpSection() {
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
                Icons.quickreply,
                color: Color(0xFF7815A0),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Quick Help',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickHelpItem('Create Post', Icons.post_add, 'Learn how to share content'),
              _buildQuickHelpItem('Community', Icons.people, 'Connect with others'),
              _buildQuickHelpItem('Profile', Icons.person, 'Manage your account'),
              _buildQuickHelpItem('Settings', Icons.settings, 'Customize app settings'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickHelpItem(String title, IconData icon, String subtitle) {
    return Container(
      width: 150,
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE9D8FD)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Color(0xFF7815A0),
            size: 30,
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
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
                Icons.question_answer,
                color: Color(0xFF7815A0),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildFAQItem(
            'How do I create a post?',
            'Tap on the "Add Post" button in the community section or use the quick action in dashboard. Write your content and add media if needed.',
          ),
          _buildFAQItem(
            'Can I edit or delete my posts?',
            'Yes, you can edit or delete your own posts by tapping the three dots menu on your post.',
          ),
          _buildFAQItem(
            'How do I connect with specialists?',
            'Browse the community posts or use the search feature to find specialists. You can comment on their posts or send direct messages.',
          ),
          _buildFAQItem(
            'Is my personal information safe?',
            'Yes, we take privacy seriously. Your personal information is encrypted and never shared with third parties.',
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline,
                color: Color(0xFF7815A0),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            answer,
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSupportSection() {
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
                Icons.support_agent,
                color: Color(0xFF7815A0),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Contact Support',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildContactOption(
            Icons.email,
            'Email Support',
            'support@specialneeds.com',
            'We respond within 24 hours',
          ),
          _buildContactOption(
            Icons.phone,
            'Phone Support',
            '+1 (555) 123-HELP',
            'Mon-Fri, 9AM-6PM EST',
          ),
          _buildContactOption(
            Icons.chat,
            'Live Chat',
            'Available in app',
            'Real-time support',
          ),
          _buildContactOption(
            Icons.feedback,
            'Feedback',
            'Share your suggestions',
            'Help us improve',
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String title, String subtitle, String description) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFFE9D8FD)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF7815A0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Color(0xFF7815A0),
              size: 22,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Color(0xFF7815A0),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: Color(0xFFA0AEC0),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildResourcesSection() {
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
                Icons.library_books,
                color: Color(0xFF7815A0),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Helpful Resources',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Text(
            'Additional resources to help you get the most out of our community:',
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          _buildResourceItem('Community Guidelines', Icons.gpp_good),
          _buildResourceItem('Privacy Policy', Icons.privacy_tip),
          _buildResourceItem('Terms of Service', Icons.description),
          _buildResourceItem('User Manual', Icons.menu_book),
        ],
      ),
    );
  }

  Widget _buildResourceItem(String title, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
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
            fontSize: 15,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFFA0AEC0),
          size: 16,
        ),
        onTap: () {
          // يمكنك إضافة navigation لكل resource
        },
      ),
    );
  }
}