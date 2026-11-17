import 'dart:io';

import 'comun.dart';

// Cada texto de la interfaz se escribe en español dentro de tr('...') y debe
// tener traducción en los catálogos de inglés y portugués, con los mismos
// marcadores {nombre}. Una clave que ya no se usa también es un fallo: los
// catálogos solo contienen lo que la app muestra.
final RegExp _uso = RegExp(r"\btr\(\s*'((?:[^'\\]|\\.)*)'");
final RegExp _entrada = RegExp(
  r"^\s*'((?:[^'\\]|\\.)*)':\s*$|^\s*'((?:[^'\\]|\\.)*)':\s*'((?:[^'\\]|\\.)*)',\s*$",
);

Map<String, String> _leerCatalogo(String ruta) {
  final List<String> l = File(ruta).readAsLinesSync();
  final Map<String, String> m = <String, String>{};
  for (int i = 0; i < l.length; i++) {
    final RegExpMatch? a = _entrada.firstMatch(l[i]);
    if (a == null) {
      continue;
    }
    if (a.group(2) != null) {
      m[a.group(2)!] = a.group(3)!;
    } else {
      final RegExpMatch? v = RegExp(
        r"^\s*'((?:[^'\\]|\\.)*)',\s*$",
      ).firstMatch(l[i + 1]);
      m[a.group(1)!] = v?.group(1) ?? '';
    }
  }
  return m;
}

Set<String> _marcadores(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((Match m) => m.group(1)!).toSet();

void main() {
  final Informe inf = Informe('i18n');
  final Map<String, String> usos = <String, String>{};
  for (final File f in archivos(<String>['lib/'], <String>['.dart'])) {
    if (f.path.startsWith('lib/core/i18n/')) {
      continue;
    }
    final String s = f.readAsStringSync();
    for (final RegExpMatch m in _uso.allMatches(s)) {
      usos.putIfAbsent(m.group(1)!, () => f.path);
    }
  }
  // Los nombres de los temas se traducen al mostrarse (tr(def.label)).
  final String temas = File(
    'lib/shared/theme/nb_theme.dart',
  ).readAsStringSync();
  for (final RegExpMatch m in RegExp(
    r"_def\(\s*'[^']*',\s*'((?:[^'\\]|\\.)*)'",
  ).allMatches(temas)) {
    usos.putIfAbsent(m.group(1)!, () => 'lib/shared/theme/nb_theme.dart');
  }
  for (final String idioma in <String>['en', 'pt']) {
    final String ruta = 'lib/core/i18n/$idioma.dart';
    final Map<String, String> cat = _leerCatalogo(ruta);
    usos.forEach((String clave, String donde) {
      final String? t = cat[clave];
      if (t == null || t.isEmpty) {
        inf.fallo(donde, 'sin traducción ($idioma): "$clave"');
      } else if (_marcadores(t).length != _marcadores(clave).length ||
          !_marcadores(t).containsAll(_marcadores(clave))) {
        inf.fallo(ruta, 'marcadores distintos en "$clave"');
      }
    });
    for (final String clave in cat.keys) {
      if (!usos.containsKey(clave)) {
        inf.fallo(ruta, 'clave sin uso: "$clave"');
      }
    }
  }
  exit(inf.cerrar());
}
