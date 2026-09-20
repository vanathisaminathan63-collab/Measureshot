import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/report_controller.dart';
import '../models/report_model.dart';
import '../theme/app_theme.dart';
import 'capture_view.dart';
import 'location_view.dart';
import 'measurement_view.dart';
import 'review_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  List<_Step> _buildSteps(ReportModel r) => [
        _Step(
          label: 'Capture',
          description: 'Add a clear photo of the surface.',
          icon: Icons.camera_alt_outlined,
          done: r.image != null,
        ),
        _Step(
          label: 'Measurements',
          description: 'Enter width and height in inches.',
          icon: Icons.straighten_rounded,
          done: r.widthInch != null && r.heightInch != null,
        ),
        _Step(
          label: 'Location',
          description: 'Pin the address of the surface.',
          icon: Icons.location_on_outlined,
          done: r.latitude != null && r.longitude != null,
        ),
        _Step(
          label: 'Review',
          description: 'Verify details and finish the report.',
          icon: Icons.task_alt_rounded,
          done: r.isSubmitted,
        ),
      ];

  Widget _nextView(ReportModel r) {
    if (r.image == null) return const CaptureView();
    if (r.widthInch == null || r.heightInch == null) {
      return const MeasurementView();
    }
    if (r.latitude == null || r.longitude == null) {
      return const LocationView();
    }
    return const ReviewView();
  }

  void _startNew(BuildContext context) {
    context.read<ReportController>().resetAll();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CaptureView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = context.watch<ReportController>().report;
    final steps = _buildSteps(report);
    final done = steps.where((s) => s.done).length;
    final inProgress = done > 0 && !report.isSubmitted;
    final currentIndex = steps.indexWhere((s) => !s.done);

    return Scaffold(
      body: Column(
        children: [
          _Hero(done: done, total: steps.length),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                if (inProgress) ...[
                  _ContinueCard(
                    done: done,
                    total: steps.length,
                    nextLabel: steps[currentIndex].label,
                    onContinue: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _nextView(report)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _NewReportCard(
                  hasInProgress: inProgress,
                  onStart: () => _startNew(context),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step {
  final String label;
  final String description;
  final IconData icon;
  final bool done;

  _Step({
    required this.label,
    required this.description,
    required this.icon,
    required this.done,
  });
}

class _Hero extends StatelessWidget {
  final int done;
  final int total;

  const _Hero({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = done == total && total > 0;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.headerGradient,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -64,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 96,
            bottom: -70,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.straighten_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MeasureShot',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              ' measurement reports',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    allDone
                        ? 'All steps completed'
                        : 'Profile a surface in minutes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Capture, measure and pin the location, then submit the '
                    'report.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 7,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.22),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$done/$total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final int done;
  final int total;
  final String nextLabel;
  final VoidCallback onContinue;

  const _ContinueCard({
    required this.done,
    required this.total,
    required this.nextLabel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.playlist_play_rounded,
                    size: 18,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report in progress',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Next step: $nextLabel',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 6,
                color: AppTheme.accent,
                backgroundColor: AppTheme.divider,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewReportCard extends StatelessWidget {
  final bool hasInProgress;
  final VoidCallback onStart;

  const _NewReportCard({
    required this.hasInProgress,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                size: 20,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'New report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              hasInProgress
                  ? 'Starting fresh clears the current draft.'
                  : 'Profile a new surface with a photo, measurements '
                      'and location.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Start New Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 14, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Text(
                'Data is sent securely over HTTPS',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Saved reports appear under the History tab.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}