import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:frontend/screens/quick_donation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/public_institution_service.dart';
import '../services/rating_service.dart';
import '../models/rating_models.dart';
import '../theme/app_colors.dart';
import 'donation_screen.dart';
import 'equipment_donation_screen.dart';
import '../widgets/institution_registration_request_sheet.dart';
import '../widgets/review_dialog.dart';

class PublicInstitutionHomeScreen extends StatefulWidget {
  final int institutionId;
  final String? institutionName;

  const PublicInstitutionHomeScreen({
    super.key,
    required this.institutionId,
    this.institutionName,
  });

  @override
  State<PublicInstitutionHomeScreen> createState() =>
      _PublicInstitutionHomeScreenState();
}

class _PublicInstitutionHomeScreenState
    extends State<PublicInstitutionHomeScreen> {
  late Future<Map<String, dynamic>> _future;
  int _selectedTab = 0; // 0: Home, 1: Team, 2: Services, 3: Reviews, 4: Programs, 5: Projects, 6: Sessions
  List<dynamic> _team = [];
  List<InstitutionReview> _reviews = [];
  InstitutionReviewStats? _reviewStats;
  bool _isLoadingReviews = false;
  bool _canAddReview = false;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  bool _isLoadingAI = false;
  int _currentReviewPage = 1;
  int _totalReviewPages = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _future = PublicInstitutionService.getInstitutionHome(widget.institutionId);
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    setState(() {
      _canAddReview = token.isNotEmpty;
    });
    await _loadFollowStatus();
  }

  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadFollowStatus() async {
    try {
      final token = await _getAuthToken();
      if (token.trim().isEmpty) {
        if (!mounted) return;
        setState(() => _isFollowing = false);
        return;
      }

      final isFollowing = await PublicInstitutionService.getFollowStatus(
        institutionId: widget.institutionId,
        token: token,
      );
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowing = false);
    }
  }

  Future<void> _toggleFollow() async {
    await _requireLogin(actionName: _isFollowing ? 'unfollow' : 'follow');
    if (!await _isLoggedIn()) return;
    if (!mounted) return;

    final token = await _getAuthToken();
    if (token.trim().isEmpty) return;

    setState(() => _isLoadingFollow = true);
    try {
      if (_isFollowing) {
        await PublicInstitutionService.unfollowInstitution(
          institutionId: widget.institutionId,
          token: token,
        );
        if (!mounted) return;
        setState(() => _isFollowing = false);
      } else {
        await PublicInstitutionService.followInstitution(
          institutionId: widget.institutionId,
          token: token,
        );
        if (!mounted) return;
        setState(() => _isFollowing = true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingFollow = false);
    }
  }

  Future<void> _requireLogin({required String actionName}) async {
    final loggedIn = await _isLoggedIn();
    if (loggedIn) return;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login required'),
          content: Text('Please sign in to $actionName.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Sign In'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.trim().isNotEmpty;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _loadTeam() async {
    try {
      final teamData = await PublicInstitutionService.getInstitutionTeam(
          widget.institutionId);
      setState(() {
        _team = teamData;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadReviews({int page = 1}) async {
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      final response = await RatingService.getInstitutionReviews(
        widget.institutionId.toString(),
        page: page,
        limit: 5,
        sort: 'newest',
      );

      if (response['success'] == true) {
        final data = response['data'];
        final items = data['reviews'] as List;

        setState(() {
          _reviews =
              items.map((item) => InstitutionReview.fromJson(item)).toList();
          _reviewStats = InstitutionReviewStats.fromJson(data['statistics']);
          _currentReviewPage = data['pagination']['current_page'] ?? page;
          _totalReviewPages = data['pagination']['total_pages'] ?? 1;
          _isLoadingReviews = false;
        });
      } else {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _addReview() async {
    await _requireLogin(actionName: 'add review');
    if (!await _isLoggedIn()) return;
    if (!mounted) return;

    final result = await showDialog(
      context: context,
      builder: (context) => ReviewDialog(
        institutionId: widget.institutionId.toString(),
        institutionName: widget.institutionName ?? 'Institution',
      ),
    );

    if (result == true) {
      _loadReviews();
    }
  }

  Future<void> _openAIHelper() async {
    if (!mounted) return;

    final questionController = TextEditingController();
    String answerText = '';
    bool isLoading = false;

    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> ask() async {
              final q = questionController.text.trim();
              if (q.isEmpty) return;
              setStateDialog(() {
                isLoading = true;
              });

              try {
                final data = await PublicInstitutionService.askInstitutionAI(
                  institutionId: widget.institutionId,
                  question: q,
                  token: token.isEmpty ? null : token,
                );
                final a = (data['answer'] ?? '').toString();
                setStateDialog(() {
                  answerText = a;
                });
              } catch (e) {
                setStateDialog(() {
                  answerText = e.toString().replaceAll('Exception: ', '');
                });
              } finally {
                setStateDialog(() {
                  isLoading = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Ask AI'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: questionController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Your question',
                          hintText: 'Ask about services, programs, projects, or contact...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (answerText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent1.withOpacity(0.7)),
                          ),
                          child: Text(
                            answerText,
                            style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : ask,
                  child: const Text('Ask'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load institution home',
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(color: AppColors.textGray),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _future =
                          PublicInstitutionService.getInstitutionHome(
                              widget.institutionId)),
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data ?? <String, dynamic>{};
          final institution =
              (data['institution'] as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{};
          final contentList = (data['content'] as List?) ?? const [];
          final programs = (data['programs'] as List?) ?? const [];
          final projects = (data['projects'] as List?) ?? const [];
          final faq = (data['faq'] as List?) ?? const [];
          final news = (data['news'] as List?) ?? const [];
          final media = (data['media'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

          final coverUrl = (media['cover_url'] as String?) ?? '';
          final logoUrl = (media['logo_url'] as String?) ?? '';
          final introVideoUrl = (media['intro_video_url'] as String?) ?? '';
          final gallery = (media['gallery'] as List?) ?? const [];

          String _contentByKey(String key) {
            for (final item in contentList) {
              if (item is Map && item['key']?.toString() == key) {
                return (item['content'] ?? '').toString();
              }
            }
            return '';
          }

          final about = _contentByKey('about');
          final mission = _contentByKey('mission');
          final ourWorld = _contentByKey('our_world');

          final website = (institution['website'] ?? '').toString();
          final contactEmail = (institution['contact_email'] ?? '').toString();
          final contactPhone = (institution['contact_phone'] ?? '').toString();

          // Check if web
          if (kIsWeb) {
            return _buildWebLayout(
              institution: institution,
              programs: programs,
              projects: projects,
              faq: faq,
              news: news,
              about: about,
              mission: mission,
              ourWorld: ourWorld,
              website: website,
              contactEmail: contactEmail,
              contactPhone: contactPhone,
              coverUrl: coverUrl,
              logoUrl: logoUrl,
              introVideoUrl: introVideoUrl,
              gallery: gallery,
            );
          }

          // Mobile layout
          return _buildMobileLayout(
            context: context,
            institution: institution,
            contentList: contentList,
            programs: programs,
            projects: projects,
            faq: faq,
            news: news,
            media: media,
            about: about,
            mission: mission,
            ourWorld: ourWorld,
            website: website,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
            coverUrl: coverUrl,
            logoUrl: logoUrl,
            introVideoUrl: introVideoUrl,
            gallery: gallery,
          );
        },
      ),
    );
  }

  // ==================== WEB LAYOUT ====================
  Widget _buildWebLayout({
    required Map<String, dynamic> institution,
    required List programs,
    required List projects,
    required List faq,
    required List news,
    required String about,
    required String mission,
    required String ourWorld,
    required String website,
    required String contactEmail,
    required String contactPhone,
    required String coverUrl,
    required String logoUrl,
    required String introVideoUrl,
    required List gallery,
  }) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Web Header - Fixed
        SliverAppBar(
          floating: true,
          pinned: true,
          snap: false,
          elevation: 2,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black.withOpacity(0.1),
          toolbarHeight: 80,
          title: _buildWebHeader(institution, logoUrl),
          automaticallyImplyLeading: false,
        ),

        // Hero Section
        SliverToBoxAdapter(
          child: _buildWebHeroSection(institution, coverUrl),
        ),

        // Main Content
        SliverToBoxAdapter(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Navigation Tabs
                _buildWebTabs(),
                const SizedBox(height: 40),

                // Content based on selected tab
                _buildWebTabContent(
                  institution: institution,
                  programs: programs,
                  projects: projects,
                  faq: faq,
                  news: news,
                  about: about,
                  mission: mission,
                  ourWorld: ourWorld,
                  website: website,
                  contactEmail: contactEmail,
                  contactPhone: contactPhone,
                  introVideoUrl: introVideoUrl,
                  gallery: gallery,
                ),
              ],
            ),
          ),
        ),

        // Footer
        SliverToBoxAdapter(
          child: _buildWebFooter(institution, website, contactEmail, contactPhone),
        ),
      ],
    );
  }

  Widget _buildWebHeader(Map<String, dynamic> institution, String logoUrl) {
    return Row(
      children: [
        // Logo & Name
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: logoUrl.isNotEmpty
                    ? Image.network(logoUrl, fit: BoxFit.cover)
                    : Icon(Icons.apartment, color: AppColors.primary, size: 30),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              (institution['name'] ?? widget.institutionName ?? '').toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        
        const Spacer(),
        
        // Right side buttons
        Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 140),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _requireLogin(actionName: 'donate');
                  if (!await _isLoggedIn()) return;
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DonationScreen(
                        institutionId: widget.institutionId,
                        institutionName: (institution['name'] ?? widget.institutionName)?.toString(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.volunteer_activism, size: 18),
                label: const Text('Donate Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120),
              child: OutlinedButton.icon(
                onPressed: _isLoadingFollow ? null : _toggleFollow,
                icon: _isLoadingFollow
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isFollowing ? Icons.star : Icons.star_border,
                        size: 18,
                        color: _isFollowing ? Colors.amber : AppColors.primary,
                      ),
                label: Text(_isFollowing ? 'Following' : 'Follow'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100),
              child: OutlinedButton.icon(
                onPressed: _isLoadingAI
                    ? null
                    : () async {
                        setState(() => _isLoadingAI = true);
                        try {
                          await _openAIHelper();
                        } finally {
                          if (!mounted) return;
                          setState(() => _isLoadingAI = false);
                        }
                      },
                icon: _isLoadingAI
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.smart_toy_outlined, size: 18),
                label: const Text('AI Assistant'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebTabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildWebTabButton(0, 'Home'),
          _buildWebTabButton(1, 'Our Team'),
          _buildWebTabButton(2, 'Services'),
          _buildWebTabButton(3, 'Reviews'),
          _buildWebTabButton(4, 'Programs'),
          _buildWebTabButton(5, 'Projects'),
          _buildWebTabButton(6, 'Sessions'),
        ],
      ),
    );
  }

  Widget _buildWebTabButton(int index, String label) {
    final isSelected = _selectedTab == index;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: TextButton(
        onPressed: () {
          setState(() => _selectedTab = index);
          if (index == 1 && _team.isEmpty) {
            _loadTeam();
          }
          if (index == 3 && _reviews.isEmpty) {
            _loadReviews();
          }
        },
        style: TextButton.styleFrom(
          foregroundColor: isSelected ? AppColors.primary : AppColors.textGray,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildWebHeroSection(Map<String, dynamic> institution, String coverUrl) {
    return Container(
      height: 500,
      width: double.infinity,
      decoration: BoxDecoration(
        image: coverUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(coverUrl),
                fit: BoxFit.cover,
              )
            : null,
        color: coverUrl.isEmpty ? AppColors.primary.withOpacity(0.12) : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.4),
            ],
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (institution['name'] ?? widget.institutionName ?? '').toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  (institution['description'] ?? '').toString(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _requireLogin(actionName: 'apply for registration');
                    if (!await _isLoggedIn()) return;
                    if (!mounted) return;
                    await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      builder: (_) => InstitutionRegistrationRequestSheet(
                        institutionId: widget.institutionId,
                        institutionName: (institution['name'] ?? widget.institutionName ?? 'Institution').toString(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment, size: 24),
                  label: const Text('Apply for Registration', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebTabContent({
    required Map<String, dynamic> institution,
    required List programs,
    required List projects,
    required List faq,
    required List news,
    required String about,
    required String mission,
    required String ourWorld,
    required String website,
    required String contactEmail,
    required String contactPhone,
    required String introVideoUrl,
    required List gallery,
  }) {
    switch (_selectedTab) {
      case 0: // Home
        return _buildWebHomeTab(
          about: about,
          mission: mission,
          ourWorld: ourWorld,
          website: website,
          contactEmail: contactEmail,
          contactPhone: contactPhone,
          gallery: gallery,
          faq: faq,
          news: news,
          introVideoUrl: introVideoUrl,
        );

      case 1: // Team
        return _buildWebTeamTab();

      case 2: // Services
        return _buildWebServicesTab();

      case 3: // Reviews
        return _buildWebReviewsTab(
            institutionName: institution['name']?.toString() ??
                widget.institutionName ??
                'Institution');

      case 4: // Programs
        return _buildWebProgramsTab(programs: programs);

      case 5: // Projects
        return _buildWebProjectsTab(projects: projects);

      case 6: // Sessions
        return _buildWebSessionsTab(institutionId: widget.institutionId);

      default:
        return Container();
    }
  }

  Widget _buildWebHomeTab({
    required String about,
    required String mission,
    required String ourWorld,
    required String website,
    required String contactEmail,
    required String contactPhone,
    required List gallery,
    required List faq,
    required List news,
    required String introVideoUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // About Us
        if (about.isNotEmpty) ...[
          _buildWebSection(
            title: 'About Us',
            content: about,
          ),
          const SizedBox(height: 60),
        ],

        // Mission
        if (mission.isNotEmpty) ...[
          _buildWebSection(
            title: 'Our Mission',
            content: mission,
          ),
          const SizedBox(height: 60),
        ],

        // Intro Video
        if (introVideoUrl.isNotEmpty) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Introduction Video',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(introVideoUrl),
                    icon: const Icon(Icons.play_circle_filled, size: 48),
                    label: const Text('Watch Video', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],

        // Gallery
        if (gallery.isNotEmpty) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gallery',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: gallery.length,
                  itemBuilder: (context, index) {
                    final item = gallery[index];
                    final url = (item is Map ? item['url'] : '')?.toString() ?? '';
                    if (url.isEmpty) return Container();
                    
                    return Container(
                      width: 250,
                      margin: EdgeInsets.only(right: index < gallery.length - 1 ? 16 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],

        // Our World
        if (ourWorld.isNotEmpty) ...[
          _buildWebSection(
            title: 'Our World',
            content: ourWorld,
          ),
          const SizedBox(height: 60),
        ],

        // FAQ & News in two columns
        if (faq.isNotEmpty || news.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FAQ
              if (faq.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Frequently Asked Questions',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...faq
                          .whereType<Map>()
                          .map((item) => _buildWebFAQItem(
                                question: (item['question'] ?? '').toString(),
                                answer: (item['answer'] ?? '').toString(),
                              ))
                          .toList(),
                    ],
                  ),
                ),
              
              if (faq.isNotEmpty && news.isNotEmpty) const SizedBox(width: 40),
              
              // News
              if (news.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Latest News',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...news
                          .whereType<Map>()
                          .map((item) => _buildWebNewsItem(
                                title: (item['title'] ?? '').toString(),
                                content: ((item['summary'] ?? item['content']) ?? '').toString(),
                                date: (item['created_at'] ?? '').toString(),
                              ))
                          .toList(),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 60),
        ],

        // Contact Information
        if (website.isNotEmpty || contactEmail.isNotEmpty || contactPhone.isNotEmpty) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (contactPhone.isNotEmpty) ...[
                      _buildWebContactItem(
                        icon: Icons.phone,
                        title: 'Phone',
                        value: contactPhone,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (contactEmail.isNotEmpty) ...[
                      _buildWebContactItem(
                        icon: Icons.email,
                        title: 'Email',
                        value: contactEmail,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (website.isNotEmpty) ...[
                      _buildWebContactItem(
                        icon: Icons.language,
                        title: 'Website',
                        value: website,
                        isLink: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildWebSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          content,
          style: const TextStyle(
            fontSize: 18,
            color: AppColors.textGray,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildWebFAQItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            answer,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebNewsItem({required String title, required String content, required String date}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              date,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            content.length > 150 ? '${content.substring(0, 150)}...' : content,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              height: 1.5,
            ),
          ),
          if (content.length > 150) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {},
              child: const Text('Read More'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebContactItem({
    required IconData icon,
    required String title,
    required String value,
    bool isLink = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textGray,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: isLink ? () => _openUrl(value) : null,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    color: isLink ? AppColors.primary : AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebTeamTab() {
  if (_team.isEmpty) {
    return FutureBuilder<void>(
      future: _loadTeam(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return const Center(
          child: Text(
            'No team members available',
            style: TextStyle(fontSize: 18, color: AppColors.textGray),
          ),
        );
      },
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Our Team',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
      const SizedBox(height: 40),
      
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 40,
          mainAxisSpacing: 40,
          childAspectRatio: 0.85,
        ),
        itemCount: _team.length,
        itemBuilder: (context, index) {
          final item = _team[index];
          if (item is! Map) return Container();

          final specialization = (item['specialization'] ?? '').toString();
          final years = (item['years_experience'] ?? '').toString();
          final avgRating = item['average_rating'];
          final totalRatings = item['total_ratings'];

          final user = (item['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          final name = (user['full_name'] ?? '').toString();
          final profilePicture = (user['profile_picture'] ?? '').toString();

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accent1.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // النصف العلوي: الصورة الدائرية
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: profilePicture.isNotEmpty
                            ? Image.network(
                                profilePicture, 
                                fit: BoxFit.cover,
                                width: 116,
                                height: 116,
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.person, 
                                  color: Colors.grey.shade400, 
                                  size: 60
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                
                // النصف السفلي: البيانات
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // الاسم
                        Text(
                          name.isNotEmpty ? name : 'Team Member',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // المنصب
                        Text(
                          specialization.isNotEmpty ? specialization : 'Specialist',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // الخط الفاصل
                        Container(
                          height: 1,
                          width: 40,
                          color: AppColors.accent1.withOpacity(0.3),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // سنوات الخبرة
                        if (years.isNotEmpty && years != '0')
                          Text(
                            '$years Years Experience',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGray.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}


  Widget _buildWebServicesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Our Services',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'Service details will be displayed here.',
          style: TextStyle(fontSize: 18, color: AppColors.textGray),
        ),
      ],
    );
  }

  Widget _buildWebReviewsTab({required String institutionName}) {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviews.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                const Icon(Icons.reviews, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                const Text(
                  'No reviews yet',
                  style: TextStyle(
                    fontSize: 24,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Be the first to review this institution',
                  style: TextStyle(fontSize: 18, color: AppColors.textGray),
                ),
                const SizedBox(height: 30),
                if (_canAddReview)
                  ElevatedButton.icon(
                    onPressed: _addReview,
                    icon: const Icon(Icons.add_comment_rounded, size: 24),
                    label: const Text('Add Your Review', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviews',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 40),
        
        // Stats
        if (_reviewStats != null)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Rating',
                      style: TextStyle(fontSize: 14, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _reviewStats!.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '/ 5.0',
                          style: TextStyle(fontSize: 20, color: AppColors.textGray),
                        ),
                      ],
                    ),
                  ],
                ),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Recommendation Rate',
                      style: TextStyle(fontSize: 14, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${((_reviewStats!.recommendations / _reviewStats!.totalReviews) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 40),
        
        // Add Review Button
        if (_canAddReview)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _addReview,
              icon: const Icon(Icons.add_comment_rounded, size: 24),
              label: const Text('Add Your Review', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
            ),
          ),
        
        const SizedBox(height: 40),
        
        // Reviews List
        ..._reviews.map((review) => _buildWebReviewCard(review)).toList(),
        
        // Pagination
        if (_totalReviewPages > 1) ...[
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentReviewPage > 1)
                OutlinedButton(
                  onPressed: () => _loadReviews(page: _currentReviewPage - 1),
                  child: const Text('Previous'),
                ),
              const SizedBox(width: 16),
              Text(
                'Page $_currentReviewPage of $_totalReviewPages',
                style: const TextStyle(fontSize: 16, color: AppColors.textGray),
              ),
              const SizedBox(width: 16),
              if (_currentReviewPage < _totalReviewPages)
                OutlinedButton(
                  onPressed: () => _loadReviews(page: _currentReviewPage + 1),
                  child: const Text('Next'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildWebReviewCard(InstitutionReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: review.parentAvatar != null
                    ? ClipOval(
                        child: Image.network(
                          review.parentAvatar!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Text(
                        review.parentName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.parentName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${review.basedOnVisits} visits',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        Icons.star,
                        size: 20,
                        color: index < review.overallRating.floor()
                            ? Colors.amber
                            : Colors.grey[300],
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          if (review.reviewText != null && review.reviewText!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              review.reviewText!,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textDark,
                height: 1.6,
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildWebReviewChip('Facilities', review.facilitiesRating),
              _buildWebReviewChip('Staff', review.staffRating),
              _buildWebReviewChip('Cleanliness', review.cleanlinessRating),
              _buildWebReviewChip('Accessibility', review.accessibilityRating),
            ],
          ),
          
          if (review.wouldRecommend) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.thumb_up, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Recommends this institution',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebReviewChip(String label, double rating) {
    Color getRatingColor(double rating) {
      if (rating >= 4) return AppColors.success;
      if (rating >= 3) return Colors.orange;
      return AppColors.error;
    }

    final color = getRatingColor(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: color),
          ),
          const SizedBox(width: 8),
          Icon(Icons.star, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebProgramsTab({required List programs}) {
    if (programs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Programs',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'No programs available',
              style: TextStyle(fontSize: 18, color: AppColors.textGray),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Our Programs',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 40),
        ...programs
            .whereType<Map>()
            .map((program) => _buildWebProgramCard(
                  title: (program['title'] ?? '').toString(),
                  description: (program['description'] ?? '').toString(),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildWebProgramCard({required String title, required String description}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textGray,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebProjectsTab({required List projects}) {
    if (projects.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Projects',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'No projects available',
              style: TextStyle(fontSize: 18, color: AppColors.textGray),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Our Projects',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 40),
        ...projects
            .whereType<Map>()
            .map((project) {
              final title = (project['title'] ?? '').toString();
              final desc = (project['description'] ?? '').toString();
              final status = (project['status'] ?? '').toString();
              final goal = project['goal_amount'];
              final raised = project['raised_amount'];

              String moneyLine() {
                if (goal == null && raised == null) return '';
                return 'Raised: ${raised ?? 0} / Goal: ${goal ?? 0}';
              }

              return _buildWebProjectCard(
                title: title,
                description: desc,
                status: status,
                moneyLine: moneyLine(),
              );
            })
            .toList(),
      ],
    );
  }

  Widget _buildWebProjectCard({
    required String title,
    required String description,
    required String status,
    required String moneyLine,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
            ],
          ),
          
          if (moneyLine.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              moneyLine,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textGray,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in progress':
        return Colors.orange;
      case 'planned':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildWebSessionsTab({required int institutionId}) {
    return FutureBuilder<List<dynamic>>(
      future: PublicInstitutionService.getInstitutionSessionTypes(institutionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Session Types',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error, size: 80, color: Colors.red),
                    const SizedBox(height: 20),
                    Text(
                      'Error: ${snapshot.error.toString().replaceAll('Exception: ', '')}',
                      style: const TextStyle(fontSize: 16, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Session Types',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.schedule, size: 80, color: Colors.grey),
                    const SizedBox(height: 20),
                    const Text(
                      'No session types available',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        
        final sessionTypes = snapshot.data!;
        
        // تعريف دالة المجموعة محلياً
        Map<String, List<dynamic>> groupByCategory(List<dynamic> sessionTypes) {
          final Map<String, List<dynamic>> result = {};
          
          for (final type in sessionTypes) {
            if (type is Map) {
              final category = (type['category'] ?? 'Other').toString();
              if (!result.containsKey(category)) {
                result[category] = [];
              }
              result[category]!.add(type);
            }
          }
          
          return result;
        }
        
        final categories = groupByCategory(sessionTypes);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Session Types',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 40),
            
            ...categories.entries.map((entry) {
              final category = entry.key;
              final types = entry.value;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: types.length,
                    itemBuilder: (context, index) {
                      final type = types[index];
                      return _buildWebSessionTypeCard(type);
                    },
                  ),
                  
                  const SizedBox(height: 40),
                ],
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildWebSessionTypeCard(Map<String, dynamic> type) {
    final name = (type['name'] ?? '').toString();
    final duration = (type['duration'] ?? 0) as int;
    final price = (type['price'] ?? 0.0) as double;
    final category = (type['category'] ?? '').toString();
    final specialization = (type['specialist_specialization'] ?? '').toString();
    final conditions = (type['target_conditions'] as List?) ?? [];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(Icons.timer, size: 16, color: AppColors.textGray),
              const SizedBox(width: 8),
              Text(
                '$duration mins',
                style: const TextStyle(color: AppColors.textGray),
              ),
              const Spacer(),
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          if (specialization.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.person, size: 16, color: AppColors.textGray),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    specialization,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
          if (conditions.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: conditions
                  .whereType<String>()
                  .take(3)
                  .map((condition) => Chip(
                        label: Text(condition),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebFooter(Map<String, dynamic> institution, String website, String contactEmail, String contactPhone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      color: Colors.grey.shade900,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (institution['name'] ?? widget.institutionName ?? '').toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        (institution['description'] ?? '').toString(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 80),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Us',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (contactPhone.isNotEmpty)
                      _buildWebFooterContact(Icons.phone, contactPhone),
                    if (contactEmail.isNotEmpty)
                      _buildWebFooterContact(Icons.email, contactEmail),
                    if (website.isNotEmpty)
                      GestureDetector(
                        onTap: () => _openUrl(website),
                        child: _buildWebFooterContact(Icons.language, website),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),
            Divider(color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text(
              '© 2024 ${(institution['name'] ?? widget.institutionName ?? '').toString()}. All rights reserved.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebFooterContact(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _buildMobileLayout({
    required BuildContext context,
    required Map<String, dynamic> institution,
    required List contentList,
    required List programs,
    required List projects,
    required List faq,
    required List news,
    required Map<String, dynamic> media,
    required String about,
    required String mission,
    required String ourWorld,
    required String website,
    required String contactEmail,
    required String contactPhone,
    required String coverUrl,
    required String logoUrl,
    required String introVideoUrl,
    required List gallery,
  }) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(widget.institutionName ?? 'Institution'),
        actions: [
          IconButton(
            tooltip: 'Ask AI',
            onPressed: _isLoadingAI
                ? null
                : () async {
                    setState(() => _isLoadingAI = true);
                    try {
                      await _openAIHelper();
                    } finally {
                      if (!mounted) return;
                      setState(() => _isLoadingAI = false);
                    }
                  },
            icon: _isLoadingAI
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.smart_toy_outlined),
          ),
          IconButton(
            tooltip: _isFollowing ? 'Unfollow' : 'Follow',
            onPressed: _isLoadingFollow ? null : _toggleFollow,
            icon: _isLoadingFollow
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(_isFollowing ? Icons.star : Icons.star_border),
          ),
          // في AppBar actions أضف:
IconButton(
  icon: const Icon(Icons.volunteer_activism),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuickDonationScreen(
          institutionId: widget.institutionId,
          institutionName: widget.institutionName ?? 'Institution',
        ),
      ),
    );
  },
  tooltip: 'Quick Donation',
),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _future = PublicInstitutionService.getInstitutionHome(widget.institutionId);
              });
              if (_selectedTab == 1) _loadTeam();
              if (_selectedTab == 3) _loadReviews();
            },
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Cover Photo with Donate Button
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      coverUrl.isNotEmpty
                          ? Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.primary.withOpacity(0.12)),
                            )
                          : Container(color: AppColors.primary.withOpacity(0.12)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.6),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: logoUrl.isNotEmpty
                                      ? Image.network(logoUrl, fit: BoxFit.cover)
                                      : Icon(Icons.apartment, color: AppColors.primary, size: 40),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (institution['name'] ?? widget.institutionName ?? '').toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      (institution['description'] ?? '').toString(),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _requireLogin(actionName: 'donate');
                                  if (!await _isLoggedIn()) return;
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CombinedEquipmentScreen(
                                        institutionId: widget.institutionId,
                                        institutionName: (institution['name'] ?? widget.institutionName)?.toString(),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.volunteer_activism, size: 20),
                                label: const Text('Donate Now', style: TextStyle(fontSize: 14)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Navigation
                Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton(0, Icons.info, 'Main Info'),
                        _buildTabButton(1, Icons.groups, 'Team'),
                        _buildTabButton(2, Icons.design_services, 'Services'),
                        _buildTabButton(3, Icons.star, 'Reviews'),
                        _buildTabButton(4, Icons.school, 'Programs'),
                        _buildTabButton(5, Icons.work, 'Projects'),
                        _buildTabButton(6, Icons.schedule, 'Sessions'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Tab Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTabContent(
                    context: context,
                    institution: institution,
                    contentList: contentList,
                    programs: programs,
                    projects: projects,
                    faq: faq,
                    news: news,
                    media: media,
                    about: about,
                    mission: mission,
                    ourWorld: ourWorld,
                    website: website,
                    contactEmail: contactEmail,
                    contactPhone: contactPhone,
                    coverUrl: coverUrl,
                    logoUrl: logoUrl,
                    introVideoUrl: introVideoUrl,
                    gallery: gallery,
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),

          // Fixed Apply Button at Bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _requireLogin(actionName: 'apply for registration');
                  if (!await _isLoggedIn()) return;
                  if (!mounted) return;
                  await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.background,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    builder: (_) => InstitutionRegistrationRequestSheet(
                      institutionId: widget.institutionId,
                      institutionName: (institution['name'] ?? widget.institutionName ?? 'Institution').toString(),
                    ),
                  );
                },
                icon: const Icon(Icons.assignment, size: 24),
                label: const Text('Apply for Registration', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return TextButton.icon(
      onPressed: () {
        setState(() => _selectedTab = index);
        if (index == 1 && _team.isEmpty) {
          _loadTeam();
        }
        if (index == 3 && _reviews.isEmpty) {
          _loadReviews();
        }
      },
      icon: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textGray,
        size: 20,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textGray,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildTabContent({
    required BuildContext context,
    required Map<String, dynamic> institution,
    required List contentList,
    required List programs,
    required List projects,
    required List faq,
    required List news,
    required Map<String, dynamic> media,
    required String about,
    required String mission,
    required String ourWorld,
    required String website,
    required String contactEmail,
    required String contactPhone,
    required String coverUrl,
    required String logoUrl,
    required String introVideoUrl,
    required List gallery,
  }) {
    switch (_selectedTab) {
      case 0: // Home
        return _buildMainInfoTab(
          about: about,
          mission: mission,
          ourWorld: ourWorld,
          website: website,
          contactEmail: contactEmail,
          contactPhone: contactPhone,
          gallery: gallery,
          faq: faq,
          news: news,
          introVideoUrl: introVideoUrl,
        );

      case 1: // Team
        return _buildTeamTab();

      case 2: // Services
        return _buildProgramsTab(programs: programs);

      case 3: // Reviews
        return _buildReviewsTab(
            institutionName: institution['name']?.toString() ??
                widget.institutionName ??
                'Institution');

      case 4: // Programs
        return _buildProgramsTab(programs: programs);

      case 5: // Projects
        return _buildProjectsTab(projects: projects);
      
      case 6: // Sessions
        return _buildSessionsTab(institutionId: widget.institutionId);

      default:
        return Container();
    }
  }

  Widget _buildMainInfoTab({
    required String about,
    required String mission,
    required String ourWorld,
    required String website,
    required String contactEmail,
    required String contactPhone,
    required List gallery,
    required List faq,
    required List news,
    required String introVideoUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (about.isNotEmpty) ...[
          _buildSection('About Us', Icons.info, about),
          const SizedBox(height: 20),
        ],
        if (mission.isNotEmpty) ...[
          _buildSection('Our Mission', Icons.flag, mission),
          const SizedBox(height: 20),
        ],
        if (introVideoUrl.isNotEmpty) ...[
          _buildSection(
            'Intro Video',
            Icons.play_circle,
            '',
            action: ElevatedButton.icon(
              onPressed: () => _openUrl(introVideoUrl),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Watch Video'),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (gallery.isNotEmpty) ...[
          _buildSection('Gallery', Icons.photo_library, ''),
          const SizedBox(height: 12),
          _buildGalleryGrid(gallery),
          const SizedBox(height: 20),
        ],
        if (ourWorld.isNotEmpty) ...[
          _buildSection('Our World', Icons.public, ourWorld),
          const SizedBox(height: 20),
        ],
        if (faq.isNotEmpty) ...[
          _buildSection('FAQ', Icons.help, ''),
          const SizedBox(height: 12),
          ..._buildFAQList(faq),
          const SizedBox(height: 20),
        ],
        if (news.isNotEmpty) ...[
          _buildSection('Latest News', Icons.article, ''),
          const SizedBox(height: 12),
          ..._buildNewsList(news),
          const SizedBox(height: 20),
        ],
        if (website.isNotEmpty ||
            contactEmail.isNotEmpty ||
            contactPhone.isNotEmpty) ...[
          _buildSection('Contact Information', Icons.contact_page, ''),
          const SizedBox(height: 12),
          _buildContactInfo(
            website: website,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
          ),
        ],
      ],
    );
  }

  Widget _buildTeamTab() {
  if (_team.isEmpty) {
    return FutureBuilder<void>(
      future: _loadTeam(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return const Center(
          child: Text('No team members available', style: TextStyle(color: AppColors.textGray)),
        );
      },
    );
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final crossAxisCount = isMobile ? 1 : 2;
      
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: _team.length,
        itemBuilder: (context, index) {
          final item = _team[index];
          if (item is! Map) return const SizedBox();

          final specialization = (item['specialization'] ?? '').toString();
          final years = (item['years_experience'] ?? '').toString();
          final avgRating = item['average_rating'];
          final totalRatings = item['total_ratings'];

          final user = (item['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          final name = (user['full_name'] ?? '').toString();
          final profilePicture = (user['profile_picture'] ?? '').toString();

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accent1.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // الجزء العلوي للصورة الدائرية
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: profilePicture.isNotEmpty
                            ? Image.network(
                                profilePicture, 
                                fit: BoxFit.cover,
                                width: 76,
                                height: 76,
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.person, 
                                  color: Colors.grey.shade400, 
                                  size: 40
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                
                // الجزء السفلي للبيانات
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // الاسم
                        Text(
                          name.isNotEmpty ? name : 'Team Member',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // المنصب
                        Text(
                          specialization.isNotEmpty ? specialization : 'Specialist',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // الخط الفاصل
                        Container(
                          height: 1,
                          width: 30,
                          color: AppColors.accent1.withOpacity(0.3),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // سنوات الخبرة
                        if (years.isNotEmpty && years != '0')
                          Text(
                            '$years Years Experience',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textGray.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}


  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab({required int institutionId}) {
    return FutureBuilder<List<dynamic>>(
      future: PublicInstitutionService.getInstitutionSessionTypes(institutionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load session types',
                  style: TextStyle(color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString().replaceAll('Exception: ', ''),
                  style: const TextStyle(color: AppColors.textGray),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              children: [
                const Icon(Icons.schedule, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No session types available',
                  style: TextStyle(color: AppColors.textGray),
                ),
              ],
            ),
          );
        }
        
        final sessionTypes = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Session Types',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sessionTypes.length,
              itemBuilder: (context, index) {
                final type = sessionTypes[index];
                if (type is! Map) return const SizedBox();
                
                final name = (type['name'] ?? '').toString();
                final duration = (type['duration'] ?? 0) as int;
                final price = (type['price'] ?? 0.0) as double;
                final category = (type['category'] ?? '').toString();
                final specialization = (type['specialist_specialization'] ?? '').toString();
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '\$${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Icon(Icons.timer, size: 16, color: AppColors.textGray),
                          const SizedBox(width: 4),
                          Text(
                            '$duration mins',
                            style: const TextStyle(color: AppColors.textGray),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.person, size: 16, color: AppColors.textGray),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              specialization,
                              style: const TextStyle(color: AppColors.textGray),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      if (type['target_conditions'] != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: (type['target_conditions'] as List?)
                              ?.whereType<String>()
                              .take(3)
                              .map((condition) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      condition,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGray,
                                      ),
                                    ),
                                  ))
                              .toList() ??
                              [],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewsTab({required String institutionName}) {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviews.isEmpty) {
      return Column(
        children: [
          if (_reviewStats != null) _buildReviewStats(_reviewStats!),
          const SizedBox(height: 20),
          const Center(
            child: Column(
              children: [
                Icon(Icons.reviews, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No reviews yet',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to review this institution',
                  style: TextStyle(color: AppColors.textGray),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_canAddReview)
            ElevatedButton.icon(
              onPressed: _addReview,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Add Review'),
            ),
        ],
      );
    }

    return Column(
      children: [
        if (_reviewStats != null) _buildReviewStats(_reviewStats!),
        const SizedBox(height: 20),
        if (_canAddReview)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: _addReview,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Add Your Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: Size(kIsWeb ? 300 : double.infinity, 50),
              ),
            ),
          ),
        ..._reviews.map((review) => _buildReviewCard(review)).toList(),
        if (_totalReviewPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_currentReviewPage > 1)
                  IconButton(
                    onPressed: () => _loadReviews(page: _currentReviewPage - 1),
                    icon: Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.primary),
                  ),
                Text(
                  'Page $_currentReviewPage of $_totalReviewPages',
                  style: const TextStyle(color: AppColors.textGray),
                ),
                if (_currentReviewPage < _totalReviewPages)
                  IconButton(
                    onPressed: () => _loadReviews(page: _currentReviewPage + 1),
                    icon: Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.primary),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReviewStats(InstitutionReviewStats stats) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall rating',
                      style: TextStyle(color: AppColors.textGray, fontSize: 14),
                    ),
                    Row(
                      children: [
                        Text(
                          stats.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '/ 5.0',
                          style: TextStyle(
                              color: AppColors.textGray, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          Icons.star_rounded,
                          size: 24,
                          color: index < stats.averageRating.floor()
                              ? Colors.amber
                              : Colors.grey[300],
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.totalReviews} reviews',
                      style: const TextStyle(
                          color: AppColors.textGray, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recommendation rate',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                  Text(
                    '${((stats.recommendations / stats.totalReviews) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ));
  }

  Widget _buildReviewCard(InstitutionReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: review.parentAvatar != null
                    ? ClipOval(
                        child: Image.network(
                          review.parentAvatar!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Text(
                        review.parentName[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primary),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.parentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${review.basedOnVisits} visits',
                      style: const TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: index < review.overallRating.floor()
                            ? Colors.amber
                            : Colors.grey[300],
                      );
                    }),
                  ),
                  Text(
                    '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (review.reviewText != null && review.reviewText!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.reviewText!,
                  style: const TextStyle(
                      color: AppColors.textDark, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
              ],
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildReviewChip('Facilities', review.facilitiesRating),
              _buildReviewChip('Staff', review.staffRating),
              _buildReviewChip('Cleanliness', review.cleanlinessRating),
              _buildReviewChip('Accessibility', review.accessibilityRating),
            ],
          ),
          if (review.wouldRecommend)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.thumb_up, size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  const Text(
                    'Recommends this institution',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewChip(String label, double rating) {
    Color getRatingColor(double rating) {
      if (rating >= 4) return AppColors.success;
      if (rating >= 3) return Colors.orange;
      return AppColors.error;
    }

    final color = getRatingColor(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
          const SizedBox(width: 4),
          Icon(Icons.star_rounded, size: 12, color: color),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramsTab({required List programs}) {
    if (programs.isEmpty) {
      return const Center(
        child: Text('No programs available',
            style: TextStyle(color: AppColors.textGray)),
      );
    }

    return Column(
      children: programs
          .whereType<Map>()
          .map((program) => _ListItemCard(
                title: (program['title'] ?? '').toString(),
                subtitle: (program['description'] ?? '').toString(),
              ))
          .toList(),
    );
  }

  Widget _buildProjectsTab({required List projects}) {
    if (projects.isEmpty) {
      return const Center(
        child: Text('No projects available',
            style: TextStyle(color: AppColors.textGray)),
      );
    }

    return Column(
      children: projects.whereType<Map>().map((project) {
        final title = (project['title'] ?? '').toString();
        final desc = (project['description'] ?? '').toString();
        final status = (project['status'] ?? '').toString();
        final goal = project['goal_amount'];
        final raised = project['raised_amount'];

        String moneyLine() {
          if (goal == null && raised == null) return '';
          return 'Raised: ${raised ?? 0} / Goal: ${goal ?? 0}';
        }

        return _ListItemCard(
          title: title,
          subtitle: [
            if (status.isNotEmpty) 'Status: $status',
            if (moneyLine().isNotEmpty) moneyLine(),
            if (desc.isNotEmpty) desc,
          ].join('\n'),
        );
      }).toList(),
    );
  }

  Widget _buildSection(String title, IconData icon, String content,
      {Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(color: AppColors.textDark, height: 1.4),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 12),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(List gallery) {
    final urls = gallery
        .whereType<Map>()
        .map((m) => (m['url'] ?? '').toString())
        .where((u) => u.trim().isNotEmpty)
        .toList();

    if (urls.isEmpty) return Container();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: urls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                child: Image.network(
                  urls[index],
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              urls[index],
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildFAQList(List faq) {
    return faq
        .whereType<Map>()
        .take(3)
        .map((item) => _FaqTile(
              question: (item['question'] ?? '').toString(),
              answer: (item['answer'] ?? '').toString(),
            ))
        .toList();
  }

  List<Widget> _buildNewsList(List news) {
    return news
        .whereType<Map>()
        .take(3)
        .map((item) => _ListItemCard(
              title: (item['title'] ?? '').toString(),
              subtitle: ((item['summary'] ?? item['content']) ?? '').toString(),
            ))
        .toList();
  }

  Widget _buildContactInfo({
    required String website,
    required String contactEmail,
    required String contactPhone,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (website.isNotEmpty)
            _ContactRow(
              icon: Icons.language,
              label: 'Website',
              value: website,
              onTap: () => _openUrl(website),
            ),
          if (contactEmail.isNotEmpty) const SizedBox(height: 12),
          if (contactEmail.isNotEmpty)
            _ContactRow(
              icon: Icons.email,
              label: 'Email',
              value: contactEmail,
            ),
          if (contactPhone.isNotEmpty) const SizedBox(height: 12),
          if (contactPhone.isNotEmpty)
            _ContactRow(
              icon: Icons.phone,
              label: 'Phone',
              value: contactPhone,
            ),
        ],
      ),
    );
  }
}

// ===================== Helper Widgets =====================

class _ListItemCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ListItemCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textGray,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent1.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          question,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(color: AppColors.textGray, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onTap,
                child: Text(
                  value,
                  style: TextStyle(
                    color:
                        onTap != null ? AppColors.primary : AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    decoration: onTap != null
                        ? TextDecoration.underline
                        : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}