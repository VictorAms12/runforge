import 'dart:io';

void main() {
  final errors = <String>[];

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    errors.add('pubspec.yaml não encontrado.');
  } else {
    final content = pubspec.readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(content);

    if (match == null) {
      errors.add('Use versionamento explícito no formato X.Y.Z+BUILD em pubspec.yaml.');
    } else {
      final major = int.parse(match.group(1)!);
      final minor = int.parse(match.group(2)!);
      final patch = int.parse(match.group(3)!);
      final build = int.parse(match.group(4)!);

      if (minor >= 100 || patch >= 100) {
        errors.add('minor e patch devem permanecer abaixo de 100 para o esquema de versionCode.');
      }

      final expectedBuild = major * 10000 + minor * 100 + patch;
      if (build != expectedBuild) {
        errors.add(
          'Build number inválido: esperado $expectedBuild para $major.$minor.$patch, encontrado $build.',
        );
      }
    }
  }

  final database = File('lib/core/database/app_database.dart');
  if (!database.existsSync()) {
    errors.add('AppDatabase não encontrado.');
  } else {
    final db = database.readAsStringSync();
    if (!db.contains("static const _dbName = 'runforge.db'")) {
      errors.add("O banco deve continuar se chamando 'runforge.db' para preservar dados instalados.");
    }
    if (!db.contains('onUpgrade: _onUpgrade')) {
      errors.add('O SQLite deve manter onUpgrade para migrações incrementais.');
    }
    if (db.contains('deleteDatabase(')) {
      errors.add('deleteDatabase() não é permitido no fluxo normal de atualização.');
    }
  }

  final platformConfig = File('tool/configure_platforms.dart');
  if (!platformConfig.existsSync() ||
      !platformConfig.readAsStringSync().contains("com.runforge.runforge")) {
    errors.add('O applicationId/bundleId fixo com.runforge.runforge deve permanecer protegido.');
  }

  if (!File('UPDATE_POLICY.md').existsSync()) {
    errors.add('UPDATE_POLICY.md é obrigatório.');
  }

  if (errors.isNotEmpty) {
    stderr.writeln('RunForge release guard falhou:');
    for (final error in errors) {
      stderr.writeln(' - $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('RunForge release guard: compatibilidade de atualização OK.');
}
