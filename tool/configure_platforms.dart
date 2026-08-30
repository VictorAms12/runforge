import 'dart:io';

const applicationId = 'com.runforge.runforge';

void main(List<String> args) {
  final requested = args.isEmpty ? 'all' : args.first.toLowerCase();
  const supported = {'android', 'ios', 'all'};

  if (!supported.contains(requested)) {
    stderr.writeln('Uso: dart run tool/configure_platforms.dart [android|ios|all]');
    exitCode = 64;
    return;
  }

  if (requested == 'android' || requested == 'all') {
    _configureAndroid();
  }

  if (requested == 'ios' || requested == 'all') {
    _configureIos();
  }
}

void _configureAndroid() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  final gradle = File('android/app/build.gradle.kts');

  if (!manifest.existsSync() || !gradle.existsSync()) {
    stderr.writeln('Projeto Android não encontrado. Execute flutter create primeiro.');
    exitCode = 2;
    return;
  }

  var manifestContent = manifest.readAsStringSync();
  const permissions = '''
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
''';

  if (!manifestContent.contains('android.permission.ACCESS_FINE_LOCATION')) {
    final manifestTagEnd = manifestContent.indexOf('>');
    if (manifestTagEnd < 0) {
      stderr.writeln('Manifest Android inválido.');
      exitCode = 2;
      return;
    }

    manifestContent = '${manifestContent.substring(0, manifestTagEnd + 1)}\n$permissions'
        '${manifestContent.substring(manifestTagEnd + 1)}';
    manifest.writeAsStringSync(manifestContent);
  }

  var gradleContent = gradle.readAsStringSync();
  if (!gradleContent.contains('namespace = "$applicationId"') ||
      !gradleContent.contains('applicationId = "$applicationId"')) {
    stderr.writeln(
      'Application ID inesperado. O RunForge deve permanecer como $applicationId para aceitar atualizações por cima.',
    );
    exitCode = 2;
    return;
  }

  gradleContent = _configureAndroidSigning(gradleContent);
  gradle.writeAsStringSync(gradleContent);

  stdout.writeln('Android: identidade fixa, permissões e assinatura configuradas.');
}

String _configureAndroidSigning(String content) {
  const marker = '// RUNFORGE_RELEASE_SIGNING_PROPERTIES';
  if (content.contains(marker)) return content;

  if (!content.contains('import java.util.Properties')) {
    content = 'import java.io.FileInputStream\nimport java.util.Properties\n\n$content';
  }

  const propertiesBlock = '''
// RUNFORGE_RELEASE_SIGNING_PROPERTIES
val runforgeKeystoreProperties = Properties()
val runforgeKeystorePropertiesFile = rootProject.file("key.properties")
if (runforgeKeystorePropertiesFile.exists()) {
    runforgeKeystoreProperties.load(FileInputStream(runforgeKeystorePropertiesFile))
}
''';

  if (!content.contains('\nandroid {')) {
    stderr.writeln('build.gradle.kts Android inválido: bloco android não encontrado.');
    exitCode = 2;
    return content;
  }
  content = content.replaceFirst('\nandroid {', '\n$propertiesBlock\nandroid {');

  const buildTypesNeedle = '    buildTypes {';
  const signingConfigBlock = '''    signingConfigs {
        if (runforgeKeystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = runforgeKeystoreProperties.getProperty("keyAlias")
                keyPassword = runforgeKeystoreProperties.getProperty("keyPassword")
                storeFile = runforgeKeystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = runforgeKeystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {''';

  if (!content.contains(buildTypesNeedle)) {
    stderr.writeln('build.gradle.kts Android inválido: buildTypes não encontrado.');
    exitCode = 2;
    return content;
  }
  content = content.replaceFirst(buildTypesNeedle, signingConfigBlock);

  const debugSigning = '            signingConfig = signingConfigs.getByName("debug")';
  const persistentSigning = '''            signingConfig = if (runforgeKeystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }''';

  if (!content.contains(debugSigning)) {
    stderr.writeln(
      'Aviso: assinatura debug padrão não encontrada; revise o template Flutter antes de publicar.',
    );
  } else {
    content = content.replaceFirst(debugSigning, persistentSigning);
  }

  return content;
}

void _configureIos() {
  final plist = File('ios/Runner/Info.plist');
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  if (!plist.existsSync() || !project.existsSync()) {
    stderr.writeln('Projeto iOS não encontrado. Execute flutter create primeiro.');
    exitCode = 2;
    return;
  }

  final projectContent = project.readAsStringSync();
  if (!projectContent.contains('PRODUCT_BUNDLE_IDENTIFIER = $applicationId;')) {
    stderr.writeln(
      'Bundle ID inesperado. O RunForge deve permanecer como $applicationId para manter a identidade do app.',
    );
    exitCode = 2;
    return;
  }

  var plistContent = plist.readAsStringSync();
  const locationEntry = '''
\t<key>NSLocationWhenInUseUsageDescription</key>
\t<string>RunForge usa sua localização durante o treino para calcular distância e ritmo.</string>
''';

  if (!plistContent.contains('NSLocationWhenInUseUsageDescription')) {
    final dictEnd = plistContent.lastIndexOf('</dict>');
    if (dictEnd < 0) {
      stderr.writeln('Info.plist inválido.');
      exitCode = 2;
      return;
    }

    plistContent = '${plistContent.substring(0, dictEnd)}$locationEntry'
        '${plistContent.substring(dictEnd)}';
    plist.writeAsStringSync(plistContent);
  }

  final podfile = File('ios/Podfile');
  if (podfile.existsSync()) {
    var podContent = podfile.readAsStringSync();
    const marker = 'BYPASS_PERMISSION_LOCATION_ALWAYS=1';
    const needle = 'flutter_additional_ios_build_settings(target)';
    const replacement = '''flutter_additional_ios_build_settings(target)
    if target.name == 'geolocator_apple'
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
          '\$(inherited)',
          'BYPASS_PERMISSION_LOCATION_ALWAYS=1'
        ]
      end
    end''';

    if (!podContent.contains(marker) && podContent.contains(needle)) {
      podContent = podContent.replaceFirst(needle, replacement);
      podfile.writeAsStringSync(podContent);
    }
  }

  stdout.writeln('iOS: bundle ID fixo e permissão When In Use configurados.');
}
