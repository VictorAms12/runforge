import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../domain/checklist_item.dart';

class ChecklistScreen extends ConsumerWidget {
  const ChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CHECKLIST', style: TextStyle(color: AppTheme.neonLime, fontWeight: FontWeight.w900, letterSpacing: 2)),
              Text('Ritual de corrida', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF1B1B1D), borderRadius: BorderRadius.circular(18)),
                child: const TabBar(
                  dividerHeight: 0,
                  tabs: [Tab(text: 'PRÉ-TREINO'), Tab(text: 'PÓS-TREINO')],
                ),
              ),
              const SizedBox(height: 14),
              const Expanded(
                child: TabBarView(
                  children: [
                    _ChecklistTab(category: ChecklistCategory.pre),
                    _ChecklistTab(category: ChecklistCategory.post),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab({required this.category});
  final ChecklistCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(checklistItemsProvider(category));
    return items.when(
      data: (list) {
        final checked = list.where((e) => e.isChecked).length;
        final progress = list.isEmpty ? 0.0 : checked / list.length;
        return Column(
          children: [
            PremiumCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$checked de ${list.length} concluídos', style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: Colors.white10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Resetar',
                    onPressed: () async {
                      await ref.read(checklistRepositoryProvider).reset(category);
                      ref.invalidate(checklistItemsProvider(category));
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Adicionar item',
                    onPressed: () => _addItem(context, ref),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 110),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: item.isCustom ? DismissDirection.endToStart : DismissDirection.none,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    ),
                    onDismissed: (_) async {
                      await ref.read(checklistRepositoryProvider).delete(item.id);
                      ref.invalidate(checklistItemsProvider(category));
                    },
                    child: _ChecklistRow(
                      item: item,
                      onTap: () async {
                        await ref.read(checklistRepositoryProvider).toggle(item);
                        ref.invalidate(checklistItemsProvider(category));
                      },
                    ).animate().fadeIn(duration: 220.ms).slideX(begin: .025),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
    );
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo item'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Ex.: passar protetor solar')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Adicionar')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await ref.read(checklistRepositoryProvider).add(category, value);
    ref.invalidate(checklistItemsProvider(category));
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item, required this.onTap});
  final ChecklistItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isChecked ? AppTheme.neonLime.withValues(alpha: .07) : const Color(0xFF1B1B1D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: item.isChecked ? AppTheme.neonLime.withValues(alpha: .22) : Colors.white.withValues(alpha: .05)),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isChecked ? AppTheme.neonLime : Colors.transparent,
                border: Border.all(color: item.isChecked ? AppTheme.neonLime : Colors.white24, width: 2),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: item.isChecked ? const Icon(Icons.check_rounded, key: ValueKey(1), color: Colors.black, size: 19) : const SizedBox(key: ValueKey(0)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: item.isChecked ? Colors.white60 : Colors.white,
                  fontWeight: FontWeight.w700,
                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                ),
                child: Text(item.title),
              ),
            ),
            if (item.isCustom) const Icon(Icons.auto_awesome_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}
