import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/sub_header.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/i18n/idioma_controller.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../core/plataforma.dart';

/// Configuración: ecualizador, temas, idioma e ícono de la app.
class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            SubHeader(title: tr('Configuración')),
            if (esAndroid)
              _Tile(
                icon: AppIcons.equalizer,
                label: tr('Ecualizador'),
                subtitle: tr(
                  'Presets, bandas, normalizador y omitir silencios',
                ),
                onTap: () => context.push('/ecualizador'),
              ),
            _Tile(
              icon: AppIcons.palette2,
              label: tr('Temas'),
              subtitle: tr('Los 63 temas de NB Sound'),
              onTap: () => context.push('/temas'),
            ),
            _Tile(
              icon: AppIcons.globe,
              label: tr('Idioma'),
              subtitle: _nombreIdioma(ref.watch(idiomaControllerProvider)),
              onTap: () => _elegirIdioma(context, ref),
            ),
            if (esAndroid)
              _Tile(
                icon: AppIcons.image,
                label: tr('Ícono de la app'),
                subtitle: tr('Cambia el ícono de tu pantalla de inicio'),
                onTap: () => context.push('/icono-app'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nombre de cada opción en su propio idioma (salvo "del sistema"), para que
/// quien no entiende el idioma actual reconozca el suyo.
String _nombreIdioma(Idioma i) => switch (i) {
  Idioma.sistema => tr('Idioma del sistema'),
  Idioma.es => 'Español',
  Idioma.en => 'English',
  Idioma.pt => 'Português',
};

Future<void> _elegirIdioma(BuildContext context, WidgetRef ref) async {
  final Idioma actual = ref.read(idiomaControllerProvider);
  final Idioma? elegido = await mostrarHojaMenu<Idioma>(
    context,
    builder: (BuildContext ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final Idioma i in Idioma.values)
          ListTile(
            title: Text(_nombreIdioma(i)),
            trailing: i == actual ? const Icon(AppIcons.check) : null,
            onTap: () => Navigator.of(ctx).pop(i),
          ),
      ],
    ),
  );
  if (elegido != null && elegido != actual) {
    ref.read(idiomaControllerProvider.notifier).elegir(elegido);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c.text2, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text3,
        ),
      ),
      trailing: Icon(AppIcons.chevronRight, color: c.text3, size: 20),
    );
  }
}
