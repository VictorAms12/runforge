import 'dart:io';

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
  if (!manifest.existsSync()) {
    stderr.writeln('AndroidManifest.xml não encontrado. Execute flutter create primeiro.');
    exitCode = 2;
    return;
  }

  var content = manifest.readAsStringSync();
  const permissions = '''
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
''';

  if (!content.contains('android.permission.ACCESS_FINE_LOCATION')) {
    final manifestTagEnd = content.indexOf('>');
    if (manifestTagEnd < 0) {
      stderr.writeln('Manifest Android inválido.');
      exitCode = 2;
      return;
    }

    content = '${content.substring(0, manifestTagEnd + 1)}\n$permissions'
        '${content.substring(manifestTagEnd + 1)}';
    manifest.writeAsStringSync(content);
  }

  stdout.writeln('Android: permissões de localização configuradas.');
}

void _configureIos() {
  final plist = File('ios/Runner/Info.plist');
  if (!plist.existsSync()) {
    stderr.writeln('Info.plist não encontrado. Execute flutter create primeiro.');
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

  stdout.writeln('iOS: permissão When In Use configurada.');
}
