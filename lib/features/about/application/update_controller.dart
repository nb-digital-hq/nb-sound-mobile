import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/update_service.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/plataforma.dart';

enum FaseUpdate {
  inicial,
  buscando,
  alDia,
  disponible,
  descargando,
  listo,
  error,
}

class UpdateState {
  const UpdateState({
    this.fase = FaseUpdate.inicial,
    this.versionInstalada = '',
    this.publicacion,
    this.progreso = 0,
    this.mensaje,
  });

  final FaseUpdate fase;
  final String versionInstalada;
  final Publicacion? publicacion;
  final double progreso;
  final String? mensaje;

  bool get ocupado =>
      fase == FaseUpdate.buscando || fase == FaseUpdate.descargando;

  UpdateState copyWith({
    FaseUpdate? fase,
    String? versionInstalada,
    Publicacion? publicacion,
    double? progreso,
    String? mensaje,
  }) => UpdateState(
    fase: fase ?? this.fase,
    versionInstalada: versionInstalada ?? this.versionInstalada,
    publicacion: publicacion ?? this.publicacion,
    progreso: progreso ?? this.progreso,
    mensaje: mensaje,
  );
}

final Provider<UpdateService> updateServiceProvider = Provider<UpdateService>(
  (Ref ref) => UpdateService(),
);

/// Actualización desde GitHub (como NB Sound y NB Books de escritorio): nunca
/// consulta sola; el botón "Buscar actualizaciones" es el consentimiento.
class UpdateController extends Notifier<UpdateState> {
  CancelToken? _cancel;
  List<String> _abis = const <String>[];
  File? _apk;

  UpdateService get _s => ref.read(updateServiceProvider);

  @override
  UpdateState build() {
    ref.onDispose(() => _cancel?.cancel());
    Future<void>(_cargarVersion);
    return const UpdateState();
  }

  Future<void> _cargarVersion() async {
    if (!esAndroid) {
      // Fuera de Android no hay instalador de paquetes ni ABI que consultar.
      state = state.copyWith(versionInstalada: kVersionApp);
      return;
    }
    try {
      final ({String version, List<String> abis}) i = await _s.info();
      _abis = i.abis;
      state = state.copyWith(
        versionInstalada: i.version,
        mensaje: state.mensaje,
      );
    } catch (_) {}
  }

  Future<void> buscar() async {
    if (state.ocupado) {
      return;
    }
    state = state.copyWith(fase: FaseUpdate.buscando, mensaje: tr('Buscando…'));
    try {
      if (state.versionInstalada.isEmpty) {
        await _cargarVersion();
      }
      final Publicacion p = await _s.ultimaPublicacion();
      if (compararVersiones(p.version, state.versionInstalada) <= 0) {
        state = state.copyWith(
          fase: FaseUpdate.alDia,
          publicacion: p,
          mensaje: tr('NB Sound está al día.'),
        );
        return;
      }
      state = state.copyWith(
        fase: FaseUpdate.disponible,
        publicacion: p,
        mensaje: tr('Hay una versión nueva: {version}.', {
          'version': p.version,
        }),
      );
    } on UpdateError catch (e) {
      state = state.copyWith(fase: FaseUpdate.error, mensaje: e.mensaje);
    } catch (_) {
      state = state.copyWith(
        fase: FaseUpdate.error,
        mensaje: tr('No se pudo buscar actualizaciones.'),
      );
    }
  }

  /// Descarga (si hace falta) e instala la versión nueva.
  Future<void> instalar() async {
    final Publicacion? p = state.publicacion;
    if (p == null || state.ocupado) {
      return;
    }
    try {
      if (!await _s.puedeInstalar()) {
        await _s.abrirPermisoInstalar();
        state = state.copyWith(
          mensaje: tr(
            'Permite a NB Sound instalar apps y vuelve a tocar "Instalar".',
          ),
        );
        return;
      }
      File? apk = _apk;
      if (apk == null || !apk.existsSync()) {
        final ApkPublicado? elegido = elegirApk(p.apks, _abis);
        if (elegido == null) {
          throw UpdateError(
            tr('Esta versión no trae un APK para tu dispositivo.'),
          );
        }
        final Directory dir = await getTemporaryDirectory();
        final File destino = File('${dir.path}/actualizacion.apk');
        if (destino.existsSync()) {
          await destino.delete();
        }
        state = state.copyWith(
          fase: FaseUpdate.descargando,
          progreso: 0,
          mensaje: tr('Descargando…'),
        );
        _cancel = CancelToken();
        apk = await _s.descargar(
          elegido,
          destino,
          cancel: _cancel,
          onProgreso: (double v) =>
              state = state.copyWith(progreso: v, mensaje: state.mensaje),
        );
        _apk = apk;
      }
      state = state.copyWith(
        fase: FaseUpdate.listo,
        progreso: 1,
        mensaje: tr('Confirma la instalación para terminar.'),
      );
      await _s.instalar(apk);
    } on UpdateError catch (e) {
      state = state.copyWith(fase: FaseUpdate.disponible, mensaje: e.mensaje);
    } catch (_) {
      state = state.copyWith(
        fase: FaseUpdate.disponible,
        mensaje: tr('No se pudo instalar.'),
      );
    }
  }

  void abrirRepo() => unawaited(_s.abrirUrl(kUrlRepo));
}

final NotifierProvider<UpdateController, UpdateState> updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
