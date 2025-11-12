import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' show cos, sqrt, asin;
import 'dart:async';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import 'map_screen.dart';
import 'institution_reviews_screen.dart';

class BrowseCentersScreen extends StatefulWidget {
  const BrowseCentersScreen({Key? key}) : super(key: key);

  @override
  State<BrowseCentersScreen> createState() => _BrowseCentersScreenState();
}

class _BrowseCentersScreenState extends State<BrowseCentersScreen> {
  List<dynamic> _allInstitutions = [];
  List<dynamic> _filteredInstitutions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // Basic Filters
  String _sortBy = 'name'; // name, rating, price, distance
  
  // Advanced Filters
  bool _showAdvancedFilters = false;
  double _minRating = 0.0;
  RangeValues _priceRange = const RangeValues(0, 1000);
  List<String> _selectedConditions = [];
  List<String> _selectedServiceTypes = [];
  String _selectedCity = 'All';
  
  // Available options
  final List<String> _availableConditions = [
    'Autism', 'ADHD', 'Down Syndrome', 'Speech Delay',
    'Learning Disabilities', 'Cerebral Palsy', 'Behavioral Issues',
  ];
  
  final List<String> _availableServices = [
    'Speech Therapy', 'Occupational Therapy', 'Behavioral Therapy',
    'Physical Therapy', 'Educational Support', 'Psychological Counseling',
  ];
  
  List<String> _availableCities = ['All'];
  
  // User location for distance sorting
  double? _userLat;
  double? _userLng;
  String? _userLocationName;

  // AI Recommendations
  bool _showAIRecommendations = false;
  bool _isLoadingAI = false;
  String? _aiSummary;
  Map<int, int> _matchScores = {}; // institution_id -> score
  Map<int, String> _aiReasonings = {}; // institution_id -> reasoning

  // Debouncer for filter updates
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInstitutions() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        throw Exception('Please login first to view centers');
      }

      print('🔑 Token: ${token.length > 20 ? token.substring(0, 20) : token}...');
      print('🌐 Loading institutions...');

      final response = await ApiService.getInstitutions(token);
      
      print('✅ Received ${response.length} institutions');
      if (response.isNotEmpty) {
        print('📊 Sample: ${response[0]['name']} - ${response[0]['city']}');
      }
      
      setState(() {
        _allInstitutions = response;
        _filteredInstitutions = response;
        _extractCities();
        _isLoading = false;
      });
      
      print('🎯 Before filters: ${_filteredInstitutions.length}');
      _applyFilters();
      print('🎯 After filters: ${_filteredInstitutions.length}');
    } catch (e) {
      print('❌ Error loading institutions: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load centers: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _extractCities() {
    final cities = _allInstitutions
        .map((inst) => inst['city']?.toString() ?? '')
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList();
    
    setState(() => _availableCities = ['All', ...cities]);
  }

  void _applyFiltersDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }

  void _applyFilters() {
    if (!mounted) return; // Safety check
    
    print('\n🔍 Applying Filters...');
    print('Starting with: ${_allInstitutions.length} institutions');
    
    List<dynamic> filtered = List.from(_allInstitutions);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((inst) {
        final name = inst['name']?.toString().toLowerCase() ?? '';
        final city = inst['city']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || city.contains(query);
      }).toList();
      print('After search: ${filtered.length}');
    }

    if (_selectedCity != 'All') {
      filtered = filtered.where((inst) => inst['city']?.toString() == _selectedCity).toList();
    }

    if (_minRating > 0) {
      filtered = filtered.where((inst) => _getNumericRating(inst['rating']) >= _minRating).toList();
    }

    // Price filter - only if not at max range
    if (_priceRange.start > 0 || _priceRange.end < 1000) {
      filtered = filtered.where((inst) {
        final price = _getNumericPrice(inst['price_range']);
        // Skip institutions with no price data when filtering
        if (price == 0 && _priceRange.start > 0) return false;
        return price >= _priceRange.start && price <= _priceRange.end;
      }).toList();
    }

    // Condition filter
    if (_selectedConditions.isNotEmpty) {
      filtered = filtered.where((inst) {
        final conditions = inst['conditions_supported']?.toString().toLowerCase() ?? '';
        return _selectedConditions.any((condition) => 
          conditions.contains(condition.toLowerCase())
        );
      }).toList();
    }

    // Service type filter
    if (_selectedServiceTypes.isNotEmpty) {
      filtered = filtered.where((inst) {
        final services = inst['services_offered']?.toString().toLowerCase() ?? '';
        return _selectedServiceTypes.any((service) => 
          services.contains(service.toLowerCase())
        );
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'rating':
        filtered.sort((a, b) => _getNumericRating(b['rating']).compareTo(_getNumericRating(a['rating'])));
        break;
      case 'price':
        filtered.sort((a, b) => _getNumericPrice(a['price_range']).compareTo(_getNumericPrice(b['price_range'])));
        break;
      case 'distance':
        if (_userLat != null && _userLng != null) {
          filtered.sort((a, b) {
            final distA = _calculateDistance(_userLat!, _userLng!, a['location_lat'], a['location_lng']);
            final distB = _calculateDistance(_userLat!, _userLng!, b['location_lat'], b['location_lng']);
            return distA.compareTo(distB);
          });
        }
        break;
      case 'ai_match':
        filtered.sort((a, b) {
          final scoreA = _matchScores[a['institution_id']] ?? 0;
          final scoreB = _matchScores[b['institution_id']] ?? 0;
          return scoreB.compareTo(scoreA);
        });
        break;
      default:
        filtered.sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
    }

    print('✅ Final filtered count: ${filtered.length}');
    
    if (mounted) {
      setState(() => _filteredInstitutions = filtered);
    }
  }

  double _getNumericRating(dynamic rating) {
    if (rating is double) return rating;
    if (rating is int) return rating.toDouble();
    if (rating is String) return double.tryParse(rating) ?? 0.0;
    return 0.0;
  }

  double _getNumericPrice(dynamic price) {
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      final match = RegExp(r'\d+').firstMatch(price);
      if (match != null) return double.tryParse(match.group(0)!) ?? 0.0;
    }
    return 0.0;
  }

  void _clearFilters() {
    setState(() {
      _minRating = 0.0;
      _priceRange = const RangeValues(0, 1000);
      _selectedConditions.clear();
      _selectedServiceTypes.clear();
      _selectedCity = 'All';
      _searchQuery = '';
      _userLat = null;
      _userLng = null;
      _userLocationName = null;
      _sortBy = 'name';
    });
    _applyFilters();
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, dynamic lat2, dynamic lon2) {
    if (lat2 == null || lon2 == null) return double.infinity;
    
    final lat2Double = lat2 is double ? lat2 : (lat2 is num ? lat2.toDouble() : double.tryParse(lat2.toString()) ?? 0);
    final lon2Double = lon2 is double ? lon2 : (lon2 is num ? lon2.toDouble() : double.tryParse(lon2.toString()) ?? 0);
    
    if (lat2Double == 0 && lon2Double == 0) return double.infinity;
    
    const double earthRadius = 6371; // kilometers
    final dLat = _toRadians(lat2Double - lat1);
    final dLon = _toRadians(lon2Double - lon1);
    
    final a = (asin(dLat / 2) * asin(dLat / 2)) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2Double)) *
        (asin(dLon / 2) * asin(dLon / 2));
    
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }

  void _selectLocationFromMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLat: _userLat ?? 31.9539,
          initialLng: _userLng ?? 35.9106,
          onLocationSelected: (lat, lng, locationName) {
            setState(() {
              _userLat = lat;
              _userLng = lng;
              _userLocationName = locationName;
              _sortBy = 'distance'; // Auto-switch to distance sorting
            });
            _applyFilters();
          },
        ),
      ),
    );
  }

  Future<void> _getAIRecommendations() async {
    if (_selectedConditions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one condition for AI recommendations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingAI = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to get AI recommendations')),
        );
        return;
      }

      final result = await ApiService.getAIRecommendations(
        token,
        childConditions: _selectedConditions.join(','),
        location: _selectedCity != 'All' ? _selectedCity : null,
        budget: _priceRange.end < 1000 ? 'low' : 'medium',
      );

      if (result['success'] == true) {
        final recommendations = result['recommendations'] as List? ?? [];
        final aiSummary = result['ai_summary'] as String?;

        setState(() {
          _showAIRecommendations = true;
          _aiSummary = aiSummary;
          _matchScores.clear();
          _aiReasonings.clear();

          for (var rec in recommendations) {
            final id = rec['institution_id'] as int?;
            if (id != null) {
              _matchScores[id] = rec['match_score'] ?? 0;
              if (rec['ai_reasoning'] != null) {
                _aiReasonings[id] = rec['ai_reasoning'];
              }
            }
          }

          // Sort by AI match score when enabled
          _sortBy = 'ai_match';
        });

        _applyFilters();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ AI Recommendations loaded!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error getting AI recommendations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load AI recommendations')),
      );
    } finally {
      setState(() => _isLoadingAI = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text('Browse Centers', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          // AI Recommendations Button
          _isLoadingAI
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _showAIRecommendations ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                    color: _showAIRecommendations ? Colors.amber : Colors.white,
                  ),
                  tooltip: 'AI Recommendations',
                  onPressed: _getAIRecommendations,
                ),
          IconButton(
            icon: Icon(_showAdvancedFilters ? Icons.filter_alt : Icons.filter_alt_outlined, color: Colors.white),
            onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchAndSort(),
                if (_showAdvancedFilters) _buildAdvancedFilters(),
                if (_showAIRecommendations && _aiSummary != null) _buildAISummaryBanner(),
                _buildResultsHeader(),
                Expanded(child: _buildInstitutionsList()),
              ],
            ),
    );
  }

  Widget _buildSearchAndSort() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyFiltersDebounced(); // Use debounced for search
            },
            decoration: InputDecoration(
              hintText: 'Search by name or city...',
              prefixIcon: Icon(Icons.search, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Sort:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('Name', 'name', Icons.sort_by_alpha),
                      _buildSortChip('Rating', 'rating', Icons.star),
                      _buildSortChip('Price', 'price', Icons.attach_money),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primary),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _sortBy = value);
          _applyFilters();
        },
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textDark),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      constraints: const BoxConstraints(maxHeight: 350), // تحديد الحد الأقصى للارتفاع
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Advanced Filters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              TextButton(
                onPressed: _clearFilters, 
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size(50, 30)),
                child: const Text('Clear All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('City', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
              TextButton.icon(
                onPressed: _selectLocationFromMap,
                icon: Icon(Icons.my_location, size: 16),
                label: Text(_userLocationName ?? 'Pick Location', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size(0, 30),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _availableCities.map((city) {
              final isSelected = _selectedCity == city;
              return FilterChip(
                label: Text(city, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedCity = city);
                  _applyFilters();
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textDark, fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 12),
          Text('Min Rating: ${_minRating.toStringAsFixed(1)}⭐', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
          Slider(
            value: _minRating,
            min: 0,
            max: 5,
            divisions: 10,
            activeColor: AppColors.primary,
            onChanged: (value) => setState(() => _minRating = value),
            onChangeEnd: (value) => _applyFilters(),
          ),
          
          const SizedBox(height: 12),
          Text('Price: ${_priceRange.start.toInt()}-${_priceRange.end.toInt()} JD', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000,
            divisions: 20,
            activeColor: AppColors.primary,
            onChanged: (values) => setState(() => _priceRange = values),
            onChangeEnd: (values) => _applyFilters(),
          ),
          
          const SizedBox(height: 12),
          Text('Filter by Condition', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _availableConditions.map((condition) {
              final isSelected = _selectedConditions.contains(condition);
              return FilterChip(
                label: Text(condition, style: const TextStyle(fontSize: 11)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedConditions.add(condition);
                    } else {
                      _selectedConditions.remove(condition);
                    }
                  });
                  _applyFilters();
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textDark, fontSize: 11),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 12),
          Text('Filter by Service Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _availableServices.map((service) {
              final isSelected = _selectedServiceTypes.contains(service);
              return FilterChip(
                label: Text(service, style: const TextStyle(fontSize: 11)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedServiceTypes.add(service);
                    } else {
                      _selectedServiceTypes.remove(service);
                    }
                  });
                  _applyFilters();
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textDark, fontSize: 11),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildAISummaryBanner() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.2),
            Colors.purple.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.amber[700], size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Recommendations',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _aiSummary!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey),
            onPressed: () => setState(() => _showAIRecommendations = false),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.primary.withOpacity(0.1),
      child: Text('${_filteredInstitutions.length} centers found',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildInstitutionsList() {
    if (_filteredInstitutions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: AppColors.textGray.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No Centers Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _clearFilters,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInstitutions,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredInstitutions.length,
        itemBuilder: (context, index) {
          final inst = _filteredInstitutions[index];
          final name = inst['name']?.toString() ?? 'Unknown';
          final city = inst['city']?.toString() ?? '';
          final rating = _getNumericRating(inst['rating']);
          final instId = inst['institution_id'] as int?;
          final matchScore = instId != null ? _matchScores[instId] : null;
          final aiReasoning = instId != null ? _aiReasonings[instId] : null;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: matchScore != null && matchScore > 70 ? 4 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: matchScore != null && matchScore > 80
                  ? BorderSide(color: Colors.amber, width: 2)
                  : BorderSide.none,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.business, color: AppColors.primary, size: 28),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  ),
                  if (matchScore != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: matchScore >= 80
                            ? Colors.amber
                            : matchScore >= 60
                                ? Colors.green
                                : Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '$matchScore%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: AppColors.textGray),
                        const SizedBox(width: 4),
                        Text(city, style: TextStyle(fontSize: 13, color: AppColors.textGray)),
                        if (_userLat != null && _userLng != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${_calculateDistance(_userLat!, _userLng!, inst['location_lat'], inst['location_lng']).toStringAsFixed(1)} km',
                            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (rating > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: 13, color: AppColors.textGray)),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reviews button
                  IconButton(
                    icon: Icon(Icons.rate_review, size: 20, color: AppColors.primary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InstitutionReviewsScreen(
                            institutionId: instId ?? 0,
                            institutionName: name,
                          ),
                        ),
                      );
                    },
                    tooltip: 'View Reviews',
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
                ],
              ),
              onTap: () {
                // Navigate to reviews for now
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InstitutionReviewsScreen(
                      institutionId: instId ?? 0,
                      institutionName: name,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
