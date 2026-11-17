import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../../core/network/salidas.dart';
import '../../../core/i18n/i18n.dart';

/// Repositorio de GitHub donde se publican las versiones de la app.
const String kRepoGithub = 'nb-digital-hq/nb-sound-mobile';
const String kUrlRepo = 'https://github.com/$kRepoGithub';
const String kUrlUltimaRelease =
    'https://api.github.com/repos/$kRepoGithub/releases/latest';

/// Un APK adjunto a una publicación.
class ApkPublicado {
  const ApkPublicado({
    required this.nombre,
    required this.url,
    required this.bytes,
    this.sha256,
  });

  final String nombre;
  final String url;
  final int bytes;

  /// Huella publicada por GitHub (`digest: sha256:…`), si la hay.
  final String? sha256;
}

/// Una versión publicada en GitHub.
class Publicacion {
  const Publicacion({
    required this.version,
    required this.notas,
    required this.apks,
    required this.url,
  });

  /// Versión sin la `v` inicial (p. ej. `0.1.3`).
  final String version;
  final String notas;
  final List<ApkPublicado> apks;
  final String url;

  factory Publicacion.fromJson(Map<String, dynamic> j) {
    final String tag = (j['tag_name'] as String? ?? '').trim();
    return Publicacion(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      notas: (j['body'] as String? ?? '').trim(),
      url: j['html_url'] as String? ?? kUrlRepo,
      apks: <ApkPublicado>[
        for (final Object? a in (j['assets'] as List<Object?>? ?? <Object?>[]))
          if (a is Map<String, dynamic> &&
              (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'))
            ApkPublicado(
              nombre: a['name'] as String,
              url: a['browser_download_url'] as String? ?? '',
              bytes: (a['size'] as num?)?.toInt() ?? 0,
              sha256: switch (a['digest']) {
                final String d when d.startsWith('sha256:') =>
                  d.substring(7).toLowerCase(),
                _ => null,
              },
            ),
      ],
    );
  }
}

/// Compara dos versiones `x.y.z` (ignora sufijos `-…`/`+…`). >0 si [a] es mayor.
int compararVersiones(String a, String b) {
  List<int> partes(String v) => v
      .split(RegExp(r'[-+]'))
      .first
      .split('.')
      .map((String p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final List<int> x = partes(a);
  final List<int> y = partes(b);
  for (int i = 0; i < 3; i++) {
    final int d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) {
      return d;
    }
  }
  return 0;
}

/// Elige el APK para un dispositivo con [abis] (en orden de preferencia). Se usa
/// SIEMPRE el APK de la ABI: con `--split-per-abi` su versionCode es mayor que el
/// del universal, así que el universal nunca podría instalarse encima de una
/// instalación por ABI. Solo si la publicación no trae APK por ABI se recurre al
/// universal. Pura y testeable.
ApkPublicado? elegirApk(List<ApkPublicado> apks, List<String> abis) {
  for (final String abi in abis) {
    for (final ApkPublicado a in apks) {
      if (a.nombre.contains('-$abi.apk') || a.nombre.contains('-$abi-')) {
        return a;
      }
    }
  }
  final bool hayPorAbi = apks.any(
    (ApkPublicado a) =>
        RegExp(r'(arm64-v8a|armeabi-v7a|x86_64|x86)').hasMatch(a.nombre),
  );
  if (hayPorAbi) {
    return null; // hay APKs por ABI, pero ninguno para este dispositivo
  }
  for (final ApkPublicado a in apks) {
    if (a.nombre.contains('universal')) {
      return a;
    }
  }
  return apks.length == 1 ? apks.first : null;
}

/// Errores del actualizador, con mensaje listo para la UI.
class UpdateError implements Exception {
  const UpdateError(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Acceso a GitHub y al instalador nativo.
class UpdateService {
  UpdateService({Dio? dio, MethodChannel? channel})
    : _dio = dio ?? clienteDePublicaciones(),
      _channel = channel ?? const MethodChannel('com.nbsound/updater');

  final Dio _dio;
  final MethodChannel _channel;

  Future<({String version, List<String> abis})> info() async {
    final Map<Object?, Object?>? r = await _channel
        .invokeMapMethod<Object?, Object?>('info');
    return (
      version: r?['version'] as String? ?? '',
      abis: <String>[
        for (final Object? a in (r?['abis'] as List<Object?>? ?? <Object?>[]))
          if (a is String) a,
      ],
    );
  }

  Future<Publicacion> ultimaPublicacion() async {
    try {
      final Response<Map<String, dynamic>> r = await _dio
          .get<Map<String, dynamic>>(kUrlUltimaRelease);
      return Publicacion.fromJson(r.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw UpdateError(tr('Todavía no hay versiones publicadas.'));
      }
      if (e.response?.statusCode == 403) {
        throw UpdateError(
          tr('GitHub limitó las consultas. Inténtalo en unos minutos.'),
        );
      }
      throw UpdateError(
        tr('No se pudo consultar GitHub. Revisa tu conexión a internet.'),
      );
    }
  }

  /// Descarga [apk] a [destino] y comprueba tamaño y huella SHA-256.
  Future<File> descargar(
    ApkPublicado apk,
    File destino, {
    void Function(double progreso)? onProgreso,
    CancelToken? cancel,
  }) async {
    try {
      await _dio.download(
        apk.url,
        destino.path,
        cancelToken: cancel,
        options: Options(headers: <String, String>{'Accept': '*/*'}),
        onReceiveProgress: (int r, int t) {
          final int total = t > 0 ? t : apk.bytes;
          if (total > 0) {
            onProgreso?.call((r / total).clamp(0.0, 1.0));
          }
        },
      );
    } on DioException {
      throw UpdateError(tr('La descarga falló. Inténtalo de nuevo.'));
    }
    final int tam = await destino.length();
    if (apk.bytes > 0 && tam != apk.bytes) {
      await destino.delete();
      throw UpdateError(tr('La descarga llegó incompleta.'));
    }
    final String? esperado = apk.sha256;
    if (esperado != null) {
      final Digest d = await sha256.bind(destino.openRead()).first;
      if (d.toString() != esperado) {
        await destino.delete();
        throw UpdateError(
          tr('El archivo descargado no coincide con el publicado.'),
        );
      }
    }
    return destino;
  }

  Future<bool> puedeInstalar() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  Future<void> abrirPermisoInstalar() =>
      _channel.invokeMethod<void>('openInstallSettings');

  Future<void> instalar(File apk) async {
    try {
      await _channel.invokeMethod<bool>('install', <String, String>{
        'path': apk.path,
      });
    } on PlatformException {
      throw UpdateError(tr('Android no pudo iniciar la instalación.'));
    }
  }

  Future<void> abrirUrl(String url) =>
      _channel.invokeMethod<void>('openUrl', <String, String>{'url': url});
}
