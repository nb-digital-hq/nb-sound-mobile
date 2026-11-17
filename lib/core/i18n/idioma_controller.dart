import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import 'i18n.dart';

/// Clave de la preferencia de idioma en la kv de estado.
const String kIdiomaPrefKey = 'idioma';

/// Preferencia de idioma leída en `main` antes del primer frame.
final Provider<Idioma> initialIdiomaProvider = Provider<Idioma>(
  (Ref ref) => Idioma.sistema,
);

Idioma idiomaDeClave(String? clave) => Idioma.values.firstWhere(
  (Idioma i) => i.name == clave,
  orElse: () => Idioma.sistema,
);

/// Preferencia de idioma (puede ser [Idioma.sistema]). Cada cambio fija el
/// idioma activo de [tr] antes de notificar, para que la reconstrucción ya lea
/// los textos nuevos, y se persiste.
class IdiomaController extends Notifier<Idioma> {
  @override
  Idioma build() {
    final Idioma inicial = ref.read(initialIdiomaProvider);
    fijarIdioma(inicial);
    return inicial;
  }

  void elegir(Idioma idioma) {
    fijarIdioma(idioma);
    state = idioma;
    ref.read(syncStateDaoProvider).setValor(kIdiomaPrefKey, idioma.name);
  }
}

final NotifierProvider<IdiomaController, Idioma> idiomaControllerProvider =
    NotifierProvider<IdiomaController, Idioma>(IdiomaController.new);
