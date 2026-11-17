import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/offline/application/image_resolver.dart';
import '../../features/player/application/cover_prefetch.dart';
import '../../features/player/application/playback.dart';
import '../../features/remote_control/presentation/destination_sheet.dart';
import '../../features/sync/application/conexion_provider.dart';
import 'mini_player.dart';
import '../../core/i18n/i18n.dart';

/// Mini-reproductor ya cableado a los providers de "lo que suena". Se reutiliza
/// en el shell de pestañas (sobre la barra inferior) y en las vistas de detalle
/// (álbum/artista/playlist) vía un `ShellRoute`. Si no hay nada sonando, no ocupa
/// espacio (`SizedBox.shrink`), de modo que en detalle el contenido usa toda la
/// altura.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key, this.safeAreaBottom = false});

  /// True cuando el mini queda pegado al borde inferior de la pantalla (vistas de
  /// detalle): respeta el inset del sistema. En el shell de pestañas es la barra
  /// de navegación la que ya aporta el SafeArea, así que va en false.
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Precarga las portadas de las pistas vecinas: al pasar de canción (desde
    // aquí, la notificación o el reproductor) la nueva ya está decodificada.
    escucharVecinas(context, ref);
    final NowPlaying np = ref.watch(nowPlayingProvider);
    if (!np.hasTrack) {
      return const SizedBox.shrink();
    }
    // El icono cast aparece si hay un PC EMPAREJADO (aunque aún no responda): así
    // no aparece de golpe al conectar y desplaza los controles. El selector ya
    // atenúa "Mi PC" mientras no está conectado.
    final bool puedeCast =
        ref.watch(conexionPcProvider) != ConexionEstado.sinEnlace;
    final Widget bar = Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: MiniPlayer(
        title: np.title,
        subtitle: np.isRemote
            ? tr('{artist} · en tu PC', {'artist': np.artist})
            : np.artist,
        cover: ref
            .watch(coverResolverProvider)
            .imageFor(np.coverPath, cacheWidth: coverCachePx(context, 44)),
        coverSeed: np.title,
        playing: np.playing,
        progress: np.progress,
        onTap: () => context.push('/player'),
        onToggle: () => ref.read(playbackActionsProvider).togglePlay(),
        onPrev: () => ref.read(playbackActionsProvider).prev(),
        onNext: () => ref.read(playbackActionsProvider).next(),
        onCast: puedeCast ? () => mostrarSelectorDestino(context, ref) : null,
      ),
    );
    return safeAreaBottom ? SafeArea(top: false, child: bar) : bar;
  }
}
