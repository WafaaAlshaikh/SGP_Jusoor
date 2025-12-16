// screens/financial_assessment/recommended_institutions_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recommended_institution_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class RecommendedInstitutionsScreen extends StatefulWidget {
  final String financialTier;
  final double discountPercentage;

  const RecommendedInstitutionsScreen({
    super.key,
    required this.financialTier,
    required this.discountPercentage,
  });

  @override
  State<RecommendedInstitutionsScreen> createState() => _RecommendedInstitutionsScreenState();
}

class _RecommendedInstitutionsScreenState extends State<RecommendedInstitutionsScreen> {
  List<RecommendedInstitution> _institutions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _sortBy = 'compatibility'; // 'compatibility', 'price', 'discount'

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await ApiService.getRecommendedInstitutionsByTier(
        token,
        widget.financialTier,
        widget.discountPercentage,
      );

      if (response['success'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        _institutions = data
            .map((i) => RecommendedInstitution.fromJson(i))
            .toList();
        
        // Sort by selected criteria
        _sortInstitutions();
      } else {
        throw Exception(response['message'] ?? 'Failed to load institutions');
      }

      setState(() { _isLoading = false; });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load institutions: $e';
      });
    }
  }

  void _sortInstitutions() {
    setState(() {
      switch (_sortBy) {
        case 'compatibility':
          _institutions.sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));
          break;
        case 'price':
          _institutions.sort((a, b) => a.averageSessionPrice.compareTo(b.averageSessionPrice));
          break;
        case 'discount':
          _institutions.sort((a, b) => b.estimatedDiscount.average.compareTo(a.estimatedDiscount.average));
          break;
      }
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 20),
              
              ListTile(
                leading: Icon(Icons.thumb_up, color: _sortBy == 'compatibility' ? AppColors.primary : Colors.grey),
                title: Text('Best Match'),
                trailing: _sortBy == 'compatibility' ? Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() { _sortBy = 'compatibility'; });
                  _sortInstitutions();
                  Navigator.pop(context);
                },
              ),
              
              ListTile(
                leading: Icon(Icons.attach_money, color: _sortBy == 'price' ? AppColors.primary : Colors.grey),
                title: Text('Lowest Price'),
                trailing: _sortBy == 'price' ? Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() { _sortBy = 'price'; });
                  _sortInstitutions();
                  Navigator.pop(context);
                },
              ),
              
              ListTile(
                leading: Icon(Icons.discount, color: _sortBy == 'discount' ? AppColors.primary : Colors.grey),
                title: Text('Highest Discount'),
                trailing: _sortBy == 'discount' ? Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() { _sortBy = 'discount'; });
                  _sortInstitutions();
                  Navigator.pop(context);
                },
              ),
              
              SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstitutionCard(RecommendedInstitution institution, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showInstitutionDetails(institution);
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and match score
              Row(
                children: [
                  Expanded(
                    child: Text(
                      institution.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: institution.compatibilityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      institution.compatibilityText,
                      style: TextStyle(
                        fontSize: 12,
                        color: institution.compatibilityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Location and city
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: AppColors.textGray),
                  SizedBox(width: 4),
                  Text(
                    institution.city,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                    ),
                  ),
                  if (institution.address != null) ...[
                    SizedBox(width: 4),
                    Text(
                      '• ${institution.address!}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              
              SizedBox(height: 8),
              
              // Specializations
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: institution.specializations.map((spec) {
                  return Chip(
                    label: Text(
                      spec,
                      style: TextStyle(fontSize: 11),
                    ),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    labelPadding: EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              
              SizedBox(height: 12),
              
              // Stats row
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Price
                    Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_money, size: 14, color: AppColors.textGray),
                            SizedBox(width: 4),
                            Text(
                              'Session',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          institution.priceText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    
                    // Discount
                    Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.discount, size: 14, color: AppColors.success),
                            SizedBox(width: 4),
                            Text(
                              'Discount',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          institution.estimatedDiscount.rangeText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    
                    // Processing time
                    Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 14, color: AppColors.textGray),
                            SizedBox(width: 4),
                            Text(
                              'Processing',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          institution.processingText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Financial aid indicator
              if (institution.financialAid)
                Row(
                  children: [
                    Icon(Icons.verified_user, size: 14, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'Financial aid available',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInstitutionDetails(RecommendedInstitution institution) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              
              // Institution name
              Text(
                institution.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 8),
              
              // Location
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 16, color: AppColors.textGray),
                  SizedBox(width: 4),
                  Text(
                    '${institution.city}${institution.address != null ? ', ${institution.address!}' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Match score
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compatibility Score',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textGray,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  institution.compatibilityText,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: institution.compatibilityColor,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Financial Tier Match',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textGray,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  widget.financialTier.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Specializations
                      Text(
                        'Specializations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: institution.specializations.map((spec) {
                          return Chip(
                            label: Text(spec),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                          );
                        }).toList(),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Financial Details
                      Text(
                        'Financial Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Average Session Price', style: TextStyle(fontSize: 14)),
                                Text(
                                  institution.priceText,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Estimated Discount Range', style: TextStyle(fontSize: 14)),
                                Text(
                                  institution.estimatedDiscount.rangeText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Average Discount', style: TextStyle(fontSize: 14)),
                                Text(
                                  institution.estimatedDiscount.averageText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Processing Time', style: TextStyle(fontSize: 14)),
                                Text(
                                  institution.processingText,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Financial Aid Status
                      if (institution.financialAid)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified_user, color: Colors.green),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This institution offers financial assistance programs for eligible families.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // يمكن إضافة تنقل لطلب المساعدة
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: Text('Select'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recommended Institutions'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showSortOptions,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textGray),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadInstitutions,
                          child: Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _institutions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business, size: 64, color: AppColors.textLight),
                          SizedBox(height: 16),
                          Text(
                            'No institutions found',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.textGray,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try completing a financial assessment first',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Go Back'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header info
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: AppColors.info),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_institutions.length} institutions match your financial profile',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Institutions list
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadInstitutions,
                            child: ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: _institutions.length,
                              itemBuilder: (context, index) {
                                return _buildInstitutionCard(_institutions[index], index);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}