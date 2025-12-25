import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'manager_page_content_editor_screen.dart';
import 'manager_news_management_screen.dart';
import 'manager_programs_management_screen.dart';
import 'manager_projects_management_screen.dart';
import 'manager_faq_management_screen.dart';
import 'manager_media_management_screen.dart';

class ManagerCmsDashboardScreen extends StatefulWidget {
  const ManagerCmsDashboardScreen({super.key});

  @override
  State<ManagerCmsDashboardScreen> createState() => _ManagerCmsDashboardScreenState();
}

class _ManagerCmsDashboardScreenState extends State<ManagerCmsDashboardScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<DashboardItem> items = [
      DashboardItem(
        title: 'Page Content',
        subtitle: 'Manage static pages content',
        icon: Icons.edit_note,
        iconBgColor: const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF2E7D32),
        screen: const ManagerPageContentEditorScreen(),
      ),
      DashboardItem(
        title: 'News',
        subtitle: 'Create and publish news',
        icon: Icons.article,
        iconBgColor: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1565C0),
        screen: const ManagerNewsManagementScreen(),
      ),
      DashboardItem(
        title: 'Programs',
        subtitle: 'Manage educational programs',
        icon: Icons.school,
        iconBgColor: const Color(0xFFF3E5F5),
        iconColor: const Color(0xFF7B1FA2),
        screen: const ManagerProgramsManagementScreen(),
      ),
      DashboardItem(
        title: 'Projects',
        subtitle: 'Ongoing projects & fundraising',
        icon: Icons.rocket_launch,
        iconBgColor: const Color(0xFFFFF3E0),
        iconColor: const Color(0xFFEF6C00),
        screen: const ManagerProjectsManagementScreen(),
      ),
      DashboardItem(
        title: 'FAQ',
        subtitle: 'Questions and answers',
        icon: Icons.help_outline,
        iconBgColor: const Color(0xFFE0F7FA),
        iconColor: const Color(0xFF006064),
        screen: const ManagerFaqManagementScreen(),
      ),
      DashboardItem(
        title: 'Media',
        subtitle: 'Gallery, videos & files',
        icon: Icons.photo_library,
        iconBgColor: const Color(0xFFFCE4EC),
        iconColor: const Color(0xFFAD1457),
        screen: const ManagerMediaManagementScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _buildResponsiveLayout(context, items),
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context, List<DashboardItem> items) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // تصميم لشاشات كبيرة (ويب)
    if (screenWidth > 1024) {
      return _buildDesktopLayout(context, items);
    }
    // تصميم لشاشات متوسطة (تابلت)
    else if (screenWidth > 600) {
      return _buildTabletLayout(context, items);
    }
    // تصميم لشاشات صغيرة (موبايل)
    else {
      return _buildMobileLayout(context, items);
    }
  }

  Widget _buildDesktopLayout(BuildContext context, List<DashboardItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AppBar بديل للويب
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: AppColors.primary),
                    onPressed: () {
                      // يمكن إضافة drawer للويب هنا
                    },
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'CMS Dashboard',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none, color: AppColors.primary),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: IconButton(
                      icon: Icon(Icons.settings, color: AppColors.primary),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Welcome Card للويب
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - _animationController.value)),
                child: Opacity(
                  opacity: _animationController.value,
                  child: _buildWebWelcomeCard(context),
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          // Grid للويب
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisExtent: 140,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final delay = index * 100;
                      final controllerValue = _animationController.value;
                      final animationValue = (controllerValue * 1000 - delay).clamp(0, 1).toDouble();
                      
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - animationValue)),
                        child: Opacity(
                          opacity: animationValue,
                          child: _DashboardCard(
                            item: items[index],
                            isDesktop: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebWelcomeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.primary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.dashboard, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, Admin!',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Manage all your website content efficiently from one place',
                            style: TextStyle(
                              color: AppColors.textGray,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Last login: Today at ${TimeOfDay.now().format(context)}',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storage, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '6 content modules',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Container(
            width: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Quick Stats',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          '24',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          'News',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        Text(
                          '8',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          'Projects',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, List<DashboardItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AppBar للتابلت
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CMS Dashboard',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none, color: AppColors.primary),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: IconButton(
                      icon: Icon(Icons.settings, color: AppColors.primary),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Welcome Card للتابلت
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - _animationController.value)),
              child: Opacity(
                opacity: _animationController.value,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _WelcomeCard(),
                ),
              ),
            );
          },
        ),
        
        // Grid للتابلت
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final delay = index * 100;
                    final controllerValue = _animationController.value;
                    final animationValue = (controllerValue * 1000 - delay).clamp(0, 1).toDouble();
                    
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - animationValue)),
                      child: Opacity(
                        opacity: animationValue,
                        child: _DashboardCard(
                          item: items[index],
                          isTablet: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, List<DashboardItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AppBar للجوال
        AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          foregroundColor: AppColors.textDark,
          title: Text(
            'CMS Dashboard',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.primary),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: IconButton(
                  icon: Icon(Icons.settings, color: AppColors.primary, size: 20),
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
        
        // Welcome Card للجوال
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - _animationController.value)),
              child: Opacity(
                opacity: _animationController.value,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _WelcomeCard(),
                ),
              ),
            );
          },
        ),
        
        // Grid للجوال
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 400 ? 2 : 2;
              final childAspectRatio = constraints.maxWidth > 400 ? 1.3 : 1.2;
              
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final delay = index * 100;
                      final controllerValue = _animationController.value;
                      final animationValue = (controllerValue * 1000 - delay).clamp(0, 1).toDouble();
                      
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - animationValue)),
                        child: Opacity(
                          opacity: animationValue,
                          child: _DashboardCard(
                            item: items[index],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Widget screen;

  DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.screen,
  });
}

class _WelcomeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.dashboard, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, Admin!',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your content efficiently',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Last login: Today at ${TimeOfDay.now().format(context)}',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final DashboardItem item;
  final bool isDesktop;
  final bool isTablet;

  const _DashboardCard({
    required this.item,
    this.isDesktop = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => item.screen,
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, animation, __, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.5, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(isDesktop ? 0.1 : 0.08),
                blurRadius: isDesktop ? 16 : 12,
                spreadRadius: isDesktop ? 2 : 1,
                offset: Offset(0, isDesktop ? 4 : 3),
              ),
            ],
            border: Border.all(
              color: Colors.grey[100]!,
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 20 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with background
                Container(
                  width: isDesktop ? 56 : 40,
                  height: isDesktop ? 56 : 40,
                  decoration: BoxDecoration(
                    color: item.iconBgColor,
                    borderRadius: BorderRadius.circular(isDesktop ? 14 : 10),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.iconColor,
                    size: isDesktop ? 28 : 20,
                  ),
                ),
                
                SizedBox(height: isDesktop ? 20 : 12),
                
                // Title
                Text(
                  item.title,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: isDesktop ? 18 : 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: isDesktop ? 10 : 6),
                
                // Subtitle
                Expanded(
                  child: Text(
                    item.subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isDesktop ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    maxLines: isDesktop ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                SizedBox(height: isDesktop ? 12 : 8),
                
                // Arrow indicator
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: isDesktop ? 36 : 28,
                    height: isDesktop ? 36 : 28,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[500],
                      size: isDesktop ? 16 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}