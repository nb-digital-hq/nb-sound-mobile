import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/player/application/sleep_timer.dart';

void main() {
  test('restante: cuenta atrás acotada a cero', () {
    final DateTime t0 = DateTime(2026, 1, 1, 12);
    final SleepTimerState s = SleepTimerState.tiempo(
      5,
      t0.add(const Duration(minutes: 5)),
    );
    expect(s.restante(t0), const Duration(minutes: 5));
    expect(s.restante(t0.add(const Duration(minutes: 6))), Duration.zero);
    expect(s.finPista, isFalse);
  });

  test('fin de canción no tiene cuenta atrás', () {
    const SleepTimerState s = SleepTimerState.finDePista();
    expect(s.finPista, isTrue);
    expect(s.restante(DateTime.now()), isNull);
  });
}
