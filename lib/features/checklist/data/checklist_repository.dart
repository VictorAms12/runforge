import '../../../core/database/app_database.dart';
import '../domain/checklist_item.dart';

class ChecklistRepository {
  ChecklistRepository(this._db);
  final AppDatabase _db;

  Future<List<ChecklistItem>> getByCategory(ChecklistCategory category) async {
    final db = await _db.database;
    final rows = await db.query(
      'checklists',
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'position ASC, id ASC',
    );
    return rows.map(ChecklistItem.fromMap).toList();
  }

  Future<void> toggle(ChecklistItem item) async {
    final db = await _db.database;
    await db.update(
      'checklists',
      {'is_checked': item.isChecked ? 0 : 1},
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> add(ChecklistCategory category, String title) async {
    final db = await _db.database;
    final max = await db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS value FROM checklists WHERE category = ?',
      [category.name],
    );
    final next = (max.first['value'] as num).toInt() + 1;
    await db.insert('checklists', {
      'category': category.name,
      'title': title,
      'is_checked': 0,
      'is_custom': 1,
      'position': next,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('checklists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reset(ChecklistCategory category) async {
    final db = await _db.database;
    await db.update(
      'checklists',
      {'is_checked': 0},
      where: 'category = ?',
      whereArgs: [category.name],
    );
  }
}
