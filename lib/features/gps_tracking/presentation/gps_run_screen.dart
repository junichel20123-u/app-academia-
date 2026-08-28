import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';
import '../../../core/utils/enum_labels.dart';
import '../application/gps_permission_flow.dart';
import '../application/gps_run_providers.dart';
import '../application/gps_tracking_controller.dart';
import 'widgets/gps_run_stats.dart';

const _trackableActivityTypes = [
  CardioActivityType.run,
  CardioActivityType.walk,
];

class GpsRunScreen extends ConsumerStatefulWidget {
  const GpsRunScreen({super.key});

  @override
  ConsumerState<GpsRunScreen> createState() => _GpsRunScreenState();
}

class _GpsRunScreenState extends ConsumerState<GpsRunScreen> {
  CardioActivityType _activityType = CardioActivityType.run;
  bool _isStarting = false;
  bool _backgroundLocationDenied = false;
  bool _resumeTriggered = false;
  // Set as soon as this screen instance itself starts a run. Guards against
  // a real race: right after Stop/Descartar, `gpsTrackingControllerProvider`
  // resets to idle synchronously, but `activeGpsRunProvider`'s DB stream can
  // take an extra microtask/frame to emit the resulting `null` — during
  // that gap this instance's own just-finished run would otherwise look
  // exactly like a stale in-progress row left by a killed process, and
  // trigger a spurious `resume()`.
  bool _startedLocally = false;

  Future<void> _resume(GpsRunSession run) async {
    await ref.read(gpsTrackingControllerProvider.notifier).resume(run);
  }

  Future<void> _start() async {
    final flow = ref.read(gpsPermissionFlowProvider);
    setState(() => _isStarting = true);

    if (!await flow.isLocationServiceEnabled()) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      final open = await _confirm(
        title: 'Ative o GPS',
        message: 'Ative o GPS do seu aparelho para rastrear a corrida.',
        confirmLabel: 'Abrir configurações',
      );
      if (open == true) await flow.openLocationSettings();
      return;
    }

    final controller = ref.read(gpsTrackingControllerProvider.notifier);
    final outcome = await controller.ensurePermissions(flow: flow);
    if (!mounted) return;

    switch (outcome) {
      case GpsPermissionOutcome.ready:
        final backgroundGranted = await flow.isBackgroundLocationGranted();
        if (!mounted) return;
        setState(() {
          _isStarting = false;
          _backgroundLocationDenied = !backgroundGranted;
        });
        _startedLocally = true;
        await controller.start(activityType: _activityType);
      case GpsPermissionOutcome.locationServiceOff:
        setState(() => _isStarting = false);
      case GpsPermissionOutcome.locationDenied:
        setState(() => _isStarting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permissão de localização negada. Toque em Iniciar para tentar de novo.',
              ),
            ),
          );
        }
      case GpsPermissionOutcome.locationPermanentlyDenied:
        setState(() => _isStarting = false);
        final open = await _confirm(
          title: 'Permissão negada permanentemente',
          message:
              'Para rastrear a corrida, permita o acesso à localização nas '
              'configurações do app.',
          confirmLabel: 'Abrir configurações',
        );
        if (open == true) await flow.openSystemAppSettings();
    }
  }

  Future<void> _stop() async {
    HapticFeedback.mediumImpact();
    final snapshot = ref.read(gpsTrackingControllerProvider);
    final action = await showDialog<_StopAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Corrida/caminhada'),
        content: GpsRunStats(
          elapsed: snapshot.elapsed,
          distanceMeters: snapshot.distanceMeters,
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_StopAction.continueTracking),
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_StopAction.discard),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_StopAction.save),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    switch (action) {
      case _StopAction.save:
        await ref.read(gpsTrackingControllerProvider.notifier).stop();
      case _StopAction.discard:
        final confirmed = await _confirm(
          title: 'Descartar esta corrida?',
          message: 'A distância percorrida não será salva.',
          confirmLabel: 'Descartar',
        );
        if (confirmed == true) {
          await ref.read(gpsTrackingControllerProvider.notifier).discard();
        }
      case _StopAction.continueTracking:
      case null:
        break;
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(gpsTrackingControllerProvider);
    final activeRunAsync = ref.watch(activeGpsRunProvider);

    final activeRun = activeRunAsync.value;
    if (!_resumeTriggered &&
        !_startedLocally &&
        activeRun != null &&
        snapshot.phase == GpsTrackingPhase.idle) {
      _resumeTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _resume(activeRun));
    }

    final tracking = snapshot.phase == GpsTrackingPhase.tracking;

    return Scaffold(
      appBar: AppBar(title: const Text('Corrida/caminhada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!tracking) ...[
                SegmentedButton<CardioActivityType>(
                  segments: [
                    for (final type in _trackableActivityTypes)
                      ButtonSegment(
                        value: type,
                        label: Text(cardioActivityTypeLabel(type)),
                      ),
                  ],
                  selected: {_activityType},
                  onSelectionChanged: (selection) =>
                      setState(() => _activityType = selection.first),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton.icon(
                  icon: _isStarting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Iniciar'),
                  onPressed: _isStarting ? null : _start,
                ),
              ] else ...[
                GpsRunStats(
                  elapsed: snapshot.elapsed,
                  distanceMeters: snapshot.distanceMeters,
                ),
                if (_backgroundLocationDenied) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Permissão "sempre" não concedida — o rastreamento pode '
                    'parar se você minimizar o app por muito tempo.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                FilledButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Parar'),
                  onPressed: _stop,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _StopAction { continueTracking, discard, save }
