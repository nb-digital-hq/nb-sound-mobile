import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/player/application/player_controller.dart';

void main() {
  group('indiceSalto', () {
    test('orden natural: siguiente y anterior', () {
      expect(
        indiceSalto(
          order: const <int>[],
          length: 4,
          actual: 1,
          paso: 1,
          darVuelta: false,
        ),
        2,
      );
      expect(
        indiceSalto(
          order: const <int>[],
          length: 4,
          actual: 1,
          paso: -1,
          darVuelta: false,
        ),
        0,
      );
    });
    test('extremos sin repetir ⇒ null; con repetir todas da la vuelta', () {
      expect(
        indiceSalto(
          order: const <int>[],
          length: 3,
          actual: 2,
          paso: 1,
          darVuelta: false,
        ),
        isNull,
      );
      expect(
        indiceSalto(
          order: const <int>[],
          length: 3,
          actual: 2,
          paso: 1,
          darVuelta: true,
        ),
        0,
      );
      expect(
        indiceSalto(
          order: const <int>[],
          length: 3,
          actual: 0,
          paso: -1,
          darVuelta: true,
        ),
        2,
      );
    });
    test('sigue el orden barajado', () {
      const List<int> o = <int>[2, 0, 3, 1];
      expect(
        indiceSalto(order: o, length: 4, actual: 0, paso: 1, darVuelta: false),
        3,
      );
      expect(
        indiceSalto(order: o, length: 4, actual: 0, paso: -1, darVuelta: false),
        2,
      );
    });
    test('cola vacía o índice inválido ⇒ null', () {
      expect(
        indiceSalto(
          order: const <int>[],
          length: 0,
          actual: 0,
          paso: 1,
          darVuelta: true,
        ),
        isNull,
      );
      expect(
        indiceSalto(
          order: const <int>[],
          length: 3,
          actual: -1,
          paso: 1,
          darVuelta: true,
        ),
        isNull,
      );
    });
  });
}
