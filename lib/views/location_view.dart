import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../controllers/location_controller.dart';
import '../controllers/report_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';
import 'review_view.dart';

class LocationView extends StatelessWidget {
  const LocationView({super.key});

  @override
  Widget build(BuildContext context) {
    final lc = context.watch<LocationController>();

    return Scaffold(
      body: Column(
        children: [
          const StepProgressHeader(
            step: 3,
            total: 5,
            title: 'Location',
            subtitle: 'Pin the address so the report has context.',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                _StatusCard(lc: lc),
                if (lc.latitude != null) ...[
                  const SizedBox(height: 16),
                  _LocationMapCard(lc: lc),
                  const SizedBox(height: 16),
                  _LocationSummaryCard(lc: lc),
                  if (lc.accuracy != null && lc.accuracy! > 50) ...[
                    const SizedBox(height: 12),
                    const _AccuracyWarning(),
                  ],
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.tonalIcon(
onPressed: lc.isLoading
                      ? null
                      : () async {
                          final controller =
                              context.read<LocationController>();
                          try {
                            final ok = await controller.fetchLocation();
                            if (ok && context.mounted) {
                              final lat = controller.latitude;
                              final lng = controller.longitude;
                              final acc = controller.accuracy;
                              if (lat == null || lng == null || acc == null) {
                                controller.setError(
                                    'Could not get a valid location fix. '
                                    'Please try again.');
                                return;
                              }
                              context.read<ReportController>().setLocation(
                                    lat: lat,
                                    lng: lng,
                                    accuracy: acc,
                                    address: controller.address ?? '',
                                  );
                            }
                          } catch (_) {
                            if (!context.mounted) return;
                            controller.setError(
                                'Unable to retrieve your location. '
                                'Please try again.');
                          }
                        },
                    icon: const Icon(Icons.my_location_rounded, size: 20),
                    label: const Text('Get Current Location'),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Next',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: lc.latitude != null
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReviewView()),
                          )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final LocationController lc;

  const _StatusCard({required this.lc});

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (lc.isLoading) {
      content = Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Fetching your location…',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    } else if (lc.error != null) {
      content = Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE5484D), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              lc.error!,
              style: const TextStyle(
                color: Color(0xFFB53B40),
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_outlined,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Tap "Get Current Location" to pin the surface address.',
              style: TextStyle(
                fontSize: 14,
                height: 1.3,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }
}

class _LocationMapCard extends StatelessWidget {
  final LocationController lc;

  const _LocationMapCard({required this.lc});

  @override
  Widget build(BuildContext context) {
    final location = LatLng(lc.latitude ?? 0, lc.longitude ?? 0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 220,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: location, zoom: 16),
          markers: {
            Marker(
              markerId: const MarkerId('current-location'),
              position: location,
            ),
          },
          myLocationEnabled: false,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
}

class _LocationSummaryCard extends StatelessWidget {
  final LocationController lc;

  const _LocationSummaryCard({required this.lc});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Latitude', lc.latitude!.toStringAsFixed(6)),
      ('Longitude', lc.longitude!.toStringAsFixed(6)),
      ('Accuracy',
          lc.accuracy == null ? '-' : '${lc.accuracy!.toStringAsFixed(1)} m'),
      ('Address', lc.address ?? '-'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Captured location',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < rows.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              if (i < rows.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccuracyWarning extends StatelessWidget {
  const _AccuracyWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFB26A00), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Accuracy is low. Consider moving to an open area.',
              style: TextStyle(
                color: Color(0xFF8A5400),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}