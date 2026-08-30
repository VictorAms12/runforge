import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/premium_card.dart';
import '../../workout/domain/workout.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyProgressProvider);
    final records = ref.watch(personalRecordsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(weeklyProgressProvider);
          ref.invalidate(personalRecordsProvider);
          await Future.wait([
            ref.read(weeklyProgressProvider.future),
            ref.read(personalRecordsProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          children: [
            const Text(
              'PROGRESSO',
              style: TextStyle(
                color: AppTheme.neonLime,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Evolução que dá para medir.',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            weekly.when(
              data: (items) => _WeeklyChart(items: items),
              loading: () => const _LoadingCard(),
              error: (error, _) => _ErrorCard(message: '$error'),
            ),
            const SizedBox(height: 18),
            Text(
              'Recordes pessoais',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            records.when(
              data: (value) => _RecordsGrid(records: value),
              loading: () => const _LoadingCard(),
              error: (error, _) => _ErrorCard(message: '$error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.items});
  final List<WeeklyTrainingSummary> items;

  @override
  Widget build(BuildContext context) {
    final maxDistance = items.fold<double>(
      0,
      (value, item) => math.max(value, item.distanceKm),
    );
    final totalDistance = items.fold<double>(
      0,
      (value, item) => value + item.distanceKm,
    );
    final totalWorkouts = items.fold<int>(0, (value, item) => value + item.workouts);
    final rpes = items.where((item) => item.averageRpe != null).toList();
    final averageRpe = rpes.isEmpty
        ? null
        : rpes.fold<double>(0, (sum, item) => sum + item.averageRpe!) /
            rpes.length;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ÚLTIMAS 8 SEMANAS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.asMap().entries.map((entry) {
                final item = entry.value;
                final ratio = maxDistance <= 0
                    ? 0.04
                    : (item.distanceKm / maxDistance).clamp(.04, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          item.distanceKm == 0
                              ? '—'
                              : item.distanceKm.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(height: 5),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: ratio.toDouble(),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: entry.key == items.length - 1
                                    ? AppTheme.neonLime
                                    : Colors.white24,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.weekStart.day}/${item.weekStart.month}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Distância',
                  value: '${totalDistance.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Treinos',
                  value: '$totalWorkouts',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'RPE médio',
                  value: averageRpe?.toStringAsFixed(1) ?? '—',
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: .04);
  }
}

class _RecordsGrid extends StatelessWidget {
  const _RecordsGrid({required this.records});
  final PersonalRecords records;

  @override
  Widget build(BuildContext context) {
    if (!records.hasAny) {
      return const PremiumCard(
        child: Text(
          'Finalize seus primeiros treinos para começar a criar recordes pessoais.',
        ),
      );
    }
    final longest = records.longestDistance;
    final duration = records.longestDuration;
    final average = records.bestAveragePace;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: [
        _RecordCard(
          icon: Icons.route_rounded,
          label: 'Maior distância',
          value: longest == null
              ? '—'
              : '${longest.distanceKm.toStringAsFixed(2)} km',
        ),
        _RecordCard(
          icon: Icons.timer_rounded,
          label: 'Maior duração',
          value: duration == null
              ? '—'
              : formatDuration(Duration(seconds: duration.durationSeconds)),
        ),
        _RecordCard(
          icon: Icons.speed_rounded,
          label: 'Melhor pace médio',
          value: average == null
              ? '—'
              : '${formatPace(average.avgPaceMinKm)}/km',
        ),
        _RecordCard(
          icon: Icons.looks_one_rounded,
          label: 'Melhor split 1 km',
          value: records.bestOneKmPace == null
              ? '—'
              : '${formatPace(records.bestOneKmPace)}/km',
        ),
        _RecordCard(
          icon: Icons.emoji_events_rounded,
          label: 'Melhor 5 km',
          value: records.bestFiveKmPace == null
              ? '—'
              : '${formatPace(records.bestFiveKmPace)}/km',
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: AppTheme.neonLime),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const PremiumCard(
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => PremiumCard(
        child: Text('Não foi possível carregar: $message'),
      );
}
