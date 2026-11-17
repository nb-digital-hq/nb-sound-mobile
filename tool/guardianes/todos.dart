import 'dart:io';

// Ejecuta todos los guardianes y falla si alguno falla. Es lo que corre
// `just verify` y la CI.
const List<String> _guardianes = <String>[
  'red',
  'registro',
  'secretos',
  'i18n',
  'licencias',
  'version',
  'docs',
];

Future<void> main() async {
  int fallos = 0;
  for (final String g in _guardianes) {
    final Process p = await Process.start(Platform.resolvedExecutable, <String>[
      'run',
      'tool/guardianes/$g.dart',
    ], mode: ProcessStartMode.inheritStdio);
    if (await p.exitCode != 0) {
      fallos++;
    }
  }
  exit(fallos == 0 ? 0 : 1);
}
