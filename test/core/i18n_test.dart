import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/i18n/i18n.dart';

void main() {
  tearDown(() => fijarIdioma(Idioma.es));

  test('en español el texto fuente se devuelve tal cual', () {
    fijarIdioma(Idioma.es);
    expect(tr('Biblioteca'), 'Biblioteca');
  });

  test('inglés y portugués traducen desde el texto fuente', () {
    fijarIdioma(Idioma.en);
    expect(tr('Biblioteca'), 'Library');
    fijarIdioma(Idioma.pt);
    expect(tr('Pistas'), 'Faixas');
  });

  test('los marcadores se sustituyen en el idioma activo', () {
    fijarIdioma(Idioma.en);
    expect(
      tr('Hay una versión nueva: {version}.', <String, Object?>{
        'version': '1.0.0',
      }),
      'A new version is available: 1.0.0.',
    );
  });

  test('un texto sin traducción cae en el español en lugar de vaciarse', () {
    fijarIdioma(Idioma.en);
    expect(
      tr('Texto que no está en el catálogo'),
      'Texto que no está en el catálogo',
    );
  });

  test('el idioma del sistema se resuelve por código de idioma', () {
    expect(idiomaDeLocale(const Locale('en', 'GB')), Idioma.en);
    expect(idiomaDeLocale(const Locale('pt', 'BR')), Idioma.pt);
    expect(idiomaDeLocale(const Locale('fr')), Idioma.es);
    fijarIdioma(Idioma.sistema, delSistema: const Locale('pt'));
    expect(idiomaActivo, Idioma.pt);
  });
}
