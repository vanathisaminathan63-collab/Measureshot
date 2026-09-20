import 'package:flutter/foundation.dart';
import '../models/measurement_response.dart';
import '../services/api_service.dart';

class HistoryController extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<MeasurementItem> _items = [];
  List<MeasurementItem> get items => _items;

  bool _isDetailLoading = false;
  bool get isDetailLoading => _isDetailLoading;

  String? _detailError;
  String? get detailError => _detailError;

  MeasurementItem? _detail;
  MeasurementItem? get detail => _detail;

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  String? _deleteError;
  String? get deleteError => _deleteError;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _api.getMeasurements();
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _error = 'Unable to load measurements. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDetail(int id) async {
    _isDetailLoading = true;
    _detailError = null;
    _detail = null;
    notifyListeners();
    try {
      _detail = await _api.getMeasurementById(id);
      _isDetailLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _detailError = e.message;
      _isDetailLoading = false;
      notifyListeners();
    } catch (_) {
      _detailError = 'Unable to load details. Please try again.';
      _isDetailLoading = false;
      notifyListeners();
    }
  }

  Future<bool> delete(int id) async {
    if (_isDeleting) return false;
    _isDeleting = true;
    _deleteError = null;
    notifyListeners();
    try {
      final ok = await _api.deleteMeasurement(id);
      if (ok) {
        _items.removeWhere((e) => e.id == id);
        _detail = null;
      }
      _isDeleting = false;
      notifyListeners();
      return ok;
    } on ApiException catch (e) {
      _deleteError = e.message;
      _isDeleting = false;
      notifyListeners();
      return false;
    } catch (_) {
      _deleteError = 'Unable to delete measurement. Please try again.';
      _isDeleting = false;
      notifyListeners();
      return false;
    }
  }
}