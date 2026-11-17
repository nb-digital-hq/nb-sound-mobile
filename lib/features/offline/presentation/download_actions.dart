import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sync/application/conexion_provider.dart';
import '../application/download_gate.dart';
import '../../../core/i18n/i18n.dart';

/// Comprueba el enlace con el PC y avisa antes de ejecutar [encolar]. Centraliza
/// el feedback de descargas (sin PC emparejado / sin conexión) para que todos los
/// puntos de entrada —menú de pista, álbum, playlist, reproductor, "descargar
/// todo"— se comporten igual y nunca encolen en silencio algo que no bajará.
///
/// Devuelve true si se ejecutó [encolar]. El `context`/`ref` se leen antes de
/// cualquier `await` y los objetos de UI (messenger/router) se capturan primero
/// para no usar un `context` posiblemente desmontado.
Future<bool> encolarConAviso(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() encolar, {
  String? exito,
}) async {
  final String textoExito = exito ?? tr('Descargando');
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final GoRouter router = GoRouter.of(context);
  final DownloadGate gate = gateDescarga(ref.read(conexionPcProvider));
  switch (gate) {
    case DownloadGate.sinEnlace:
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('Empareja un PC para descargar tu música.')),
          action: SnackBarAction(
            label: tr('Sincronizar'),
            onPressed: () => router.push('/sync'),
          ),
        ),
      );
      return false;
    case DownloadGate.encolarAvisando:
      await encolar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('Sin conexión con tu PC ahora. Se descargará al reconectar.'),
          ),
        ),
      );
      return true;
    case DownloadGate.encolar:
      await encolar();
      messenger.showSnackBar(SnackBar(content: Text(textoExito)));
      return true;
  }
}
