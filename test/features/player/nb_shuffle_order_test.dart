import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/player/application/nb_shuffle_order.dart';

void main() {
  group('NbShuffleOrder', () {
    NbShuffleOrder baraja(int n, {int inicial = 0}) {
      final NbShuffleOrder o = NbShuffleOrder(random: Random(7))..insert(0, n);
      o.shuffle(initialIndex: inicial);
      return o;
    }

    test('la pista inicial encabeza la baraja y no se pierde ninguna', () {
      final NbShuffleOrder o = baraja(10, inicial: 4);
      expect(o.indices.first, 4);
      expect(
        o.indices.toSet(),
        Set<int>.of(List<int>.generate(10, (int i) => i)),
      );
    });

    test(
      'inserción dirigida: las nuevas quedan, en orden, en la posición pedida',
      () {
        final NbShuffleOrder o = baraja(6, inicial: 2);
        final List<int> antes = List<int>.of(o.indices);
        // Inserta 2 pistas al final (índices naturales 6 y 7) justo tras la actual.
        o.posicionSiguienteInsercion = 1;
        o.insert(6, 2);
        expect(o.indices.sublist(0, 3), <int>[2, 6, 7]);
        expect(o.indices.sublist(3), antes.sublist(1));
        // Se consume: la siguiente inserción vuelve a ser al azar.
        expect(o.posicionSiguienteInsercion, isNull);
      },
    );

    test('insertar en medio desplaza los índices posteriores', () {
      final NbShuffleOrder o = NbShuffleOrder(random: Random(1))
        ..posicionSiguienteInsercion = 0
        ..insert(0, 4);
      // Sin barajar: [0,1,2,3]. Inserta en el índice natural 1.
      o.posicionSiguienteInsercion = 1;
      o.insert(1, 1);
      expect(o.indices, <int>[0, 1, 2, 3, 4]);
    });

    test('removeRange reajusta índices', () {
      final NbShuffleOrder o = NbShuffleOrder(random: Random(1))
        ..posicionSiguienteInsercion = 0
        ..insert(0, 5);
      o.removeRange(1, 3);
      expect(o.indices, <int>[0, 1, 2]);
    });
  });

  group('posicionEnCola (a continuación / cola FIFO)', () {
    test('reproducir a continuación va justo detrás de la actual', () {
      final ({int natural, int efectiva}) p = posicionEnCola(
        actual: 3,
        slotActual: 0,
        enCola: 2,
        largo: 10,
        alFrente: true,
      );
      expect(p.natural, 4);
      expect(p.efectiva, 1);
    });

    test('añadir a la cola va detrás de lo ya encolado', () {
      final ({int natural, int efectiva}) p = posicionEnCola(
        actual: 3,
        slotActual: 0,
        enCola: 2,
        largo: 10,
        alFrente: false,
      );
      expect(p.natural, 6);
      expect(p.efectiva, 3);
    });

    test('acota al largo de la cola', () {
      final ({int natural, int efectiva}) p = posicionEnCola(
        actual: 9,
        slotActual: 9,
        enCola: 5,
        largo: 10,
        alFrente: false,
      );
      expect(p.natural, 10);
      expect(p.efectiva, 10);
    });
  });
}
