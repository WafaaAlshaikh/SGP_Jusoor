// lib/services/location_service.dart - تحديث كامل
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;

class LocationService {
  // طلب صلاحيات الموقع
  static Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      print('❌ Permission error: $e');
      return false;
    }
  }

  // التحقق من إمكانية الحصول على الموقع الحالي
  static Future<Map<String, dynamic>> checkLocationAvailability() async {
    try {
      // التحقق من خدمة الموقع
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'available': false,
          'error': 'location_services_disabled',
          'message': 'Location services are disabled',
        };
      }

      // التحقق من الصلاحيات
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        return {
          'available': false,
          'error': 'permission_denied',
          'message': 'Location permission denied',
        };
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'available': false,
          'error': 'permission_denied_forever',
          'message': 'Location permission permanently denied',
        };
      }

      return {
        'available': true,
        'message': 'Location services are available',
      };

    } catch (e) {
      return {
        'available': false,
        'error': 'unknown_error',
        'message': 'Error checking location availability: $e',
      };
    }
  }

  // التحقق من إعدادات الخريطة
  static Future<bool> checkMapRequirements() async {
    try {
      // التحقق من خدمة الموقع
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      // التحقق من الصلاحيات
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Map requirements check error: $e');
      return false;
    }
  }

  // الحصول على الموقع الحالي
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      // التحقق من خدمة الموقع
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'error': 'location_disabled',
          'message': 'Please enable location services on your device',
        };
      }

      // طلب الصلاحيات
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return {
          'error': 'permission_denied',
          'message': 'Please allow location access in app settings',
        };
      }

      // الحصول على الموقع
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // محاولة الحصول على العنوان
      String address = 'Current Location';
      try {
        List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          geo.Placemark placemark = placemarks.first;
          address = [
            if (placemark.street != null && placemark.street!.isNotEmpty) placemark.street,
            if (placemark.locality != null && placemark.locality!.isNotEmpty) placemark.locality,
            if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) placemark.administrativeArea,
            if (placemark.country != null && placemark.country!.isNotEmpty) placemark.country,
          ].where((part) => part != null).join(', ');
        }
      } catch (e) {
        print('⚠️ Address lookup failed: $e');
      }

      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'address': address,
        'success': true,
      };
    } catch (e) {
      print('❌ Location error: $e');

      if (e.toString().contains('timeout')) {
        return {
          'error': 'timeout',
          'message': 'Location request timed out. Please try again',
        };
      } else {
        return {
          'error': 'unknown_error',
          'message': 'Failed to get location. Please try again or enter address manually',
        };
      }
    }
  }



  static Future<Map<String, dynamic>?> getLocationFromAddress(String address) async {
    try {
      if (address.length < 3) return null;

      List<geo.Location> locations = await geo.locationFromAddress(address);

      if (locations.isNotEmpty) {
        geo.Location location = locations.first;

        // الحصول على العنوان المفصل من الإحداثيات
        String detailedAddress = address;
        try {
          List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );

          if (placemarks.isNotEmpty) {
            geo.Placemark placemark = placemarks.first;
            detailedAddress = [
              if (placemark.street != null && placemark.street!.isNotEmpty) placemark.street,
              if (placemark.locality != null && placemark.locality!.isNotEmpty) placemark.locality,
              if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) placemark.administrativeArea,
              if (placemark.country != null && placemark.country!.isNotEmpty) placemark.country,
            ].where((part) => part != null).join(', ');
          }
        } catch (e) {
          print('⚠️ Reverse geocoding failed: $e');
        }

        return {
          'lat': location.latitude,
          'lng': location.longitude,
          'address': detailedAddress,
          'success': true,
        };
      }
      return null;
    } catch (e) {
      print('❌ Geocoding error: $e');
      return null;
    }
  }

  // فتح إعدادات التطبيق
  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      print('❌ Could not open app settings: $e');
    }
  }

  // فتح إعدادات الموقع
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      print('❌ Could not open location settings: $e');
    }
  }

  // حساب المسافة بين نقطتين (بالكيلومتر)
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }
}