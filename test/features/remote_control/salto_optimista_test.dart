import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/security/secure_store.dart';
import 'package:nb_sound_mobile/features/remote_control/application/remote_controller.dart';
import 'package:web_socket_channel/io.dart';

Future<void> _hasta(bool Function() c) async {
  final DateTime fin = DateTime.now().add(const Duration(seconds: 3));
  while (!c() && DateTime.now().isBefore(fin)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Map<String, dynamic> _pista(int id) => <String, dynamic>{
  'id': id,
  'titulo': 'Pista $id',
  'artista': 'Artista',
  'duracion_seg': 100,
};

/// PC simulado: publica estado y cola, y registra los comandos recibidos.
Future<(HttpServer, List<Map<String, dynamic>>, List<WebSocket>)> _pcSimulado({
  bool aleatorio = false,
}) async {
  final HttpServer server = await HttpServer.bind('localhost', 0);
  final List<Map<String, dynamic>> recibidos = <Map<String, dynamic>>[];
  final List<WebSocket> sockets = <WebSocket>[];
  server.listen((HttpRequest req) async {
    final WebSocket ws = await WebSocketTransformer.upgrade(req);
    sockets.add(ws);
    ws.listen(
      (dynamic d) =>
          recibidos.add(jsonDecode(d as String) as Map<String, dynamic>),
    );
    ws.add(
      jsonEncode(<String, dynamic>{
        'tipo': 'estado',
        'reproduciendo': true,
        'pista': _pista(10),
        'posicion_seg': 1,
        'aleatorio': aleatorio,
        'indice_cola': 0,
      }),
    );
    ws.add(
      jsonEncode(<String, dynamic>{
        'tipo': 'cola',
        'items': <Map<String, dynamic>>[
          for (int i = 0; i < 6; i++) _pista(10 + i),
        ],
        'indice': 0,
      }),
    );
  });
  return (server, recibidos, sockets);
}

Future<(ProviderContainer, RemoteController)> _conectar(HttpServer s) async {
  final ProviderContainer c = ProviderContainer(
    overrides: [
      remoteControllerProvider.overrideWith(
        () => RemoteController(
          connect: (Uri url, {String? fingerprint, String? token}) =>
              IOWebSocketChannel.connect(url),
        ),
      ),
    ],
  );
  final RemoteController ctrl = c.read(remoteControllerProvider.notifier);
  ctrl.conectar(
    PairedPc(
      deviceToken: 't',
      fingerprint: null,
      host: 'localhost',
      port: s.port,
      nombre: 'PC',
    ),
  );
  await _hasta(() => c.read(remoteControllerProvider).cola.length == 6);
  return (c, ctrl);
}

void main() {
  test(
    'siguiente en Connect cambia la pista al instante, sin esperar al PC',
    () async {
      final (HttpServer s, _, _) = await _pcSimulado();
      addTearDown(() => s.close(force: true));
      final (ProviderContainer c, RemoteController ctrl) = await _conectar(s);
      addTearDown(c.dispose);

      ctrl.siguiente();
      // Sin ninguna respuesta del PC, la UI ya muestra la pista siguiente.
      expect(c.read(remoteControllerProvider).pista?.id, 11);
      expect(c.read(remoteControllerProvider).estado.indiceCola, 1);
    },
  );

  test(
    'una ráfaga de siguientes llega al PC como un único salto al destino',
    () async {
      final (HttpServer s, List<Map<String, dynamic>> rec, _) =
          await _pcSimulado();
      addTearDown(() => s.close(force: true));
      final (ProviderContainer c, RemoteController ctrl) = await _conectar(s);
      addTearDown(c.dispose);

      ctrl.siguiente();
      ctrl.siguiente();
      ctrl.siguiente();
      expect(c.read(remoteControllerProvider).pista?.id, 13);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final List<Map<String, dynamic>> saltos = rec
          .where(
            (Map<String, dynamic> m) =>
                m['accion'] == 'play_index' || m['accion'] == 'next',
          )
          .toList();
      // El primero va directo (sin latencia) y el último cierra la ráfaga.
      expect(saltos.map((Map<String, dynamic> m) => m['indice']), <int>[1, 3]);
      expect(
        saltos.every((Map<String, dynamic> m) => m['accion'] == 'play_index'),
        isTrue,
      );
    },
  );

  test(
    'un estado viejo del PC no hace retroceder la UI durante el salto',
    () async {
      final (HttpServer s, _, List<WebSocket> socks) = await _pcSimulado();
      addTearDown(() => s.close(force: true));
      final (ProviderContainer c, RemoteController ctrl) = await _conectar(s);
      addTearDown(c.dispose);

      ctrl.siguiente();
      socks.first.add(
        jsonEncode(<String, dynamic>{
          'tipo': 'estado',
          'reproduciendo': true,
          'pista': _pista(10),
          'posicion_seg': 2,
          'volumen': 30,
          'indice_cola': 0,
        }),
      );
      await _hasta(() => c.read(remoteControllerProvider).estado.volumen == 30);
      final RemoteState st = c.read(remoteControllerProvider);
      expect(st.pista?.id, 11); // conserva el destino
      expect(st.estado.volumen, 30); // el resto del estado sí se aplica
    },
  );

  test(
    'con aleatorio activo se delega en el PC (no se adivina la siguiente)',
    () async {
      final (HttpServer s, List<Map<String, dynamic>> rec, _) =
          await _pcSimulado(aleatorio: true);
      addTearDown(() => s.close(force: true));
      final (ProviderContainer c, RemoteController ctrl) = await _conectar(s);
      addTearDown(c.dispose);

      ctrl.siguiente();
      expect(c.read(remoteControllerProvider).pista?.id, 10);
      await _hasta(
        () => rec.any((Map<String, dynamic> m) => m['accion'] == 'next'),
      );
      expect(
        rec.any((Map<String, dynamic> m) => m['accion'] == 'next'),
        isTrue,
      );
    },
  );
}
