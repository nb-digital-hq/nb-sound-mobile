import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/util/responsive.dart';
import '../../player/application/player_controller.dart';
import '../../remote_control/application/remote_controller.dart';
import '../application/lyrics_providers.dart';
import '../data/lyrics_models.dart';
import '../../../core/i18n/i18n.dart';

/// Vista de letra: consume `/lyrics` (cache-first) y muestra la letra
/// sincronizada con la línea activa resaltada y auto-scroll; cae a texto plano,
/// y a estados claros cuando no hay letra o no hay PC. Incluye el toggle Karaoke.
class LetraView extends ConsumerWidget {
  const LetraView({super.key, required this.pistaId, this.remota = false});

  final int pistaId;

  /// True en Connect ("Mi PC"): sincroniza con la posición que publica el PC y
  /// tocar una línea salta en el PC.
  final bool remota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final AsyncValue<Lyrics?> lyricsAsync = ref.watch(lyricsProvider(pistaId));
    // `skipLoadingOnReload`: cuando el provider se re-evalúa (p. ej. al
    // conectar/desconectar el PC) se sigue mostrando la letra ya cargada en vez
    // de pasar por el spinner. Ese paso por "cargando" destruía la lista y la
    // recreaba arriba del todo: la letra "subía al inicio de la nada" y solo
    // volvía a bajar con el siguiente cambio de línea.
    return lyricsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
      error: (Object _, StackTrace _) =>
          _message(c, tr('No se pudo cargar la letra.')),
      data: (Lyrics? lyrics) {
        if (lyrics == null) {
          return _message(
            c,
            tr('Conéctate a tu PC para ver la letra de esta pista.'),
          );
        }
        if (lyrics.hasSynced) {
          // Una lista por pista: al cambiar de canción empieza de cero, pero
          // para la misma pista el estado (scroll) sobrevive a las recargas.
          return LetraSincronizada(
            key: ValueKey<int>(pistaId),
            lyrics: lyrics,
            remota: remota,
          );
        }
        // Solo se muestra la letra sincronizada (con auto-scroll). La letra
        // plana se descarga y conserva en disco, pero no se muestra: igual
        // que el PC, sin marcas de tiempo no hay experiencia de karaoke.
        return _message(
          c,
          tr('¡Lo sentimos! No encontramos la letra de esta canción.'),
        );
      },
    );
  }

  Widget _message(NbColors c, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: NbFonts.display,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.5,
            color: c.text2,
          ),
        ),
      ),
    );
  }
}

/// Lista de la letra sincronizada: resalta la línea activa y la mantiene
/// centrada. Solo se reconstruye cuando **cambia la línea activa** (no en cada
/// tick de posición).
class LetraSincronizada extends ConsumerStatefulWidget {
  const LetraSincronizada({
    super.key,
    required this.lyrics,
    this.remota = false,
  });

  final Lyrics lyrics;
  final bool remota;

  @override
  ConsumerState<LetraSincronizada> createState() => _LetraSincronizadaState();
}

class _LetraSincronizadaState extends ConsumerState<LetraSincronizada> {
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    vertical: 24,
    horizontal: 8,
  );

  /// Se crea en el primer build, ya colocado sobre la línea activa (sin animar
  /// desde arriba cada vez que se abre la letra).
  ScrollController? _scroll;
  int _lastActive = -1;
  double _lastViewport = -1;
  double _itemExtent = 58;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  /// Offset que centra la línea [index] en un viewport de alto [viewport].
  double _offsetPara(int index, double viewport) {
    final double total =
        widget.lyrics.synced.length * _itemExtent + _padding.vertical;
    final double max = math.max(0, total - viewport);
    final double target =
        (index * _itemExtent) - (viewport / 2) + (_itemExtent / 2);
    return target.clamp(0.0, max);
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Lyrics lyrics = widget.lyrics;
    final int active = widget.remota
        ? ref.watch(
            remoteControllerProvider.select(
              (RemoteState s) => lyrics.activeIndex(
                Duration(milliseconds: (s.estado.posicionSeg * 1000).round()),
              ),
            ),
          )
        : ref.watch(
            playerControllerProvider.select(
              (PlayerState s) => lyrics.activeIndex(s.position),
            ),
          );
    // Escala de letra por tamaño de pantalla (en grande, mucho mayor).
    final double escala = switch (context.bp) {
      Bp.compact => 1.0,
      Bp.medium => 1.5,
      Bp.expanded => 2.0,
    };
    _itemExtent = 58 * escala;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewport = constraints.maxHeight;
        final ScrollController scroll = _scroll ??= ScrollController(
          initialScrollOffset: active < 0 ? 0 : _offsetPara(active, viewport),
        );
        if (_lastActive == -1 && _lastViewport < 0) {
          // Primer build: la lista ya nace en su sitio.
          _lastActive = active;
          _lastViewport = viewport;
        } else if (viewport != _lastViewport) {
          // Cambió el alto (pantalla completa, giro): recoloca sin animar.
          _lastViewport = viewport;
          _lastActive = active;
          _trasElFrame(() => _irA(active, animar: false));
        } else if (active != _lastActive) {
          _lastActive = active;
          _trasElFrame(() => _irA(active, animar: true));
        }
        final double anchoLinea = math.max(
          0,
          constraints.maxWidth - _padding.horizontal - 12,
        );
        return ListView.builder(
          controller: scroll,
          itemExtent: _itemExtent,
          padding: _padding,
          itemCount: lyrics.synced.length,
          itemBuilder: (BuildContext context, int i) {
            final LyricsLine linea = lyrics.synced[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Toca una línea para saltar a ese momento de la canción.
              onTap: () => widget.remota
                  ? ref
                        .read(remoteControllerProvider.notifier)
                        .buscarSeg(linea.time.inMilliseconds / 1000.0)
                  : ref
                        .read(playerControllerProvider.notifier)
                        .buscarPosicion(linea.time),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(
                  child: LineaLetra(
                    texto: linea.text.isEmpty ? '…' : linea.text,
                    activa: i == active,
                    escala: escala,
                    maxWidth: anchoLinea,
                    maxHeight: _itemExtent - 4,
                    color: c.text3,
                    colorActiva: c.text,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _trasElFrame(VoidCallback f) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        f();
      }
    });
  }

  void _irA(int index, {required bool animar}) {
    final ScrollController? scroll = _scroll;
    if (index < 0 || scroll == null || !scroll.hasClients) {
      return;
    }
    final double viewport = scroll.position.viewportDimension;
    final double target =
        ((index * _itemExtent) - (viewport / 2) + (_itemExtent / 2)).clamp(
          0.0,
          scroll.position.maxScrollExtent,
        );
    if (animar) {
      scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      scroll.jumpTo(target);
    }
  }
}

/// Reparto de una línea de letra: el texto con sus saltos de renglón ya fijados
/// y el tamaño de fuente en reposo y resaltada.
@immutable
class AjusteLinea {
  const AjusteLinea({
    required this.texto,
    required this.fontSize,
    required this.fontSizeActiva,
  });

  /// Texto con los saltos de renglón explícitos (`\n`).
  final String texto;
  final double fontSize;
  final double fontSizeActiva;

  int get renglones => '\n'.allMatches(texto).length + 1;
}

/// Calcula el reparto de una línea de letra de modo que **resaltarla no la
/// cambie de forma**: los renglones se deciden una sola vez con el estilo en
/// reposo (16 px, hasta 2 renglones, reduciendo hasta 13 px; nunca elipsis) y la
/// línea activa conserva exactamente esos renglones. Al resaltarse crece hacia
/// los 20 px en negrita solo hasta donde cabe a lo ancho y a lo alto; si la
/// línea ya ocupaba todo el ancho, se queda del mismo tamaño en vez de partirse
/// en más renglones o cortarse con "…".
AjusteLinea ajustarLineaLetra({
  required String texto,
  required double maxWidth,
  required double maxHeight,
  required double escala,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final double base = 16 * escala;
  final double minimo = 13 * escala;
  final double tope = 20 * escala;

  TextPainter pintor(String t, double size, FontWeight w, {int? maxLines}) {
    return TextPainter(
      text: TextSpan(text: t, style: estiloLineaLetra(size, w)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: maxLines,
    );
  }

  final String palabraLarga = texto
      .split(RegExp(r'\s+'))
      .fold<String>('', (String a, String w) => w.length > a.length ? w : a);

  bool cabe(double size, int renglones) {
    final TextPainter p = pintor(
      texto,
      size,
      FontWeight.w600,
      maxLines: renglones,
    )..layout(maxWidth: maxWidth);
    final bool ok = !p.didExceedMaxLines && p.height <= maxHeight + 0.5;
    p.dispose();
    if (!ok) {
      return false;
    }
    // Ninguna palabra debe partirse por la mitad.
    final TextPainter w = pintor(palabraLarga, size, FontWeight.w600)..layout();
    final bool palabraOk = w.width <= maxWidth + 0.5;
    w.dispose();
    return palabraOk;
  }

  // 1) Tamaño en reposo: el mayor que quepa en 2 renglones; si ni al mínimo,
  //    se permite un tercer renglón antes que cortar el texto.
  double size = minimo;
  bool hallado = false;
  for (final int renglones in const <int>[2, 3]) {
    for (double s = base; s >= minimo - 0.01; s -= 1) {
      if (cabe(s, renglones)) {
        size = s;
        hallado = true;
        break;
      }
    }
    if (hallado) {
      break;
    }
  }

  // 2) Renglones resultantes, fijados con saltos explícitos.
  final TextPainter p = pintor(texto, size, FontWeight.w600)
    ..layout(maxWidth: maxWidth);
  final List<String> renglones = <String>[];
  int inicio = 0;
  while (inicio < texto.length) {
    final TextRange r = p.getLineBoundary(TextPosition(offset: inicio));
    if (!r.isValid || r.end <= inicio) {
      renglones.add(texto.substring(inicio));
      break;
    }
    renglones.add(texto.substring(r.start, r.end));
    inicio = r.end;
  }
  p.dispose();
  final String fijado = <String>[
    for (final String r in renglones)
      if (r.trim().isNotEmpty) r.trim(),
  ].join('\n');
  final String textoFinal = fijado.isEmpty ? texto : fijado;

  // 3) Tamaño resaltada: crece hasta el tope sin salirse del ancho ni del alto.
  double activa = size;
  for (double s = tope; s > size; s -= 0.5) {
    final TextPainter a = pintor(textoFinal, s, FontWeight.w800)..layout();
    final bool ok = a.width <= maxWidth + 0.5 && a.height <= maxHeight + 0.5;
    a.dispose();
    if (ok) {
      activa = s;
      break;
    }
  }
  return AjusteLinea(texto: textoFinal, fontSize: size, fontSizeActiva: activa);
}

/// Estilo tipográfico de una línea de letra.
TextStyle estiloLineaLetra(double size, FontWeight weight, [Color? color]) {
  return TextStyle(
    fontFamily: NbFonts.display,
    fontSize: size,
    fontWeight: weight,
    height: 1.2,
    color: color,
  );
}

/// Una línea de la letra. Sus renglones son los mismos esté o no resaltada
/// (ver [ajustarLineaLetra]); el resaltado solo cambia color, grosor y —si hay
/// sitio— tamaño, con una transición corta.
class LineaLetra extends StatelessWidget {
  const LineaLetra({
    super.key,
    required this.texto,
    required this.activa,
    required this.escala,
    required this.maxWidth,
    required this.maxHeight,
    required this.color,
    required this.colorActiva,
  });

  final String texto;
  final bool activa;
  final double escala;
  final double maxWidth;
  final double maxHeight;
  final Color color;
  final Color colorActiva;

  @override
  Widget build(BuildContext context) {
    final AjusteLinea ajuste = ajustarLineaLetra(
      texto: texto,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      escala: escala,
      textScaler: MediaQuery.textScalerOf(context),
    );
    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      // Red de seguridad: si aun así no cupiera (negrita un pelo más ancha, texto
      // enorme del sistema), se reduce entera; nunca se recorta ni pone "…".
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          textAlign: TextAlign.center,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: activa
              ? estiloLineaLetra(
                  ajuste.fontSizeActiva,
                  FontWeight.w800,
                  colorActiva,
                )
              : estiloLineaLetra(ajuste.fontSize, FontWeight.w600, color),
          child: Text(ajuste.texto),
        ),
      ),
    );
  }
}
