import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/report_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/step_progress_header.dart';
import 'submit_view.dart';

class ReviewView extends StatelessWidget {
  const ReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReportController>().report;

    return Scaffold(
      body: Column(
        children: [
          const StepProgressHeader(
            step: 4,
            total: 5,
            title: 'Review',
            subtitle: 'Confirm every detail before submitting.',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                SectionCard(
                  icon: Icons.photo_outlined,
                  title: 'Image',
                  child: r.image == null
                      ? const Text(
                          '-',
                          style: TextStyle(color: AppTheme.textSecondary),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            r.image!,
                            height: 170,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  icon: Icons.straighten_rounded,
                  title: 'Measurements',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kvRow('Width', '${r.widthInch ?? '-'} in'),
                      const SizedBox(height: 8),
                      _kvRow('Height', '${r.heightInch ?? '-'} in'),
                      const SizedBox(height: 8),
                      _kvRow('Square feet',
                          r.squareFeet.toStringAsFixed(2)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kvRow('Latitude', '${r.latitude ?? '-'}'),
                      const SizedBox(height: 8),
                      _kvRow('Longitude', '${r.longitude ?? '-'}'),
                      const SizedBox(height: 8),
                      _kvRow('Accuracy', '${r.accuracy ?? '-'} m'),
                      const SizedBox(height: 8),
                      _kvRow('Address', r.address ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  icon: Icons.schedule_rounded,
                  title: 'Timestamps',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kvRow('Captured',
                          _fmt(r.capturedAt)),
                      const SizedBox(height: 8),
                      _kvRow('Located',
                          _fmt(r.locationCapturedAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Proceed to Submit',
                  icon: Icons.cloud_upload_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubmitView()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(String key, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
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
          child: Text(
            value,
            style: const TextStyle(fontSize: 13.5, height: 1.35),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return '-';
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}