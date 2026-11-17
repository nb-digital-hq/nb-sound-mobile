import 'dart:ui' show Locale, PlatformDispatcher;

import 'en.dart';
import 'pt.dart';

/// Idiomas de la interfaz. El español es el idioma fuente: los textos se
/// escriben en español en el código y los catálogos traducen desde él, así una
/// cadena sin traducir sigue siendo legible y el guardián `i18n` la detecta.
enum Idioma { sistema, es, en, pt }

/// Idioma efectivo (nunca [Idioma.sistema]).
Idioma _activo = Idioma.es;

Idioma get idiomaActivo => _activo;

/// Fija el idioma. [Idioma.sistema] se resuelve con la configuración regional
/// del dispositivo; lo que no sea inglés ni portugués cae en español.
void fijarIdioma(Idioma preferido, {Locale? delSistema}) {
  _activo = preferido == Idioma.sistema
      ? idiomaDeLocale(delSistema ?? PlatformDispatcher.instance.locale)
      : preferido;
}

Idioma idiomaDeLocale(Locale l) => switch (l.languageCode) {
  'en' => Idioma.en,
  'pt' => Idioma.pt,
  _ => Idioma.es,
};

Locale localeDe(Idioma i) => switch (i) {
  Idioma.en => const Locale('en'),
  Idioma.pt => const Locale('pt'),
  _ => const Locale('es'),
};

/// Catálogo por idioma (clave: el texto en español).
const Map<Idioma, Map<String, String>> catalogos =
    <Idioma, Map<String, String>>{Idioma.en: en, Idioma.pt: pt};

/// Traduce [es] al idioma activo y sustituye los marcadores `{nombre}` por
/// [args]. Se resuelve en cada llamada (no en constantes) para que un cambio de
/// idioma se vea en la siguiente reconstrucción.
String tr(String es, [Map<String, Object?> args = const <String, Object?>{}]) {
  final String base = catalogos[_activo]?[es] ?? es;
  if (args.isEmpty) {
    return base;
  }
  return base.replaceAllMapped(RegExp(r'\{(\w+)\}'), (Match m) {
    final String k = m.group(1)!;
    return args.containsKey(k) ? '${args[k]}' : m.group(0)!;
  });
}
