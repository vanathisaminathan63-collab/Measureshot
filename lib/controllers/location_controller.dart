import 'package:flutter/foundation.dart';
import '../services/location_service.dart';

class LocationController extends ChangeNotifier {
  final LocationService _service = LocationService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  double? _lat, _lng, _accuracy;
  String? _address;

  double? get latitude => _lat;
  double? get longitude => _lng;
  double? get accuracy => _accuracy;
  String? get address => _address;

  void setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  Future<bool> fetchLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.getCurrentLocationWithAddress();
      final lat = result.latitude;
      final lng = result.longitude;
      final accuracy = result.accuracy;

      if (lat.isNaN ||
          lat.isInfinite ||
          lng.isNaN ||
          lng.isInfinite ||
          accuracy.isNaN ||
          accuracy < 0 ||
          lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        throw LocationException(
            'Could not get a valid location fix. Try again in an open area.');
      }

      _lat = lat;
      _lng = lng;
      _accuracy = accuracy;
      _address = result.address;
      _isLoading = false;
      notifyListeners();
      return true;
    } on LocationException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Unable to retrieve location. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}