import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_endpoints.dart';
import '../models/measurement_response.dart';
import '../models/report_model.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final List<String> errors;

  ApiException({this.statusCode, this.message = '', this.errors = const []});

  @override
  String toString() => message;
}

class ApiService {
  final Dio _dio;

  ApiService({Dio? dio})
      : _dio = dio ??
      Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ));

  /// Creates a measurement. Returns the backend-parsed result on success.
  /// Throws [ApiException] on any failure (400/409/network/unexpected).
  Future<MeasurementResult> createMeasurement(
      ReportModel report, String base64Image) async {
    final data = {
      'image': base64Image,
      'width': _intOrDouble(report.widthInch),
      'height': _intOrDouble(report.heightInch),
      'latitude': report.latitude,
      'longitude': report.longitude,
      'accuracy': _intOrDouble(report.accuracy),
      'timestamp': _utcSeconds(_timestamp(report)),
    };

    final imageLength = base64Image.length;

    debugPrint('[GPS] Latitude: ${report.latitude}');
    debugPrint('[GPS] Longitude: ${report.longitude}');
    debugPrint('[GPS] Accuracy: ${report.accuracy}');
    debugPrint('[API] POST ${ApiEndpoints.measurements}');
    debugPrint('[API] Request payload: ${_logPayload(data)}');
    debugPrint('[API] Image Base64 length: $imageLength');

    try {
      final response =
          await _dio.post<Map<String, dynamic>>(ApiEndpoints.measurements,
              data: data,
              options:
                  Options(responseType: ResponseType.json, contentType: 'application/json'));

      debugPrint('[API] POST ${ApiEndpoints.measurements}');
      debugPrint('[API] Status: ${response.statusCode}');
      debugPrint('[API] Response: ${response.data}');
      return _parseCreateResult(response.data);
    } on DioException catch (e) {
      debugPrint('[API] POST ${ApiEndpoints.measurements}');
      debugPrint('[API] Error status: ${e.response?.statusCode}');
      debugPrint('[API] Error response: ${e.response?.data}');
      throw _mapError(e);
    } on FormatException {
      throw ApiException(message: 'Unexpected server response. Please try again.');
    } on TypeError {
      throw ApiException(message: 'Unexpected server response. Please try again.');
    }
  }

  DateTime _timestamp(ReportModel report) =>
      report.capturedAt ?? report.locationCapturedAt ?? DateTime.now();

  Object? _intOrDouble(double? value) {
    if (value == null) return value;
    if (value == value.roundToDouble()) return value.round();
    return value;
  }

  String _utcSeconds(DateTime dt) {
    final u = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)}T'
        '${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  MeasurementResult _parseCreateResult(dynamic data) {
    if (data is Map) {
      return MeasurementResult.fromJson(Map<String, dynamic>.from(data));
    }
    throw ApiException(message: 'Unexpected server response. Please try again.');
  }

  /// Returns a copy of the request payload with the full Base64 image replaced
  /// by its byte count so logs stay small.
  Map<String, Object?> _logPayload(Map<String, Object?> data) {
    final copy = Map<String, Object?>.from(data);
    final image = copy['image'];
    copy['image'] =
        'data:image/jpeg;base64,<${image is String ? image.length : 0} bytes>';
    return copy;
  }

  /// Fetches all measurement items.
  Future<List<MeasurementItem>> getMeasurements() async {
    const method = 'GET';
    final path = ApiEndpoints.measurements;
    debugPrint('[API] $method $path');
    try {
      return await _performGetAll();
    } on DioException catch (e) {
      if (_isRetryable(e)) {
        debugPrint('[API] $method $path transient failure '
            '(${e.type.name}), retrying once');
        try {
          return await _performGetAll();
        } on DioException catch (e2) {
          _logDioError(e2, method, path);
          throw _mapError(e2);
        }
      }
      _logDioError(e, method, path);
      throw _mapError(e);
    } on FormatException {
      throw ApiException(message: 'Unexpected server response. Please try again.');
    } on TypeError {
      throw ApiException(message: 'Unexpected server response. Please try again.');
    }
  }

  Future<List<MeasurementItem>> _performGetAll() async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.measurements,
      options: Options(responseType: ResponseType.json),
    );
    debugPrint('[API] Status: ${response.statusCode}');
    debugPrint('[API] Response: ${response.data}');
    return _parseList(response.data);
  }

  /// Fetches a single measurement by id.
  Future<MeasurementItem> getMeasurementById(int id) async {
    const method = 'GET';
    final path = ApiEndpoints.measurementById(id);
    debugPrint('[API] $method $path (id: $id)');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        options: Options(responseType: ResponseType.json),
      );
      debugPrint('[API] Status: ${response.statusCode}');
      debugPrint('[API] Response: ${response.data}');
      return _parseSingle(response.data);
    } on DioException catch (e) {
      _logDioError(e, method, '$path (id: $id)');
      throw _mapError(e);
    } on FormatException {
      throw ApiException(message: 'Unexpected server response. Please try again.');
    } on TypeError {
      throw ApiException(message: 'Unexpected server response. Please try again.');
    }
  }

  /// Deletes a measurement by id. Returns true when removed.
  Future<bool> deleteMeasurement(int id) async {
    const method = 'DELETE';
    final path = ApiEndpoints.measurementById(id);
    debugPrint('[API] $method $path (id: $id)');
    try {
      final response = await _dio.delete<dynamic>(path);
      debugPrint('[API] Status: ${response.statusCode}');
      debugPrint('[API] Response: ${response.data}');
      final status =
          response.statusCode ?? 0;
      if (status == 200 || status == 204 || status == 202) return true;
      throw ApiException(statusCode: status, message: 'Delete failed ($status).');
    } on DioException catch (e) {
      _logDioError(e, method, '$path (id: $id)');
      throw _mapError(e);
    }
  }

  /// Parses GET /api/measurements. The response is a top-level Map whose "data"
  /// key carries the item list:
  ///   { "status": "success", "data": [ { ...measurement... } ] }
  /// A bare array is tolerated for backward compatibility. Any other shape
  /// raises a clear [ApiException] instead of a raw Type cast error.
  List<MeasurementItem> _parseList(dynamic data) {
    final Object? rawItems;
    if (data is Map) {
      debugPrint('[API] Parsed status: ${data['status']}');
      rawItems = data['data'];
    } else if (data is List) {
      rawItems = data;
    } else {
      throw ApiException(
        message: 'Invalid history response: expected an object with a '
            '"data" list, got ${data.runtimeType}.',
      );
    }

    if (rawItems is! List) {
      throw ApiException(
        message: 'Invalid history response: "data" is not a list '
            '(got ${rawItems.runtimeType}).',
      );
    }

    final items = <MeasurementItem>[];
    for (final raw in rawItems) {
      if (raw is! Map) {
        throw ApiException(
          message: 'Invalid history response: measurement item is not an '
              'object (got ${raw.runtimeType}).',
        );
      }
      items.add(MeasurementItem.fromJson(Map<String, dynamic>.from(raw)));
    }
    return items;
  }

  /// Parses GET /api/measurements/:id. The response is a top-level Map whose
  /// "data" key carries the single measurement object:
  ///   { "status": "success", "data": { ...measurement... } }
  MeasurementItem _parseSingle(dynamic data) {
    Object? inner;
    if (data is Map) {
      final payload = data['data'];
      if (payload is Map) {
        inner = payload;
      } else if (data.containsKey('data')) {
        throw ApiException(
          message: 'Invalid details response: "data" is not an object '
              '(got ${payload.runtimeType}).',
        );
      } else {
        inner = data;
      }
    } else {
      throw ApiException(
        message: 'Invalid details response: expected an object, got '
            '${data.runtimeType}.',
      );
    }

    if (inner is! Map) {
      throw ApiException(
        message: 'Invalid details response: item is not an object '
            '(got ${inner.runtimeType}).',
      );
    }
    return MeasurementItem.fromJson(Map<String, dynamic>.from(inner));
  }

  bool _isRetryable(DioException e) {
    if (e.response != null) return false;
    // Parsing/model type errors (e.g. "_Map is not a subtype of List<dynamic>")
    // are NOT network failures and must never be retried.
    final cause = e.error;
    if (cause is TypeError) return false;
    if (cause is FormatException) return false;
    final msg = cause?.toString() ?? e.message ?? '';
    if (msg.contains('is not a subtype of') || msg.contains('type cast')) {
      return false;
    }
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.unknown =>
        true,
      _ => false,
    };
  }

  void _logDioError(DioException e, String method, String path) {
    debugPrint('[API] $method $path failed');
    debugPrint('[API] DioException type: ${e.type.name}');
    debugPrint('[API] DioException message: ${e.message}');
    final cause = e.error;
    if (cause != null) debugPrint('[API] Underlying error: $cause');
    debugPrint('[API] Error status: ${e.response?.statusCode}');
    debugPrint('[API] Error response: ${e.response?.data}');
    debugPrintStack(label: '[API] Stack trace for $method $path');
  }

  ApiException _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(message: 'Network timeout. Please try again.');
      case DioExceptionType.connectionError:
        return ApiException(
            message: 'No internet connection. Please check your network.');
      case DioExceptionType.badResponse:
        return _mapBadResponse(e.response);
      default:
        return ApiException(message: 'Unexpected error. Please try again.');
    }
  }

  ApiException _mapBadResponse(Response? response) {
    final status = response?.statusCode;
    final statusOk = status ?? 0;
    var message = 'Something went wrong. Please try again. ($statusOk)';
    var errors = <String>[];

    try {
      final body = response?.data;
      if (body is Map) {
        message = body['message'] as String? ?? message;
        final rawErrors = body['errors'];
        if (rawErrors is List) {
          errors = rawErrors.map((e) => e.toString()).toList();
        } else if (rawErrors is Map) {
          errors = rawErrors.values.map((e) => e.toString()).toList();
        }
      } else if (body is String && body.isNotEmpty) {
        message = body;
      }
    } catch (_) {
      // keep defaults
    }

    return ApiException(
      statusCode: statusOk,
      message: message,
      errors: errors,
    );
  }
}