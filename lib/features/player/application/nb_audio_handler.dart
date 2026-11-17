import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/network/salidas.dart';
import '../../../data/db/database.dart';
import '../../../shared/util/media_source.dart';
import 'nb_shuffle_order.dart';
import '../../../core/i18n/i18n.dart';

/// Handler de `audio_service` que envuelve un [AudioPlayer] de `just_audio`.
/// Gestiona la cola, la reproducción en background y los controles del sistema
/// (notificación / pantalla de bloqueo). No depende de la BD: el registro de
/// historial vive en el controlador Riverpod.
///
/// En modo [preview] (escritorio/web, donde just_audio/audio_service no tienen
/// implementación) no se crea el [AudioPlayer]: la cola y el `mediaItem` se
/// actualizan para que la UI se pueda previsualizar, pero no hay audio real.
class NbAudioHandler extends BaseAudioHandler with SeekHandler {
  NbAudioHandler({this.preview = false}) {
    if (preview) {
      return;
    }
    // Ecualizador y normalizador de volumen: solo Android los implementa en
    // just_audio (`AndroidEqualizer`/`AndroidLoudnessEnhancer`). Se insertan en el
    // pipeline del reproductor al crearlo (no se pueden añadir después). En iOS/
    // otros quedan null y el ecualizador se reporta como no soportado.
    final bool android = !kIsWeb && Platform.isAndroid;
    final AndroidEqualizer? eq = android ? AndroidEqualizer() : null;
    final AndroidLoudnessEnhancer? loud = android
        ? AndroidLoudnessEnhancer()
        : null;
    _equalizer = eq;
    _loudness = loud;
    final AudioPipeline pipeline = AudioPipeline(
      androidAudioEffects: <AndroidAudioEffect>[?eq, ?loud],
    );
    final AudioPlayer player = AudioPlayer(audioPipeline: pipeline);
    _player = player;
    if (android) {
      _initAudioSession(player);
    }
    player.playbackEventStream.listen(_broadcastState);
    player.currentIndexStream.listen((int? index) {
      final List<MediaItem> q = queue.value;
      if (_connect != null) {
        return; // la notificación refleja el PC
      }
      if (index != null && index >= 0 && index < q.length) {
        mediaItem.add(q[index]);
        _syncWidget(player.playing);
      }
    });
    player.processingStateStream.listen((ProcessingState s) {
      if (s == ProcessingState.completed) {
        _broadcastState(player.playbackEvent);
      }
    });
  }

  final bool preview;
  AudioPlayer? _player;

  /// Efectos de audio Android (null en iOS/otros/preview). El [EqualizerController]
  /// los lee para exponer bandas/ganancias/normalizador en la pantalla de ajustes.
  AndroidEqualizer? _equalizer;
  AndroidLoudnessEnhancer? _loudness;

  AndroidEqualizer? get equalizer => _equalizer;
  AndroidLoudnessEnhancer? get loudness => _loudness;

  /// PC emparejado activo (para resolver pistas en streaming `/api/...`). Lo fija
  /// el [PlayerController] antes de cargar la cola; null si no hay PC.
  RemoteMedia? remote;

  /// Id de la pista que debe sonar en modo karaoke (instrumental `/stems`), o
  /// null. Lo fija el [PlayerController] al alternar karaoke antes de recargar.
  int? karaokeId;

  /// Resuelve el archivo local del instrumental de una pista (lo fija el
  /// [PlayerController] desde `OfflineStore`). Si existe se reproduce el karaoke
  /// offline; si no, se hace streaming de `/stems`.
  File Function(int pistaId)? stemFileFor;

  /// Resuelve el archivo local de la portada de un álbum (lo fija el
  /// [PlayerController] desde `OfflineStore`); null si no está descargada. Permite
  /// que la notificación/lockscreen muestren la carátula: el sistema no envía la
  /// auth de las portadas `/api/...`, así que solo sirve un archivo local.
  File? Function(int albumId)? localCoverFor;

  /// Estado de favorito de la pista en curso (lo fija el [PlayerController]).
  /// Permite pintar el botón de favorito en la notificación/lockscreen.
  bool Function()? esFavoritaActual;

  /// Alterna el favorito de la pista en curso (acción desde la notificación).
  void Function()? onToggleFavorita;

  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream<Duration>.empty();
  Stream<Duration?> get durationStream =>
      _player?.durationStream ?? const Stream<Duration?>.empty();
  Stream<bool> get shuffleStream =>
      _player?.shuffleModeEnabledStream ?? const Stream<bool>.empty();
  Stream<LoopMode> get loopStream =>
      _player?.loopModeStream ?? const Stream<LoopMode>.empty();

  /// Orden **efectivo** de reproducción (índices originales en el orden en que
  /// sonarán): la identidad `[0,1,2,…]` si el aleatorio está apagado, o el orden
  /// barajado si está encendido. Permite que la Cola refleje qué sigue de verdad.
  Stream<List<int>> get effectiveOrderStream =>
      _player?.sequenceStateStream.map((_) => _player!.effectiveIndices) ??
      const Stream<List<int>>.empty();

  /// Carga una cola de pistas y empieza a reproducir desde [initialIndex].
  /// [initialPosition] permite reanudar en una posición concreta (p. ej. al
  /// alternar karaoke sin perder el punto de la canción). Con [autoPlay] en false
  /// la cola queda cargada **en pausa** (restaurar la sesión al abrir la app).
  Future<void> loadQueue(
    List<Pista> pistas,
    int initialIndex, {
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    final List<MediaItem> items = pistas
        .map(_toMediaItem)
        .toList(growable: false);
    queue.add(items);
    if (initialIndex >= 0 && initialIndex < items.length) {
      mediaItem.add(items[initialIndex]);
      _syncWidget(autoPlay);
    }
    final AudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    final NbShuffleOrder orden = NbShuffleOrder();
    _orden = orden;
    await player.setAudioSources(
      pistas.map(_toAudioSource).toList(growable: false),
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      initialPosition: initialPosition,
      shuffleOrder: orden,
    );
    if (autoPlay) {
      await player.play();
    }
  }

  /// Fija la portada (archivo local) del item en curso si coincide con [pistaId].
  /// Se usa para mostrar la carátula en la notificación una vez materializada,
  /// incluso si la pista se está reproduciendo en streaming.
  void setCurrentArt(int pistaId, String filePath) {
    final MediaItem? current = mediaItem.value;
    final String id = pistaId.toString();
    if (current == null || current.id != id || _connect != null) {
      return;
    }
    final MediaItem updated = current.copyWith(artUri: Uri.file(filePath));
    mediaItem.add(updated);
    // Refleja también la portada en la cola (misma identidad).
    final List<MediaItem> q = queue.value;
    final int idx = q.indexWhere((MediaItem m) => m.id == id);
    if (idx >= 0) {
      final List<MediaItem> nq = List<MediaItem>.of(q);
      nq[idx] = updated;
      queue.add(nq);
    }
    _syncWidget(_player?.playing ?? false);
  }

  /// Añade [p] al final de la cola (la fuente ya viene resuelta del controlador).
  /// Mantiene `queue` (audio_service) en sync con la secuencia del player.
  Future<void> addToQueueEnd(Pista p) async {
    queue.add(<MediaItem>[...queue.value, _toMediaItem(p)]);
    await _player?.addAudioSource(_toAudioSource(p));
  }

  /// Añade varias pistas al final de la cola en **una sola operación**: una
  /// difusión de `queue` y una llamada al player (`addAudioSources`), en vez de
  /// N llamadas en bucle. Clave para encolar un álbum/artista sin bloquear el hilo
  /// de UI con decenas de operaciones (cada `addToQueueEnd` copiaba la cola O(n)).
  Future<void> addAllToQueueEnd(List<Pista> ps) async {
    if (ps.isEmpty) {
      return;
    }
    queue.add(<MediaItem>[
      ...queue.value,
      for (final Pista p in ps) _toMediaItem(p),
    ]);
    await _player?.addAudioSources(<AudioSource>[
      for (final Pista p in ps) _toAudioSource(p),
    ]);
  }

  /// Índice (natural) de la pista que el motor tiene cargada ahora mismo; null
  /// sin reproductor (preview) o sin cola.
  int? get indiceActual => _player?.currentIndex;

  /// Duración de la pista cargada (null si aún no se conoce).
  Duration? get duracionActual => _player?.duration;

  /// Orden aleatorio de la cola cargada (permite insertar "a continuación").
  NbShuffleOrder? _orden;

  /// Posición de la pista en curso en el orden EFECTIVO (barajado o natural).
  int get slotEfectivoActual {
    final AudioPlayer? p = _player;
    final int cur = p?.currentIndex ?? 0;
    if (p == null || !p.shuffleModeEnabled) {
      return cur;
    }
    final int slot = _orden?.indices.indexOf(cur) ?? -1;
    return slot < 0 ? cur : slot;
  }

  /// Inserta [ps] en la posición natural [index] y, con aleatorio activo, en la
  /// posición [efectiva] del orden de reproducción (cola "a continuación").
  Future<void> insertarEnCola(int index, List<Pista> ps, int efectiva) async {
    if (ps.isEmpty) {
      return;
    }
    final List<MediaItem> q = List<MediaItem>.of(queue.value);
    final int idx = index.clamp(0, q.length);
    q.insertAll(idx, ps.map(_toMediaItem));
    queue.add(q);
    final AudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    if (player.shuffleModeEnabled) {
      _orden?.posicionSiguienteInsercion = efectiva;
    }
    await player.insertAudioSources(idx, <AudioSource>[
      for (final Pista p in ps) _toAudioSource(p),
    ]);
  }

  /// Inserta [p] en la posición [index] de la cola (p. ej. `index actual + 1`
  /// para "reproducir a continuación").
  Future<void> insertAt(int index, Pista p) async {
    final List<MediaItem> q = List<MediaItem>.of(queue.value);
    final int idx = index.clamp(0, q.length);
    q.insert(idx, _toMediaItem(p));
    queue.add(q);
    await _player?.insertAudioSource(idx, _toAudioSource(p));
  }

  /// Quita la pista en [index] de la cola.
  Future<void> removeFromQueue(int index) async {
    final List<MediaItem> q = List<MediaItem>.of(queue.value);
    if (index < 0 || index >= q.length) {
      return;
    }
    q.removeAt(index);
    queue.add(q);
    await _player?.removeAudioSourceAt(index);
  }

  /// Mueve la pista de [oldIndex] a [newIndex] (semántica `removeAt`+`insert`,
  /// igual que `ReorderableListView.onReorderItem` y `just_audio.moveAudioSource`).
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    final List<MediaItem> q = List<MediaItem>.of(queue.value);
    if (oldIndex < 0 || oldIndex >= q.length) {
      return;
    }
    final MediaItem m = q.removeAt(oldIndex);
    q.insert(newIndex.clamp(0, q.length), m);
    queue.add(q);
    await _player?.moveAudioSource(oldIndex, newIndex);
  }

  MediaItem _toMediaItem(Pista p) {
    final String? cover = p.coverPath;
    Uri? artUri;
    // Preferencia: archivo local de portada (sirve a la notificación con auth ya
    // resuelta). Si no está descargada, se materializa luego (setCurrentArt).
    final File? localCover = p.albumId != null
        ? localCoverFor?.call(p.albumId!)
        : null;
    if (localCover != null && localCover.existsSync()) {
      artUri = Uri.file(localCover.path);
    } else if (cover != null && cover.isNotEmpty && cover.startsWith('http')) {
      // Portadas http absolutas (seed). Las `/api/...` requieren auth y la
      // notificación del sistema no la envía: se omiten aquí (se materializan).
      artUri = Uri.tryParse(cover);
    }
    return MediaItem(
      id: p.id.toString(),
      title: p.titulo,
      artist: p.artistaNombre,
      album: p.albumTitulo,
      duration: Duration(milliseconds: (p.duracionSeg * 1000).round()),
      artUri: artUri,
      extras: <String, dynamic>{'pistaId': p.id, 'coverPath': cover},
    );
  }

  AudioSource _toAudioSource(Pista p) {
    // Resolución de la fuente: karaoke (instrumental `/stems`) · descargada
    // (file) · sincronizada del PC (`/api/...` → streaming) · música local del
    // teléfono (content://).
    final MediaItem tag = _toMediaItem(p);
    final RemoteMedia? r = remote;
    if (p.id == karaokeId) {
      // Karaoke: instrumental local si está descargado (offline); si no, streaming
      // de `/stems` con el PC. Si no hay ni local ni PC, cae al audio normal.
      final File? local = stemFileFor?.call(p.id);
      if (local != null && local.existsSync()) {
        return AudioSource.file(local.path, tag: tag);
      }
      if (r != null) {
        return audioDelPc(
          r.urlFor('/api/v1/track/${p.id}/stems'),
          cabeceras: r.authHeaders,
          tag: tag,
        );
      }
    }
    final String? path = p.audioPath;
    // Música local del teléfono: content-URI de MediaStore (reproducible por
    // just_audio en Android). Nunca pasa por el PC/Connect (id < 0).
    if (path != null && path.startsWith('content://')) {
      return AudioSource.uri(Uri.parse(path), tag: tag); // red: no (content://)
    }
    if (path == null || path.startsWith('/api/')) {
      // Sincronizada del PC: streaming con auth. Sin ruta explícita se deriva
      // del id. Sin PC no es reproducible; se devuelve la URI relativa para que
      // just_audio falle de forma controlada (error de reproducción), sin
      // recurrir a un asset de demo.
      final String rel = path ?? '/api/v1/track/${p.id}/audio';
      return r != null
          ? audioDelPc(r.urlFor(rel), cabeceras: r.authHeaders, tag: tag)
          : AudioSource.uri(Uri.parse(rel), tag: tag); // red: no (relativa)
    }
    // Ruta de archivo local de una descarga (la fija el PlayerController).
    return AudioSource.file(path, tag: tag);
  }

  // ── Controles (móvil + sistema) ─────────────────────────────────────────
  // En modo Connect los botones de la notificación/lockscreen/auriculares mandan
  // sobre el PC; los llamadores internos (PlayerController) solo actúan en local.
  @override
  Future<void> play() async {
    final ConnectRemoto? c = _connect;
    c != null ? c.play() : await _player?.play();
  }

  @override
  Future<void> pause() async {
    final ConnectRemoto? c = _connect;
    c != null ? c.pause() : await _player?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    final ConnectRemoto? c = _connect;
    c != null ? c.buscar(position) : await _player?.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    final ConnectRemoto? c = _connect;
    c != null ? c.siguiente() : await _saltoRelativo(1);
  }

  @override
  Future<void> skipToPrevious() async {
    final ConnectRemoto? c = _connect;
    c != null ? c.anterior() : await _saltoRelativo(-1);
  }

  /// Siguiente/anterior del sistema (notificación, auriculares). Con "repetir
  /// una", just_audio "salta" a la misma pista; aquí el botón cambia de pista de
  /// verdad (repetir aplica al terminar la canción), igual que en la app.
  Future<void> _saltoRelativo(int paso) async {
    final AudioPlayer? p = _player;
    if (p == null) {
      return;
    }
    if (p.loopMode != LoopMode.one) {
      await (paso > 0 ? p.seekToNext() : p.seekToPrevious());
      return;
    }
    final int? actual = p.currentIndex;
    final List<int> orden = p.effectiveIndices;
    final int slot = actual == null ? -1 : orden.indexOf(actual);
    final int nuevo = slot + paso;
    if (slot >= 0 && nuevo >= 0 && nuevo < orden.length) {
      await p.seek(Duration.zero, index: orden[nuevo]);
    }
  }

  /// Pausa SOLO el reproductor local (handoff al PC): no pasa por [pause], que en
  /// modo Connect se enruta al PC.
  Future<void> pausarLocal() async => _player?.pause();

  // ── Connect: espejo del PC en el sistema ────────────────────────────────
  /// Delegado de Connect: con él activo la notificación/lockscreen reflejan el
  /// PC y las teclas de volumen del teléfono cambian el volumen del PC (sesión
  /// de reproducción remota de Android, como Connect).
  ConnectRemoto? _connect;
  int _volumenRemoto = -1;

  bool get modoConnect => _connect != null;

  void activarConnect(ConnectRemoto delegado) => _connect = delegado;

  /// Refleja el estado del PC en la notificación. [item] null conserva el actual.
  void reflejarConnect({
    MediaItem? item,
    required bool playing,
    required Duration position,
    required int volumen,
  }) {
    if (_connect == null) {
      return;
    }
    final MediaItem? actual = mediaItem.value;
    if (item != null &&
        (actual?.id != item.id || actual?.artUri != item.artUri)) {
      mediaItem.add(item);
    }
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: position,
        bufferedPosition: position,
        speed: playing ? 1.0 : 0.0,
      ),
    );
    final int vol = volumen.clamp(0, 100);
    if (vol != _volumenRemoto) {
      _volumenRemoto = vol;
      androidPlaybackInfo.add(
        RemoteAndroidPlaybackInfo(
          volumeControlType: AndroidVolumeControlType.absolute,
          maxVolume: 100,
          volume: vol,
        ),
      );
    }
    _syncWidget(playing);
  }

  /// Sale de Connect: vuelve la sesión local (volumen del teléfono) y la
  /// notificación vuelve a reflejar el reproductor local.
  void desactivarConnect() {
    if (_connect == null) {
      return;
    }
    _connect = null;
    _volumenRemoto = -1;
    androidPlaybackInfo.add(LocalAndroidPlaybackInfo());
    final AudioPlayer? player = _player;
    final List<MediaItem> q = queue.value;
    final int? idx = player?.currentIndex;
    if (idx != null && idx >= 0 && idx < q.length) {
      mediaItem.add(q[idx]);
    }
    if (player != null) {
      _broadcastState(player.playbackEvent);
    }
  }

  /// Portada local de un álbum para la notificación (null si no está en disco).
  Uri? artLocalDeAlbum(int albumId) {
    final File? f = localCoverFor?.call(albumId);
    return f != null && f.existsSync() ? Uri.file(f.path) : null;
  }

  @override
  Future<void> androidSetRemoteVolume(int volumeIndex) async =>
      _connect?.volumen(volumeIndex.clamp(0, 100));

  @override
  Future<void> androidAdjustRemoteVolume(
    AndroidVolumeDirection direction,
  ) async {
    final ConnectRemoto? c = _connect;
    if (c == null || _volumenRemoto < 0) {
      return;
    }
    // Paso de ~1/16 del rango, como las teclas de volumen del sistema.
    final int paso = direction == AndroidVolumeDirection.raise
        ? 6
        : direction == AndroidVolumeDirection.lower
        ? -6
        : 0;
    if (paso == 0) {
      return;
    }
    final int vol = (_volumenRemoto + paso).clamp(0, 100);
    // Optimista: el siguiente frame del PC lo confirma.
    _volumenRemoto = vol;
    androidPlaybackInfo.add(
      RemoteAndroidPlaybackInfo(
        volumeControlType: AndroidVolumeControlType.absolute,
        maxVolume: 100,
        volume: vol,
      ),
    );
    c.volumen(vol);
  }

  @override
  Future<void> skipToQueueItem(int index) async =>
      _player?.seek(Duration.zero, index: index);

  @override
  Future<void> stop() async {
    await _player?.stop();
    await super.stop();
  }

  /// El usuario cerró la app (la quitó de recientes / cerró la ventana en
  /// ChromeOS): se detiene la reproducción y se retira el servicio en primer
  /// plano, en vez de seguir sonando con la app "cerrada". Es la señal canónica
  /// de Android para "app cerrada" (distinta de ir a segundo plano, donde la
  /// música SÍ debe seguir). Sin esto, en Chromebook el audio seguía tras cerrar.
  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async =>
      _player?.setShuffleModeEnabled(
        shuffleMode == AudioServiceShuffleMode.all,
      );

  /// Regenera el orden aleatorio (baraja nueva, conservando la pista actual al
  /// inicio). just_audio mantiene **el mismo** orden barajado entre activaciones de
  /// shuffle (genera la baraja una sola vez al cargar la cola), por lo que
  /// "aleatorio" parecía una segunda cola fija. Llamar a `shuffle()` produce una
  /// permutación fresca cada vez que se activa el modo aleatorio.
  Future<void> reshuffle() async => _player?.shuffle();

  /// Omitir silencios entre/within pistas (efecto del propio reproductor; Android).
  Future<void> setSkipSilence(bool enabled) async =>
      _player?.setSkipSilenceEnabled(enabled);

  /// Velocidad de reproducción (1.0 = normal). Afecta también al tono salvo en
  /// plataformas que lo compensan; just_audio mantiene el tono en Android/iOS.
  @override
  Future<void> setSpeed(double speed) async => _player?.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final AudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await player.setLoopMode(LoopMode.off);
      case AudioServiceRepeatMode.one:
        await player.setLoopMode(LoopMode.one);
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await player.setLoopMode(LoopMode.all);
    }
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'favorito') {
      onToggleFavorita?.call();
      return null;
    }
    return super.customAction(name, extras);
  }

  /// Re-emite el estado para refrescar los controles de la notificación (p. ej.
  /// cuando cambia el favorito de la pista en curso).
  void refreshControls() {
    final AudioPlayer? player = _player;
    if (player != null) {
      _broadcastState(player.playbackEvent);
    }
  }

  Future<void> dispose() async => _player?.dispose();

  void _broadcastState(PlaybackEvent event) {
    final AudioPlayer? player = _player;
    if (player == null || _connect != null) {
      return;
    }
    final bool playing = player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          if (esFavoritaActual != null)
            MediaControl.custom(
              androidIcon: esFavoritaActual!()
                  ? 'drawable/ic_fav_filled'
                  : 'drawable/ic_fav',
              label: tr('Me gusta'),
              name: 'favorito',
            ),
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: _mapProcessingState(player.processingState),
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: event.currentIndex,
      ),
    );
    _syncWidget(playing);
  }

  static const MethodChannel _widgetChannel = MethodChannel(
    'com.nbsound/widget',
  );

  void _syncWidget(bool isPlaying) {
    if (kIsWeb || !Platform.isAndroid) return;
    final MediaItem? item = mediaItem.value;
    try {
      _widgetChannel.invokeMethod<void>('updateWidget', <String, dynamic>{
        'title': item?.title ?? tr('NB Sound'),
        // Vacío = sin reproducción: el widget pinta su texto de reposo en el
        // idioma del sistema (recursos de Android).
        'artist': item?.artist ?? '',
        'album': item?.album ?? '',
        'isPlaying': isPlaying,
        'artUri': item?.artUri?.toString(),
      });
    } catch (_) {}
  }

  Future<void> _initAudioSession(AudioPlayer player) async {
    try {
      final AudioSession session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.interruptionEventStream.listen((AudioInterruptionEvent event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              player.setVolume(player.volume / 2);
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              player.pause();
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              player.setVolume(1.0);
            case AudioInterruptionType.pause:
              player.play();
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
      session.becomingNoisyEventStream.listen((_) {
        player.pause();
      });
    } catch (_) {}
  }

  static AudioProcessingState _mapProcessingState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}

/// Acciones sobre el PC que la sesión de sistema dispara en modo Connect.
class ConnectRemoto {
  const ConnectRemoto({
    required this.play,
    required this.pause,
    required this.siguiente,
    required this.anterior,
    required this.buscar,
    required this.volumen,
  });

  final void Function() play;
  final void Function() pause;
  final void Function() siguiente;
  final void Function() anterior;
  final void Function(Duration posicion) buscar;
  final void Function(int volumen) volumen;
}
