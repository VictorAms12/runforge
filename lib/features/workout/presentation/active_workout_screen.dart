import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/premium_card.dart';
import '../../plans/domain/training_plan.dart';
import '../domain/interval_workout_config.dart';
import '../domain/workout_mode.dart';
import 'workout_session_controller.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.mode,
    this.initialIntervalConfig,
    this.planSession,
  });

  final WorkoutMode mode;
  final IntervalWorkoutConfig? initialIntervalConfig;
  final TrainingPlanSession? planSession;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  bool _configured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(workoutSessionProvider(widget.mode).notifier);
      if (widget.initialIntervalConfig != null) {
        controller.configureIntervals(widget.initialIntervalConfig!);
      }
      final plan = widget.planSession;
      if (plan != null) {
        controller.configurePlanSession(
          index: plan.index,
          title: plan.title,
          targetDuration: plan.targetDuration,
          targetDistanceKm: plan.targetDistanceKm,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutSessionProvider(widget.mode));
    final controller = ref.read(workoutSessionProvider(widget.mode).notifier);
    final canPop = state.status == WorkoutStatus.idle || state.status == WorkoutStatus.finished;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitWarning();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              children: [
                _TopBar(
                  mode: widget.mode,
                  state: state,
                  onBack: canPop ? () => Navigator.pop(context) : null,
                  onLock: controller.toggleLock,
                ),
                const SizedBox(height: 14),
                if (state.planTitle != null) ...[
                  _PlanBanner(title: state.planTitle!),
                  const SizedBox(height: 10),
                ],
                if (state.locationMessage != null) ...[
                  _StatusBanner(
                    icon: Icons.location_off_rounded,
                    message: state.locationMessage!,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 10),
                ],
                if (state.isAutoPaused) ...[
                  const _StatusBanner(
                    icon: Icons.pause_circle_filled_rounded,
                    message: 'Auto-pause ativo. O cronômetro retoma quando você voltar a se mover.',
                    color: AppTheme.neonLime,
                  ),
                  const SizedBox(height: 10),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        if (widget.mode == WorkoutMode.interval) ...[
                          _IntervalCard(
                            controller: controller,
                            state: state,
                            onConfigure: state.status == WorkoutStatus.idle && widget.planSession == null
                                ? () => _configureIntervals(controller)
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (widget.mode == WorkoutMode.free && widget.planSession != null) ...[
                          _FreePlanTargetCard(state: state),
                          const SizedBox(height: 12),
                        ],
                        if (state.status == WorkoutStatus.idle) ...[
                          _AutomationCard(
                            state: state,
                            onAutoPause: controller.setAutoPauseEnabled,
                            onAutoSplit: controller.setAutoSplitEnabled,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (state.intervalCompleted) ...[
                          const _StatusBanner(
                            icon: Icons.emoji_events_rounded,
                            message: 'Treino programado concluído. Salve a sessão para registrar o progresso.',
                            color: AppTheme.neonLime,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _MetricsCard(state: state),
                        if (state.splits.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _SplitsCard(state: state),
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
                  onFinish: () => _finish(controller, state),
                  onUnlock: controller.toggleLock,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _configureIntervals(WorkoutSessionController controller) async {
    final current = controller.intervalConfig;
    final warmup = TextEditingController(text: current.warmup.inSeconds.toString());
    final run = TextEditingController(text: current.run.inSeconds.toString());
    final recovery = TextEditingController(text: current.recovery.inSeconds.toString());
    final cycles = TextEditingController(text: current.cycles.toString());
    final cooldown = TextEditingController(text: current.cooldown.inSeconds.toString());

    final config = await showDialog<IntervalWorkoutConfig>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Configurar intervalado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Templates rápidos', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: WorkoutTemplateCatalog.all
                    .map(
                      (template) => ActionChip(
                        label: Text(template.title),
                        onPressed: () => Navigator.pop(dialogContext, template),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _NumberField(controller: warmup, label: 'Aquecimento (s)'),
              const SizedBox(height: 9),
              _NumberField(controller: run, label: 'Corrida (s)'),
              const SizedBox(height: 9),
              _NumberField(controller: recovery, label: 'Recuperação (s)'),
              const SizedBox(height: 9),
              _NumberField(controller: cycles, label: 'Ciclos'),
              const SizedBox(height: 9),
              _NumberField(controller: cooldown, label: 'Desaquecimento (s)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final w = int.tryParse(warmup.text) ?? 0;
              final r = int.tryParse(run.text);
              final rec = int.tryParse(recovery.text);
              final c = int.tryParse(cycles.text);
              final cool = int.tryParse(cooldown.text) ?? 0;
              if (r == null || rec == null || c == null || r <= 0 || rec <= 0 || c <= 0 || c > 99 || w < 0 || cool < 0) {
                return;
              }
              Navigator.pop(
                dialogContext,
                IntervalWorkoutConfig(
                  id: 'custom_${r}_${rec}_$c',
                  title: 'Personalizado',
                  warmup: Duration(seconds: w),
                  run: Duration(seconds: r),
                  recovery: Duration(seconds: rec),
                  cycles: c,
                  cooldown: Duration(seconds: cool),
                ),
              );
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    warmup.dispose();
    run.dispose();
    recovery.dispose();
    cycles.dispose();
    cooldown.dispose();
    if (config != null) controller.configureIntervals(config);
  }

  Future<void> _finish(WorkoutSessionController controller, WorkoutSessionState state) async {
    if (state.status == WorkoutStatus.running || state.status == WorkoutStatus.autoPaused) {
      controller.pause();
    }
    final notes = TextEditingController();
    int? rpe = 5;
    final targetMet = _planTargetMet(state);
    final result = await showModalBottomSheet<({bool save, int? rpe})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Como foi o treino?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('RPE é sua percepção de esforço: 1 muito leve, 10 máximo.'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(10, (index) {
                  final value = index + 1;
                  return ChoiceChip(
                    label: Text('$value'),
                    selected: rpe == value,
                    onSelected: (_) => setSheetState(() => rpe = value),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(_rpeLabel(rpe), style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 14),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Dor, cansaço, sensação, observações...'),
              ),
              if (!targetMet && state.planSessionIndex != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'A sessão será salva no histórico, mas o plano não avançará porque o alvo ainda não foi cumprido.',
                    style: TextStyle(color: Colors.amber),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, (save: true, rpe: rpe)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Salvar e finalizar'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, (save: false, rpe: rpe)),
                child: const Text('Continuar treino'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result?.save == true) {
      await controller.finish(notes: notes.text, rpe: result?.rpe);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(goalsProvider);
      ref.invalidate(personalRecordsProvider);
      ref.invalidate(weeklyProgressProvider);
      ref.invalidate(beginnerPlanProgressProvider);
      if (mounted) Navigator.pop(context);
    } else if (!state.intervalCompleted) {
      await controller.start();
    }
    notes.dispose();
  }

  bool _planTargetMet(WorkoutSessionState state) {
    if (state.planSessionIndex == null) return true;
    if (state.mode == WorkoutMode.interval) return state.intervalCompleted;
    if (state.planTargetDistanceKm != null) return state.distanceKm >= state.planTargetDistanceKm!;
    if (state.planTargetDuration != null) return state.elapsed >= state.planTargetDuration!;
    return true;
  }

  Future<void> _showExitWarning() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Treino em andamento'),
          content: const Text('Finalize o treino antes de sair para não perder a sessão atual.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
        ),
      );
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.mode, required this.state, required this.onBack, required this.onLock});
  final WorkoutMode mode;
  final WorkoutSessionState state;
  final VoidCallback? onBack;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton.filledTonal(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mode == WorkoutMode.free ? 'CORRIDA LIVRE' : 'INTERVALADO', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                Text(
                  state.gpsActive ? 'GPS ativo' : 'GPS sem sinal',
                  style: TextStyle(color: state.gpsActive ? AppTheme.neonLime : Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onLock,
            icon: Icon(state.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded),
          ),
        ],
      );
}

class _PlanBanner extends StatelessWidget {
  const _PlanBanner({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.neonLime.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.neonLime.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            const Icon(Icons.route_rounded, color: AppTheme.neonLime, size: 18),
            const SizedBox(width: 9),
            Expanded(child: Text('PLANO 5K · $title', style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
      );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.message, required this.color});
  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}

class _IntervalCard extends StatelessWidget {
  const _IntervalCard({required this.controller, required this.state, this.onConfigure});
  final WorkoutSessionController controller;
  final WorkoutSessionState state;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final config = controller.intervalConfig;
    final segment = controller.currentInterval;
    final total = segment.duration.inSeconds;
    final remaining = state.intervalRemaining.inSeconds.clamp(0, total).toInt();
    final stepProgress = total == 0 ? 1.0 : (1 - remaining / total).clamp(0.0, 1.0).toDouble();
    final overall = config.totalDuration.inSeconds == 0
        ? 0.0
        : (state.elapsed.inSeconds / config.totalDuration.inSeconds).clamp(0.0, 1.0).toDouble();
    final accent = state.intervalIntense ? AppTheme.electricCoral : AppTheme.neonLime;
    final cycleText = state.currentCycle <= 0 ? 'Preparação' : 'Ciclo ${state.currentCycle}/${state.totalCycles}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(state.intervalIntense ? Icons.directions_run_rounded : Icons.timer_outlined, color: accent),
              const SizedBox(width: 8),
              Expanded(child: Text(state.intervalLabel, style: TextStyle(color: accent, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
              if (onConfigure != null) IconButton(onPressed: onConfigure, icon: const Icon(Icons.tune_rounded)),
            ],
          ),
          Text(cycleText, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(formatDuration(state.intervalRemaining), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: stepProgress, minHeight: 8, color: accent, backgroundColor: Colors.white10),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('${formatDuration(config.run)} corrida / ${formatDuration(config.recovery)} recuperação × ${config.cycles}', style: const TextStyle(color: Colors.white54, fontSize: 12))),
              Text(formatDuration(config.totalDuration), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: overall, minHeight: 4, backgroundColor: Colors.white10),
          ),
        ],
      ),
    );
  }
}

class _FreePlanTargetCard extends StatelessWidget {
  const _FreePlanTargetCard({required this.state});
  final WorkoutSessionState state;

  @override
  Widget build(BuildContext context) {
    final byDistance = state.planTargetDistanceKm != null;
    final target = byDistance ? state.planTargetDistanceKm! : state.planTargetDuration!.inSeconds.toDouble();
    final current = byDistance ? state.distanceKm : state.elapsed.inSeconds.toDouble();
    final progress = (current / target).clamp(0.0, 1.0).toDouble();
    final value = byDistance
        ? '${state.distanceKm.toStringAsFixed(2)} / ${state.planTargetDistanceKm!.toStringAsFixed(1)} km'
        : '${formatDuration(state.elapsed)} / ${formatDuration(state.planTargetDuration!)}';
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppTheme.neonLime),
              const SizedBox(width: 9),
              const Text('META DE HOJE', style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              if (progress >= 1) const Icon(Icons.check_circle_rounded, color: AppTheme.neonLime),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, minHeight: 7, borderRadius: BorderRadius.circular(99)),
        ],
      ),
    );
  }
}

class _AutomationCard extends StatelessWidget {
  const _AutomationCard({required this.state, required this.onAutoPause, required this.onAutoSplit});
  final WorkoutSessionState state;
  final ValueChanged<bool> onAutoPause;
  final ValueChanged<bool> onAutoSplit;

  @override
  Widget build(BuildContext context) => PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: state.autoPauseEnabled,
              onChanged: onAutoPause,
              title: const Text('Auto-pause', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Pausa após ~10 s parado e retoma ao voltar a correr.'),
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: state.autoSplitEnabled,
              onChanged: onAutoSplit,
              title: const Text('Auto Split 1 km', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Registra automaticamente cada quilômetro.'),
            ),
          ],
        ),
      );
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.state});
  final WorkoutSessionState state;

  @override
  Widget build(BuildContext context) => PremiumCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            MetricTile(label: 'Tempo', value: formatDuration(state.elapsed), emphasized: true),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: MetricTile(label: 'Distância', value: state.distanceKm.toStringAsFixed(2), unit: 'km')),
                const SizedBox(width: 14),
                Expanded(child: MetricTile(label: 'Pace médio', value: formatPace(state.avgPaceMinKm), unit: '/km')),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: MetricTile(label: 'Pace atual', value: formatPace(state.currentPaceMinKm), unit: '/km')),
                const SizedBox(width: 14),
                Expanded(child: MetricTile(label: 'Calorias', value: state.calories.toStringAsFixed(0), unit: 'kcal')),
              ],
            ),
          ],
        ),
      ).animate(target: state.isRunning ? 1 : 0).shimmer(duration: 900.ms);
}

class _SplitsCard extends StatelessWidget {
  const _SplitsCard({required this.state});
  final WorkoutSessionState state;

  @override
  Widget build(BuildContext context) => PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('SPLITS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 10),
            ...state.splits.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Text('${entry.key + 1}${entry.value.isAuto ? ' · AUTO' : ''}', style: const TextStyle(color: Colors.white54)),
                        const Spacer(),
                        Text('${entry.value.distanceKm.toStringAsFixed(2)} km', style: const TextStyle(color: Colors.white60)),
                        const SizedBox(width: 12),
                        Text('${formatPace(entry.value.paceMinKm)}/km', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.onStart, required this.onPause, required this.onLap, required this.onFinish, required this.onUnlock});
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
              Text('SEGURE PARA DESBLOQUEAR', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    }

    final idle = state.status == WorkoutStatus.idle;
    final running = state.status == WorkoutStatus.running;
    final autoPaused = state.status == WorkoutStatus.autoPaused;
    final complete = state.intervalCompleted;

    if (complete) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onFinish,
          icon: const Icon(Icons.save_rounded),
          label: const Padding(padding: EdgeInsets.symmetric(vertical: 17), child: Text('SALVAR TREINO')),
        ),
      );
    }

    return Row(
      children: [
        if (!idle) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onLap,
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 17), child: Text('SPLIT')),
            ),
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: running ? onPause : onStart,
            icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Text(idle ? 'START' : autoPaused ? 'RETOMAR' : running ? 'PAUSE' : 'RETOMAR'),
            ),
          ),
        ),
        if (!idle) ...[
          const SizedBox(width: 9),
          Expanded(
            child: FilledButton.tonal(
              onPressed: onFinish,
              style: FilledButton.styleFrom(foregroundColor: AppTheme.electricCoral),
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 17), child: Icon(Icons.stop_rounded)),
            ),
          ),
        ],
      ],
    );
  }
}

String _rpeLabel(int? rpe) {
  if (rpe == null) return 'Sem avaliação';
  if (rpe <= 2) return 'Muito leve';
  if (rpe <= 4) return 'Leve';
  if (rpe <= 6) return 'Moderado';
  if (rpe <= 8) return 'Difícil';
  return 'Muito difícil / máximo';
}
