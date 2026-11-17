import 'dart:io';

import 'comun.dart';

// La app no escribe registros: ni en Dart ni en el código nativo. Un registro
// acabaría llevando títulos, rutas o direcciones del PC al logcat, que otras
// apps con permisos de depuración pueden leer.
void main() {
  final Informe inf = Informe('registro');
  for (final File f in archivos(<String>['lib/'], <String>['.dart'])) {
    final List<String> lineas = f.readAsLinesSync();
    for (int i = 0; i < lineas.length; i++) {
      final String l = lineas[i];
      if (l.trimLeft().startsWith('//')) {
        continue;
      }
      if (RegExp(
        r'(?<![\w.])(print|debugPrint|log)\s*\(|\bdeveloper\.log\(',
      ).hasMatch(l)) {
        inf.fallo('${f.path}:${i + 1}', 'escritura de registro');
      }
    }
  }
  for (final File f in archivos(
    <String>['android/app/src/'],
    <String>['.kt', '.java'],
  )) {
    final List<String> lineas = f.readAsLinesSync();
    for (int i = 0; i < lineas.length; i++) {
      if (RegExp(
        r'\bLog\.[vdiwe]\(|printStackTrace\(|println\(',
      ).hasMatch(lineas[i])) {
        inf.fallo('${f.path}:${i + 1}', 'escritura de registro nativa');
      }
    }
  }
  exit(inf.cerrar());
}
