import 'dart:io';

/// Utilidades compartidas por los guardianes. Cada guardián imprime sus
/// hallazgos como `ruta:línea: motivo` y termina con código 1 si hay alguno.

/// Archivos versionados (según git) bajo [prefijos] con alguna [extensiones].
List<File> archivos(List<String> prefijos, List<String> extensiones) {
  final ProcessResult r = Process.runSync('git', <String>[
    'ls-files',
    '-co',
    '--exclude-standard',
  ]);
  final List<String> rutas =
      (r.stdout as String)
          .split('\n')
          .where((String p) => p.isNotEmpty)
          .where((String p) => prefijos.any(p.startsWith))
          .where((String p) => extensiones.any(p.endsWith))
          .where((String p) => File(p).existsSync())
          .toList()
        ..sort();
  return <File>[for (final String p in rutas) File(p)];
}

class Informe {
  Informe(this.nombre);
  final String nombre;
  final List<String> _fallos = <String>[];

  void fallo(String donde, String motivo) => _fallos.add('$donde: $motivo');

  /// Imprime el resultado y devuelve el código de salida.
  int cerrar() {
    if (_fallos.isEmpty) {
      stdout.writeln('[$nombre] correcto');
      return 0;
    }
    for (final String f in _fallos) {
      stderr.writeln('[$nombre] $f');
    }
    stderr.writeln('[$nombre] ${_fallos.length} problema(s)');
    return 1;
  }
}

/// Emoji y pictogramas: rangos que nunca deben aparecer en código ni documentos.
final RegExp emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]',
  unicode: true,
);
