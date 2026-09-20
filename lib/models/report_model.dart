import 'dart:io';

class ReportModel {
  File? image;
  DateTime? capturedAt;

  // Measurements
  double? widthInch;
  double? heightInch;

  // Location
  double? latitude;
  double? longitude;
  double? accuracy;
  String? address;
  DateTime? locationCapturedAt;

  // Submission
  String? submissionId;
  bool isSubmitted = false;

  double get squareFeet {
    if (widthInch == null || heightInch == null) return 0;
    return (widthInch! * heightInch!) / 144.0;
  }

  Map<String, dynamic> toJson() => {
    'widthInch': widthInch,
    'heightInch': heightInch,
    'squareFeet': squareFeet,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'address': address,
    'capturedAt': capturedAt?.toIso8601String(),
    'locationCapturedAt': locationCapturedAt?.toIso8601String(),
    'submissionId': submissionId,
  };

  bool isComplete() {
    return image != null &&
        widthInch != null &&
        widthInch! > 0 &&
        heightInch != null &&
        heightInch! > 0 &&
        latitude != null &&
        longitude != null &&
        address != null;
  }

  void reset() {
    image = null;
    capturedAt = null;
    widthInch = null;
    heightInch = null;
    latitude = null;
    longitude = null;
    accuracy = null;
    address = null;
    locationCapturedAt = null;
    submissionId = null;
    isSubmitted = false;
  }
}