import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/measurement_controller.dart';
import '../controllers/report_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';
import 'location_view.dart';

class MeasurementView extends StatelessWidget {
  const MeasurementView({super.key});

  @override
  Widget build(BuildContext context) {
    final mc = context.watch<MeasurementController>();
    final value =
        mc.isValid ? '${mc.squareFeet.toStringAsFixed(2)} sq ft' : '—';

    return Scaffold(
      body: Column(
        children: [
          const StepProgressHeader(
            step: 2,
            total: 5,
            title: 'Measurements',
            subtitle: 'Enter the dimensions of the surface in inches.',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              children: [
                TextFormField(
                  initialValue: mc.widthText,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Width',
                    suffixText: 'in',
                    errorText: mc.widthError,
                  ),
                  onChanged: mc.setWidth,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: mc.heightText,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Height',
                    suffixText: 'in',
                    errorText: mc.heightError,
                  ),
                  onChanged: mc.setHeight,
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primary,
                          AppTheme.primaryDark,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Surface area',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                value,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.square_foot_rounded,
                              color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Square feet = width (in) × height (in) ÷ 144',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Next',
                  onPressed: mc.isValid
                      ? () {
                          context.read<ReportController>().setMeasurements(
                                mc.width,
                                mc.height,
                              );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LocationView()),
                          );
                        }
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