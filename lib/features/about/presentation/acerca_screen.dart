import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/sub_header.dart';
import '../application/update_controller.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/plataforma.dart';

/// Ajustes › **Acerca de**: logo, versión instalada y actualizaciones desde
/// GitHub (como NB Sound y NB Books de escritorio). Nunca busca sola: el botón
/// es el consentimiento; lo que se instala debe estar firmado con la misma llave
/// que la app (Android lo comprueba).
class AcercaScreen extends ConsumerWidget {
  const AcercaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final UpdateState s = ref.watch(updateControllerProvider);
    final UpdateController ctrl = ref.read(updateControllerProvider.notifier);
    final bool hayNueva =
        s.fase == FaseUpdate.disponible ||
        s.fase == FaseUpdate.descargando ||
        s.fase == FaseUpdate.listo;

    TextStyle texto(
      double size, {
      FontWeight w = FontWeight.w500,
      Color? color,
      double? h,
    }) => TextStyle(
      fontFamily: NbFonts.ui,
      fontSize: size,
      fontWeight: w,
      height: h,
      color: color ?? c.text2,
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 36),
          children: <Widget>[
            SubHeader(title: tr('Acerca de')),
            const SizedBox(height: 12),
            Center(
              child: Image.asset(
                'assets/app_icons/logo_default.png',
                width: 108,
                height: 108,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                tr('NB Sound'),
                style: TextStyle(
                  fontFamily: NbFonts.display,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                s.versionInstalada.isEmpty
                    ? tr('Versión —')
                    : tr('Versión {versionInstalada}', {
                        'versionInstalada': s.versionInstalada,
                      }),
                style: texto(13.5),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                tr('Parte del ecosistema NB Digital'),
                style: texto(12.5, color: c.text3),
              ),
            ),
            const SizedBox(height: 26),
            // Las actualizaciones instalan un APK: solo existen en Android.
            if (esAndroid)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.bg2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr('Actualizaciones'),
                      style: texto(15, w: FontWeight.w700, color: c.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        'Las versiones nuevas se publican en GitHub. NB Sound solo consulta cuando tú lo pides.',
                      ),
                      style: texto(12.5, color: c.text3, h: 1.4),
                    ),
                    const SizedBox(height: 14),
                    if (s.fase == FaseUpdate.descargando) ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: s.progreso > 0 ? s.progreso : null,
                          minHeight: 6,
                          color: c.accent,
                          backgroundColor: c.line2,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: hayNueva
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: c.accent,
                                foregroundColor: c.ink,
                              ),
                              onPressed: s.ocupado ? null : ctrl.instalar,
                              child: Text(
                                s.fase == FaseUpdate.descargando
                                    ? tr('Descargando {p0} %', {
                                        'p0': (s.progreso * 100).round(),
                                      })
                                    : tr('Instalar versión {v}', {
                                        'v': s.publicacion?.version ?? '',
                                      }),
                              ),
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: c.text,
                                side: BorderSide(color: c.line2),
                              ),
                              onPressed: s.ocupado ? null : ctrl.buscar,
                              child: s.fase == FaseUpdate.buscando
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: c.accent,
                                      ),
                                    )
                                  : Text(tr('Buscar actualizaciones')),
                            ),
                    ),
                    if (s.mensaje != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(s.mensaje!, style: texto(13)),
                    ],
                    if (hayNueva &&
                        (s.publicacion?.notas.isNotEmpty ?? false)) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        tr('Novedades'),
                        style: texto(13, w: FontWeight.w700, color: c.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.publicacion!.notas,
                        style: texto(12.5, color: c.text2, h: 1.45),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              onTap: ctrl.abrirRepo,
              leading: Icon(Icons.code_rounded, color: c.text2),
              title: Text(
                tr('Código y versiones en GitHub'),
                style: texto(14.5, w: FontWeight.w600, color: c.text),
              ),
              subtitle: Text(
                'github.com/nb-digital-hq/nb-sound-mobile',
                style: texto(12.5, color: c.text3),
              ),
              trailing: Icon(
                Icons.open_in_new_rounded,
                color: c.text3,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
