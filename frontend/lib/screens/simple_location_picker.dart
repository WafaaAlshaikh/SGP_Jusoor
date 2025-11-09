import 'package:flutter/material.dart';

/// ⭐ بديل بسيط للـ MapScreen بدون الحاجة لـ Google Maps API
/// استخدم هذا إذا كان Google Maps يسبب crash
class SimpleLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const SimpleLocationPicker({
    Key? key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  }) : super(key: key);

  @override
  _SimpleLocationPickerState createState() => _SimpleLocationPickerState();
}

class _SimpleLocationPickerState extends State<SimpleLocationPicker> {
  String? _selectedCity;
  double? _selectedLat;
  double? _selectedLng;
  
  // المدن الفلسطينية الرئيسية مع إحداثياتها
  final Map<String, Map<String, dynamic>> _cities = {
    'جنين': {'lat': 32.4645, 'lng': 35.3027, 'region': 'شمال الضفة'},
    'نابلس': {'lat': 32.2211, 'lng': 35.2544, 'region': 'شمال الضفة'},
    'طولكرم': {'lat': 32.3107, 'lng': 35.0278, 'region': 'شمال الضفة'},
    'قلقيلية': {'lat': 32.1896, 'lng': 34.9705, 'region': 'شمال الضفة'},
    'رام الله': {'lat': 31.9466, 'lng': 35.3027, 'region': 'وسط الضفة'},
    'القدس': {'lat': 31.7683, 'lng': 35.2137, 'region': 'وسط الضفة'},
    'بيت لحم': {'lat': 31.7054, 'lng': 35.2024, 'region': 'وسط الضفة'},
    'أريحا': {'lat': 31.8611, 'lng': 35.4622, 'region': 'وسط الضفة'},
    'الخليل': {'lat': 31.5326, 'lng': 35.0998, 'region': 'جنوب الضفة'},
    'غزة': {'lat': 31.5017, 'lng': 34.4668, 'region': 'قطاع غزة'},
    'خان يونس': {'lat': 31.3461, 'lng': 34.3063, 'region': 'قطاع غزة'},
    'رفح': {'lat': 31.2969, 'lng': 34.2467, 'region': 'قطاع غزة'},
  };

  @override
  void initState() {
    super.initState();
    
    // تحديد الموقع الابتدائي
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLat = widget.initialLat;
      _selectedLng = widget.initialLng;
      _findClosestCity(widget.initialLat!, widget.initialLng!);
    }
  }

  void _findClosestCity(double lat, double lng) {
    double minDistance = double.infinity;
    String? closestCity;
    
    _cities.forEach((city, coords) {
      final distance = _calculateDistance(
        lat, lng,
        coords['lat'], coords['lng'],
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestCity = city;
      }
    });
    
    if (closestCity != null) {
      setState(() {
        _selectedCity = closestCity;
      });
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat2 - lat1;
    final dLng = lng2 - lng1;
    return dLat * dLat + dLng * dLng;
  }

  void _selectCity(String city) {
    setState(() {
      _selectedCity = city;
      _selectedLat = _cities[city]!['lat'];
      _selectedLng = _cities[city]!['lng'];
    });
  }

  void _confirmSelection() {
    if (_selectedCity != null && _selectedLat != null && _selectedLng != null) {
      final cityData = _cities[_selectedCity!]!;
      final result = {
        'lat': _selectedLat,
        'lng': _selectedLng,
        'address': '$_selectedCity, فلسطين',
        'city': _selectedCity,
        'region': cityData['region'],
      };
      
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء اختيار مدينة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCityCard(String city) {
    final cityData = _cities[city]!;
    final isSelected = _selectedCity == city;
    
    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Color(0xFF7815A0) : Colors.white,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _selectCity(city),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.location_city,
                color: isSelected ? Colors.white : Color(0xFF7815A0),
                size: 32,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      cityData['region'],
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.white70 : Colors.grey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'الإحداثيات: ${cityData['lat'].toStringAsFixed(4)}, ${cityData['lng'].toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final citiesByRegion = <String, List<String>>{};
    _cities.forEach((city, data) {
      final region = data['region'];
      if (!citiesByRegion.containsKey(region)) {
        citiesByRegion[region] = [];
      }
      citiesByRegion[region]!.add(city);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('اختر موقع الطفل'),
        backgroundColor: Color(0xFF7815A0),
      ),
      body: Column(
        children: [
          // معلومات توضيحية
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'اختر المدينة الأقرب لموقع الطفل لمساعدتنا في إيجاد المؤسسات المناسبة',
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          
          // قائمة المدن
          Expanded(
            child: ListView(
              children: [
                ...citiesByRegion.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      ...entry.value.map((city) => _buildCityCard(city)),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
          
          // زر التأكيد
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _confirmSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7815A0),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _selectedCity != null
                    ? 'تأكيد اختيار $_selectedCity'
                    : 'اختر مدينة أولاً',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
