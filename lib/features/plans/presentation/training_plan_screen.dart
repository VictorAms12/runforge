import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../workout/presentation/active_workout_screen.dart';
import '../domain/training_plan.dart';

class TrainingPlanScreen extends ConsumerWidget {
  const TrainingPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(beginnerPlanProgressProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano 5K'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: progress.when(
          data: (value) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(beginnerPlanProgressProvider);
              await ref.read(beginnerPlanProgressProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                PremiumCard(
                  child: Row(
                    children: [
                      ProgressRing(
                        progress: value.ratio,
                        size: 92,
                        child: Text(
                          '${(value.ratio * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DO ZERO AOS 5 KM',
                              style: TextStyle(
                                color: AppTheme.neonLime,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${value.completedSessions}/${value.totalSessions} treinos concluídos',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              '3 sessões por semana, com pelo menos um dia de recuperação entre corridas.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: .04),
                const SizedBox(height: 18),
                if (value.isCompleted)
                  const _PlanCompletedCard()
                else if (value.nextSession != null)
                  _NextSessionCard(
                    session: value.nextSession!,
                    onStart: () => _openSession(context, value.nextSession!),
                  ),
                const SizedBox(height: 22),
                ...List.generate(Beginner5kPlan.weeks, (weekIndex) {
                  final week = weekIndex + 1;
                  final sessions = Beginner5kPlan.sessions
                      .where((session) => session.week == week)
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEMANA $week',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 9),
                        ...sessions.map((session) {
                          final completed =
                              session.index < value.completedSessions;
                          final isNext =
                              session.index == value.completedSessions;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SessionTile(
                              session: session,
                              completed: completed,
                              isNext: isNext,
                              onTap: isNext
                                  ? () => _openSession(context, session)
                                  : null,
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Não foi possível carregar o plano: $error'),
            ),
          ),
        ),
      ),
    );
  }

  void _openSession(BuildContext context, TrainingPlanSession session) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ActiveWorkoutScreen(
          mode: session.mode,
          initialIntervalConfig: session.intervalConfig,
          planSession: session,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.session, required this.onStart});

  final TrainingPlanSession session;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF293300), Color(0xFF151810)],
          ),
          border: Border.all(color: AppTheme.neonLime.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PRÓXIMO TREINO',
              style: TextStyle(
                color: AppTheme.neonLime,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              session.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(session.description),
            if (session.intervalConfig != null) ...[
              const SizedBox(height: 6),
              Text(
                'Duração programada: ${formatDuration(session.intervalConfig!.totalDuration)}',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar treino'),
            ),
          ],
        ),
      );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.completed,
    required this.isNext,
    this.onTap,
  });

  final TrainingPlanSession session;
  final bool completed;
  final bool isNext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: isNext
            ? AppTheme.neonLime.withValues(alpha: .08)
            : Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed
                        ? AppTheme.neonLime
                        : Colors.white.withValues(alpha: .06),
                  ),
                  child: Icon(
                    completed
                        ? Icons.check_rounded
                        : isNext
                            ? Icons.play_arrow_rounded
                            : Icons.lock_outline_rounded,
                    color: completed ? Colors.black : Colors.white70,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Treino ${session.day}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.description,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _PlanCompletedCard extends StatelessWidget {
  const _PlanCompletedCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.neonLime.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.neonLime.withValues(alpha: .3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: AppTheme.neonLime, size: 34),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Plano concluído. Você completou as 24 sessões e chegou ao desafio de 5 km.',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
}
