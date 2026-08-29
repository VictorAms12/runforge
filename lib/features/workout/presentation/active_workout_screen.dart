import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_card.dart';
import 'workout_session_controller.dart';

class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key, required this.mode});
  final WorkoutMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutSessionProvider(mode));
    final controller = ref.read(workoutSessionProvider(mode).notifier);

    return PopScope(
      canPop: state.status == WorkoutStatus.idle || state.status == WorkoutStatus.finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitWarning(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              children: [
                _TopBar(mode: mode, state: state, onLock: controller.toggleLock),
                const SizedBox(height: 16),
                if (state.locationMessage != null)
                  _LocationBanner(message: state.locationMessage!),
                if (state.locationMessage != null) const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        if (mode == WorkoutMode.interval)
                          _IntervalCard(
                            controller: controller,
                            state: state,
                            onConfigure: state.status == WorkoutStatus.idle
                                ? () => _configureIntervals(context, controller)
                                : null,
                          ),
                        if (mode == WorkoutMode.interval) const SizedBox(height: 14),
                        PremiumCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              MetricTile(
                                label: 'Tempo',
                                value: formatDuration(state.elapsed),
                                emphasized: true,
                              ),
                              const SizedBox(height: 26),
                              Row(
                                children: [
                                  Expanded(
                                    child: MetricTile(
                                      label: 'Distância',
                                      value: state.distanceKm.toStringAsFixed(2),
                                      unit: 'km',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: MetricTile(
                                      label: 'Pace médio',
                                      value: formatPace(state.avgPaceMinKm),
                                      unit: '/km',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: MetricTile(
                                      label: 'Pace atual',
                                      value: formatPace(state.currentPaceMinKm),
                                      unit: '/km',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: MetricTile(
                                      label: 'Calorias',
                                      value: state.calories.toStringAsFixed(0),
                                      unit: 'kcal',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate(target: state.isRunning ? 1 : 0).shimmer(duration: 900.ms),
                        if (state.laps.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          PremiumCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('SPLITS / VOLTAS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                const SizedBox(height: 12),
                                ...state.laps.asMap().entries.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 5),
                                        child: Row(
                                          children: [
                                            Text('#${entry.key + 1}', style: const TextStyle(color: Colors.white54)),
                                            const Spacer(),
                                            Text(formatDuration(entry.value), style: const TextStyle(fontWeight: FontWeight.w800)),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Controls(
                  state: state,
                  onStart: controller.start,
                  onPause: controller.pause,
                  onLap: controller.addLap,
                  onFinish: () => _finish(context, ref, controller),
                  onUnlock: controller.toggleLock,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _configureIntervals(
    BuildContext context,
    WorkoutSessionController controller,
  ) async {
    final run = TextEditingController(text: controller.intervals.first.duration.inSeconds.toString());
    final walk = TextEditingController(text: controller.intervals.last.duration.inSeconds.toString());
    final values = await showDialog<(int, int)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar intervalos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: run,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Corrida forte (segundos)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: walk,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Caminhada/recuperação (segundos)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final r = int.tryParse(run.text);
              final w = int.tryParse(walk.text);
              if (r == null || w == null || r <= 0 || w <= 0) return;
              Navigator.pop(context, (r, w));
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    run.dispose();
    walk.dispose();
    if (values != null) {
      controller.configureIntervals(
        run: Duration(seconds: values.$1),
        walk: Duration(seconds: values.$2),
      );
    }
  }

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    WorkoutSessionController controller,
  ) async {
    controller.pause();
    final notesController = TextEditingController();
    final shouldFinish = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Finalizar treino?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Você pode adicionar uma observação rápida. O treino será salvo no histórico local.'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Como foi a corrida? Dor, esforço, sensação...'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Salvar e finalizar'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar treino'),
            ),
          ],
        ),
      ),
    );

    if (shouldFinish == true) {
      await controller.finish(notes: notesController.text);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(goalsProvider);
      if (context.mounted) Navigator.pop(context);
    } else {
      await controller.start();
    }
    notesController.dispose();
  }

  Future<void> _showExitWarning(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Treino em andamento'),
        content: const Text('Finalize o treino antes de sair para não perder a sessão atual.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.mode, required this.state, required this.onLock});
  final WorkoutMode mode;
  final WorkoutSessionState state;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: state.status == WorkoutStatus.idle || state.status == WorkoutStatus.finished
              ? () => Navigator.pop(context)
              : null,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode == WorkoutMode.free ? 'CORRIDA LIVRE' : 'INTERVALADO', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4)),
              Text(
                state.gpsActive ? 'GPS ativo' : 'GPS sem sinal',
                style: TextStyle(color: state.gpsActive ? AppTheme.neonLime : Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: state.isLocked ? 'Desbloquear' : 'Travar tela',
          onPressed: onLock,
          icon: Icon(state.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded),
        ),
      ],
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, size: 18, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _IntervalCard extends StatelessWidget {
  const _IntervalCard({required this.controller, required this.state, this.onConfigure});
  final WorkoutSessionController controller;
  final WorkoutSessionState state;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final segment = controller.intervals[state.intervalIndex];
    final total = segment.duration.inSeconds;
    final remaining = state.intervalRemaining.inSeconds.clamp(0, total).toInt();
    final progress = total == 0 ? 0.0 : 1 - (remaining / total);
    final accent = segment.intense ? AppTheme.electricCoral : AppTheme.neonLime;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(segment.intense ? Icons.speed_rounded : Icons.directions_walk_rounded, color: accent),
              const SizedBox(width: 8),
              Text(segment.label, style: TextStyle(color: accent, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              const Spacer(),
              if (onConfigure != null)
                IconButton(
                  tooltip: 'Configurar intervalos',
                  onPressed: onConfigure,
                  icon: const Icon(Icons.tune_rounded),
                ),
              Text(formatDuration(state.intervalRemaining), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: progress, minHeight: 8, color: accent, backgroundColor: Colors.white10),
          ),
          const SizedBox(height: 8),
          Text(
            'Ciclo: ${formatDuration(controller.intervals.first.duration)} forte / ${formatDuration(controller.intervals.last.duration)} recuperação • repetição contínua',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onStart,
    required this.onPause,
    required this.onLap,
    required this.onFinish,
    required this.onUnlock,
  });

  final WorkoutSessionState state;
  final Future<void> Function() onStart;
  final VoidCallback onPause;
  final VoidCallback onLap;
  final VoidCallback onFinish;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    if (state.isLocked) {
      return GestureDetector(
        onLongPress: onUnlock,
        child: Container(
          height: 64,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: .06),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded),
              SizedBox(width: 10),
              Text('SEGURE PARA DESBLOQUEAR', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8)),
            ],
          ),
        ),
      );
    }

    final idle = state.status == WorkoutStatus.idle;
    final running = state.status == WorkoutStatus.running;

    return Row(
      children: [
        if (!idle) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onLap,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 17),
                child: Text('SPLIT'),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: running ? onPause : onStart,
            icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Text(idle ? 'START' : running ? 'PAUSE' : 'RETOMAR'),
            ),
          ),
        ).animate(key: ValueKey(state.status)).scale(begin: const Offset(.96, .96), duration: 180.ms),
        if (!idle) ...[
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(foregroundColor: AppTheme.electricCoral),
              onPressed: onFinish,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 17),
                child: Icon(Icons.stop_rounded),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
