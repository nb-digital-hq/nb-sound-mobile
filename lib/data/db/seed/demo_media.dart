import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:flutter/painting.dart' show HSVColor;
import 'package:flutter/foundation.dart';

import '../../../features/offline/data/offline_store.dart';
import '../daos/assets_dao.dart';
import '../database.dart';
import 'dev_seed.dart';

/// Media del catálogo de demostración, generada en el propio dispositivo.
///
/// Las portadas se dibujan, el audio se sintetiza y las letras son originales:
/// así la demostración no necesita PC ni archivos con derechos de terceros, y
/// el repositorio no lleva media binaria. Solo corre con `NB_SEED=true`.
Future<void> materializarMediaDemo(AppDatabase db, OfflineStore store) async {
  for (final Directory d in <Directory>[
    store.coversDir,
    store.artistsDir,
    store.audioDir,
    store.lyricsDir,
  ]) {
    await d.create(recursive: true);
  }

  for (final (int id, String titulo, int artistaId, int _) in demoAlbums) {
    await store
        .coverFile(id)
        .writeAsBytes(
          await _dibujar(512, id * 7919 + artistaId, titulo, false),
        );
    await db.assetsDao.setEstado(AssetTipo.cover, id, 'done');
  }
  for (final (int id, String nombre) in demoArtistas) {
    await store
        .artistFile(id)
        .writeAsBytes(await _dibujar(384, id * 104729, nombre, true));
    await db.assetsDao.setEstado(AssetTipo.artist, id, 'done');
  }

  // Cuatro piezas base, una por duración del catálogo; cada pista enlaza la
  // suya para no multiplicar decenas de megas de audio idéntico.
  final Map<int, File> base = <int, File>{};
  for (final int dur in <int>{for (final t in demoPistas) t.$5}) {
    final File f = File('${store.audioDir.path}/demo_$dur.wav');
    await f.writeAsBytes(await compute(sintetizarPieza, (dur, base.length)));
    base[dur] = f;
  }
  for (final (int id, String _, int _, int _, int dur, bool _) in demoPistas) {
    final File destino = store.audioFile(id);
    if (await destino.exists()) {
      await destino.delete();
    }
    await Link(destino.path).create(base[dur]!.path);
    final bool conLetra = _letras.containsKey(id);
    if (conLetra) {
      await store
          .lyricsFile(id)
          .writeAsString(
            jsonEncode(<String, String>{
              'synced_lyrics': _letras[id]!,
              'plain_lyrics': '',
            }),
          );
    }
    await db.downloadsDao.upsert(
      DescargasAudioCompanion.insert(
        pistaId: Value(id),
        estado: const Value('done'),
        hashOk: const Value(true),
        lyricsEstado: Value(conLetra ? 'done' : 'none'),
        actualizadoEn: DateTime.now().toUtc(),
      ),
    );
  }

  // Historial reciente para que Inicio muestre actividad.
  for (final int id in <int>[14, 6, 1, 9, 18, 4, 20, 13]) {
    await db.historyDao.registrarReproduccion(id, completada: true);
  }
}

/// Portada abstracta determinista: degradado de dos tonos y formas a partir de
/// una semilla. El título no se pinta (las capturas lo muestran al lado).
Future<Uint8List> _dibujar(
  int lado,
  int semilla,
  String _,
  bool circulo,
) async {
  final math.Random r = math.Random(semilla);
  final double l = lado.toDouble();
  ui.Color tono(double s, double v) =>
      HSVColor.fromAHSV(1, r.nextDouble() * 360, s, v).toColor();
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final ui.Canvas c = ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, l, l));
  c.drawRect(
    ui.Rect.fromLTWH(0, 0, l, l),
    ui.Paint()
      ..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(l, l), <ui.Color>[
        tono(0.65, 0.55),
        tono(0.75, 0.25),
      ]),
  );
  for (int i = 0; i < 5; i++) {
    final ui.Paint p = ui.Paint()
      ..color = tono(0.5, 0.95).withValues(alpha: 0.18 + r.nextDouble() * 0.3);
    final ui.Offset centro = ui.Offset(r.nextDouble() * l, r.nextDouble() * l);
    if (circulo || r.nextBool()) {
      c.drawCircle(centro, l * (0.1 + r.nextDouble() * 0.35), p);
    } else {
      c.save();
      c.translate(centro.dx, centro.dy);
      c.rotate(r.nextDouble() * math.pi);
      c.drawRect(
        ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: l * (0.2 + r.nextDouble() * 0.6),
          height: l * (0.04 + r.nextDouble() * 0.12),
        ),
        p,
      );
      c.restore();
    }
  }
  final ui.Image img = await rec.endRecording().toImage(lado, lado);
  final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

/// Sintetiza una pieza instrumental sencilla (acordes suaves y arpegio) en WAV
/// mono de 16 kHz. Pública para poder probar la cabecera del archivo.
Uint8List sintetizarPieza((int, int) args) {
  final (int segundos, int variante) = args;
  const int fs = 16000;
  final int n = segundos * fs;
  final Float64List mezcla = Float64List(n);
  // Progresiones en semitonos sobre La 220 Hz.
  const List<List<List<int>>> progresiones = <List<List<int>>>[
    <List<int>>[
      <int>[0, 4, 7],
      <int>[-3, 0, 4],
      <int>[5, 9, 12],
      <int>[7, 11, 14],
    ],
    <List<int>>[
      <int>[0, 3, 7],
      <int>[5, 8, 12],
      <int>[-2, 2, 5],
      <int>[3, 7, 10],
    ],
    <List<int>>[
      <int>[2, 5, 9],
      <int>[7, 11, 14],
      <int>[0, 4, 7],
      <int>[-3, 0, 4],
    ],
    <List<int>>[
      <int>[0, 4, 7],
      <int>[7, 11, 14],
      <int>[-3, 0, 4],
      <int>[5, 9, 12],
    ],
  ];
  final List<List<int>> prog = progresiones[variante % progresiones.length];
  double hz(int st) => 220 * math.pow(2, st / 12).toDouble();
  const double compas = 2.4; // segundos por acorde
  for (int i = 0; i < n; i++) {
    final double t = i / fs;
    final int k = (t / compas).floor();
    final List<int> acorde = prog[k % prog.length];
    final double dentro = t - k * compas;
    double v = 0;
    for (final int st in acorde) {
      v += math.sin(2 * math.pi * hz(st - 12) * t) * 0.12;
    }
    // Arpegio en corcheas con envolvente percusiva.
    const double paso = compas / 8;
    final int nota = (dentro / paso).floor();
    final double fase = dentro - nota * paso;
    final int st = acorde[nota % acorde.length] + (nota >= 4 ? 12 : 0);
    v += math.sin(2 * math.pi * hz(st) * t) * 0.22 * math.exp(-fase * 6);
    // Entrada y salida suaves.
    final double env = math.min(1, math.min(t / 2, (segundos - t) / 3));
    mezcla[i] = v * env;
  }
  final BytesBuilder b = BytesBuilder();
  void u32(int x) =>
      b.add(Uint8List(4)..buffer.asByteData().setUint32(0, x, Endian.little));
  void u16(int x) =>
      b.add(Uint8List(2)..buffer.asByteData().setUint16(0, x, Endian.little));
  b.add(ascii.encode('RIFF'));
  u32(36 + n * 2);
  b.add(ascii.encode('WAVEfmt '));
  u32(16);
  u16(1);
  u16(1);
  u32(fs);
  u32(fs * 2);
  u16(2);
  u16(16);
  b.add(ascii.encode('data'));
  u32(n * 2);
  final ByteData datos = ByteData(n * 2);
  for (int i = 0; i < n; i++) {
    datos.setInt16(
      i * 2,
      (mezcla[i].clamp(-1.0, 1.0) * 32000).round(),
      Endian.little,
    );
  }
  b.add(datos.buffer.asUint8List());
  return b.toBytes();
}

/// Letras originales para la demostración (LRC).
const Map<int, String> _letras = <int, String>{
  1: '''[00:04.00]Hay un faro encendido en la orilla
[00:10.00]que no sabe que lo miro desde aquí
[00:16.00]cuenta barcos, cuenta olas, cuenta días
[00:22.00]y yo cuento los minutos para ir
[00:30.00]Luz que gira, luz que vuelve
[00:36.00]luz que espera sin pedir
[00:42.00]si me pierdo en la marea
[00:48.00]tú me sabes traer a mí
[00:56.00]Faro encendido
[01:02.00]faro encendido
[01:08.00]nadie duerme mientras sigas tú
[01:16.00]Faro encendido''',
  6: '''[00:04.00]We left the city at kilometer zero
[00:10.00]with a map that we drew on our hands
[00:16.00]every sign on the road said tomorrow
[00:22.00]every song on the radio said stay
[00:30.00]Turn it up, turn it up
[00:36.00]let the highway do the talking
[00:42.00]we are nowhere, we are going
[00:48.00]kilometer zero again''',
  14: '''[00:04.00]Bajan los satélites a la verbena
[00:10.00]con antenas de colores y luces de neón
[00:16.00]el acordeón responde desde la luna
[00:22.00]y la plaza entera mueve el corazón
[00:30.00]Cumbia de satélites
[00:36.00]órbita para bailar
[00:42.00]que se acabe la noche
[00:48.00]cuando quiera el mar''',
  18: '''[00:04.00]Agua de domingo, pan recién hecho
[00:12.00]la ventana abierta y el reloj sin prisa
[00:20.00]nadie nos espera, nadie nos llama
[00:28.00]solo la tarde lenta y tu risa
[00:36.00]Agua de domingo
[00:44.00]que no pase nada más''',
};
