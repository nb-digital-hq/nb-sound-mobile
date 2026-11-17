import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_controller.dart';

/// Estado del temporizador de apagado: por tiempo ([hasta] = instante en que
/// pausa, [minutos] = opción elegida) o "al terminar la canción" ([finPista]).
class SleepTimerState {
  const SleepTimerState.tiempo(this.minutos, this.hasta) : finPista = false;
  const SleepTimerState.finDePista()
    : minutos = null,
      hasta = null,
      finPista = true;

  final int? minutos;
  final DateTime? hasta;
  final bool finPista;

  /// Tiempo que falta (null en modo fin de canción).
  Duration? restante(DateTime ahora) {
    final DateTime? h = hasta;
    if (h == null) {
      return null;
    }
    final Duration d = h.difference(ahora);
    return d.isNegative ? Duration.zero : d;
  }
}

/// Temporizador de apagado ("sleep timer"): pausa la reproducción tras la
/// duración elegida o al terminar la canción en curso (). null =
/// apagado.
class SleepTimer extends Notifier<SleepTimerState?> {
  Timer? _timer;
  ProviderSubscription<({int index, Duration pos, Duration dur})>? _sub;

  /// Margen antes del final para pausar sin que arranque la siguiente pista.
  static const Duration _margenFin = Duration(milliseconds: 450);

  @override
  SleepTimerState? build() {
    ref.onDispose(_limpiar);
    return null;
  }

  /// Programa la pausa dentro de [minutos]. Reemplaza un temporizador previo.
  void activar(int minutos) {
    _limpiar();
    final Duration d = Duration(minutes: minutos);
    state = SleepTimerState.tiempo(minutos, DateTime.now().add(d));
    _timer = Timer(d, _disparar);
  }

  /// Pausa justo al acabar la canción en curso (o en cuanto cambie de pista).
  void activarFinDePista() {
    _limpiar();
    state = const SleepTimerState.finDePista();
    final int inicio = ref.read(playerControllerProvider).index;
    _sub = ref.listen<({int index, Duration pos, Duration dur})>(
      playerControllerProvider.select(
        (PlayerState s) => (index: s.index, pos: s.position, dur: s.duration),
      ),
      (_, ({int index, Duration pos, Duration dur}) v) {
        final bool cerca = v.dur > _margenFin && v.pos >= v.dur - _margenFin;
        if (v.index != inicio || cerca) {
          _disparar();
        }
      },
    );
  }

  void cancelar() {
    _limpiar();
    state = null;
  }

  bool get activo => state != null;

  void _disparar() {
    ref.read(playerControllerProvider.notifier).pausar();
    _limpiar();
    state = null;
  }

  void _limpiar() {
    _timer?.cancel();
    _timer = null;
    _sub?.close();
    _sub = null;
  }
}

final NotifierProvider<SleepTimer, SleepTimerState?> sleepTimerProvider =
    NotifierProvider<SleepTimer, SleepTimerState?>(SleepTimer.new);
