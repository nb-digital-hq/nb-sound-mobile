import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../../../core/security/secure_store.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/sub_header.dart';
import '../application/conexion_provider.dart';
import '../application/sync_controller.dart';
import '../../../core/i18n/i18n.dart';

/// Flujo de sincronización con el PC: intro → escaneo QR → conexión → conectado.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final SyncState s = ref.watch(syncControllerProvider);

    return Scaffold(
      backgroundColor: s.phase == SyncPhase.scanning ? Colors.black : c.bg,
      body: SafeArea(
        child: switch (s.phase) {
          SyncPhase.scanning => const _Scanner(),
          SyncPhase.connecting => const _Connecting(),
          SyncPhase.connected => _Connected(pc: s.pc),
          SyncPhase.error => _ErrorView(code: s.errorCode),
          SyncPhase.intro => const _Intro(),
        },
      ),
    );
  }
}

class _Intro extends ConsumerWidget {
  const _Intro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    return Column(
      children: <Widget>[
        SubHeader(title: tr('Sincronizar con PC')),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              children: <Widget>[
                Icon(AppIcons.laptop, size: 56, color: c.accent),
                const SizedBox(height: 18),
                Text(
                  tr('Lleva tu música contigo'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NbFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Conecta esta app a NB Sound en tu computadora. Todo viaja por tu red local, sin nube.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: c.text2,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    children: <Widget>[
                      Icon(AppIcons.qr, size: 40, color: c.text2),
                      const SizedBox(height: 14),
                      Text(
                        tr(
                          'En tu PC abre NB Sound → Sincronizar y muestra el código QR.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          color: c.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        ref.read(syncControllerProvider.notifier).startScan(),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.ink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(AppIcons.qr, color: c.ink),
                    label: Text(
                      tr('Escanear código QR'),
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Alternativa sin cámara (Chromebook, cámara dañada, etc.):
                // escribir la IP del PC. La app descubre el puerto y fija la
                // huella TLS automáticamente; solo hace falta el código del QR.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _mostrarConexionIp(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text2,
                      side: BorderSide(color: c.line2),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(AppIcons.laptop, color: c.text2, size: 18),
                    label: Text(
                      tr('Sin cámara: conectar por IP'),
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: c.text2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Hoja de conexión manual por IP (sin cámara).
Future<void> _mostrarConexionIp(BuildContext context, WidgetRef ref) {
  final NbColors c = context.nb;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.bg2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext _) => const _ManualIpSheet(),
  );
}

class _ManualIpSheet extends ConsumerStatefulWidget {
  const _ManualIpSheet();

  @override
  ConsumerState<_ManualIpSheet> createState() => _ManualIpSheetState();
}

class _ManualIpSheetState extends ConsumerState<_ManualIpSheet> {
  final TextEditingController _dir = TextEditingController();
  final TextEditingController _codigo = TextEditingController();

  @override
  void dispose() {
    _dir.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _conectar() {
    final String dir = _dir.text.trim();
    final String code = _codigo.text.trim();
    if (dir.isEmpty || code.isEmpty) {
      return;
    }
    // Cierra la hoja; la pantalla principal refleja connecting→connected/error.
    Navigator.of(context).pop();
    ref.read(syncControllerProvider.notifier).conectarPorIp(dir, code);
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            tr('Conectar por IP'),
            style: TextStyle(
              fontFamily: NbFonts.display,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'En el PC, abre NB Sound → Sincronizar. Escribe la "Dirección en la red local" y el "Código para conectar sin QR".',
            ),
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 13,
              height: 1.45,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dir,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: c.text, fontFamily: NbFonts.ui),
            decoration: _dec(
              c,
              tr('Dirección del PC'),
              tr('p. ej. 192.168.1.40:8731'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codigo,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _conectar(),
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: c.text, fontFamily: NbFonts.ui),
            decoration: _dec(
              c,
              tr('Código para conectar sin QR'),
              tr('8 caracteres del PC'),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _conectar,
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.ink,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                tr('Conectar'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(NbColors c, String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: c.text2, fontFamily: NbFonts.ui),
      hintStyle: TextStyle(color: c.text3, fontFamily: NbFonts.ui),
      filled: true,
      fillColor: c.bg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent),
      ),
    );
  }
}

class _Scanner extends ConsumerStatefulWidget {
  const _Scanner();

  @override
  ConsumerState<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends ConsumerState<_Scanner> {
  // ZXing (zxing-cpp por FFI) y no ML Kit: el lector es código abierto y no
  // mete en el APK un binario propietario de Google, requisito para que todo
  // lo que se distribuye sea compatible con Apache-2.0.
  bool _manejado = false;
  _FalloCamara? _fallo;

  void _onScan(Code code) {
    final String? raw = code.text;
    if (_manejado || !code.isValid || raw == null || raw.isEmpty) {
      return;
    }
    _manejado = true;
    ref.read(syncControllerProvider.notifier).onQrDetected(raw);
  }

  void _onCamara(CameraController? _, Exception? error) {
    if (error == null || !mounted) {
      return;
    }
    final String texto = error.toString();
    setState(() {
      _fallo =
          texto.contains('CameraAccessDenied') || texto.contains('ermission')
          ? _FalloCamara.permiso
          : _FalloCamara.otro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _FalloCamara? fallo = _fallo;
    if (fallo != null) {
      return _ScannerError(
        fallo: fallo,
        onReintentar: () => setState(() => _fallo = null),
        onCerrar: () => ref.read(syncControllerProvider.notifier).cancel(),
      );
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ReaderWidget(
            codeFormat: Format.qrCode,
            onScan: _onScan,
            onControllerCreated: _onCamara,
            showGallery: false,
            showToggleCamera: false,
            showScannerOverlay: false,
            cropPercent: 0.7,
            scanDelay: const Duration(milliseconds: 250),
            loading: const ColoredBox(color: Colors.black),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1FD4E6), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            onPressed: () => ref.read(syncControllerProvider.notifier).cancel(),
            icon: const Icon(AppIcons.close, color: Colors.white, size: 26),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 96,
          child: IgnorePointer(
            child: Text(
              tr('Apunta al código QR de NB Sound'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _FalloCamara { permiso, otro }

/// Pantalla de error del escáner con reintentar/cerrar, en lugar de un cuadro
/// negro sin explicación cuando la cámara no arranca.
class _ScannerError extends StatelessWidget {
  const _ScannerError({
    required this.fallo,
    required this.onReintentar,
    required this.onCerrar,
  });

  final _FalloCamara fallo;
  final VoidCallback onReintentar;
  final VoidCallback onCerrar;

  String get _mensaje => switch (fallo) {
    _FalloCamara.permiso => tr(
      'Sin permiso de cámara. Habilítalo para escanear el código QR.',
    ),
    _FalloCamara.otro => tr(
      'No se pudo iniciar la cámara para escanear el QR.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(AppIcons.close, color: Colors.white70, size: 44),
            const SizedBox(height: 16),
            Text(
              _mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onCerrar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Text(tr('Cerrar')),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onReintentar,
                  child: Text(tr('Reintentar')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting();

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: c.accent),
          const SizedBox(height: 24),
          Text(
            tr('Estableciendo conexión…'),
            style: TextStyle(
              fontFamily: NbFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('Enlazando con el PC por la red local'),
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 13.5,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Connected extends ConsumerWidget {
  const _Connected({required this.pc});
  final PairedPc? pc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final SyncState s = ref.watch(syncControllerProvider);
    // Estado de conexión real (sondeo `/ping`), no el del emparejamiento: un PC
    // emparejado puede no estar respondiendo.
    final ConexionEstado conexion = ref.watch(conexionPcProvider);
    final (
      Color estadoColor,
      IconData estadoIcon,
      String estadoTexto,
    ) = switch (conexion) {
      ConexionEstado.conectado => (
        const Color(0xFF3DDC84),
        AppIcons.wifi,
        tr('Conectado · misma red local'),
      ),
      ConexionEstado.desconectado => (
        const Color(0xFFFFA502),
        AppIcons.laptop,
        tr('Desconectado · no se alcanza el PC'),
      ),
      ConexionEstado.sinEnlace => (c.text3, AppIcons.laptop, tr('Sin enlace')),
    };
    return Column(
      children: <Widget>[
        SubHeader(title: tr('Sincronización')),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: c.soft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(AppIcons.laptop, color: c.accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // No se usa `pc.nombre`: emparejamientos antiguos
                            // guardaron ahí el nombre del propio teléfono.
                            Text(
                              tr('NB Sound en tu PC'),
                              style: TextStyle(
                                fontFamily: NbFonts.ui,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: <Widget>[
                                Icon(estadoIcon, size: 13, color: estadoColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    estadoTexto,
                                    style: TextStyle(
                                      fontFamily: NbFonts.ui,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: estadoColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (pc != null) ...<Widget>[
                              const SizedBox(height: 3),
                              Text(
                                '${pc!.host}:${pc!.port}',
                                style: TextStyle(
                                  fontFamily: NbFonts.ui,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: c.text3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Consejos sencillos cuando no conecta o falla la sincronización
                // (al tocar Sincronizar / Reintentar conexión y seguir sin éxito).
                if (conexion != ConexionEstado.conectado || s.syncError != null)
                  const _TipsConexion(),
                if (conexion == ConexionEstado.desconectado) ...<Widget>[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(syncControllerProvider.notifier).reconnect(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: estadoColor,
                        side: BorderSide(color: estadoColor),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        AppIcons.refresh,
                        color: estadoColor,
                        size: 18,
                      ),
                      label: Text(
                        tr('Reintentar conexión'),
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: estadoColor,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: s.syncing
                        ? null
                        : () => ref
                              .read(syncControllerProvider.notifier)
                              .syncNow(),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.ink,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: s.syncing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.ink,
                            ),
                          )
                        : Icon(AppIcons.refresh, color: c.ink, size: 18),
                    label: Text(
                      s.syncing
                          ? tr('Sincronizando…')
                          : tr('Sincronizar ahora'),
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                  ),
                ),
                if (s.lastSync != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _InfoTile(
                    text: tr(
                      'Sincronizado · {p0} entidades · {p1} borrados · subido {p2} de historial.',
                      {
                        'p0': s.lastSync!.totalEntidades,
                        'p1': s.lastSync!.tombstones,
                        'p2': s.lastSync!.historialSubido,
                      },
                    ),
                  ),
                ],
                if (s.syncError != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _InfoTile(
                    text: s.syncError == 'token_invalido_o_expirado'
                        ? tr(
                            'El PC revocó este dispositivo. Vuelve a emparejar.',
                          )
                        : tr(
                            'No se pudo sincronizar. Verifica que el PC esté en la misma red.',
                          ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    // Pide confirmación: desemparejar obliga a volver a
                    // escanear el QR o meter el código del PC.
                    onPressed: () async {
                      final bool? ok = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext dc) => AlertDialog(
                          backgroundColor: c.bg2,
                          title: Text(
                            tr('¿Desconectar de tu PC?'),
                            style: TextStyle(
                              fontFamily: NbFonts.display,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          content: Text(
                            tr(
                              'Para volver a sincronizar tendrás que emparejar de nuevo con el QR o el código del PC. Tu música descargada se conserva.',
                            ),
                            style: TextStyle(
                              fontFamily: NbFonts.ui,
                              color: c.text2,
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(dc).pop(false),
                              child: Text(
                                tr('Cancelar'),
                                style: TextStyle(color: c.text2),
                              ),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(dc).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: c.accent,
                                foregroundColor: c.ink,
                              ),
                              child: Text(tr('Desconectar')),
                            ),
                          ],
                        ),
                      );
                      if (ok ?? false) {
                        await ref
                            .read(syncControllerProvider.notifier)
                            .disconnect();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text2,
                      side: BorderSide(color: c.line2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(tr('Desconectar')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Lista de comprobaciones sencillas cuando no se logra conectar/sincronizar.
class _TipsConexion extends StatelessWidget {
  const _TipsConexion();

  static List<String> get _tips => <String>[
    tr('Abre NB Sound en tu PC.'),
    tr('Conecta el PC y el celular a la misma red Wi-Fi.'),
    tr(
      'En el PC, entra a la pestaña Sincronización (el servidor debe estar encendido).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(AppIcons.wifi, size: 16, color: c.text2),
              const SizedBox(width: 8),
              Text(
                tr('Si no conecta, revisa:'),
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final String tip in _tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '•  ',
                    style: TextStyle(color: c.accent, fontFamily: NbFonts.ui),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 13,
                        height: 1.4,
                        color: c.text2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 13,
          height: 1.5,
          color: c.text2,
        ),
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.code});
  final String? code;

  static Map<String, String> get _messages => <String, String>{
    'qr_invalido': tr(
      'El código no es válido. Asegúrate de escanear el QR de NB Sound.',
    ),
    'token_invalido_o_expirado': tr(
      'El código expiró. Genera uno nuevo en el PC e inténtalo otra vez.',
    ),
    'error_red': tr(
      'No se pudo conectar con el PC. Verifica que ambos estén en la misma red local y que el firewall del PC no bloquee la conexión.',
    ),
    'red_timeout': tr(
      'El PC no respondió a tiempo. Aun en la misma red, suele deberse al firewall del PC o al "aislamiento de clientes" del Wi-Fi (frecuente en redes de invitados o de malla), que impide que los dispositivos se vean entre sí. Revisa el firewall del PC y desactiva el aislamiento, o prueba otra red.',
    ),
    'red_inalcanzable': tr(
      'No se pudo abrir la conexión con el PC. Asegúrate de que el servidor esté encendido, que el firewall del PC permita NB Sound y que el Wi-Fi no aísle los dispositivos entre sí.',
    ),
    'red_tls': tr(
      'El certificado del PC cambió. Desvincula y vuelve a vincular (o vuelve a escanear el QR) para confiar en el nuevo.',
    ),
    'respuesta_invalida': tr('El PC respondió algo inesperado.'),
    'pc_no_encontrado': tr(
      'No se encontró NB Sound en esa IP. Revisa la dirección y que el servidor esté encendido en el PC (misma red).',
    ),
    'direccion_invalida': tr(
      'La dirección no es válida. Usa la IP o IP:puerto.',
    ),
    'datos_incompletos': tr('Escribe la IP del PC y el código de un solo uso.'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    return Column(
      children: <Widget>[
        SubHeader(title: tr('Sincronizar con PC')),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(AppIcons.close, size: 48, color: c.text3),
                const SizedBox(height: 16),
                Text(
                  _messages[code] ??
                      tr('No se pudo emparejar ({codigo}).', {
                        'codigo': code ?? '—',
                      }),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: c.text2,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  // Vuelve a la intro: el usuario elige reintentar por QR o IP.
                  onPressed: () =>
                      ref.read(syncControllerProvider.notifier).cancel(),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.ink,
                  ),
                  child: Text(tr('Volver')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
