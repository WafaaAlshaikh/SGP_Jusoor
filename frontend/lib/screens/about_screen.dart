import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF5FF),
      appBar: AppBar(
        title: Text(
          'About Us',
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

            // Mission Section
            _buildSection(
              title: 'Our Mission',
              icon: Icons.flag,
              content: 'To create a supportive community where parents, specialists, and caregivers can connect, share knowledge, and support each other in the journey of raising children with special needs.',
            ),
            SizedBox(height: 25),

            // Features Section
            _buildFeaturesSection(),
            SizedBox(height: 25),

            // Team Section
            _buildTeamSection(),
            SizedBox(height: 25),

            // Contact Section
            _buildContactSection(),
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
            Icons.favorite,
            color: Colors.white,
            size: 50,
          ),
          SizedBox(height: 15),
          Text(
            'Special Needs Support Community',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Connecting families, specialists, and caregivers in one supportive platform',
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String content,
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
          SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF4A5568),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
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
                Icons.star,
                color: Color(0xFF7815A0),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'What We Offer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildFeatureItem('Community Support', 'Connect with other parents and specialists'),
          _buildFeatureItem('Resource Sharing', 'Share experiences, tips, and resources'),
          _buildFeatureItem('Expert Guidance', 'Get advice from qualified specialists'),
          _buildFeatureItem('Safe Environment', 'Moderated community with zero tolerance for discrimination'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String subtitle) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Color(0xFF48BB78),
            size: 20,
          ),
          SizedBox(width: 12),
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
                    color: Color(0xFF718096),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection() {
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
                Icons.people,
                color: Color(0xFF7815A0),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Our Team',
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
            'We are a dedicated team of developers, specialists, and community managers committed to creating a positive impact in the special needs community.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF4A5568),
              height: 1.5,
            ),
          ),
          SizedBox(height: 15),
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              _buildTeamMember('Development Team', 'Flutter Experts'),
              _buildTeamMember('Specialists', 'Child Development Experts'),
              _buildTeamMember('Community Managers', 'Support & Moderation'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMember(String name, String role) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFFE9D8FD)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFF7815A0).withOpacity(0.1),
            child: Icon(
              Icons.person,
              color: Color(0xFF7815A0),
            ),
          ),
          SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
              fontSize: 13,
            ),
          ),
          Text(
            role,
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
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
                Icons.contact_support,
                color: Color(0xFF7815A0),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildContactItem(Icons.email, 'support@specialneeds.com'),
          _buildContactItem(Icons.phone, '+1 (555) 123-4567'),
          _buildContactItem(Icons.language, 'www.specialneeds-support.com'),
          SizedBox(height: 15),
          Text(
            'We\'re here to help! Reach out to us for any questions or support.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Color(0xFF7815A0),
            size: 20,
          ),
          SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}