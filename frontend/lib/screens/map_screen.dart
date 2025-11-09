import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const MapScreen({
    Key? key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};

  // Palestinian locations
  static const LatLng _jeninLocation = LatLng(32.4645, 35.3027);
  static const LatLng _ramallahLocation = LatLng(31.9466, 35.3027);
  static const LatLng _gazaLocation = LatLng(31.5017, 34.4668);
  static const LatLng _hebronLocation = LatLng(31.5326, 35.0998);

  @override
  void initState() {
    super.initState();
    print('🗺️ [MAP] MapScreen initialized');

    // Use initial location or default
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
      print('📍 [MAP] Using initial location: $_selectedLocation');
    } else {
      _selectedLocation = _jeninLocation;
      print('📍 [MAP] Using default location: $_selectedLocation');
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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
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
      SnackBar(content: Text('Moved to $cityName')),
    );
  }

  void _selectAndReturnLocation() {
    if (_selectedLocation != null) {
      print('✅ [MAP] Location selected: $_selectedLocation');

      final result = {
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'address': _getAddressFromPosition(_selectedLocation!),
        'city': _extractCityFromPosition(_selectedLocation!),
        'region': _extractRegionFromPosition(_selectedLocation!),
      };

      print('✅ [MAP] Returning data: $result');

      // ✅ Important: Return data to previous screen
      Navigator.pop(context, result);
    } else {
      print('❌ [MAP] No location selected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a location on the map')),
      );
    }
  }

  String _getAddressFromPosition(LatLng position) {
    if (position.latitude >= 32.4 && position.latitude <= 32.5) return 'Jenin, Palestine';
    if (position.latitude >= 31.9 && position.latitude <= 32.0) return 'Ramallah, Palestine';
    if (position.latitude >= 31.5 && position.latitude <= 31.6) return 'Gaza, Palestine';
    if (position.latitude >= 31.5 && position.latitude <= 31.6) return 'Hebron, Palestine';
    return 'Selected location on map';
  }

  String _extractCityFromPosition(LatLng position) {
    if (position.latitude >= 32.4 && position.latitude <= 32.5) return 'Jenin';
    if (position.latitude >= 31.9 && position.latitude <= 32.0) return 'Ramallah';
    if (position.latitude >= 31.5 && position.latitude <= 31.6) return 'Gaza';
    if (position.latitude >= 31.5 && position.latitude <= 31.6) return 'Hebron';
    return 'Palestine';
  }

  String _extractRegionFromPosition(LatLng position) {
    if (position.latitude >= 32.0) return 'North West Bank';
    if (position.latitude >= 31.5) return 'Central West Bank';
    return 'South West Bank';
  }

  Widget _buildCityButton(String cityName, LatLng location, Color color) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _moveToCity(location, cityName),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            cityName,
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location - Palestine'),
        backgroundColor: Color(0xFF7815A0),
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
                    target: _selectedLocation ?? _jeninLocation,
                    zoom: 10,
                  ),
                  markers: _markers,
                  onTap: _onMapTapped,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  myLocationEnabled: false, // Disable my location to avoid crashes
                  myLocationButtonEnabled: false,
                );
              } catch (e) {
                print('❌ [MAP] Error creating map: $e');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Error loading map',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Check your internet connection\nand ensure Google Maps is enabled',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Back'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),

          // City buttons
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              children: [
                _buildCityButton('Jenin', _jeninLocation, Colors.green),
                SizedBox(height: 10),
                _buildCityButton('Ramallah', _ramallahLocation, Colors.blue),
                SizedBox(height: 10),
                _buildCityButton('Gaza', _gazaLocation, Colors.orange),
                SizedBox(height: 10),
                _buildCityButton('Hebron', _hebronLocation, Colors.purple),
              ],
            ),
          ),

          // Confirmation button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap on the map or select a city, then press Confirm',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
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
                        backgroundColor: Color(0xFF7815A0),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                      ),
                      child: Text(
                        'Confirm Location',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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