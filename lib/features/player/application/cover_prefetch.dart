import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../offline/application/image_resolver.dart';
import '../../remote_control/application/remote_controller.dart';
import '../../remote_control/data/remote_dtos.dart';
import 'playback.dart';
import 'player_controller.dart';

/// Versión diminuta de una portada para el fondo ambiente difuminado del
/// reproductor (misma clave de caché la use quien la use).
ImageProvider coverAmbiente(ImageProvider cover) {
  final ImageProvider base = cover is ResizeImage ? cover.imageProvider : cover;
  return ResizeImage(base, width: 64, allowUpscaling: false);
}

/// Rutas de portada de las pistas vecinas a la que suena (siguiente, anterior y
/// la de después), en el orden real de reproducción, local o del PC.
final Provider<List<String?>> vecinasCoverPathsProvider =
    Provider<List<String?>>((Ref ref) {
      if (ref.watch(playbackTargetProvider) == PlaybackTarget.remote) {
        final (List<RemotePistaDto> cola, int idx) = ref.watch(
          remoteControllerProvider.select(
            (RemoteState s) => (s.cola, s.estado.indiceCola),
          ),
        );
        return <String?>[
          for (final int d in const <int>[1, -1, 2])
            if (idx + d >= 0 && idx + d < cola.length) cola[idx + d].coverUrl,
        ];
      }
      final (List<Pista> queue, int idx, List<int> order) = ref.watch(
        playerControllerProvider.select(
          (PlayerState s) => (s.queue, s.index, s.order),
        ),
      );
      final List<int> o = ordenEfectivo(order, queue.length);
      final int slot = o.indexOf(idx);
      if (slot < 0) {
        return const <String?>[];
      }
      return <String?>[
        for (final int d in const <int>[1, -1, 2])
          if (slot + d >= 0 && slot + d < o.length)
            queue[o[slot + d]].coverPath,
      ];
    });

/// Precarga (decodifica en la caché de imágenes) las portadas de las pistas
/// vecinas en todos los tamaños en que se muestran (mini, reproductor, fondo y
/// vista Connect). Así, al pasar de canción la portada ya está en memoria y
/// aparece en el mismo frame, sin placeholder ni carga.
void precargarVecinas(
  BuildContext context,
  CoverResolver resolver,
  List<String?> paths,
) {
  final double ancho = MediaQuery.sizeOf(context).width;
  final List<int> tamanos = <int>[
    coverCachePx(context, 44),
    coverCachePx(context, ancho),
    coverCachePx(context, 300),
  ];
  for (final String? path in paths) {
    for (final int px in tamanos) {
      final ImageProvider? img = resolver.imageFor(path, cacheWidth: px);
      if (img == null) {
        break;
      }
      precacheImage(img, context, onError: (Object _, StackTrace? _) {});
      if (px == tamanos.first) {
        precacheImage(
          coverAmbiente(img),
          context,
          onError: (Object _, StackTrace? _) {},
        );
      }
    }
  }
}

List<String?> _ultimasPrecargadas = const <String?>[];

/// Engancha la precarga a un widget (llamar en `build`). Las vecinas cambian
/// junto con la pista, momento en que el widget ya se reconstruye; varias
/// pantallas pueden llamarla sin duplicar trabajo.
void escucharVecinas(BuildContext context, WidgetRef ref) {
  final List<String?> paths = ref.watch(vecinasCoverPathsProvider);
  if (listEquals(paths, _ultimasPrecargadas)) {
    return;
  }
  _ultimasPrecargadas = paths;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      precargarVecinas(context, ref.read(coverResolverProvider), paths);
    }
  });
}
