import '../../../core/database/app_database.dart';
import '../domain/user_profile.dart';

class UserRepository {
  UserRepository(this._db);
  final AppDatabase _db;

  Future<UserProfile> getProfile() async {
    final db = await _db.database;
    final rows = await db.query('users', where: 'id = 1', limit: 1);
    return UserProfile.fromMap(rows.first);
  }

  Future<void> save(UserProfile profile) async {
    final db = await _db.database;
    await db.update('users', profile.toMap(), where: 'id = 1');
  }
}
