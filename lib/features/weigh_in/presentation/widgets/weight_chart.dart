import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

/// Line chart of body weight over time.
///
/// [entries] must be sorted ascending by [WeighIn.occurredAt].
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.entries});

  final List<WeighIn> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('Adicione ao menos 2 pesagens para ver o gráfico.'),
        ),
      );
    }

    final spots = [
      for (var i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].weightKg),
    ];
    final weights = entries.map((e) => e.weightKg);
    final minY = weights.reduce(math.min) - 1;
    final maxY = weights.reduce(math.max) + 1;
    final color = Theme.of(context).colorScheme.primary;

    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 16),
        child: LineChart(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: true),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index != 0 && index != entries.length - 1) {
                      return const SizedBox.shrink();
                    }
                    if (index < 0 || index >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    final date = entries[index].occurredAt;
                    return Text('${date.day}/${date.month}');
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                color: color,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
