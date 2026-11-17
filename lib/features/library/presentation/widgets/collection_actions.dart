import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/aviso.dart';
import '../../../player/application/playback.dart';
import '../../../player/application/player_controller.dart';
import '../../../../core/i18n/i18n.dart';

/// Botón "Reproducir en aleatorio" de una colección (álbum/artista/playlist),
/// **con estado coherente**: el icono se ilumina en acento cuando el aleatorio
/// global está activo (mismo estado que respeta el reproductor), de modo que se ve
/// si está encendido o no — el defecto anterior era que en unas vistas reflejaba
/// el estado y en otras siempre salía apagado. Al tocarlo reproduce la colección
/// barajada (deja el aleatorio encendido) y da feedback de lo que pasó.
class ShuffleCollectionButton extends ConsumerWidget {
  const ShuffleCollectionButton({super.key, required this.pistas});

  final List<Pista> pistas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final bool shuffle = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.shuffle),
    );
    return IconButton(
      tooltip: shuffle
          ? tr('Aleatorio activado')
          : tr('Reproducir en aleatorio'),
      onPressed: pistas.isEmpty
          ? null
          : () async {
              await ref
                  .read(playbackActionsProvider)
                  .reproducirColeccionAleatorio(pistas);
              if (context.mounted) {
                avisar(context, tr('Reproducción aleatoria activada'));
              }
            },
      icon: Icon(
        AppIcons.shuffle,
        // Color explícito: sin canciones hay que atenuarlo a mano.
        color: pistas.isEmpty ? c.text3 : (shuffle ? c.accent : c.text2),
      ),
    );
  }
}
