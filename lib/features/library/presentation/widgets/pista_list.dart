import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/aviso.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../../shared/widgets/track_row.dart';
import '../../../../shared/util/plural.dart';
import '../../../local_media/application/local_ids.dart';
import '../../../offline/application/download_providers.dart';
import '../../../offline/application/image_resolver.dart';
import '../../../offline/presentation/download_actions.dart';
import '../../../player/application/playback.dart';
import '../../../player/application/player_controller.dart';
import '../../../player/application/sleep_timer.dart';
import '../../../remote_control/application/remote_controller.dart';
import '../../../remote_control/presentation/destination_sheet.dart';
import '../../application/library_providers.dart';
import 'playlist_dialogs.dart';
import '../../../../core/i18n/i18n.dart';

/// Dependencias compartidas para construir filas de pista, recogidas **una vez
/// por lista** (no por fila) para que un `ListView.builder` no observe providers
/// en cada item.
typedef PistaRowDeps = ({
  Set<int> favoritas,
  Set<int> descargadas,
  int? currentId,
  CoverResolver resolver,
});

PistaRowDeps pistaRowDeps(WidgetRef ref) => (
  favoritas: ref.watch(favoritasIdsProvider).value ?? const <int>{},
  descargadas: ref.watch(descargadasProvider).value ?? const <int>{},
  currentId: ref.watch(
    playerControllerProvider.select((PlayerState s) => s.current?.id),
  ),
  resolver: ref.watch(coverResolverProvider),
);

/// Construye una fila de pista. Compartido por la lista no-scrollable [PistaList]
/// y por los `ListView.builder`/slivers de las pantallas grandes (pestaña Pistas,
/// búsqueda, álbum, artista, playlist) para no duplicar lógica de tap/estado.
Widget pistaRow(
  BuildContext context,
  WidgetRef ref,
  List<Pista> pistas,
  int i,
  PistaRowDeps deps, {
  bool comoColeccion = true,
  bool numbered = false,
  bool showCover = true,
  bool showAlbum = true,
  void Function(Pista)? onOpen,
}) {
  final Pista p = pistas[i];
  return TrackRow(
    title: p.titulo,
    // En la página del álbum el nombre del álbum sobra ().
    subtitle: p.albumTitulo == null || !showAlbum
        ? p.artistaNombre
        : '${p.artistaNombre} · ${p.albumTitulo}',
    cover: showCover
        ? deps.resolver.imageFor(
            p.coverPath,
            cacheWidth: coverCachePx(context, 48),
          )
        : null,
    coverSeed: p.id,
    durationSeconds: p.duracionSeg,
    index: numbered ? i + 1 : null,
    showCover: showCover,
    playing: p.id == deps.currentId,
    liked: deps.favoritas.contains(p.id),
    downloaded: deps.descargadas.contains(p.id),
    onTap: () {
      onOpen?.call(p);
      final PlaybackActions acciones = ref.read(playbackActionsProvider);
      if (comoColeccion) {
        acciones.reproducirColeccion(pistas, i);
      } else {
        acciones.reproducirPistaUnica(p);
      }
    },
    onMore: () => mostrarMenuPista(context, ref, p),
    swipeKey: ValueKey<String>('q-$i-${p.id}'),
    onSwipeQueue: () {
      ref.read(playbackActionsProvider).encolarColeccion(<Pista>[p]);
      avisar(context, tr('Añadida a la cola'));
    },
  );
}

/// Lista (no scrollable) de pistas: reproduce en su propia cola al tocar,
/// resalta la pista en curso y marca las favoritas. El llamador la envuelve en
/// un contexto scrollable.
class PistaList extends ConsumerWidget {
  const PistaList({
    super.key,
    required this.pistas,
    this.showCover = true,
    this.numbered = false,
    this.comoColeccion = true,
  });

  final List<Pista> pistas;
  final bool showCover;
  final bool numbered;

  /// Si true (álbum/playlist), tocar una pista encola toda la lista desde ahí;
  /// si false (búsqueda, pistas sueltas), reproduce solo esa pista.
  final bool comoColeccion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PistaRowDeps deps = pistaRowDeps(ref);
    return Column(
      children: <Widget>[
        for (int i = 0; i < pistas.length; i++)
          pistaRow(
            context,
            ref,
            pistas,
            i,
            deps,
            comoColeccion: comoColeccion,
            numbered: numbered,
            showCover: showCover,
          ),
      ],
    );
  }
}

/// Lista de pistas **lazy** y scrollable por sí misma (`ListView.builder`), para
/// colecciones grandes (pestaña Pistas, búsqueda). Recoge las dependencias una
/// sola vez y construye filas bajo demanda.
class PistaListView extends ConsumerWidget {
  const PistaListView({
    super.key,
    required this.pistas,
    this.comoColeccion = true,
    this.numbered = false,
    this.showCover = true,
    this.padding,
  });

  final List<Pista> pistas;
  final bool comoColeccion;
  final bool numbered;
  final bool showCover;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PistaRowDeps deps = pistaRowDeps(ref);
    return ListView.builder(
      padding: padding,
      itemCount: pistas.length,
      itemBuilder: (BuildContext context, int i) => pistaRow(
        context,
        ref,
        pistas,
        i,
        deps,
        comoColeccion: comoColeccion,
        numbered: numbered,
        showCover: showCover,
      ),
    );
  }
}

/// Variante **sliver** y lazy (`SliverList.builder`) para pantallas con cabecera
/// scrollable (detalle de álbum/artista/playlist), dentro de un `CustomScrollView`.
class PistaSliverList extends ConsumerWidget {
  const PistaSliverList({
    super.key,
    required this.pistas,
    this.comoColeccion = true,
    this.numbered = false,
    this.showCover = true,
    this.showAlbum = true,
    this.maxItems,
    this.onOpen,
  });

  final List<Pista> pistas;
  final bool comoColeccion;
  final bool numbered;
  final bool showCover;

  /// False en la página del álbum: la fila muestra solo el artista.
  final bool showAlbum;

  /// Si se indica, pinta solo las primeras N filas; tocar una sigue
  /// reproduciendo la colección COMPLETA desde ahí ("Populares" del artista).
  final int? maxItems;

  /// Efecto secundario al tocar una fila (p. ej. registrar en el historial).
  final void Function(Pista)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PistaRowDeps deps = pistaRowDeps(ref);
    final int? max = maxItems;
    return SliverList.builder(
      itemCount: max == null ? pistas.length : pistas.length.clamp(0, max),
      itemBuilder: (BuildContext context, int i) => pistaRow(
        context,
        ref,
        pistas,
        i,
        deps,
        comoColeccion: comoColeccion,
        numbered: numbered,
        showCover: showCover,
        showAlbum: showAlbum,
        onOpen: onOpen,
      ),
    );
  }
}

/// Acción extra opcional para el menú de pista (p. ej. "Quitar de la playlist").
typedef AccionMenuPista = ({String label, IconData icon, VoidCallback onTap});

/// Menú contextual de una pista: reproducir, cola, favorito, añadir a playlist,
/// ir al álbum/artista, descargar y (en remoto) acciones del PC. Con
/// [accionRemover] añade una opción destructiva al final (quitar de una lista).
Future<void> mostrarMenuPista(
  BuildContext context,
  WidgetRef ref,
  Pista pista, {
  AccionMenuPista? accionRemover,
  bool ajustesReproductor = false,
}) {
  final NbColors c = context.nb;
  final bool esFav = (ref.read(favoritasIdsProvider).value ?? const <int>{})
      .contains(pista.id);
  final bool descargada = (ref.read(descargadasProvider).value ?? const <int>{})
      .contains(pista.id);
  // Música local del teléfono: no se descarga (ya está en el dispositivo) ni se
  // manda al PC (jamás se relaciona con el Connect).
  final bool local = esIdLocal(pista.id);
  final bool enPc =
      ref.read(playbackTargetProvider) == PlaybackTarget.remote &&
      ref.read(remoteControllerProvider).conectado &&
      !local;
  return mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    pista.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NbFonts.display,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(AppIcons.play, color: c.text),
            title: Text(
              tr('Reproducir'),
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              ref.read(playbackActionsProvider).reproducirPistaUnica(pista);
            },
          ),
          // Cola local (en remoto, la cola es del PC: ver "Añadir a la cola del
          // PC" más abajo).
          if (!enPc) ...<Widget>[
            ListTile(
              leading: Icon(AppIcons.next, color: c.text),
              title: Text(
                tr('Reproducir a continuación'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref
                    .read(playerControllerProvider.notifier)
                    .reproducirACont(pista);
                avisar(context, tr('Se reproducirá a continuación'));
              },
            ),
            ListTile(
              leading: Icon(AppIcons.queue, color: c.text),
              title: Text(
                tr('Añadir a la cola'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(playerControllerProvider.notifier).addToQueue(pista);
                avisar(context, tr('Añadida a la cola'));
              },
            ),
          ],
          ListTile(
            leading: Icon(
              esFav ? AppIcons.heartFilled : AppIcons.heart,
              color: esFav ? c.accent : c.text,
            ),
            title: Text(
              esFav ? tr('Quitar de favoritos') : tr('Añadir a favoritos'),
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              ref.read(favoritesDaoProvider).setFavorita(pista.id, !esFav);
              avisar(
                context,
                esFav
                    ? tr('Quitada de Tus me gusta')
                    : tr('Añadida a Tus me gusta'),
              );
            },
          ),
          ListTile(
            leading: Icon(AppIcons.plus, color: c.text),
            title: Text(
              tr('Añadir a playlist'),
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              anadirAPlaylist(context, ref, pista.id);
            },
          ),
          if (pista.albumId != null)
            ListTile(
              leading: Icon(AppIcons.disc, color: c.text),
              title: Text(
                tr('Ir al álbum'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/album/${pista.albumId}');
              },
            ),
          if (pista.artistaId != null)
            ListTile(
              leading: Icon(AppIcons.user, color: c.text),
              title: Text(
                tr('Ir al artista'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/artist/${pista.artistaId}');
              },
            ),
          // La descarga es bajar la pista del PC para tenerla offline; una
          // pista local ya vive en el dispositivo, así que no se ofrece.
          if (!local)
            ListTile(
              leading: Icon(
                descargada ? AppIcons.downloadDone : AppIcons.download,
                color: descargada ? c.accent : c.text,
              ),
              title: Text(
                descargada ? tr('Quitar descarga') : tr('Descargar'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final DownloadQueueController q = ref.read(
                  downloadQueueProvider.notifier,
                );
                if (descargada) {
                  q.eliminar(pista.id);
                  avisar(context, tr('Descarga eliminada'));
                } else {
                  // Avisa si no hay PC emparejado / sin conexión, en vez de
                  // encolar en silencio algo que no se descargará.
                  encolarConAviso(context, ref, () => q.encolarPista(pista.id));
                }
              },
            ),
          if (enPc) ...<Widget>[
            ListTile(
              leading: Icon(AppIcons.cast, color: c.accent),
              title: Text(
                tr('Reproducir en el PC'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref
                    .read(remoteControllerProvider.notifier)
                    .reproducirPista(pista.id);
                avisar(context, tr('Reproduciendo en tu PC'));
              },
            ),
            ListTile(
              leading: Icon(AppIcons.plus, color: c.accent),
              title: Text(
                tr('Añadir a la cola del PC'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref
                    .read(remoteControllerProvider.notifier)
                    .encolarPista(pista.id);
                avisar(context, tr('Añadida a la cola del PC'));
              },
            ),
          ],
          if (ajustesReproductor) ...<Widget>[
            ListTile(
              leading: Icon(AppIcons.cast, color: c.text),
              title: Text(
                tr('Reproducir en…'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                mostrarSelectorDestino(context, ref);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.sliders, color: c.text),
              title: Text(
                tr('Velocidad'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _mostrarVelocidad(context, ref);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.clock, color: c.text),
              title: Text(
                tr('Temporizador de apagado'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              subtitle: _subtituloTemporizador(c, ref.read(sleepTimerProvider)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _mostrarTemporizador(context, ref);
              },
            ),
          ],
          if (accionRemover != null)
            ListTile(
              leading: Icon(accionRemover.icon, color: _menuDanger),
              title: Text(
                accionRemover.label,
                style: const TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: _menuDanger,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                accionRemover.onTap();
              },
            ),
        ],
      );
    },
  );
}

/// Rojo de acción destructiva en el menú de pista (convencional, fuera del tema).
const Color _menuDanger = Color(0xFFE5484D);

/// Menú de una colección (álbum/playlist): "Añadir a la cola" + acciones extra.
Future<void> mostrarMenuColeccion(
  BuildContext context,
  WidgetRef ref,
  List<Pista> pistas, {
  List<AccionMenuPista> extras = const <AccionMenuPista>[],
}) {
  return mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      final NbColors c = sheetContext.nb;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(AppIcons.queue, color: c.text),
            title: Text(
              tr('Añadir a la cola'),
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            onTap: pistas.isEmpty
                ? null
                : () {
                    Navigator.of(sheetContext).pop();
                    ref.read(playbackActionsProvider).encolarColeccion(pistas);
                    avisar(
                      context,
                      tr('{p0} añadidas a la cola', {
                        'p0': nPistas(pistas.length),
                      }),
                    );
                  },
          ),
          for (final AccionMenuPista a in extras)
            ListTile(
              leading: Icon(a.icon, color: c.text),
              title: Text(
                a.label,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                a.onTap();
              },
            ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

Widget _tituloHoja(NbColors c, String titulo) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
  child: Align(
    alignment: Alignment.centerLeft,
    child: Text(
      titulo,
      style: TextStyle(
        fontFamily: NbFonts.display,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: c.text,
      ),
    ),
  ),
);

String _fmtVel(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Hoja de velocidad de reproducción.
void _mostrarVelocidad(BuildContext context, WidgetRef ref) {
  final NbColors c = context.nb;
  mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      return Consumer(
        builder: (BuildContext ctx, WidgetRef r, _) {
          final double actual = r.watch(
            playerControllerProvider.select((PlayerState s) => s.velocidad),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _tituloHoja(c, tr('Velocidad')),
              for (final double v in const <double>[
                0.5,
                0.75,
                1.0,
                1.25,
                1.5,
                1.75,
                2.0,
              ])
                ListTile(
                  dense: true,
                  onTap: () {
                    r.read(playerControllerProvider.notifier).setVelocidad(v);
                    Navigator.of(sheetContext).pop();
                  },
                  leading: Icon(
                    (v - actual).abs() < 0.01 ? AppIcons.check : AppIcons.list,
                    color: (v - actual).abs() < 0.01 ? c.accent : c.text3,
                  ),
                  title: Text(
                    v == 1.0 ? tr('Normal (1×)') : '${_fmtVel(v)}×',
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontWeight: FontWeight.w600,
                      color: (v - actual).abs() < 0.01 ? c.accent : c.text,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      );
    },
  );
}

/// Hoja del temporizador de apagado.
void _mostrarTemporizador(BuildContext context, WidgetRef ref) {
  final NbColors c = context.nb;
  mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      return Consumer(
        builder: (BuildContext ctx, WidgetRef r, _) {
          final SleepTimerState? activo = r.watch(sleepTimerProvider);
          final Duration? resta = activo?.restante(DateTime.now());
          Widget opcion({
            required String label,
            required bool marcado,
            required VoidCallback onTap,
          }) => ListTile(
            dense: true,
            onTap: () {
              onTap();
              Navigator.of(sheetContext).pop();
            },
            leading: Icon(
              marcado ? AppIcons.check : AppIcons.clock,
              color: marcado ? c.accent : c.text3,
            ),
            title: Text(
              label,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontWeight: FontWeight.w600,
                color: marcado ? c.accent : c.text,
              ),
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _tituloHoja(
                c,
                activo == null
                    ? tr('Temporizador de apagado')
                    : activo.finPista
                    ? tr('Se pausará al terminar la canción')
                    : tr('Se pausará en {p0}', {
                        'p0': _minutosRestantes(resta!),
                      }),
              ),
              for (final int m in const <int>[5, 10, 15, 30, 45, 60])
                opcion(
                  label: '$m minutos',
                  marcado: activo?.minutos == m,
                  onTap: () {
                    r.read(sleepTimerProvider.notifier).activar(m);
                    avisar(context, tr('Se pausará en {m} minutos', {'m': m}));
                  },
                ),
              opcion(
                label: tr('Al terminar la canción'),
                marcado: activo?.finPista ?? false,
                onTap: () {
                  r.read(sleepTimerProvider.notifier).activarFinDePista();
                  avisar(context, tr('Se pausará al terminar la canción'));
                },
              ),
              if (activo != null)
                ListTile(
                  dense: true,
                  onTap: () {
                    r.read(sleepTimerProvider.notifier).cancelar();
                    Navigator.of(sheetContext).pop();
                    avisar(context, tr('Temporizador desactivado'));
                  },
                  leading: const Icon(AppIcons.close, color: _menuDanger),
                  title: Text(
                    tr('Desactivar'),
                    style: const TextStyle(
                      fontFamily: NbFonts.ui,
                      fontWeight: FontWeight.w600,
                      color: _menuDanger,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      );
    },
  );
}

Widget? _subtituloTemporizador(NbColors c, SleepTimerState? t) {
  if (t == null) {
    return null;
  }
  final String txt = t.finPista
      ? tr('Al terminar la canción')
      : tr('Quedan {p0}', {
          'p0': _minutosRestantes(t.restante(DateTime.now())!),
        });
  return Text(
    txt,
    style: TextStyle(
      fontFamily: NbFonts.ui,
      fontWeight: FontWeight.w600,
      color: c.accent,
    ),
  );
}

/// "4 min" / "menos de 1 min" para el tiempo que le queda al temporizador.
String _minutosRestantes(Duration d) {
  final int m = (d.inSeconds / 60).ceil();
  return m <= 1
      ? (d.inSeconds < 60 ? tr('menos de 1 min') : tr('1 min'))
      : '$m min';
}
