import 'dart:io';

import 'comun.dart';

// Nada de claves privadas, almacenes de firma ni configuración de herramientas
// de agentes en el repositorio. Las claves públicas de verificación sí entran.
void main() {
  final Informe inf = Informe('secretos');
  final ProcessResult r = Process.runSync('git', <String>[
    'ls-files',
    '-co',
    '--exclude-standard',
  ]);
  for (final String p in (r.stdout as String).split('\n')) {
    if (p.isEmpty) {
      continue;
    }
    if (RegExp(
      r'\.(jks|keystore|p12|pfx|key)$|key\.properties$|(^|/)\.env$',
    ).hasMatch(p)) {
      inf.fallo(p, 'almacén de claves o secreto versionado');
    }
    if (RegExp(r'(^|/)(\.claude|\.gemini|CLAUDE\.md|GEMINI\.md)').hasMatch(p)) {
      inf.fallo(p, 'configuración de herramienta versionada (va en AGENTS.md)');
    }
    final File f = File(p);
    if (p == 'tool/guardianes/secretos.dart') {
      continue;
    }
    if (f.existsSync() &&
        f.lengthSync() < 2000000 &&
        !p.endsWith('.png') &&
        !p.endsWith('.webp')) {
      try {
        if (f.readAsStringSync().contains('PRIVATE KEY-----')) {
          inf.fallo(p, 'clave privada');
        }
      } on FileSystemException {
        // binario: no es texto
      }
    }
  }
  exit(inf.cerrar());
}
