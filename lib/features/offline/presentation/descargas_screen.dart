import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/search/fuzzy.dart';
import '../../../data/db/daos/assets_dao.dart';
import '../../../data/db/daos/downloads_dao.dart';
import '../../../data/db/daos/sync_state_dao.dart';
import '../../../data/db/database.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/placeholder_body.dart';
import '../../../shared/widgets/sub_header.dart';
import '../../library/application/library_providers.dart';
import '../application/download_providers.dart';
import '../data/download_repository.dart';
import '../data/offline_store.dart';
import 'download_actions.dart';
import '../../../core/i18n/i18n.dart';

/// Puntuación de la pista frente a la búsqueda difusa (0 = no coincide; se
/// exige ≥ 0.4). Resiliente a typos/acentos (reusa `fuzzy.dart`).
double _puntuarDescarga(Pista? p, String queryNorm) {
  if (p == null) {
    return 0;
  }
  final String t = normalizar(p.titulo);
  final String a = normalizar(p.artistaNombre);
  final double s = <double>[
    puntuarTexto(queryNorm, t, tokenizar(t)),
    puntuarTexto(queryNorm, a, tokenizar(a)) * 0.9,
  ].reduce((double x, double y) => x > y ? x : y);
  return s >= 0.4 ? s : 0;
}

/// Gestión de la descarga offline: contadores reales (N de M), desglose por
/// categoría, espacio en disco, playlists guardadas y la lista de pistas, con un
/// buscador resiliente para encontrar/borrar sin salir de la pantalla.
class DescargasScreen extends ConsumerStatefulWidget {
  const DescargasScreen({super.key});

  @override
  ConsumerState<DescargasScreen> createState() => _DescargasScreenState();
}

class _DescargasScreenState extends ConsumerState<DescargasScreen> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 90), () {
      if (mounted) {
        setState(() => _q = v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final List<DescargaAudio> descargas =
        ref.watch(descargasProvider).value ?? const <DescargaAudio>[];
    final Map<int, Pista> porId = <int, Pista>{
      for (final Pista p in ref.watch(pistasProvider).value ?? const <Pista>[])
        p.id: p,
    };
    final DownloadQueueState queue = ref.watch(downloadQueueProvider);

    final String qn = normalizar(_q);
    // Con búsqueda: solo las que coinciden, de más a menos relevante, para que
    // la coincidencia exacta no quede enterrada en el orden alfabético.
    final List<DescargaAudio> filtradas;
    if (qn.isEmpty) {
      filtradas = descargas;
    } else {
      final List<({double s, DescargaAudio d})> puntuadas =
          <({double s, DescargaAudio d})>[
            for (final DescargaAudio d in descargas)
              (s: _puntuarDescarga(porId[d.pistaId], qn), d: d),
          ]..removeWhere((({double s, DescargaAudio d}) e) => e.s <= 0);
      puntuadas.sort(
        (({double s, DescargaAudio d}) a, ({double s, DescargaAudio d}) b) =>
            b.s.compareTo(a.s),
      );
      filtradas = <DescargaAudio>[
        for (final ({double s, DescargaAudio d}) e in puntuadas) e.d,
      ];
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: <Widget>[
            SliverToBoxAdapter(child: SubHeader(title: tr('Descargas'))),
            // Buscando: se pliegan resumen y acciones para que los resultados
            // queden justo bajo el buscador (y no tapados por el teclado).
            if (qn.isEmpty) ...<Widget>[
              const SliverToBoxAdapter(child: _Resumen()),
              if (queue.restantes > 0)
                SliverToBoxAdapter(child: _DownloadCounter(queue: queue)),
              const SliverToBoxAdapter(child: _Acciones()),
            ],
            if (descargas.isNotEmpty)
              SliverToBoxAdapter(
                child: _Buscador(controller: _ctrl, onChanged: _onChanged),
              ),
            SliverToBoxAdapter(
              child: _PlaylistsGuardadasSection(queryNorm: qn),
            ),
            if (descargas.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: PlaceholderBody(
                  icon: AppIcons.download,
                  title: tr('Sin descargas'),
                  subtitle: tr(
                    'Descarga pistas, álbumes o playlists para escucharlas sin conexión.',
                  ),
                ),
              )
            else if (filtradas.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Text(
                    tr('Sin resultados para "{_q}".', {'_q': _q}),
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 14,
                      color: c.text3,
                    ),
                  ),
                ),
              )
            else ...<Widget>[
              SliverToBoxAdapter(child: _SeccionTitulo(tr('Pistas'))),
              SliverList.builder(
                itemCount: filtradas.length,
                itemBuilder: (BuildContext context, int i) {
                  final DescargaAudio d = filtradas[i];
                  return _DescargaTile(
                    descarga: d,
                    pista: porId[d.pistaId],
                    progreso: d.pistaId == queue.actual ? queue.progreso : null,
                    onEliminar: () => ref
                        .read(downloadQueueProvider.notifier)
                        .eliminar(d.pistaId),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Buscador resiliente (difuso) de la pantalla de Descargas.
class _Buscador extends StatelessWidget {
  const _Buscador({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontFamily: NbFonts.ui, fontSize: 14.5, color: c.text),
        decoration: InputDecoration(
          isDense: true,
          hintText: tr('Buscar en tus descargas'),
          hintStyle: TextStyle(color: c.text3, fontFamily: NbFonts.ui),
          prefixIcon: Icon(AppIcons.search, color: c.text3, size: 19),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(AppIcons.close, color: c.text3, size: 17),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: c.bg2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
        ),
      ),
    );
  }
}

/// Tarjeta de resumen con los contadores fijos (N de M) y el desglose por
/// categoría + espacio en disco. Datos reactivos de la BD (no del lote en curso).
class _Resumen extends ConsumerWidget {
  const _Resumen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ResumenDescargas r =
        ref.watch(resumenDescargasProvider).value ?? const ResumenDescargas();
    final int total = ref.watch(totalPistasProvider).value ?? 0;
    final ConteoAsset covers =
        ref.watch(conteoCoversProvider).value ?? const ConteoAsset();
    final ConteoAsset artistas =
        ref.watch(conteoArtistasProvider).value ?? const ConteoAsset();
    final EspacioOffline espacio =
        ref.watch(espacioOfflineProvider).value ?? const EspacioOffline();

    final int fallidas = r.totalFallidas + covers.failed + artistas.failed;
    final double? progreso = total > 0
        ? (r.audioDone / total).clamp(0.0, 1.0)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  tr('Pistas descargadas'),
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const Spacer(),
                Text(
                  '${r.audioDone} de $total',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 6,
                backgroundColor: c.line2,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Chip(
                  icon: AppIcons.disc,
                  label: tr('Portadas'),
                  n: covers.done,
                ),
                _Chip(
                  icon: AppIcons.user,
                  label: tr('Artistas'),
                  n: artistas.done,
                ),
                _Chip(
                  icon: AppIcons.note,
                  label: tr('Letras'),
                  n: r.lyricsDone,
                ),
                _Chip(icon: AppIcons.mic, label: tr('Karaoke'), n: r.stemsDone),
                if (fallidas > 0)
                  _Chip(
                    icon: AppIcons.close,
                    label: tr('Con error'),
                    n: fallidas,
                    color: const Color(0xFFFF6B6B),
                  ),
              ],
            ),
            if (espacio.total > 0) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                tr(
                  'Ocupado: {p0}  ·  audio {p1} · karaoke {p2} · imágenes {p3}',
                  {
                    'p0': _formatBytes(espacio.total),
                    'p1': _formatBytes(espacio.audio),
                    'p2': _formatBytes(espacio.stems),
                    'p3': _formatBytes(espacio.covers + espacio.artists),
                  },
                ),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 11.5,
                  color: c.text3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.n,
    this.color,
  });

  final IconData icon;
  final String label;
  final int n;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Color col = color ?? c.text2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: col),
          const SizedBox(width: 6),
          Text(
            '$label $n',
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Acciones globales: reintentar fallidas y el espejo offline completo.
class _Acciones extends ConsumerWidget {
  const _Acciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ResumenDescargas r =
        ref.watch(resumenDescargasProvider).value ?? const ResumenDescargas();
    final ConteoAsset covers =
        ref.watch(conteoCoversProvider).value ?? const ConteoAsset();
    final ConteoAsset artistas =
        ref.watch(conteoArtistasProvider).value ?? const ConteoAsset();
    final int fallidas = r.totalFallidas + covers.failed + artistas.failed;
    final bool descargarTodo = ref.watch(descargarTodoProvider).value ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
      child: Column(
        children: <Widget>[
          if (fallidas > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(downloadQueueProvider.notifier)
                      .reintentarFallidas(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accent,
                    side: BorderSide(color: c.line2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(AppIcons.refresh, size: 18, color: c.accent),
                  label: Text(
                    fallidas == 1
                        ? tr('Reintentar 1 descarga con error')
                        : tr('Reintentar {n} descargas con error', {
                            'n': fallidas,
                          }),
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.line2),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        tr('Descargar todo automáticamente'),
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descargarTodo
                            ? tr(
                                'Activado: cada sincronización descarga toda tu biblioteca para tenerla offline.',
                              )
                            : tr(
                                'Desactivado: descargas solo lo que elijas. Actívalo para un espejo offline completo.',
                              ),
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 11.5,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: descargarTodo,
                  activeThumbColor: c.accent,
                  onChanged: (bool v) async {
                    // La preferencia se guarda siempre (cada sync la honra). Al
                    // activar, se intenta encolar ya, avisando si no hay PC.
                    await ref
                        .read(syncStateDaoProvider)
                        .setValor(SyncStateDao.kDescargarTodo, v ? '1' : '0');
                    if (v && context.mounted) {
                      await encolarConAviso(
                        context,
                        ref,
                        () => ref
                            .read(downloadQueueProvider.notifier)
                            .encolarTodo(),
                        exito: tr('Descargando toda tu biblioteca'),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección de playlists guardadas con su progreso de descarga (N/total).
/// Filtra por el buscador (difuso, resiliente) cuando hay query.
class _PlaylistsGuardadasSection extends ConsumerWidget {
  const _PlaylistsGuardadasSection({required this.queryNorm});

  final String queryNorm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Playlist> base = ref.watch(playlistsGuardadasProvider);
    final List<Playlist> guardadas = queryNorm.isEmpty
        ? base
        : <Playlist>[
            for (final Playlist p in base)
              if (puntuarTexto(
                    queryNorm,
                    normalizar(p.nombre),
                    tokenizar(normalizar(p.nombre)),
                  ) >=
                  0.4)
                p,
          ];
    if (guardadas.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SeccionTitulo(tr('Playlists guardadas')),
        for (final Playlist pl in guardadas)
          _PlaylistGuardadaTile(playlist: pl),
      ],
    );
  }
}

class _PlaylistGuardadaTile extends ConsumerWidget {
  const _PlaylistGuardadaTile({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistProvider(playlist.id)).value ??
        const <Pista>[];
    final Set<int> completas = ref.watch(pistasCompletasProvider);
    final int total = pistas.length;
    final int hechas = pistas
        .where((Pista p) => completas.contains(p.id))
        .length;
    final bool listo = total > 0 && hechas >= total;

    return ListTile(
      leading: Icon(
        listo ? AppIcons.downloadDone : AppIcons.downloading,
        color: c.accent,
      ),
      title: Text(
        playlist.nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        listo
            ? tr('{total} pistas · al día', {'total': total})
            : tr('Descargando · {hechas}/{total}', {
                'hechas': hechas,
                'total': total,
              }),
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text2,
        ),
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: c.text3,
        ),
      ),
    );
  }
}

/// Contador en vivo del lote de descargas: cuántas van, cuántas faltan, barra
/// de progreso global y ETA estimada. Visible mientras hay pistas en cola.
class _DownloadCounter extends StatelessWidget {
  const _DownloadCounter({required this.queue});

  final DownloadQueueState queue;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Duration? eta = queue.eta;
    final String faltan = queue.restantes == 1
        ? tr('Falta 1 pista')
        : tr('Faltan {restantes} pistas', {'restantes': queue.restantes});
    final String detalle = eta != null
        ? '$faltan · ~${_formatEta(eta)}'
        : faltan;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(AppIcons.downloading, color: c.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  tr('Descargando'),
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const Spacer(),
                Text(
                  '${queue.completados}/${queue.totalLote}',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: queue.progresoLote,
                minHeight: 6,
                backgroundColor: c.line2,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 12.5,
                color: c.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formato compacto de la ETA: "45 s", "3 min", "1 h 5 min".
  static String _formatEta(Duration d) {
    if (d.inSeconds < 60) {
      final int s = d.inSeconds;
      return s <= 1 ? '1 s' : '$s s';
    }
    if (d.inMinutes < 60) {
      return '${d.inMinutes} min';
    }
    final int h = d.inHours;
    final int m = d.inMinutes % 60;
    return m == 0 ? '$h h' : tr('{h} h {m} min', {'h': h, 'm': m});
  }
}

class _DescargaTile extends StatelessWidget {
  const _DescargaTile({
    required this.descarga,
    required this.pista,
    required this.progreso,
    required this.onEliminar,
  });

  final DescargaAudio descarga;
  final Pista? pista;
  final double? progreso;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final (
      IconData icon,
      Color color,
      String label,
    ) = switch (descarga.estado) {
      DownloadEstado.done => (
        AppIcons.downloadDone,
        c.accent,
        _etiquetaDone(descarga),
      ),
      DownloadEstado.downloading => (
        AppIcons.downloading,
        c.accent,
        progreso != null
            ? tr('Descargando {p0}%', {'p0': (progreso! * 100).round()})
            : tr('Descargando…'),
      ),
      DownloadEstado.failed => (
        AppIcons.close,
        const Color(0xFFFF6B6B),
        tr('Falló'),
      ),
      DownloadEstado.unavailable => (
        AppIcons.close,
        c.text3,
        tr('No disponible en el PC'),
      ),
      _ => (AppIcons.download, c.text3, tr('En cola')),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        pista?.titulo ?? tr('Pista {pistaId}', {'pistaId': descarga.pistaId}),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        pista != null ? '${pista!.artistaNombre} · $label' : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text2,
        ),
      ),
      trailing: IconButton(
        onPressed: onEliminar,
        icon: Icon(AppIcons.trash, color: c.text3, size: 20),
      ),
    );
  }

  /// Etiqueta del estado `done` enriquecida con karaoke y verificación de hash.
  static String _etiquetaDone(DescargaAudio d) {
    if (d.stemsEstado == DownloadEstado.done) {
      return tr('Descargada · karaoke');
    }
    if (d.hashOk == false) {
      return tr('Descargada · sin verificar');
    }
    return tr('Descargada');
  }
}

/// Formato compacto de tamaño en disco.
String _formatBytes(int b) {
  if (b < 1024) {
    return '$b B';
  }
  const List<String> u = <String>['KB', 'MB', 'GB', 'TB'];
  double v = b / 1024;
  int i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 10 ? 0 : 1)} ${u[i]}';
}
