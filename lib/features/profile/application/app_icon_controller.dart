import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/db/daos/sync_state_dao.dart';
import '../../../shared/theme/nb_theme.dart';

/// Ícono de la app activo (clave de tema, o `''` para el por defecto). Conmuta el
/// ícono del lanzador de Android vía activity-alias (MethodChannel nativo) y
/// persiste la elección. En plataformas sin soporte solo persiste.
class AppIconController extends Notifier<String> {
  static const MethodChannel _channel = MethodChannel('com.nbsound/app_icon');

  @override
  String build() {
    _cargar();
    return '';
  }

  Future<void> _cargar() async {
    final String? v = await ref
        .read(syncStateDaoProvider)
        .getValor(SyncStateDao.kIconoApp);
    if (v == null) {
      return;
    }
    state = v;
    // Ícono retirado (p. ej. el antiguo "Nothing"): se vuelve al por defecto.
    if (!iconoAppValido(v)) {
      await seleccionar('');
    }
  }

  /// Aplica el ícono [key] (''=por defecto). Persiste y, en Android, conmuta el
  /// alias del lanzador (pasando el anterior para tocar solo dos componentes).
  Future<void> seleccionar(String key) async {
    final String previo = state;
    if (key == previo) {
      return;
    }
    state = key;
    await ref.read(syncStateDaoProvider).setValor(SyncStateDao.kIconoApp, key);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<void>('setIcon', <String, String>{
          'key': key,
          'previous': previo,
        });
      } catch (_) {
        // Si el canal falla, la preferencia queda guardada igualmente.
      }
    }
  }
}

/// True si [key] es un ícono que la app ofrece ('' = por defecto, o un tema).
bool iconoAppValido(String key) =>
    key.isEmpty || kNbThemes.any((NbThemeDef t) => t.key == key);

final NotifierProvider<AppIconController, String> appIconProvider =
    NotifierProvider<AppIconController, String>(AppIconController.new);
