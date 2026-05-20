import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const String _locationKey = 'userLocation';
  static const String _latKey = 'userLatitude';
  static const String _lngKey = 'userLongitude';

  static Future<Map<String, dynamic>> detectAndSaveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'status': 'error',
          'message': 'Location services are disabled.',
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return {
          'status': 'denied',
          'message': 'Location permission denied.',
        };
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'status': 'denied_forever',
          'message': 'Location permission permanently denied.',
        };
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String locationText = 'Location not available';

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        final parts = <String>[
          if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          if ((p.subAdministrativeArea ?? '').trim().isNotEmpty)
            p.subAdministrativeArea!.trim(),
          if ((p.administrativeArea ?? '').trim().isNotEmpty &&
              p.administrativeArea!.trim() != (p.subAdministrativeArea ?? '').trim())
            p.administrativeArea!.trim(),
        ];

        final uniqueParts = <String>[];
        for (final item in parts) {
          if (!uniqueParts.contains(item)) {
            uniqueParts.add(item);
          }
        }

        if (uniqueParts.isNotEmpty) {
          locationText = uniqueParts.join(', ');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationKey, locationText);
      await prefs.setDouble(_latKey, position.latitude);
      await prefs.setDouble(_lngKey, position.longitude);

      return {
        'status': 'success',
        'message': 'Location updated successfully.',
        'location': locationText,
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to detect location: $e',
      };
    }
  }

  static Future<String> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_locationKey) ?? '';
  }

  static Future<void> clearSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_locationKey);
    await prefs.remove(_latKey);
    await prefs.remove(_lngKey);
  }

  static Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  static Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }
}