import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/report_model.dart';

class ReportController extends ChangeNotifier {
  final ReportModel _report = ReportModel();
  ReportModel get report => _report;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _error;
  String? get error => _error;

  // ---------- Image ----------
  void setImage(File file) {
    _report.image = file;
    _report.capturedAt = DateTime.now();
    _report.submissionId ??= const Uuid().v4();
    notifyListeners();
  }

  void removeImage() {
    _report.image = null;
    _report.capturedAt = null;
    notifyListeners();
  }

  // ---------- Measurements ----------
  void setMeasurements(double? w, double? h) {
    _report.widthInch = w;
    _report.heightInch = h;
    notifyListeners();
  }

  // ---------- Location ----------
  void setLocation({
    required double lat,
    required double lng,
    required double accuracy,
    required String address,
  }) {
    _report.latitude = lat;
    _report.longitude = lng;
    _report.accuracy = accuracy;
    _report.address = address;
    _report.locationCapturedAt = DateTime.now();
    notifyListeners();
  }

  // ---------- Submission state ----------
  void setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  void setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  void markSubmitted() {
    _report.isSubmitted = true;
    notifyListeners();
  }

  void resetAll() {
    _report.reset();
    _error = null;
    _isSubmitting = false;
    notifyListeners();
  }
}

