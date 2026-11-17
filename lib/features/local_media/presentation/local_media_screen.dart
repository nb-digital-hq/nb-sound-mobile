import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/search/fuzzy.dart';
import '../../../data/db/database.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/cover.dart';
import '../../../shared/widgets/sub_header.dart';
import '../../offline/application/image_resolver.dart';
import '../application/local_ids.dart';
import '../application/local_media_providers.dart';
import '../application/local_media_service.dart';
import '../../../core/i18n/i18n.dart';

/// Pantalla de **Música local**: detecta y gestiona la música guardada en el
/// teléfono (MediaStore). Permite revisar (manual o automático), ocultar pistas
/// sueltas o todas (sin borrarlas del teléfono) y revelarlas de nuevo. La música
/// local nunca se relaciona con el PC/Connect.
class LocalMediaScreen extends ConsumerWidget {
  const LocalMediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final EstadoLocalMedia estado = ref.watch(localMediaControllerProvider);
    final LocalMediaController ctrl = ref.read(
      localMediaControllerProvider.notifier,
    );
    final int conteo = ref.watch(conteoLocalesProvider).value ?? 0;
    final List<LocalOcultaRow> ocultas =
        ref.watch(ocultasLocalesProvider).value ?? const <LocalOcultaRow>[];
    final bool escaneando = estado.fase == FaseEscaneo.escaneando;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 36),
          children: <Widget>[
            SubHeader(title: tr('Música local')),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
              child: Text(
                tr(
                  'La música guardada en este teléfono se detecta automáticamente (ignora notas de voz y sonidos de otras apps) y vive solo en el dispositivo: nunca se envía al PC.',
                ),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 13.5,
                  height: 1.4,
                  color: c.text2,
                ),
              ),
            ),
            _EstadoCard(estado: estado, conteo: conteo),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (escaneando || estado.ocultaGlobal)
                      ? null
                      : () => ctrl.escanear(),
                  icon: escaneando
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(c.ink),
                          ),
                        )
                      : const Icon(AppIcons.refresh, size: 20),
                  label: Text(
                    escaneando
                        ? tr('Revisando…')
                        : tr('Revisar el dispositivo'),
                    style: const TextStyle(
                      fontFamily: NbFonts.ui,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            if (estado.fase == FaseEscaneo.sinPermiso &&
                estado.permiso == PermisoAudio.denegadoPermanente)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
                child: TextButton(
                  onPressed: openAppSettings,
                  child: Text(tr('Abrir ajustes de la app')),
                ),
              ),
            _SwitchTile(
              titulo: tr('Revisión automática'),
              subtitulo: estado.ocultaGlobal
                  ? tr('En pausa mientras la música local está oculta.')
                  : estado.auto
                  ? tr(
                      'Busca música nueva al abrir la app y tras cada sincronización.',
                    )
                  : tr(
                      'Desactivada: solo se revisa al tocar "Revisar el dispositivo".',
                    ),
              valor: estado.auto,
              onChanged: ctrl.setAuto,
            ),
            _SwitchTile(
              titulo: tr('Ocultar toda la música local'),
              subtitulo: estado.ocultaGlobal
                  ? tr(
                      'Oculta: no aparece en la app (sigue guardada en el teléfono).',
                    )
                  : tr(
                      'Quita toda la música local de la app sin borrarla del teléfono.',
                    ),
              valor: estado.ocultaGlobal,
              onChanged: escaneando ? null : ctrl.setOcultarTodas,
            ),
            if (!estado.ocultaGlobal) ...<Widget>[
              _SeccionTitulo(tr('En tu biblioteca')),
              if (conteo == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                  child: Text(
                    tr('No hay música local indexada todavía.'),
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 13,
                      color: c.text3,
                    ),
                  ),
                )
              else
                const _ListaLocales(),
            ],
            if (ocultas.isNotEmpty) ...<Widget>[
              _SeccionTitulo(
                tr('Ocultas ({length})', {'length': ocultas.length}),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                child: TextButton.icon(
                  onPressed: () => ctrl.mostrarTodasOcultas(),
                  icon: const Icon(AppIcons.show, size: 18),
                  label: Text(tr('Mostrar todas')),
                ),
              ),
              for (final LocalOcultaRow o in ocultas)
                ListTile(
                  dense: true,
                  leading: Icon(AppIcons.hide, color: c.text3),
                  title: Text(
                    o.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text2,
                    ),
                  ),
                  subtitle: o.artista == null
                      ? null
                      : Text(
                          o.artista!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: TextButton(
                    onPressed: () => ctrl.mostrarPista(o.mediaId),
                    child: Text(tr('Mostrar')),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Filtra las pistas locales por búsqueda difusa (tolerante a typos/símbolos,
/// igual que Buscar/Biblioteca). Función pura para poder testearla.
List<Pista> filtrarLocales(List<Pista> pistas, String query) {
  final String q = normalizar(query);
  if (q.isEmpty) {
    return pistas;
  }
  final List<({double score, Pista pista})> scored =
      <({double score, Pista pista})>[];
  for (final Pista p in pistas) {
    final String n = normalizar('${p.titulo} ${p.artistaNombre}');
    final double s = puntuarTexto(q, n, tokenizar(n));
    // Umbral indulgente (como Buscar): deja pasar typos y consultas multipalabra
    // por subsecuencia (0.35), pero descarta lo no relacionado (0).
    if (s > 0.3) {
      scored.add((score: s, pista: p));
    }
  }
  scored.sort(
    (({double score, Pista pista}) a, ({double score, Pista pista}) b) =>
        b.score.compareTo(a.score),
  );
  return <Pista>[for (final ({double score, Pista pista}) e in scored) e.pista];
}

/// Lista reactiva de las pistas locales, con **buscador difuso** y acción de
/// ocultar por pista.
class _ListaLocales extends ConsumerStatefulWidget {
  const _ListaLocales();

  @override
  ConsumerState<_ListaLocales> createState() => _ListaLocalesState();
}

class _ListaLocalesState extends ConsumerState<_ListaLocales> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

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
        setState(() => _query = v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final List<Pista> pistas =
        ref.watch(pistasLocalesProvider).value ?? const <Pista>[];
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final LocalMediaController ctrl = ref.read(
      localMediaControllerProvider.notifier,
    );
    final List<Pista> filtradas = filtrarLocales(pistas, _query);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
          child: TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            style: TextStyle(fontFamily: NbFonts.ui, color: c.text),
            decoration: InputDecoration(
              isDense: true,
              hintText: tr('Buscar en tu música local'),
              hintStyle: TextStyle(fontFamily: NbFonts.ui, color: c.text3),
              prefixIcon: Icon(AppIcons.search, color: c.text3, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(AppIcons.close, color: c.text3, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        _onChanged('');
                      },
                    ),
              filled: true,
              fillColor: c.bg2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.line2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.line2),
              ),
            ),
          ),
        ),
        if (filtradas.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
            child: Text(
              tr('Sin resultados'),
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 13,
                color: c.text3,
              ),
            ),
          )
        else
          for (final Pista p in filtradas)
            ListTile(
              dense: true,
              leading: Cover(
                image: resolver.imageFor(
                  p.coverPath,
                  cacheWidth: coverCachePx(context, 44),
                ),
                size: 44,
                radius: 8,
                shadow: false,
                kind: CoverKind.track,
                coverSeed: p.id,
              ),
              title: Text(
                p.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              subtitle: Text(
                p.artistaNombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 12.5,
                  color: c.text3,
                ),
              ),
              trailing: IconButton(
                tooltip: tr('Quitar de la app'),
                icon: Icon(AppIcons.hide, color: c.text3, size: 20),
                onPressed: () => ctrl.ocultarPista(
                  mediaStoreIdDePista(p.id),
                  p.titulo,
                  p.artistaNombre,
                ),
              ),
            ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 16, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  titulo,
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
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
            value: valor,
            activeThumbColor: c.accent,
            onChanged: onChanged,
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
      child: Text(
        texto,
        style: TextStyle(
          fontFamily: NbFonts.display,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: c.text,
        ),
      ),
    );
  }
}

class _EstadoCard extends StatelessWidget {
  const _EstadoCard({required this.estado, required this.conteo});
  final EstadoLocalMedia estado;
  final int conteo;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    // Oculta manda: explica por qué "Revisar" está deshabilitado y la revisión
    // automática no corre.
    final (
      IconData icon,
      String texto,
    ) = estado.ocultaGlobal && estado.fase != FaseEscaneo.escaneando
        ? (
            AppIcons.note,
            tr(
              'La música local está oculta. Desactiva "Ocultar toda la música local" para revisarla y verla en la app.',
            ),
          )
        : switch (estado.fase) {
            FaseEscaneo.inactivo => (
              AppIcons.note,
              conteo > 0
                  ? tr('{conteo} pistas locales en tu biblioteca', {
                      'conteo': conteo,
                    })
                  : tr('Aún no has revisado la música de este dispositivo.'),
            ),
            FaseEscaneo.escaneando => (
              AppIcons.downloading,
              tr('Revisando música…'),
            ),
            FaseEscaneo.listo => (
              AppIcons.check,
              estado.ocultaGlobal
                  ? tr('Música local oculta')
                  : estado.duplicadosQuitados > 0
                  ? tr(
                      '{conteo} pistas locales en tu biblioteca · {d} duplicadas con el PC omitidas',
                      {'conteo': conteo, 'd': estado.duplicadosQuitados},
                    )
                  : tr('{conteo} pistas locales en tu biblioteca', {
                      'conteo': conteo,
                    }),
            ),
            FaseEscaneo.sinPermiso => (
              AppIcons.bell,
              tr('Necesito permiso para leer la música del dispositivo.'),
            ),
            FaseEscaneo.error => (
              AppIcons.bell,
              tr('No se pudo leer la música del dispositivo.'),
            ),
          };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line2),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: c.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 13.5,
                height: 1.35,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
