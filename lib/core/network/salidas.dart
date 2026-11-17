import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'tls_pinning.dart';

// Única puerta de red de la app. Todo lo que abre una conexión se construye
// aquí, y `tool/guardianes/red.dart` rechaza cualquier cliente HTTP, socket o
// imagen remota fuera de `lib/core/network/`. Hay exactamente dos destinos y
// los dos los pide la persona:
//  - el PC emparejado (lo autoriza al escanear su QR; TLS fijado por huella);
//  - la API pública de publicaciones de GitHub, solo al pulsar "Buscar
//    actualizaciones" (Android).
// No existe telemetría ni ningún otro destino.

/// Imagen servida por el PC emparejado (portadas y fotos), con caché en disco.
ImageProvider imagenDelPc(
  String url, {
  Map<String, String>? cabeceras,
  BaseCacheManager? cache,
}) => CachedNetworkImageProvider(url, headers: cabeceras, cacheManager: cache);

/// Audio en streaming desde el PC emparejado. El certificado lo valida
/// `NbHttpOverrides`, porque el proxy de just_audio usa el `HttpClient` global.
AudioSource audioDelPc(
  String url, {
  Map<String, String>? cabeceras,
  Object? tag,
}) => AudioSource.uri(Uri.parse(url), headers: cabeceras, tag: tag);

/// Canal de control remoto (WebSocket) con el PC, con la huella fijada.
WebSocketChannel conectarControl(
  Uri url, {
  String? fingerprint,
  String? token,
}) => IOWebSocketChannel.connect(
  url,
  customClient: pinnedHttpClient(fingerprint),
  headers: <String, dynamic>{
    if (token != null) 'Authorization': 'Bearer $token',
  },
);

/// Cliente de sondeo de un posible PC durante el descubrimiento. En TLS acepta
/// cualquier certificado solo para aprender su huella (TOFU); la huella se
/// confirma después contra la del QR.
({Dio dio, String? Function() huella}) clienteDeSondeo(
  String host,
  int puerto, {
  required bool tls,
  required Duration espera,
}) {
  String? huella;
  final HttpClient client = HttpClient()..connectionTimeout = espera;
  if (tls) {
    client.badCertificateCallback = (X509Certificate cert, String h, int p) {
      huella = sha256.convert(cert.der).toString();
      return true;
    };
  }
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: '${tls ? 'https' : 'http'}://$host:$puerto',
      connectTimeout: espera,
      receiveTimeout: espera,
      sendTimeout: espera,
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => client);
  return (dio: dio, huella: () => huella);
}

/// Cliente de la API de publicaciones de GitHub (comprobación manual de
/// actualizaciones). Sin credenciales ni identificadores del dispositivo.
Dio clienteDePublicaciones() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    headers: <String, String>{
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'NB-Sound-Mobile',
    },
  ),
);
