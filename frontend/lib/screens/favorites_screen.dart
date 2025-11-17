import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class FavoritesScreen extends StatefulWidget {
  final List<dynamic>? allResources;
  
  const FavoritesScreen({super.key, this.allResources});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<String> favoriteLinks = [];
  List<Map<String, dynamic>> favoriteResources = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    favoriteLinks = prefs.getStringList('favorites') ?? [];
    
    // Filter resources based on favorite links
    if (widget.allResources != null) {
      favoriteResources = widget.allResources!
          .where((r) => favoriteLinks.contains(r['link']))
          .cast<Map<String, dynamic>>()
          .toList();
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _removeFavorite(String link) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteLinks.remove(link);
      favoriteResources.removeWhere((r) => r['link'] == link);
    });
    await prefs.setStringList('favorites', favoriteLinks);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Removed from favorites'),
            ],
          ),
          backgroundColor: AppColors.textGray,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearAllFavorites() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Favorites?'),
        content: Text('Are you sure you want to remove all favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        favoriteLinks.clear();
        favoriteResources.clear();
      });
      await prefs.remove('favorites');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All favorites cleared'),
            backgroundColor: AppColors.textGray,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white),
            SizedBox(width: 8),
            Text('My Favorites'),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 2,
        actions: [
          if (favoriteLinks.isNotEmpty)
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${favoriteLinks.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          if (favoriteLinks.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              tooltip: 'Clear All',
              onPressed: _clearAllFavorites,
            ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : favoriteLinks.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 100,
              color: AppColors.textGray.withOpacity(0.5),
            ),
            SizedBox(height: 24),
            Text(
              'No Favorites Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Start adding resources to your favorites to see them here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back),
              label: Text('Browse Resources'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: favoriteResources.length,
      itemBuilder: (context, index) {
        final resource = favoriteResources[index];
        final link = resource['link'] ?? '';
        
        // Determine icon based on type
        IconData typeIcon = Icons.article_outlined;
        if (resource['type'] == 'Video') {
          typeIcon = Icons.play_circle_outline;
        } else if (resource['type'] == 'PDF') {
          typeIcon = Icons.picture_as_pdf;
        }
        
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => launchUrl(Uri.parse(link)),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent1,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      typeIcon,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                resource['title'] ?? 'Educational Resource',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 20,
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          resource['description'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (resource['source'] != null)
                              _buildChip(
                                Icons.verified,
                                resource['source'],
                                Colors.blue[700]!,
                              ),
                            if (resource['skill_type'] != null)
                              _buildChip(
                                Icons.category_outlined,
                                resource['skill_type'],
                                AppColors.primary,
                              ),
                            if (resource['age_group'] != null)
                              _buildChip(
                                Icons.child_care,
                                resource['age_group'],
                                AppColors.primaryDark,
                              ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => launchUrl(Uri.parse(link)),
                                icon: Icon(Icons.open_in_new, size: 16),
                                label: Text('Open'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _removeFavorite(link),
                              icon: Icon(Icons.delete_outline, size: 16),
                              label: Text('Remove'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
