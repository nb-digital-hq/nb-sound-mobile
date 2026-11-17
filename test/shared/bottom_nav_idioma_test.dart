import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/i18n/i18n.dart';
import 'package:nb_sound_mobile/shared/widgets/bottom_nav.dart';

void main() {
  // Regresión: las pestañas eran una lista global evaluada una sola vez y se
  // quedaban en el idioma del arranque al cambiar de idioma.
  test('las pestañas siguen al idioma activo tras cambiarlo', () {
    fijarIdioma(Idioma.es);
    expect(kNavDestinations.first.label, 'Inicio');
    fijarIdioma(Idioma.en);
    expect(kNavDestinations.first.label, 'Home');
    fijarIdioma(Idioma.es);
  });
}
