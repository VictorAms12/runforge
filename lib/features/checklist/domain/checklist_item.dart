enum ChecklistCategory { pre, post }

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.category,
    required this.title,
    required this.isChecked,
    required this.isCustom,
    required this.position,
  });

  final int id;
  final ChecklistCategory category;
  final String title;
  final bool isChecked;
  final bool isCustom;
  final int position;

  factory ChecklistItem.fromMap(Map<String, Object?> map) => ChecklistItem(
        id: map['id'] as int,
        category: ChecklistCategory.values.byName(map['category'] as String),
        title: map['title'] as String,
        isChecked: (map['is_checked'] as int) == 1,
        isCustom: (map['is_custom'] as int) == 1,
        position: map['position'] as int,
      );
}
