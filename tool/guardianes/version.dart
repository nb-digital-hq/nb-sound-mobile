import 'dart:io';

import 'comun.dart';

// Una sola versión y una sola fecha de publicación en todos los sitios que la
// declaran: el manifiesto, la constante de la app, el registro de cambios y la
// cita. Si no coinciden, la release diría una cosa y la app otra.
void main() {
  final Informe inf = Informe('version');
  final String pub =
      RegExp(
        r'^version: (\d+\.\d+\.\d+)\+\d+',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())?.group(1) ??
      '';
  final String app =
      RegExp(r"kVersionApp = '([^']+)'")
          .firstMatch(File('lib/core/plataforma.dart').readAsStringSync())
          ?.group(1) ??
      '';
  final RegExpMatch? cl = RegExp(
    r'^## (\d+\.\d+\.\d+) — (\d{4}-\d{2}-\d{2})',
    multiLine: true,
  ).firstMatch(File('CHANGELOG.md').readAsStringSync());
  final String cita = File('CITATION.cff').readAsStringSync();
  final String citaVer =
      RegExp(
        r'^version: "([^"]+)"',
        multiLine: true,
      ).firstMatch(cita)?.group(1) ??
      '';
  final String citaFecha =
      RegExp(
        r'^date-released: (\S+)',
        multiLine: true,
      ).firstMatch(cita)?.group(1) ??
      '';
  if (pub.isEmpty) {
    inf.fallo('pubspec.yaml', 'sin versión');
  }
  if (app != pub) {
    inf.fallo('lib/core/plataforma.dart', 'kVersionApp $app ≠ pubspec $pub');
  }
  if (cl == null) {
    inf.fallo('CHANGELOG.md', 'sin entrada "## x.y.z — AAAA-MM-DD"');
  } else {
    if (cl.group(1) != pub) {
      inf.fallo('CHANGELOG.md', 'última versión ${cl.group(1)} ≠ $pub');
    }
    if (citaFecha != cl.group(2)) {
      inf.fallo('CITATION.cff', 'fecha $citaFecha ≠ CHANGELOG ${cl.group(2)}');
    }
  }
  if (citaVer != pub) {
    inf.fallo('CITATION.cff', 'versión $citaVer ≠ $pub');
  }
  exit(inf.cerrar());
}
