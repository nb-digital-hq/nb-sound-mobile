import 'dart:math';

import 'package:just_audio/just_audio.dart';

/// Orden aleatorio de just_audio con **inserción dirigida**: igual que
/// `DefaultShuffleOrder` (la pista en curso encabeza la baraja), pero si se fija
/// [posicionSiguienteInsercion] las pistas añadidas se colocan, en orden, en esa
/// posición del orden efectivo. Con el orden por defecto, "reproducir a
/// continuación"/"añadir a la cola" caían en un sitio AL AZAR con aleatorio
/// activo; así suenan justo después.
class NbShuffleOrder extends ShuffleOrder {
  NbShuffleOrder({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  final List<int> indices = <int>[];

  /// Posición (en el orden efectivo) para la PRÓXIMA inserción; se consume al
  /// usarse. null = posición al azar (comportamiento por defecto).
  int? posicionSiguienteInsercion;

  @override
  void shuffle({int? initialIndex}) {
    if (indices.length <= 1) {
      return;
    }
    indices.shuffle(_random);
    if (initialIndex == null) {
      return;
    }
    final int swapPos = indices.indexOf(initialIndex);
    if (swapPos < 0) {
      return;
    }
    indices[swapPos] = indices[0];
    indices[0] = initialIndex;
  }

  @override
  void insert(int index, int count) {
    for (int i = 0; i < indices.length; i++) {
      if (indices[i] >= index) {
        indices[i] += count;
      }
    }
    final List<int> nuevos = List<int>.generate(count, (int i) => index + i);
    final int? pos = posicionSiguienteInsercion;
    posicionSiguienteInsercion = null;
    if (pos != null) {
      indices.insertAll(pos.clamp(0, indices.length), nuevos);
      return;
    }
    for (final int n in nuevos) {
      indices.insert(_random.nextInt(indices.length + 1), n);
    }
  }

  @override
  void removeRange(int start, int end) {
    final int count = end - start;
    indices.removeWhere((int i) => i >= start && i < end);
    for (int i = 0; i < indices.length; i++) {
      if (indices[i] >= end) {
        indices[i] -= count;
      }
    }
  }

  @override
  void clear() => indices.clear();
}

/// Dónde insertar en la cola "a continuación" (). [actual] es el
/// índice natural de la pista en curso, [slotActual] su posición en el orden
/// efectivo y [enCola] cuántas pistas añadidas por el usuario esperan ya detrás.
/// "Reproducir a continuación" ([alFrente]) va justo detrás de la actual; "añadir
/// a la cola" va detrás de las ya encoladas (FIFO). Pura y testeable.
({int natural, int efectiva}) posicionEnCola({
  required int actual,
  required int slotActual,
  required int enCola,
  required int largo,
  required bool alFrente,
}) {
  final int extra = alFrente ? 0 : enCola;
  return (
    natural: (actual + 1 + extra).clamp(0, largo),
    efectiva: (slotActual + 1 + extra).clamp(0, largo),
  );
}
