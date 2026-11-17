import 'dart:io';

import 'comun.dart';

// Integridad de la documentación: cada documento tiene título de nivel uno y,
// dentro de docs/, declara su estado en las primeras líneas; los enlaces
// relativos apuntan a archivos que existen; no hay emoji, rutas de una máquina
// concreta ni trabajo pendiente anunciado. El código tampoco anuncia pendientes.
final RegExp _enlace = RegExp(r'\]\(([^)\s#]+)(#[^)]*)?\)');
final RegExp _pendiente = RegExp(
  r'fase 2|para más adelante|en una versión futura|próxima versión|coming soon',
  caseSensitive: false,
);
final RegExp _marcaPendiente = RegExp(r'\b(TODO|FIXME|XXX)\b');
final RegExp _rutaLocal = RegExp(
  r'/home/[a-z]|/Users/[A-Za-z]|[A-Z]:\\Users|file://',
);

void main() {
  final Informe inf = Informe('docs');
  final List<File> docs = archivos(<String>['docs/', ''], <String>['.md'])
      .where(
        (File f) =>
            !f.path.startsWith('THIRD-PARTY') && !f.path.startsWith('.'),
      )
      .where(
        (File f) =>
            !f.path.startsWith('build/') &&
            !f.path.startsWith('ios/') &&
            !f.path.startsWith('android/'),
      )
      .toList();
  for (final File f in docs) {
    final String p = f.path;
    final List<String> l = f.readAsLinesSync();
    if (l.isEmpty || !l.first.startsWith('# ')) {
      inf.fallo(p, 'falta el título de nivel uno en la primera línea');
    }
    if (p.startsWith('docs/') &&
        !l
            .take(8)
            .any(
              (String x) => x.replaceFirst('> ', '').startsWith('**Estado:**'),
            )) {
      inf.fallo(p, 'no declara su estado (**Estado:**) en las primeras líneas');
    }
    bool enCodigo = false;
    for (int i = 0; i < l.length; i++) {
      final String x = l[i];
      if (x.trimLeft().startsWith('```')) {
        enCodigo = !enCodigo;
      }
      if (emoji.hasMatch(x)) {
        inf.fallo('$p:${i + 1}', 'emoji');
      }
      if (_rutaLocal.hasMatch(x)) {
        inf.fallo('$p:${i + 1}', 'ruta de una máquina concreta');
      }
      if (_pendiente.hasMatch(x) || _marcaPendiente.hasMatch(x)) {
        inf.fallo('$p:${i + 1}', 'trabajo pendiente anunciado');
      }
      if (enCodigo) {
        continue;
      }
      for (final RegExpMatch m in _enlace.allMatches(x)) {
        final String destino = m.group(1)!;
        if (destino.contains('://') || destino.startsWith('mailto:')) {
          continue;
        }
        final Uri base = File(p).absolute.uri;
        final String ruta = Uri.decodeFull(base.resolve(destino).toFilePath());
        if (!File(ruta).existsSync() && !Directory(ruta).existsSync()) {
          inf.fallo('$p:${i + 1}', 'enlace roto: $destino');
        }
      }
    }
  }
  // Código y herramientas: sin pendientes ni emoji.
  for (final File f in archivos(
    <String>['lib/', 'test/', 'tool/', 'android/app/src/', 'ios/Runner/'],
    <String>['.dart', '.kt', '.swift', '.xml', '.py'],
  )) {
    if (f.path == 'tool/guardianes/docs.dart' ||
        f.path.startsWith('lib/core/i18n/')) {
      continue;
    }
    final List<String> l = f.readAsLinesSync();
    for (int i = 0; i < l.length; i++) {
      if (RegExp(r'\b(TODO|FIXME|XXX)\b').hasMatch(l[i])) {
        inf.fallo('${f.path}:${i + 1}', 'trabajo pendiente en el código');
      }
      if (emoji.hasMatch(l[i])) {
        inf.fallo('${f.path}:${i + 1}', 'emoji');
      }
    }
  }
  exit(inf.cerrar());
}
