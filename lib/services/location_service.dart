import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String address;
  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.address,
  });
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}

class LocationService {
  /// Always resolves to a valid, non-throwing result for the UI on success,
  /// or throws a user-friendly [LocationException]. It never propagates raw
  /// platform/geolocator exceptions to the caller.
  Future<LocationResult> getCurrentLocationWithAddress() async {
    try {
      final pos = await _fetchPosition();

      final address = await _nativeReverseGeocode(pos.latitude, pos.longitude);

      return LocationResult(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        address: address,
      );
    } on LocationException {
      rethrow;
    } on TimeoutException catch (e) {
      debugPrint('[Location] Request timed out: $e');
      throw LocationException(
          'Location request timed out. Check GPS and try again.');
    } catch (e) {
      debugPrint('[Location] Unexpected error: $e');
      throw LocationException(
          'Unable to retrieve your location. Please try again.');
    }
  }

  Future<Position> _fetchPosition() async {
    // 1. Location services (GPS) enabled?
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('[Location] Service check error: $e');
      throw LocationException(
          'Could not check location services. Please try again.');
    }

    if (!serviceEnabled) {
      throw LocationException(
          'GPS is disabled. Please enable it in your device Settings.');
    }

    // 2. Runtime permission
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } on PermissionDeniedException catch (e) {
      debugPrint('[Location] Permission denied: $e');
      throw LocationException(
          'Location permission was denied. Allow location access in Settings '
          'to continue.');
    } on PermissionRequestInProgressException {
      throw LocationException(
          'A location permission request is already in progress. '
          'Please wait for it to finish.');
    } on PermissionDefinitionsNotFoundException catch (e) {
      debugPrint('[Location] Permission definitions missing: $e');
      throw LocationException(
          'Location permissions are missing from the app manifest.');
    } on InvalidPermissionException catch (e) {
      debugPrint('[Location] Invalid permission: $e');
      throw LocationException(
          'The requested location permission is not valid.');
    } catch (e) {
      debugPrint('[Location] Permission check error: $e');
      throw LocationException(
          'Could not check location permission. Please try again.');
    }

    switch (permission) {
      case LocationPermission.denied:
        throw LocationException(
            'Location permission denied. Allow location access in Settings '
            'to continue.');
      case LocationPermission.deniedForever:
        throw LocationException(
            'Location permission is permanently denied. Enable it in your '
            'device Settings.');
      case LocationPermission.unableToDetermine:
        throw LocationException(
            'Could not determine location permission. Please try again.');
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        break;
    }

    // 3. Get the current position from the device
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit:
              const Duration(seconds: AppConstants.locationTimeoutSeconds),
        ),
      );
    } on LocationServiceDisabledException {
      throw LocationException(
          'Location services were turned off. Enable GPS and try again.');
    } on PermissionDeniedException {
      throw LocationException(
          'Location permission was denied. Allow location access in Settings '
          'to continue.');
    } on PositionUpdateException catch (e) {
      debugPrint('[Location] Position update error: $e');
      throw LocationException(
          'Could not get a location fix. Move to an open area and try again.');
    } on TimeoutException catch (e) {
      debugPrint('[Location] Position timeout: $e');
      throw LocationException(
          'Location timed out. Check GPS and try again.');
    } catch (e) {
      debugPrint('[Location] Position error: $e');
      throw LocationException(
          'Unable to retrieve your location. Please try again.');
    }

    if (!_isValidPosition(pos)) {
      debugPrint('[Location] Invalid position returned: $pos');
      throw LocationException(
          'Could not get a valid location fix. Try again in an open area.');
    }

    return pos;
  }

  bool _isValidPosition(Position pos) {
    final lat = pos.latitude;
    final lng = pos.longitude;
    final accuracy = pos.accuracy;

    final hasInvalidValue = lat.isNaN ||
        lng.isNaN ||
        accuracy.isNaN ||
        lat.isInfinite ||
        lng.isInfinite ||
        accuracy.isInfinite;

    if (hasInvalidValue) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    if (accuracy < 0) return false;
    if (lat == 0 && lng == 0) return false;

    return true;
  }

  Future<String> _nativeReverseGeocode(double lat, double lng) async {
    try {
      final placemarks =
          await Geocoding().placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final address = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.postalCode,
          p.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        if (address.isNotEmpty) {
          debugPrint('Reverse geocode: using native platform geocoder');
          return address;
        }
      }
      return 'Address unavailable';
    } catch (e) {
      debugPrint('Reverse geocode: native geocoder error: $e');
      return 'Address lookup failed';
    }
  }
}