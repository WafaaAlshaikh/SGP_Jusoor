import 'package:flutter/material.dart';

import '../services/public_institution_service.dart';
import '../theme/app_colors.dart';

class PublicInstitutionTeamScreen extends StatefulWidget {
  final int institutionId;
  final String? institutionName;

  const PublicInstitutionTeamScreen({
    super.key,
    required this.institutionId,
    this.institutionName,
  });

  @override
  State<PublicInstitutionTeamScreen> createState() => _PublicInstitutionTeamScreenState();
}

class _PublicInstitutionTeamScreenState extends State<PublicInstitutionTeamScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = PublicInstitutionService.getInstitutionTeam(widget.institutionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(widget.institutionName != null ? '${widget.institutionName} Team' : 'Team'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() => _future = PublicInstitutionService.getInstitutionTeam(widget.institutionId)),
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
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
                    const Text(
                      'Failed to load team',
                      style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800),
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
                      onPressed: () => setState(() => _future = PublicInstitutionService.getInstitutionTeam(widget.institutionId)),
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
            );
          }

          final list = snapshot.data ?? const [];

          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No approved specialists found yet.',
                  style: TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              if (item is! Map) return const SizedBox();

              final specialization = (item['specialization'] ?? '').toString();
              final years = (item['years_experience'] ?? '').toString();
              final avgRating = item['average_rating'];
              final totalRatings = item['total_ratings'];

              final user = (item['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
              final name = (user['full_name'] ?? '').toString();
              final profilePicture = (user['profile_picture'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.accent1,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent2.withOpacity(0.8)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: profilePicture.trim().isNotEmpty
                            ? Image.network(profilePicture, fit: BoxFit.cover)
                            : Icon(Icons.person, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : 'Specialist',
                            style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900),
                          ),
                          if (specialization.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              specialization,
                              style: const TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w700),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (years.isNotEmpty)
                                _Pill(label: '$years years', color: AppColors.info),
                              if (avgRating != null)
                                _Pill(label: '★ ${avgRating.toString()}', color: AppColors.warning),
                              if (totalRatings != null)
                                _Pill(label: '${totalRatings.toString()} reviews', color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
