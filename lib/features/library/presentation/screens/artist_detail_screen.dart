import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../../shared/widgets/section_head.dart';
import '../../../../shared/widgets/sub_header.dart';
import '../../../../shared/util/plural.dart';
import '../../../offline/application/image_resolver.dart';
import '../../../player/application/playback.dart';
import '../../application/library_providers.dart';
import '../widgets/collection_actions.dart';
import '../widgets/library_cards.dart';
import '../widgets/pista_list.dart';
import '../../../../core/i18n/i18n.dart';

/// Detalle de artista: imagen, álbumes y pistas.
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artistId});

  final int artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final Artista? artista = ref.watch(artistaProvider(artistId)).value;
    final List<Album> albums =
        ref.watch(albumsDeArtistaProvider(artistId)).value ?? const <Album>[];
    final List<Pista> pistasRaw =
        ref.watch(pistasDeArtistaProvider(artistId)).value ?? const <Pista>[];
    // "Populares": las más reproducidas primero (), no alfabético.
    final Map<int, int> conteo =
        ref.watch(conteoPorPistaProvider).value ?? const <int, int>{};
    final List<Pista> pistas = pistasPorPopularidad(pistasRaw, conteo);

    final ImageProvider? img = ref
        .watch(coverResolverProvider)
        .imageFor(artista?.imagenPath, cacheWidth: coverCachePx(context, 160));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: MaxWidth(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Column(
                  children: <Widget>[
                    SubHeader(title: artista?.nombre ?? tr('Artista')),
                    Center(
                      child: ArtistAvatar(
                        image: img,
                        size: 160,
                        seed: artista?.id ?? artistId,
                        shadow: true,
                        animated: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        artista?.nombre ?? '',
                        style: TextStyle(
                          fontFamily: NbFonts.display,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${plural(albums.length, tr('álbum'), tr('álbumes'))} · ${nPistas(pistas.length)}',
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.text2,
                        ),
                      ),
                    ),
                    if (pistas.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: () => ref
                                .read(playbackActionsProvider)
                                .reproducirColeccion(pistas, 0),
                            style: FilledButton.styleFrom(
                              backgroundColor: c.accent,
                              foregroundColor: c.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            icon: Icon(AppIcons.play, color: c.ink, size: 22),
                            label: Text(
                              tr('Reproducir'),
                              style: TextStyle(
                                fontFamily: NbFonts.ui,
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                              ),
                            ),
                          ),
                          ShuffleCollectionButton(pistas: pistas),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                      child: SectionHead(title: tr('Populares')),
                    ),
                  ],
                ),
              ),
              // primero "Populares" y después la discografía.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                sliver: _PopularesSliver(pistas: pistas),
              ),
              if (albums.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 28),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                          child: SectionHead(title: tr('Álbumes')),
                        ),
                        SizedBox(
                          height: 196,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            itemCount: albums.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 14),
                            itemBuilder: (BuildContext context, int i) =>
                                SizedBox(
                                  width: 148,
                                  child: AlbumCard(album: albums[i]),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Populares" del artista: las 5 más escuchadas () con "Ver todas"
/// para desplegar el resto. Tocar una fila reproduce la lista completa.
class _PopularesSliver extends StatefulWidget {
  const _PopularesSliver({required this.pistas});

  final List<Pista> pistas;

  static const int _visibles = 5;

  @override
  State<_PopularesSliver> createState() => _PopularesSliverState();
}

class _PopularesSliverState extends State<_PopularesSliver> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final int total = widget.pistas.length;
    final bool plegable = total > _PopularesSliver._visibles;
    return SliverMainAxisGroup(
      slivers: <Widget>[
        PistaSliverList(
          pistas: widget.pistas,
          maxItems: _expandido ? null : _PopularesSliver._visibles,
        ),
        if (plegable)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expandido = !_expandido),
                child: Text(
                  _expandido
                      ? tr('Ver menos')
                      : tr('Ver todas ({total})', {'total': total}),
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w700,
                    color: c.text2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
