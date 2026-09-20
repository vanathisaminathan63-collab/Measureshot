import 'package:flutter/foundation.dart';

class MeasurementController extends ChangeNotifier {
  String _widthText = '';
  String _heightText = '';

  String get widthText => _widthText;
  String get heightText => _heightText;

  double? get width => double.tryParse(_widthText);
  double? get height => double.tryParse(_heightText);

  double get squareFeet {
    if (width == null || height == null) return 0;
    if (width! <= 0 || height! <= 0) return 0;
    return (width! * height!) / 144.0;
  }

  String? get widthError => _validate(_widthText);
  String? get heightError => _validate(_heightText);

  bool get isValid =>
      widthError == null &&
          heightError == null &&
          _widthText.isNotEmpty &&
          _heightText.isNotEmpty;

  String? _validate(String value) {
    if (value.isEmpty) return null;
    final num = double.tryParse(value);
    if (num == null) return 'Enter a number';
    if (num <= 0) return 'Must be > 0';
    return null;
  }

  void setWidth(String v) {
    _widthText = v;
    notifyListeners();
  }

  void setHeight(String v) {
    _heightText = v;
    notifyListeners();
  }
}