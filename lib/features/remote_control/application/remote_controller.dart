import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/salidas.dart';
import '../../../core/security/secure_store.dart';
import '../data/remote_dtos.dart';

/// Fábrica del canal WS (inyectable; los tests conectan a un servidor local).
typedef WsConnect =
    WebSocketChannel Function(Uri url, {String? fingerprint, String? token});

const WsConnect _defaultConnect = conectarControl;

enum RemoteConnection { disconnected, connecting, connected, error }

/// Estado en vivo del reproductor del PC (espejo del frame `estado`).
class RemoteState {
  const RemoteState({
    this.connection = RemoteConnection.disconnected,
    this.estado = const RemoteEstadoDto(),
    this.cola = const <RemotePistaDto>[],
  });

  final RemoteConnection connection;
  final RemoteEstadoDto estado;
  final List<RemotePistaDto> cola;

  bool get conectado => connection == RemoteConnection.connected;
  RemotePistaDto? get pista => estado.pista;

  double get progress {
    final double dur = estado.pista?.duracionSeg ?? 0;
    if (dur <= 0) {
      return 0;
    }
    return (estado.posicionSeg / dur).clamp(0.0, 1.0);
  }

  RemoteState copyWith({
    RemoteConnection? connection,
    RemoteEstadoDto? estado,
    List<RemotePistaDto>? cola,
  }) => RemoteState(
    connection: connection ?? this.connection,
    estado: estado ?? this.estado,
    cola: cola ?? this.cola,
  );
}

/// Cliente del WebSocket `/api/v1/control` (docs/architecture/pc-contract.md §5): refleja el
/// estado que publica el PC y envía comandos; reconexión con backoff.
class RemoteController extends Notifier<RemoteState> {
  RemoteController({WsConnect? connect})
    : _connect = connect ?? _defaultConnect;

  final WsConnect _connect;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnect;
  int _attempt = 0;
  bool _wantConnected = false;
  PairedPc? _pc;

  /// Handoff en pausa: el PC siempre arranca a sonar al recibir `set_queue`, así
  /// que si el teléfono estaba en pausa se pausa el PC en cuanto publique que
  /// suena esa pista. Se arma con el `ack` del `set_queue` (así no actúa sobre el
  /// frame inicial, previo a la carga) y caduca para no pausar algo posterior.
  ({int pistaId, DateTime hasta, bool armado})? _pausarAlSonar;

  @override
  RemoteState build() {
    ref.onDispose(_teardown);
    return const RemoteState();
  }

  /// Conecta al PC [pc] (idempotente).
  void conectar(PairedPc pc) {
    _pc = pc;
    _wantConnected = true;
    _attempt = 0;
    _open();
  }

  void desconectar() {
    _wantConnected = false;
    _pausarAlSonar = null;
    _cancelarSaltoRemoto();
    _teardown();
    state = const RemoteState();
  }

  // ── Comandos (docs §5.2) ─────────────────────────────────────────────────
  void playPause() => _comando('play_pause');

  /// Siguiente/anterior **optimistas**: la UI cambia al instante a la pista
  /// vecina de la cola espejada y, si se pulsa en ráfaga, solo se envía al PC el
  /// destino final (`play_index`), en vez de N `next` que el PC tendría que cargar
  /// uno a uno. Sin cola fiable (aleatorio, cola desalineada o en un extremo) se
  /// envía el comando clásico.
  void siguiente() => _saltoRemoto(1);
  void anterior() => _saltoRemoto(-1);
  void detener() => _comando('stop');
  void buscarSeg(double posicionSeg) =>
      _comando('seek', <String, dynamic>{'posicion_seg': posicionSeg});
  void setVolumen(int volumen) =>
      _comando('set_volume', <String, dynamic>{'volumen': volumen});
  void reproducirIndice(int indice) {
    _cancelarSaltoRemoto();
    _comando('play_index', <String, dynamic>{'indice': indice});
  }

  void setRepeticion(String modo) =>
      _comando('repeat', <String, dynamic>{'modo': modo});
  void setAleatorio(bool activo) =>
      _comando('shuffle', <String, dynamic>{'activo': activo});
  void pedirCola() => _comando('queue');

  /// Alterna el karaoke (instrumental) en el PC. El estado autoritativo llega en
  /// el frame `estado` (`karaoke_activo`). Requiere el PC con el comando `karaoke`.
  void alternarKaraoke() => _comando('karaoke');

  // ── Cola espejada (móvil → PC) ───────────────────────────────────────────
  /// Reemplaza la cola COMPLETA del PC por [ids] y reproduce el índice [indice]
  /// (colas espejadas reales: una sola difusión, no pista a pista). Requiere el
  /// PC con el comando `set_queue`. Si se indica [posicionSeg] (> 0), el PC salta
  /// a esa posición tras cargar la cola: se usa en el handoff con cola completa
  /// (al pasar el control al PC) para conservar dónde iba la pista. Aditivo: un
  /// PC viejo ignora la clave extra.
  ///
  /// Con [reproducir] en false (handoff desde un teléfono en pausa) la cola queda
  /// **en pausa** en el PC: se envía `reproducir: false` (aditivo) y,
  /// como el PC arranca igualmente, se pausa al primer frame `estado`
  /// que lo reporte sonando esa pista.
  void establecerCola(
    List<int> ids,
    int indice, {
    double posicionSeg = 0,
    bool reproducir = true,
  }) {
    _comando('set_queue', <String, dynamic>{
      'ids': ids,
      'indice': indice,
      if (posicionSeg > 0) 'posicion_seg': posicionSeg,
      if (!reproducir) 'reproducir': false,
    });
    if (!reproducir && indice >= 0 && indice < ids.length) {
      _pausarAlSonar = (
        pistaId: ids[indice],
        hasta: DateTime.now().add(const Duration(seconds: 6)),
        armado: false,
      );
    }
  }

  /// Handoff completo teléfono → PC: carga [ids] arrancando en
  /// [indice]/[posicionSeg], con los modos de la sesión ([aleatorio],
  /// [modoRepeticion]) y conservando la pausa si no se estaba [reproducir]ndo.
  ///
  /// El PC, con aleatorio activo, ignora el índice de `set_queue` si la
  /// pista que ya sonaba allí está en la nueva cola (la conserva como actual). Por
  /// eso la cola se carga con el aleatorio APAGADO y se reactiva después: así
  /// arranca en la pista correcta y baraja solo el resto.
  void traspasar({
    required List<int> ids,
    required int indice,
    required double posicionSeg,
    required bool reproducir,
    required bool aleatorio,
    required String modoRepeticion,
  }) {
    _enviar('shuffle', <String, dynamic>{'activo': false});
    _enviar('repeat', <String, dynamic>{'modo': modoRepeticion});
    establecerCola(
      ids,
      indice,
      posicionSeg: posicionSeg,
      reproducir: reproducir,
    );
    if (aleatorio) {
      _enviar('shuffle', <String, dynamic>{'activo': true});
    }
  }

  /// Mueve un ítem de la cola del PC de [desde] a [hasta] (reordenar).
  void moverEnCola(int desde, int hasta) =>
      _comando('move_queue', <String, dynamic>{'desde': desde, 'hasta': hasta});

  /// Quita el ítem [indice] de la cola del PC.
  void quitarDeCola(int indice) =>
      _comando('remove_queue', <String, dynamic>{'indice': indice});

  /// Vacía la cola del PC manteniendo la pista en curso.
  void vaciarCola() => _comando('clear_queue');

  /// Handoff: reproducir en el PC la pista [pistaId] de la biblioteca, saltando
  /// a [posicionSeg] (transferir lo que sonaba en el móvil).
  void reproducirPista(int pistaId, {double posicionSeg = 0}) => _comando(
    'reproducir_pista',
    <String, dynamic>{'pista_id': pistaId, 'posicion_seg': posicionSeg},
  );

  /// Encolar en el PC la pista [pistaId] desde el móvil.
  void encolarPista(int pistaId) =>
      _comando('encolar_pista', <String, dynamic>{'pista_id': pistaId});

  /// Busca por progreso normalizado 0..1.
  void buscarProgreso(double progreso) {
    final double dur = state.estado.pista?.duracionSeg ?? 0;
    buscarSeg(dur * progreso.clamp(0.0, 1.0));
  }

  void cicloRepeticion() {
    // Vocabulario del PC (ninguno/todo/uno): el PC valida `repeat`
    // contra estos valores y descarta lo demás, así que el ciclo debe hablar su
    // idioma. Valor desconocido (indexOf == -1) ⇒ arranca en el primer modo.
    const List<String> modos = ModoRepeticionPc.ciclo;
    final int i = modos.indexOf(state.estado.modoRepeticion);
    setRepeticion(modos[(i + 1) % modos.length]);
  }

  // ── Salto optimista (Connect) ────────────────────────────────────────────
  /// Índice de cola al que la UI ya saltó y el PC aún no confirma.
  int? _saltoObjetivo;
  int? _saltoEnviado;
  Timer? _saltoRafaga;
  DateTime _saltoCaduca = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _ventanaRafaga = Duration(milliseconds: 220);
  static const Duration _esperaConfirmacion = Duration(seconds: 3);

  void _saltoRemoto(int paso) {
    final RemoteEstadoDto e = state.estado;
    final List<RemotePistaDto> cola = state.cola;
    final int base = _saltoObjetivo ?? e.indiceCola;
    final bool alineada =
        base >= 0 &&
        base < cola.length &&
        (_saltoObjetivo != null || cola[base].id == e.pista?.id);
    // "Anterior" pasados 3 s reinicia la pista (lo decide el PC).
    final bool reinicia =
        paso < 0 && _saltoObjetivo == null && e.posicionSeg > 3;
    final int destino = base + paso;
    if (e.aleatorio ||
        e.djActivo ||
        !alineada ||
        reinicia ||
        destino < 0 ||
        destino >= cola.length) {
      _cancelarSaltoRemoto();
      _comando(paso > 0 ? 'next' : 'prev');
      return;
    }
    _saltoObjetivo = destino;
    _saltoCaduca = DateTime.now().add(_esperaConfirmacion);
    state = state.copyWith(estado: _optimista(e, destino));
    final bool enRafaga = _saltoRafaga != null;
    _saltoRafaga?.cancel();
    _saltoRafaga = Timer(_ventanaRafaga, () {
      _saltoRafaga = null;
      if (_saltoObjetivo != null && _saltoObjetivo != _saltoEnviado) {
        _enviarSalto();
      }
    });
    if (!enRafaga) {
      _enviarSalto();
    }
  }

  void _enviarSalto() {
    final int? t = _saltoObjetivo;
    if (t == null) {
      return;
    }
    _saltoEnviado = t;
    _comando('play_index', <String, dynamic>{'indice': t});
  }

  RemoteEstadoDto _optimista(RemoteEstadoDto e, int destino) => e.copyWith(
    pista: state.cola[destino],
    indiceCola: destino,
    posicionSeg: 0,
  );

  void _cancelarSaltoRemoto() {
    _saltoRafaga?.cancel();
    _saltoRafaga = null;
    _saltoObjetivo = null;
    _saltoEnviado = null;
  }

  /// Con un salto pendiente, los frames del PC que aún hablan de la pista vieja
  /// no hacen retroceder la UI (se conserva la pista objetivo); el resto de
  /// campos (volumen, play/pausa, modos) sí se aplican.
  RemoteEstadoDto _filtrarSalto(RemoteEstadoDto llegado) {
    final int? t = _saltoObjetivo;
    if (t == null) {
      return llegado;
    }
    final bool confirmado =
        _saltoRafaga == null && t == _saltoEnviado && llegado.indiceCola == t;
    if (confirmado ||
        DateTime.now().isAfter(_saltoCaduca) ||
        t >= state.cola.length) {
      _cancelarSaltoRemoto();
      return llegado;
    }
    return _optimista(llegado, t);
  }

  // ── Interno ──────────────────────────────────────────────────────────────
  void _open() {
    final PairedPc? pc = _pc;
    if (pc == null || !_wantConnected) {
      return;
    }
    _teardownChannel();
    state = state.copyWith(connection: RemoteConnection.connecting);
    try {
      final WebSocketChannel ch = _connect(
        Uri.parse('${pc.wsBaseUrl}/api/v1/control'),
        fingerprint: pc.fingerprint,
        token: pc.deviceToken,
      );
      _channel = ch;
      _sub = ch.stream.listen(
        _onMessage,
        onError: (_) => _onClosed(),
        onDone: _onClosed,
        cancelOnError: true,
      );
      state = state.copyWith(connection: RemoteConnection.connected);
      // El PC manda el estado inicial al conectar, pero NO la cola: se pide para
      // poblar la vista de cola espejada de inmediato. Idempotente (el PC también
      // la difunde ante cada cambio de cola).
      pedirCola();
    } catch (_) {
      _onClosed();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    // Llegó un frame: la conexión funciona. Reinicia el backoff de reconexión.
    _attempt = 0;
    switch (decoded['tipo']) {
      case 'estado':
        final RemoteEstadoDto estado = _filtrarSalto(
          RemoteEstadoDto.fromJson(decoded),
        );
        state = state.copyWith(
          connection: RemoteConnection.connected,
          estado: estado,
        );
        _quizaPausarTrasHandoff(estado);
      case 'cola':
        final RemoteColaDto cola = RemoteColaDto.fromJson(decoded);
        state = state.copyWith(
          connection: RemoteConnection.connected,
          cola: cola.items,
        );
      case 'ack':
        final ({int pistaId, DateTime hasta, bool armado})? p = _pausarAlSonar;
        if (p != null && decoded['accion'] == 'set_queue') {
          // El PC publica el progreso mientras suena: el siguiente `estado`
          // tras el ack confirma la carga y dispara la pausa.
          _pausarAlSonar = (pistaId: p.pistaId, hasta: p.hasta, armado: true);
        }
      default:
        break; // error: el estado autoritativo llega en 'estado'
    }
  }

  void _quizaPausarTrasHandoff(RemoteEstadoDto estado) {
    final ({int pistaId, DateTime hasta, bool armado})? p = _pausarAlSonar;
    if (p == null || !p.armado) {
      return;
    }
    if (DateTime.now().isAfter(p.hasta)) {
      _pausarAlSonar = null;
      return;
    }
    if (estado.reproduciendo && estado.pista?.id == p.pistaId) {
      _pausarAlSonar = null;
      _enviar('play_pause');
    }
  }

  void _onClosed() {
    _attempt += 1;
    if (!_wantConnected) {
      state = state.copyWith(connection: RemoteConnection.disconnected);
      return;
    }
    // Reconexión con backoff acotado. Tras agotar los intentos la UI pasa a
    // "error" (degradable a local) pero se SIGUE reintentando al intervalo máximo
    // para recuperarse solo cuando vuelva el PC/WiFi.
    final ({int delaySeconds, bool degradar}) plan = planReconexion(_attempt);
    state = state.copyWith(
      connection: plan.degradar
          ? RemoteConnection.error
          : RemoteConnection.connecting,
    );
    _reconnect?.cancel();
    _reconnect = Timer(Duration(seconds: plan.delaySeconds), _open);
  }

  void _comando(String accion, [Map<String, dynamic>? args]) {
    // Otra orden que mueve la pista anula el salto optimista pendiente.
    const Set<String> mueven = <String>{
      'set_queue',
      'move_queue',
      'remove_queue',
      'clear_queue',
      'reproducir_pista',
      'shuffle',
      'stop',
    };
    if (_saltoObjetivo != null && mueven.contains(accion)) {
      _cancelarSaltoRemoto();
    }
    // Cualquier orden del usuario anula la pausa pendiente del handoff (p. ej.
    // pulsó play antes de que el PC confirmara).
    if (accion != 'set_queue' && accion != 'queue') {
      _pausarAlSonar = null;
    }
    _enviar(accion, args);
  }

  void _enviar(String accion, [Map<String, dynamic>? args]) {
    final WebSocketChannel? ch = _channel;
    if (ch == null) {
      return;
    }
    ch.sink.add(
      jsonEncode(<String, dynamic>{
        'tipo': 'comando',
        'accion': accion,
        ...?args,
      }),
    );
  }

  void _teardownChannel() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _teardown() {
    _reconnect?.cancel();
    _reconnect = null;
    _teardownChannel();
  }
}

/// Plan de reconexión del WS de control dado el [intento] fallido consecutivo
/// (1-based). Backoff exponencial acotado a 16 s; tras [maxIntentos] marca
/// `degradar` (la UI muestra "sin conexión" y permite volver a local) pero NO deja
/// de reintentar: al intervalo máximo sigue probando para recuperarse solo cuando
/// el PC/WiFi vuelva. Pura y testeable.
({int delaySeconds, bool degradar}) planReconexion(
  int intento, {
  int maxIntentos = 6,
}) {
  final int exp = (intento - 1).clamp(0, 4); // 2^4 = 16 s tope
  final int seconds = (1 << exp).clamp(1, 16);
  return (delaySeconds: seconds, degradar: intento >= maxIntentos);
}

final NotifierProvider<RemoteController, RemoteState> remoteControllerProvider =
    NotifierProvider<RemoteController, RemoteState>(RemoteController.new);
