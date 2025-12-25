import 'package:flutter/material.dart';
import 'package:frontend/services/public_institution_service.dart';
import 'package:frontend/theme/app_colors.dart';
import 'institution_reviews_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicInstitutionProfileScreen extends StatefulWidget {
  final int institutionId;
  final String? institutionName;

  const PublicInstitutionProfileScreen({
    super.key,
    required this.institutionId,
    this.institutionName,
  });

  @override
  State<PublicInstitutionProfileScreen> createState() => _PublicInstitutionProfileScreenState();
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent1.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _PublicInstitutionProfileScreenState extends State<PublicInstitutionProfileScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = PublicInstitutionService.getInstitutionProfile(widget.institutionId);
  }

  void _reload() {
    setState(() {
      _future = PublicInstitutionService.getInstitutionProfile(widget.institutionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.institutionName ?? 'Institution'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 44, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reload,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Try again', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data ?? <String, dynamic>{};
          final institution = (data['institution'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          final media = (data['media'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          final reviewsSummary = (data['reviews_summary'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          final teamSummary = (data['team_summary'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
          final publicStats = (data['public_stats'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

          final name = (institution['name'] ?? widget.institutionName ?? 'Institution').toString();
          final city = (institution['city'] ?? '').toString();
          final region = (institution['region'] ?? '').toString();
          final description = (institution['description'] ?? '').toString();

          final services = (institution['services_offered'] is List)
              ? List<String>.from(institution['services_offered'])
              : <String>[];
          final conditions = (institution['conditions_supported'] is List)
              ? List<String>.from(institution['conditions_supported'])
              : <String>[];

          final String? coverUrl = media['cover_url']?.toString();
          final String? logoUrl = media['logo_url']?.toString();
          final String? introVideoUrl = media['intro_video_url']?.toString();
          final List gallery = (media['gallery'] is List) ? media['gallery'] as List : [];

          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                _Header(
                  name: name,
                  locationText: [city, region].where((s) => s.trim().isNotEmpty).join(' - '),
                  coverUrl: coverUrl,
                  logoUrl: logoUrl,
                  averageRating: double.tryParse('${reviewsSummary['average_rating'] ?? 0}') ?? 0.0,
                  totalReviews: int.tryParse('${reviewsSummary['total_reviews'] ?? 0}') ?? 0,
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textLight,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Media'),
                      Tab(text: 'Team'),
                      Tab(text: 'Reviews'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OverviewTab(
                        description: description,
                        services: services,
                        conditions: conditions,
                        institution: institution,
                        publicStats: publicStats,
                      ),
                      _MediaTab(
                        introVideoUrl: introVideoUrl,
                        logoUrl: logoUrl,
                        coverUrl: coverUrl,
                        gallery: gallery,
                      ),
                      _TeamTab(teamSummary: teamSummary),
                      _ReviewsTab(
                        institutionId: widget.institutionId,
                        institutionName: name,
                        reviewsSummary: reviewsSummary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String locationText;
  final String? coverUrl;
  final String? logoUrl;
  final double averageRating;
  final int totalReviews;

  const _Header({
    required this.name,
    required this.locationText,
    required this.coverUrl,
    required this.logoUrl,
    required this.averageRating,
    required this.totalReviews,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = coverUrl != null && coverUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 170,
      color: AppColors.primaryDark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCover)
            Image.network(
              coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDark.withOpacity(0.15),
                  AppColors.primaryDark.withOpacity(0.85),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: (logoUrl != null && logoUrl!.isNotEmpty)
                        ? Image.network(
                            logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.business, color: Colors.white, size: 30),
                          )
                        : const Icon(Icons.business, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (locationText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 15, color: Colors.white.withOpacity(0.85)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                locationText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _RatingPill(averageRating: averageRating, totalReviews: totalReviews),
                          if (hasCover) _CoverHintPill(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      color: AppColors.primaryDark,
      child: const Center(
        child: Icon(Icons.apartment, color: Colors.white70, size: 50),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double averageRating;
  final int totalReviews;

  const _RatingPill({required this.averageRating, required this.totalReviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 16, color: Colors.amber),
          const SizedBox(width: 6),
          Text(
            (averageRating > 0 ? averageRating.toStringAsFixed(1) : '0.0'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          Text(
            '($totalReviews)',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CoverHintPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image, size: 16, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 6),
          Text(
            'Media available',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final String description;
  final List<String> services;
  final List<String> conditions;
  final Map<String, dynamic> institution;
  final Map<String, dynamic> publicStats;

  const _OverviewTab({
    required this.description,
    required this.services,
    required this.conditions,
    required this.institution,
    required this.publicStats,
  });

  @override
  Widget build(BuildContext context) {
    final contactEmail = (institution['contact_email'] ?? '').toString();
    final contactPhone = (institution['contact_phone'] ?? '').toString();
    final address = (institution['location_address'] ?? '').toString();

    final website = (institution['website'] ?? '').toString();
    final licenseNumber = (institution['license_number'] ?? '').toString();
    final establishedYear = (institution['established_year'] ?? '').toString();

    final childrenCount = int.tryParse('${publicStats['children_count'] ?? 0}') ?? 0;
    final completedSessions = int.tryParse('${publicStats['completed_sessions_count'] ?? 0}') ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (description.trim().isNotEmpty)
          _SectionCard(
            title: 'About',
            icon: Icons.info_outline,
            child: Text(
              description,
              style: const TextStyle(height: 1.45, color: AppColors.textDark),
            ),
          ),
        _SectionCard(
          title: 'Quick stats',
          icon: Icons.insights,
          child: _StatsRow(childrenCount: childrenCount, completedSessions: completedSessions),
        ),
        _SectionCard(
          title: 'Contact & location',
          icon: Icons.contact_mail,
          child: Column(
            children: [
              _DetailTile(icon: Icons.map, label: 'Address', value: address),
              _DetailTile(icon: Icons.email, label: 'Email', value: contactEmail),
              _DetailTile(icon: Icons.phone, label: 'Phone', value: contactPhone),
              _DetailTile(icon: Icons.language, label: 'Website', value: website),
            ],
          ),
        ),
        if (licenseNumber.trim().isNotEmpty || establishedYear.trim().isNotEmpty)
          _SectionCard(
            title: 'Institution info',
            icon: Icons.badge,
            child: Column(
              children: [
                _DetailTile(icon: Icons.verified, label: 'License', value: licenseNumber),
                _DetailTile(icon: Icons.event, label: 'Established', value: establishedYear),
              ],
            ),
          ),
        if (services.isNotEmpty)
          _SectionCard(
            title: 'Services',
            icon: Icons.medical_services,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services
                  .map(
                    (s) => Chip(
                      label: Text(s),
                      backgroundColor: AppColors.accent1,
                      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      side: BorderSide(color: AppColors.accent3.withOpacity(0.6)),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (conditions.isNotEmpty)
          _SectionCard(
            title: 'Conditions supported',
            icon: Icons.healing,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: conditions
                  .map(
                    (c) => Chip(
                      label: Text(c),
                      backgroundColor: AppColors.accent2,
                      labelStyle: const TextStyle(color: AppColors.darkGreen, fontWeight: FontWeight.w700),
                      side: BorderSide(color: AppColors.accent3.withOpacity(0.6)),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _MediaTab extends StatelessWidget {
  final String? introVideoUrl;
  final String? logoUrl;
  final String? coverUrl;
  final List gallery;

  const _MediaTab({
    required this.introVideoUrl,
    required this.logoUrl,
    required this.coverUrl,
    required this.gallery,
  });

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if ((logoUrl != null && logoUrl!.isNotEmpty) || (coverUrl != null && coverUrl!.isNotEmpty))
          _SectionCard(
            title: 'Branding',
            icon: Icons.image,
            child: Column(
              children: [
                if (logoUrl != null && logoUrl!.isNotEmpty)
                  _MediaImageTile(
                    title: 'Logo',
                    url: logoUrl!,
                  ),
                if (coverUrl != null && coverUrl!.isNotEmpty)
                  _MediaImageTile(
                    title: 'Cover',
                    url: coverUrl!,
                  ),
              ],
            ),
          ),
        if (introVideoUrl != null && introVideoUrl!.isNotEmpty)
          _SectionCard(
            title: 'Intro video',
            icon: Icons.play_circle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  introVideoUrl!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(context, introVideoUrl!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.open_in_new, color: Colors.white, size: 18),
                    label: const Text('Open', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                )
              ],
            ),
          ),
        _SectionCard(
          title: 'Gallery',
          icon: Icons.photo_library,
          child: gallery.isEmpty
              ? const Text('No media yet', style: TextStyle(color: AppColors.textGray))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: gallery.length,
                  itemBuilder: (context, index) {
                    final item = (gallery[index] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
                    final url = (item['url'] ?? '').toString();
                    if (url.isEmpty) return const SizedBox();
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FullScreenImageViewer(
                              title: 'Gallery',
                              imageUrl: url,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.accent1,
                            child: const Icon(Icons.broken_image, color: AppColors.textLight),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MediaImageTile extends StatelessWidget {
  final String title;
  final String url;

  const _MediaImageTile({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FullScreenImageViewer(
                title: title,
                imageUrl: url,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.accent1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent2.withOpacity(0.6)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.accent1,
                    child: const Icon(Icons.broken_image, color: AppColors.textLight, size: 30),
                  ),
                ),
                Container(
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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

class _FullScreenImageViewer extends StatelessWidget {
  final String title;
  final String imageUrl;

  const _FullScreenImageViewer({required this.title, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70, size: 48),
          ),
        ),
      ),
    );
  }
}

class _TeamTab extends StatelessWidget {
  final Map<String, dynamic> teamSummary;

  const _TeamTab({required this.teamSummary});

  @override
  Widget build(BuildContext context) {
    final total = int.tryParse('${teamSummary['total_specialists'] ?? 0}') ?? 0;
    final avgExp = teamSummary['avg_years_experience'];
    final specialties = (teamSummary['specialties'] is List) ? List<String>.from(teamSummary['specialties']) : <String>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Team summary',
          icon: Icons.groups,
          child: Column(
            children: [
              _DetailTile(icon: Icons.people, label: 'Total specialists', value: total.toString()),
              _DetailTile(icon: Icons.timeline, label: 'Avg experience (years)', value: avgExp == null ? 'N/A' : avgExp.toString()),
            ],
          ),
        ),
        _SectionCard(
          title: 'Specialties',
          icon: Icons.auto_awesome,
          child: specialties.isEmpty
              ? const Text('No specialties listed', style: TextStyle(color: AppColors.textGray))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: specialties
                      .map(
                        (s) => Chip(
                          label: Text(s),
                          backgroundColor: AppColors.accent1,
                          labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          side: BorderSide(color: AppColors.accent3.withOpacity(0.6)),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  final int institutionId;
  final String institutionName;
  final Map<String, dynamic> reviewsSummary;

  const _ReviewsTab({
    required this.institutionId,
    required this.institutionName,
    required this.reviewsSummary,
  });

  @override
  Widget build(BuildContext context) {
    final avg = double.tryParse('${reviewsSummary['average_rating'] ?? 0}') ?? 0.0;
    final total = int.tryParse('${reviewsSummary['total_reviews'] ?? 0}') ?? 0;
    final recRate = int.tryParse('${reviewsSummary['recommendation_rate'] ?? 0}') ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Ratings',
          icon: Icons.star_rate,
          child: Column(
            children: [
              _DetailTile(icon: Icons.star, label: 'Average rating', value: avg.toStringAsFixed(1)),
              _DetailTile(icon: Icons.rate_review, label: 'Total reviews', value: total.toString()),
              _DetailTile(icon: Icons.thumb_up, label: 'Recommendation rate', value: '$recRate%'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InstitutionReviewsScreen(
                    institutionId: institutionId.toString(),
                    institutionName: institutionName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.reviews, color: Colors.white),
            label: const Text('View reviews', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int childrenCount;
  final int completedSessions;

  const _StatsRow({required this.childrenCount, required this.completedSessions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Children',
            value: childrenCount.toString(),
            icon: Icons.child_care,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Completed sessions',
            value: completedSessions.toString(),
            icon: Icons.check_circle,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
