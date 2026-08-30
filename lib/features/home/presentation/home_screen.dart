import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../plans/domain/training_plan.dart';
import '../../plans/presentation/training_plan_screen.dart';
import '../../profile/presentation/profile_sheet.dart';
import '../../workout/domain/workout_mode.dart';
import '../../workout/presentation/active_workout_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final goals = ref.watch(goalsProvider);
    final plan = ref.watch(beginnerPlanProgressProvider);
    final profileData = profile.asData?.value;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(goalsProvider);
          ref.invalidate(workoutHistoryProvider);
          ref.invalidate(beginnerPlanProgressProvider);
          ref.invalidate(personalRecordsProvider);
          ref.invalidate(weeklyProgressProvider);
          await ref.read(dashboardStatsProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RUNFORGE',
                              style: TextStyle(
                                color: AppTheme.neonLime,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            profile.when(
                              data: (p) => Text(
                                'Olá, ${p.name}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              loading: () => const Text('Preparando seu treino...'),
                              error: (_, __) => const Text('Seu painel'),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Editar perfil',
                        onPressed: profileData == null
                            ? null
                            : () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  showDragHandle: false,
                                  builder: (_) => ProfileSheet(initial: profileData),
                                ),
                        icon: const Icon(Icons.person_rounded),
                      ),
                    ],
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: -.08),
                  const SizedBox(height: 22),
                  plan.when(
                    data: (value) => _TodayWorkoutCard(
                      progress: value,
                      onStart: value.nextSession == null
                          ? null
                          : () => _openPlanWorkout(context, value.nextSession!),
                      onOpenPlan: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TrainingPlanScreen()),
                      ),
                    ),
                    loading: () => const _LoadingCard(),
                    error: (error, _) => _ErrorCard(message: '$error'),
                  ),
                  const SizedBox(height: 16),
                  _HeroStartCard(
                    onFree: () => _openWorkout(context, WorkoutMode.free),
                    onInterval: () => _openWorkout(context, WorkoutMode.interval),
                  ).animate().fadeIn(delay: 80.ms).slideY(begin: .08),
                  const SizedBox(height: 18),
                  Text(
                    'Sua semana',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  stats.when(
                    data: (s) => PremiumCard(
                      child: Row(
                        children: [
                          ProgressRing(
                            progress: (s.weekDistanceKm / 10).clamp(0.0, 1.0).toDouble(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.weekDistanceKm.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                const Text('km', style: TextStyle(fontSize: 11, color: Colors.white54)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                _StatLine(label: 'Treinos', value: '${s.weekWorkouts}'),
                                const SizedBox(height: 12),
                                _StatLine(label: 'Tempo', value: formatDuration(s.weekDuration)),
                                const SizedBox(height: 12),
                                _StatLine(label: 'Mês', value: '${s.monthDistanceKm.toStringAsFixed(1)} km'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const _LoadingCard(),
                    error: (e, _) => _ErrorCard(message: '$e'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Metas em foco',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.neonLime.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'AUTO',
                          style: TextStyle(color: AppTheme.neonLime, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  goals.when(
                    data: (items) {
                      final active = items.where((e) => !e.goal.isCompleted).take(2).toList();
                      if (active.isEmpty) {
                        return const PremiumCard(
                          child: Text('Nenhuma meta ativa. Abra a aba Metas para criar sua próxima conquista.'),
                        );
                      }
                      return Column(
                        children: active.map((g) {
                          final distance = g.goal.metric.name == 'distanceKm';
                          final decimals = distance ? 1 : 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PremiumCard(
                              child: Row(
                                children: [
                                  ProgressRing(
                                    progress: g.ratio,
                                    size: 64,
                                    strokeWidth: 7,
                                    child: Text(
                                      '${(g.ratio * 100).round()}%',
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(g.goal.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${g.current.toStringAsFixed(decimals)} / ${g.goal.target.toStringAsFixed(decimals)} ${distance ? 'km' : 'dias'}',
                                          style: const TextStyle(color: Colors.white60),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const _LoadingCard(),
                    error: (e, _) => _ErrorCard(message: '$e'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWorkout(BuildContext context, WorkoutMode mode) {
    Navigator.of(context).push(_workoutRoute(ActiveWorkoutScreen(mode: mode)));
  }

  void _openPlanWorkout(BuildContext context, TrainingPlanSession session) {
    Navigator.of(context).push(
      _workoutRoute(
        ActiveWorkoutScreen(
          mode: session.mode,
          initialIntervalConfig: session.intervalConfig,
          planSession: session,
        ),
      ),
    );
  }

  Route<void> _workoutRoute(Widget child) => PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => child,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      );
}

class _TodayWorkoutCard extends StatelessWidget {
  const _TodayWorkoutCard({required this.progress, required this.onStart, required this.onOpenPlan});
  final TrainingPlanProgress progress;
  final VoidCallback? onStart;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final next = progress.nextSession;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF313C00), Color(0xFF14170F)],
        ),
        border: Border.all(color: AppTheme.neonLime.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: AppTheme.neonLime),
              const SizedBox(width: 8),
              const Text(
                'TREINO DE HOJE',
                style: TextStyle(color: AppTheme.neonLime, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const Spacer(),
              Text('${progress.completedSessions}/${progress.totalSessions}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          if (next == null) ...[
            Text('Plano concluído!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('As 24 sessões do plano iniciante foram concluídas.'),
          ] else ...[
            Text(next.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(next.description),
            if (next.intervalConfig != null) ...[
              const SizedBox(height: 4),
              Text('~${formatDuration(next.intervalConfig!.totalDuration)} programados', style: const TextStyle(color: Colors.white54)),
            ],
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (onStart != null) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Começar')),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenPlan,
                  child: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Ver plano')),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: .05);
  }
}

class _HeroStartCard extends StatelessWidget {
  const _HeroStartCard({required this.onFree, required this.onInterval});
  final VoidCallback onFree;
  final VoidCallback onInterval;

  @override
  Widget build(BuildContext context) => PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppTheme.neonLime),
                SizedBox(width: 8),
                Text('TREINO RÁPIDO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Fora do plano? Inicie uma corrida livre ou monte seu próprio intervalado.'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onFree,
                    icon: const Icon(Icons.directions_run_rounded),
                    label: const Text('Livre'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onInterval,
                    icon: const Icon(Icons.timer_rounded),
                    label: const Text('Intervalado'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white54))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const PremiumCard(child: Center(child: CircularProgressIndicator()));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => PremiumCard(child: Text('Não foi possível carregar: $message'));
}
