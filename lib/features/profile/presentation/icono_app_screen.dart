import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/util/responsive.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/sub_header.dart';
import '../application/app_icon_controller.dart';
import '../../../core/i18n/i18n.dart';

/// Una opción de ícono: clave (''=por defecto), nombre y asset de previsualización.
class _OpcionIcono {
  const _OpcionIcono(this.key, this.label, this.asset);
  final String key;
  final String label;
  final String asset;
}

/// Pantalla "Ícono de la app": cuadrícula mediana con el ícono por defecto + sus
/// variantes por tema. Al tocar uno se aplica de verdad (conmuta el ícono del lanzador
/// vía activity-alias) y se persiste la elección.
class IconoAppScreen extends ConsumerWidget {
  const IconoAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final String activo = ref.watch(appIconProvider);
    final List<_OpcionIcono> opciones = <_OpcionIcono>[
      _OpcionIcono('', tr('Por defecto'), 'assets/app_icons/logo_default.png'),
      for (final NbThemeDef t in kNbThemes)
        _OpcionIcono(t.key, tr(t.label), 'assets/app_icons/logo_${t.key}.png'),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SubHeader(title: tr('Ícono de la app')),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                tr(
                  'Elige el ícono que verás en tu pantalla de inicio. El cambio se aplica la próxima vez que cierres y vuelvas a abrir la app.',
                ),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 12.5,
                  height: 1.4,
                  color: c.text3,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns(MediaQuery.sizeOf(context).width),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.82,
                ),
                itemCount: opciones.length,
                itemBuilder: (BuildContext context, int i) {
                  final _OpcionIcono o = opciones[i];
                  return _IconCell(
                    opcion: o,
                    activo: o.key == activo,
                    onTap: () async {
                      await ref
                          .read(appIconProvider.notifier)
                          .seleccionar(o.key);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 4),
                            content: Text(
                              tr(
                                'Ícono "{label}" guardado. Se aplicará cuando cierres y vuelvas a abrir la app.',
                                {'label': o.label},
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.opcion,
    required this.activo,
    required this.onTap,
  });

  final _OpcionIcono opcion;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    // Todas las opciones son el mismo logo (generado desde el SVG de la app) con
    // distinto fondo: PNG circulares con transparencia, mostrados completos y
    // sin recuadro detrás.
    final Widget media = Padding(
      padding: const EdgeInsets.all(6),
      child: Image.asset(opcion.asset, fit: BoxFit.contain),
    );
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  media,
                  if (activo)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.bg, width: 2),
                        ),
                        child: Icon(AppIcons.check, color: c.ink, size: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            opcion.label,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: activo ? c.accent : c.text2,
            ),
          ),
        ],
      ),
    );
  }
}
