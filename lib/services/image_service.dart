import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera);
    return x == null ? null : File(x.path);
  }

  Future<File?> pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    return x == null ? null : File(x.path);
  }

  /// Android-only: recovers a photo/video whose picking was interrupted when
  /// MainActivity was destroyed while the system camera/gallery was open.
  /// Returns the recovered file, or null when there is nothing to restore.
  /// Never throws; logs any platform error instead.
  Future<File?> recoverLostCapture() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return null;
      if (response.exception != null) {
        debugPrint(
            '[Image] Lost capture recovery: platform error ${response.exception}');
        return null;
      }
      final XFile? lost =
          (response.files != null && response.files!.isNotEmpty)
              ? response.files!.first
              : response.file;
      if (lost == null) {
        debugPrint('[Image] Lost capture recovery: no file returned');
        return null;
      }
      debugPrint('[Image] Lost capture recovery: recovered ${lost.path}');
      return File(lost.path);
    } catch (e) {
      debugPrint('[Image] Lost capture recovery error: $e');
      return null;
    }
  }

  /// Returns compressed file, or throws if it exceeds max size.
  Future<File> compressAndValidate(File file) async {
    final inputExists = await file.exists();
    final inputBytes = await file.length();
    debugPrint('[Image] Compress input: path=${file.absolute.path} '
        'exists=$inputExists bytes=$inputBytes');

    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: AppConstants.compressedImageQuality,
      minWidth: AppConstants.compressedImageMaxWidth,
      minHeight: AppConstants.compressedImageMaxWidth,
    );

    if (result == null) throw Exception('Image compression failed');

    final compressed = File(result.path);
    final size = await compressed.length();
    debugPrint('[Image] Compressed bytes: $size '
        '(max ${AppConstants.maxImageSizeBytes})');
    if (size > AppConstants.maxImageSizeBytes) {
      throw Exception('Image is larger than 5 MB after compression');
    }
    return compressed;
  }

  /// Persists editor output (e.g. cropped / annotated image) as a temp file.
  Future<File> saveEdits(Uint8List bytes, {String extension = 'jpg'}) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.$extension');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Encodes the (edited) JPEG file as a `data:image/jpeg;base64,...` string.
  /// Runs off the UI thread so the encode does not block the main isolate.
  Future<String> encodedJpegBase64(File file) async {
    if (!await file.exists()) {
      debugPrint('[Image] Encode failed: file not found ${file.path}');
      throw Exception('Image file not found.');
    }
    final bytes = await file.length();
    if (bytes <= 0) {
      debugPrint('[Image] Encode failed: empty file ${file.path} (0 bytes)');
      throw Exception('Image file is empty.');
    }
    debugPrint('[Image] Encode: path=${file.path} exists=true bytes=$bytes');
    final base64 = await compute(_readFileAsBase64, file.path);
    debugPrint('[Image] Encoded base64 chars: ${base64.length}');
    if (!base64.startsWith('/9j/')) {
      debugPrint('[Image] Encoded data is NOT JPEG (expected leading /9j/ for '
          '0xFFD8FF magic). Prefix will stay data:image/jpeg;base64,');
    }
    return 'data:image/jpeg;base64,$base64';
  }
}

String _readFileAsBase64(String path) {
  return base64Encode(File(path).readAsBytesSync());
}