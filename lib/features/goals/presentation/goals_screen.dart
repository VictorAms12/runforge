import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../domain/goal.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('METAS', style: TextStyle(color: AppTheme.neonLime, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        Text('Consistência vence.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Nova meta',
                    onPressed: () => _showCreateGoal(context, ref),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: goals.when(
                  data: (items) => items.isEmpty
                      ? _EmptyGoals(onCreate: () => _showCreateGoal(context, ref))
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(goalsProvider);
                            await ref.read(goalsProvider.future);
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 110),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _GoalCard(
                              progress: items[index],
                              onDelete: () async {
                                final id = items[index].goal.id;
                                if (id == null) return;
                                await ref.read(goalsRepositoryProvider).delete(id);
                                ref.invalidate(goalsProvider);
                              },
                            ).animate(delay: (index * 45).ms).fadeIn().slideY(begin: .06),
                          ),
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro ao carregar metas: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateGoal(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final target = TextEditingController(text: '20');
    var metric = GoalMetric.distanceKm;
    var period = GoalPeriod.weekly;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Criar meta', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('A meta usa seus treinos salvos para atualizar o progresso automaticamente.'),
                const SizedBox(height: 18),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Título', hintText: 'Ex.: Correr 20 km esta semana')),
                const SizedBox(height: 12),
                DropdownButtonFormField<GoalMetric>(
                  initialValue: metric,
                  decoration: const InputDecoration(labelText: 'Métrica'),
                  items: const [
                    DropdownMenuItem(value: GoalMetric.distanceKm, child: Text('Distância (km)')),
                    DropdownMenuItem(value: GoalMetric.workoutDays, child: Text('Dias com treino')),
                  ],
                  onChanged: (value) {
                    if (value != null) setModalState(() => metric = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: metric == GoalMetric.distanceKm ? 'Alvo em km' : 'Quantidade de dias'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<GoalPeriod>(
                  initialValue: period,
                  decoration: const InputDecoration(labelText: 'Período'),
                  items: const [
                    DropdownMenuItem(value: GoalPeriod.daily, child: Text('Diária')),
                    DropdownMenuItem(value: GoalPeriod.weekly, child: Text('Semanal')),
                    DropdownMenuItem(value: GoalPeriod.monthly, child: Text('Mensal')),
                  ],
                  onChanged: (value) {
                    if (value != null) setModalState(() => period = value);
                  },
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    final value = double.tryParse(target.text.replaceAll(',', '.'));
                    if (value == null || value <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um alvo válido.')));
                      return;
                    }
                    final range = _rangeFor(period);
                    await ref.read(goalsRepositoryProvider).insert(
                          Goal(
                            title: title.text.trim().isEmpty ? _defaultTitle(metric, period, value) : title.text.trim(),
                            metric: metric,
                            target: value,
                            period: period,
                            startDate: range.$1,
                            endDate: range.$2,
                            isCompleted: false,
                          ),
                        );
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Criar meta')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    title.dispose();
    target.dispose();
    if (created == true) ref.invalidate(goalsProvider);
  }

  (DateTime, DateTime) _rangeFor(GoalPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case GoalPeriod.daily:
        return (
          DateTime(now.year, now.month, now.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case GoalPeriod.weekly:
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        return (start, start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1)));
      case GoalPeriod.monthly:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
        return (start, end);
    }
  }

  String _defaultTitle(GoalMetric metric, GoalPeriod period, double value) {
    final unit = metric == GoalMetric.distanceKm ? 'km' : 'dias';
    final p = switch (period) {
      GoalPeriod.daily => 'hoje',
      GoalPeriod.weekly => 'esta semana',
      GoalPeriod.monthly => 'este mês',
    };
    return '${value.toStringAsFixed(metric == GoalMetric.distanceKm ? 1 : 0)} $unit $p';
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.progress, required this.onDelete});
  final GoalProgress progress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final unit = goal.metric == GoalMetric.distanceKm ? 'km' : 'dias';
    final decimals = goal.metric == GoalMetric.distanceKm ? 1 : 0;
    return PremiumCard(
      child: Row(
        children: [
          ProgressRing(
            progress: progress.ratio,
            size: 78,
            color: goal.isCompleted ? AppTheme.neonLime : null,
            child: Icon(goal.isCompleted ? Icons.emoji_events_rounded : Icons.flag_rounded, color: goal.isCompleted ? AppTheme.neonLime : Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(goal.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Excluir meta'))],
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text('${progress.current.toStringAsFixed(decimals)} / ${goal.target.toStringAsFixed(decimals)} $unit', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(
                  goal.isCompleted
                      ? 'Concluída${goal.completedAt == null ? '' : ' em ${shortDate(goal.completedAt!)}'}'
                      : 'Até ${shortDate(goal.endDate)}',
                  style: TextStyle(color: goal.isCompleted ? AppTheme.neonLime : Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_circle_rounded, size: 70, color: AppTheme.neonLime),
            const SizedBox(height: 14),
            Text('Defina o próximo alvo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Distância ou frequência: o progresso é calculado a partir do histórico local.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text('Criar primeira meta')),
          ],
        ),
      ),
    );
  }
}
