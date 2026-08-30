import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/premium_card.dart';
import '../../workout/domain/workout.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HISTÓRICO',
              style: TextStyle(
                color: AppTheme.neonLime,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Seu volume de treino',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: history.when(
                data: (items) => items.isEmpty
                    ? const _EmptyHistory()
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(workoutHistoryProvider);
                          ref.invalidate(personalRecordsProvider);
                          ref.invalidate(weeklyProgressProvider);
                          await ref.read(workoutHistoryProvider.future);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 110),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _WorkoutCard(workout: items[index])
                              .animate(delay: (index.clamp(0, 8) * 35).ms)
                              .fadeIn()
                              .slideY(begin: .04),
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro ao carregar histórico: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final icon = workout.workoutType == 'interval' ? Icons.timer_rounded : Icons.directions_run_rounded;
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.neonLime.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.neonLime),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.planSessionIndex != null
                          ? 'Plano 5K · Sessão ${workout.planSessionIndex! + 1}'
                          : workout.workoutType == 'interval'
                              ? 'Treino intervalado'
                              : 'Corrida livre',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(shortDate(workout.startedAt), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '${workout.distanceKm.toStringAsFixed(2)} km',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniMetric(label: 'Tempo', value: formatDuration(Duration(seconds: workout.durationSeconds)))),
              Expanded(child: _MiniMetric(label: 'Pace', value: '${formatPace(workout.avgPaceMinKm)}/km')),
              Expanded(child: _MiniMetric(label: 'RPE', value: workout.rpe?.toString() ?? '—')),
              Expanded(child: _MiniMetric(label: 'Kcal', value: workout.calories.toStringAsFixed(0))),
            ],
          ),
          if (workout.splits.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('${workout.splits.length} splits registrados', style: const TextStyle(fontWeight: FontWeight.w800)),
              children: workout.splits.asMap().entries.map((entry) {
                final split = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Text('${entry.key + 1}', style: const TextStyle(color: Colors.white54)),
                      const SizedBox(width: 12),
                      Text('${split.distanceKm.toStringAsFixed(2)} km'),
                      const Spacer(),
                      Text('${formatPace(split.paceMinKm)}/km', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (workout.autoPausedSeconds > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Auto-pause: ${formatDuration(Duration(seconds: workout.autoPausedSeconds))}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
          if (workout.notes != null && workout.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: Text(workout.notes!, style: const TextStyle(color: Colors.white60))),
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_rounded, size: 64, color: AppTheme.neonLime),
            const SizedBox(height: 14),
            Text(
              'A primeira corrida começa aqui',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text('Seus treinos finalizados aparecerão neste histórico.', textAlign: TextAlign.center),
          ],
        ),
      );
}
