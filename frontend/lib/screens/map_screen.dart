import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_colors.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final Function(double lat, double lng, String locationName)? onLocationSelected;

  const MapScreen({
    Key? key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  bool _isResolvingAddress = false;

  // Jordanian locations (Main cities for Jusoor project)
  static const LatLng _ammanLocation = LatLng(31.9539, 35.9106);
  static const LatLng _irbidLocation = LatLng(32.5556, 35.8469);
  static const LatLng _zarqaLocation = LatLng(32.0728, 36.0881);
  static const LatLng _aqabaLocation = LatLng(29.5267, 35.0063);

  // Palestinian locations (for reference)
  static const LatLng _jeninLocation = LatLng(32.4645, 35.3027);
  static const LatLng _ramallahLocation = LatLng(31.9466, 35.3027);
  static const LatLng _gazaLocation = LatLng(31.5017, 34.4668);
  static const LatLng _hebronLocation = LatLng(31.5326, 35.0998);

  @override
  void initState() {
    super.initState();
    print('🗺️ [MAP] MapScreen initialized');

    // Use initial location or default (Palestine)
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
      print('📍 [MAP] Using initial location: $_selectedLocation');
    } else {
      _selectedLocation = _ramallahLocation;
      print('📍 [MAP] Using default location: Ramallah');
    }

    _updateMarkers();
  }

  void _updateMarkers() {
    _markers.clear();
    if (_selectedLocation != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('selected_location'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Selected Location',
            snippet: '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
          ),
        ),
      );
    }
    print('📍 [MAP] Markers updated: ${_markers.length}');
  }

  void _onMapCreated(GoogleMapController controller) {
    print('🗺️ [MAP] Map created successfully');
    _mapController = controller;
  }

  void _onMapTapped(LatLng location) {
    print('📍 [MAP] Map tapped at: $location');
    setState(() {
      _selectedLocation = location;
      _updateMarkers();
    });
  }

  void _moveToCity(LatLng cityLocation, String cityName) {
    print('🏙️ [MAP] Moving to city: $cityName');
    setState(() {
      _selectedLocation = cityLocation;
      _updateMarkers();
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(cityLocation, 12),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved to $cityName'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _selectAndReturnLocation() async {
    if (_selectedLocation == null) {
      print('❌ [MAP] No location selected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a location on the map'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    print('✅ [MAP] Location selected: $_selectedLocation');

    final lat = _selectedLocation!.latitude;
    final lng = _selectedLocation!.longitude;

    setState(() {
      _isResolvingAddress = true;
    });

    final addressData = await LocationService.getAddressFromCoordinates(lat, lng);
    final address = addressData['address']?.toString() ?? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    final city = addressData['city']?.toString() ?? '';
    final region = addressData['region']?.toString() ?? '';

    if (!mounted) return;
    setState(() {
      _isResolvingAddress = false;
    });

    final locationName = city.isNotEmpty ? city : address;

    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(lat, lng, locationName);
      Navigator.pop(context);
      return;
    }

    final result = {
      'lat': lat,
      'lng': lng,
      'address': address,
      'city': city,
      'region': region,
    };

    print('✅ [MAP] Returning data: $result');
    Navigator.pop(context, result);
  }

  String _getAddressFromPosition(LatLng position) {
    // Jordanian cities
    if (_isNear(position, _ammanLocation)) return 'Amman, Jordan';
    if (_isNear(position, _irbidLocation)) return 'Irbid, Jordan';
    if (_isNear(position, _zarqaLocation)) return 'Zarqa, Jordan';
    if (_isNear(position, _aqabaLocation)) return 'Aqaba, Jordan';

    // Palestinian cities
    if (_isNear(position, _jeninLocation)) return 'Jenin, Palestine';
    if (_isNear(position, _ramallahLocation)) return 'Ramallah, Palestine';
    if (_isNear(position, _gazaLocation)) return 'Gaza, Palestine';
    if (_isNear(position, _hebronLocation)) return 'Hebron, Palestine';

    return 'Selected location in Jordan';
  }

  bool _isNear(LatLng pos1, LatLng pos2) {
    final latDiff = (pos1.latitude - pos2.latitude).abs();
    final lngDiff = (pos1.longitude - pos2.longitude).abs();
    return latDiff < 0.5 && lngDiff < 0.5; // Within ~50km radius
  }

  String _extractCityFromPosition(LatLng position) {
    // Jordanian cities (primary)
    if (_isNear(position, _ammanLocation)) return 'Amman';
    if (_isNear(position, _irbidLocation)) return 'Irbid';
    if (_isNear(position, _zarqaLocation)) return 'Zarqa';
    if (_isNear(position, _aqabaLocation)) return 'Aqaba';

    // Palestinian cities
    if (_isNear(position, _jeninLocation)) return 'Jenin';
    if (_isNear(position, _ramallahLocation)) return 'Ramallah';
    if (_isNear(position, _gazaLocation)) return 'Gaza';
    if (_isNear(position, _hebronLocation)) return 'Hebron';

    return 'Jordan';
  }

  String _extractRegionFromPosition(LatLng position) {
    // Jordanian regions
    if (position.latitude >= 32.0) return 'North Jordan';
    if (position.latitude >= 31.0) return 'Central Jordan';
    if (position.latitude < 31.0) return 'South Jordan';
    return 'Jordan';
  }

  Widget _buildCityButton(String cityName, LatLng location, Color color) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: () => _moveToCity(location, cityName),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            cityName,
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Location',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // ⭐ Add error handling for map
          Builder(
            builder: (context) {
              try {
                return GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ?? _ramallahLocation,
                    zoom: 10,
                  ),
                  markers: _markers,
                  onTap: _onMapTapped,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                );
              } catch (e) {
                print('❌ [MAP] Error creating map: $e');
                return Container(
                  color: AppColors.background,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.error
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Error loading map',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Check your internet connection and ensure Google Maps is enabled',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Go Back',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),

          if (_isResolvingAddress)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Resolving address...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // City buttons - Palestine first
          Positioned(
            top: 20,
            left: 16,
            child: Container(
              padding: EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Cities',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  Column(
                    children: [
                      _buildCityButton('Ramallah', _ramallahLocation, AppColors.primary),
                      SizedBox(height: 8),
                      _buildCityButton('Jenin', _jeninLocation, AppColors.primaryLight),
                      SizedBox(height: 8),
                      _buildCityButton('Hebron', _hebronLocation, AppColors.accent4),
                      SizedBox(height: 8),
                      _buildCityButton('Gaza', _gazaLocation, AppColors.info),
                      SizedBox(height: 12),
                      Divider(height: 1),
                      SizedBox(height: 12),
                      _buildCityButton('Amman', _ammanLocation, AppColors.primary),
                      SizedBox(height: 8),
                      _buildCityButton('Irbid', _irbidLocation, AppColors.primaryLight),
                      SizedBox(height: 8),
                      _buildCityButton('Zarqa', _zarqaLocation, AppColors.accent4),
                      SizedBox(height: 8),
                      _buildCityButton('Aqaba', _aqabaLocation, AppColors.info),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Confirmation button
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                            Icons.location_on,
                            size: 20,
                            color: AppColors.primary
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Location',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap on the map or select a city',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectAndReturnLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Confirm Location',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected location info
          if (_selectedLocation != null)
            Positioned(
              top: 20,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_selectedLocation!.latitude.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '${_selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}