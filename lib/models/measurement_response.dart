class MeasurementResult {
  final String? status;
  final String? message;
  final MeasurementItem? data;

  MeasurementResult({this.status, this.message, this.data});

  factory MeasurementResult.fromJson(Map<String, dynamic> json) {
    return MeasurementResult(
      status: json['status'] as String?,
      message: json['message'] as String?,
      data: json['data'] is Map<String, dynamic>
          ? MeasurementItem.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MeasurementItem {
  final int? id;
  final int width;
  final int height;
  final double sqft;
  final double latitude;
  final double longitude;
  final double accuracy;
  final String timestamp;
  final String? createdAt;
  final String? imageUrl;

  MeasurementItem({
    required this.id,
    required this.width,
    required this.height,
    required this.sqft,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.createdAt,
    this.imageUrl,
  });

  factory MeasurementItem.fromJson(Map<String, dynamic> json) {
    return MeasurementItem(
      id: _asInt(json['id']),
      width: _asInt(json['width']) ?? 0,
      height: _asInt(json['height']) ?? 0,
      sqft: _asDouble(json['sqft']) ?? 0,
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
      accuracy: _asDouble(json['accuracy']) ?? 0,
      timestamp: json['timestamp'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}