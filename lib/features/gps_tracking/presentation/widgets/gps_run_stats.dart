import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

String formatElapsed(Duration elapsed) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes.remainder(60);
  final seconds = elapsed.inSeconds.remainder(60);
  return hours > 0
      ? '${two(hours)}:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}

/// The live time + distance readout shown while a GPS run is being
/// tracked. Purely presentational — [elapsed]/[distanceMeters] come from
/// `GpsTrackingSnapshot`.
class GpsRunStats extends StatelessWidget {
  const GpsRunStats({
    super.key,
    required this.elapsed,
    required this.distanceMeters,
  });

  final Duration elapsed;
  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final km = distanceMeters / 1000;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatElapsed(elapsed),
          style: theme.textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${km.toStringAsFixed(2)} km',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
