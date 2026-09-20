import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/report_controller.dart';
import '../models/measurement_response.dart';
import '../models/report_model.dart';
import '../services/api_service.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';

class SubmitView extends StatelessWidget {
  const SubmitView({super.key});

  Future<void> _submit(BuildContext context) async {
    final controller = context.read<ReportController>();
    if (controller.isSubmitting) return; // prevent double tap

    final report = controller.report;
    final missing = _missingField(report);
    if (missing != null) {
      controller.setError(missing);
      return;
    }

    controller.setSubmitting(true);
    controller.setError(null);

    try {
      final base64Image = await ImageService().encodedJpegBase64(report.image!);
      debugPrint('[Submit] Encoded image base64 chars: ${base64Image.length}');
      if (!context.mounted) return;

      final result = await ApiService().createMeasurement(report, base64Image);
      if (!context.mounted) return;

      final item = result.data;
      if (item == null) {
        controller.setError('Unexpected server response. Please try again.');
        _showRetryDialog(
          context,
          message: 'Unexpected server response. Please try again.',
        );
        return;
      }

      controller.markSubmitted();
      _showSuccessDialog(context, item);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      debugPrint(
          '[Submit] ApiException status=${e.statusCode} message=${e.message}');
      if (e.statusCode == 409) {
        controller.setError('Duplicate submission detected.');
        _showDuplicateDialog(context);
      } else if (e.statusCode == 400) {
        controller.setError(e.message);
        _showRetryDialog(context, message: e.message, errors: e.errors);
      } else {
        controller.setError(e.message);
        _showRetryDialog(context, message: e.message);
      }
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('[Submit] Unexpected error: $e');
      const fallback = 'Something went wrong. Please try again.';
      controller.setError(fallback);
      _showRetryDialog(context, message: fallback);
    } finally {
      if (context.mounted) controller.setSubmitting(false);
    }
  }

  String? _missingField(ReportModel r) {
    if (r.image == null) return 'An image is required.';
    if (r.widthInch == null || r.widthInch! <= 0) {
      return 'Width must be a positive number.';
    }
    if (r.heightInch == null || r.heightInch! <= 0) {
      return 'Height must be a positive number.';
    }
    if (r.latitude == null) return 'Latitude is required.';
    if (r.longitude == null) return 'Longitude is required.';
    if (r.accuracy == null) return 'Location accuracy is required.';
    if (r.capturedAt == null && r.locationCapturedAt == null) {
      return 'Capture timestamp is required.';
    }
    return null;
  }

  void _showSuccessDialog(BuildContext context, MeasurementItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogHeader(
              icon: Icons.check_rounded,
              color: AppTheme.primaryDark,
              title: 'Details saved successfully',
              subtitle:
                  'Measurement #${item.id ?? '-'} is now in your history.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kvRow('ID', '${item.id ?? '-'}'),
                        _kvRow('Width', '${item.width} in'),
                        _kvRow('Height', '${item.height} in'),
                        _kvRow('Sq. Ft', _num(item.sqft)),
                        _kvRow('Latitude', _num(item.latitude)),
                        _kvRow('Longitude', _num(item.longitude)),
                        _kvRow('Accuracy', '${_num(item.accuracy)} m'),
                        _kvRow('Timestamp', item.timestamp),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        context.read<ReportController>().resetAll();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: const Text(
                        'Create New Measurement',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRetryDialog(
    BuildContext context, {
    required String message,
    List<String>? errors,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogHeader(
              icon: Icons.error_outline_rounded,
              color: const Color(0xFFE5484D),
              title: 'Submission failed',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (errors != null && errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final error in errors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $error',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            side: BorderSide(
                              color: AppTheme.textSecondary.withValues(
                                  alpha: 0.4),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _submit(context);
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('Try Again'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDuplicateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogHeader(
              icon: Icons.info_outline_rounded,
              color: const Color(0xFFB26A00),
              title: 'Duplicate submission detected',
              subtitle: 'This measurement has already been saved.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB26A00),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogHeader({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.18)!],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kvRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              key,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  String _num(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReportController>();

    return Scaffold(
      body: Column(
        children: [
          const StepProgressHeader(
            step: 5,
            total: 5,
            title: 'Submit',
            subtitle: 'Send the finished report to the server.',
            showBack: false,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                if (c.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECE9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFE5484D), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.error!,
                            style: const TextStyle(
                              color: Color(0xFFB53B40),
                              fontSize: 13.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.cloud_upload_outlined,
                              color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ready to send',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'The report will be uploaded together with the '
                          'photo, measurements and location.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: c.isSubmitting ? 'Submitting…' : 'Save Report',
                          loading: c.isSubmitting,
                          icon: Icons.cloud_upload_rounded,
                          onPressed:
                              c.isSubmitting ? null : () => _submit(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}