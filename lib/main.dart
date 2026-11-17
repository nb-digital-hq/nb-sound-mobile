// Entry point de NB Sound Mobile.
//
// Arranque: abre la BD local (Drift) y la siembra si está vacía, inicializa el
// servicio de audio (audio_service + just_audio) y monta el ProviderScope
// (Riverpod) raíz proveyendo ambos. Tema y routing los resuelve [NbSoundApp].

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/nb_sound_app.dart';
import 'core/di/providers.dart';
import 'core/i18n/i18n.dart';
import 'core/i18n/idioma_controller.dart';
import 'core/network/pinned_http_overrides.dart';
import 'core/security/secure_store.dart';
import 'data/db/daos/assets_dao.dart';
import 'data/db/daos/sync_state_dao.dart';
import 'data/db/database.dart';
import 'data/db/seed/demo_media.dart';
import 'data/db/seed/dev_seed.dart';
import 'features/offline/data/offline_store.dart';
import 'features/player/application/nb_audio_handler.dart';
import 'features/player/application/player_controller.dart';
import 'shared/theme/nb_theme.dart';
import 'shared/theme/theme_controller.dart';
import 'shared/util/responsive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Caché de imágenes en memoria más amplia (la de RAM; el disco lo cubre
  // CoverCache): mantiene decodificadas más portadas al navegar entre vistas, así
  // se reduce el "parpadeo" de recarga al reentrar a una pantalla.
  PaintingBinding.instance.imageCache
    ..maximumSize = 1500
    ..maximumSizeBytes = 200 << 20; // 200 MB

  // Pinning TLS global para NetworkImage y el proxy de just_audio (rutas que no
  // pasan por dio). La huella del PC emparejado la fija NbSoundApp.
  HttpOverrides.global = NbHttpOverrides();

  // Teléfonos solo en vertical (): en horizontal la barra inferior y
  // el mini player dejaban sin sitio al contenido. Tablets/Chromebooks rotan.
  await SystemChrome.setPreferredOrientations(
    soloVertical(PlatformDispatcher.instance.views.first)
        ? const <DeviceOrientation>[DeviceOrientation.portraitUp]
        : const <DeviceOrientation>[],
  );

  final AppDatabase database = AppDatabase();
  final bool demoRecienSembrada = await applyDevSeedIfEmpty(database);
  final Directory docsDir = await getApplicationDocumentsDirectory();
  final Directory audioDir = Directory(p.join(docsDir.path, 'audio'));
  if (demoRecienSembrada) {
    await materializarMediaDemo(database, OfflineStore(docsDir));
  }

  // Preferencias persistidas (sobreviven reinicios): tema y estado global del
  // reproductor (aleatorio/repetición).
  final SyncStateDao syncState = database.syncStateDao;
  final String initialTheme = nbThemeKeyFromStored(
    await syncState.getValor(kTemaPrefKey),
  );
  final bool initialShuffle =
      await syncState.getValor(SyncStateDao.kAleatorio) == '1';
  final Idioma idiomaInicial = idiomaDeClave(
    await syncState.getValor(kIdiomaPrefKey),
  );
  fijarIdioma(idiomaInicial);
  final String? repeatPref = await syncState.getValor(SyncStateDao.kRepeticion);
  final RepeatMode initialRepeat = RepeatMode.values.firstWhere(
    (RepeatMode m) => m.name == repeatPref,
    orElse: () => RepeatMode.off,
  );

  // Precarga (en paralelo) lo que las portadas necesitan para salir estables en
  // el primer frame: qué portadas/fotos ya están en disco y el PC emparejado.
  final (
    Set<int> coversLocales,
    Set<int> artistasLocales,
    PairedPc? pairing,
  ) = await (
    database.assetsDao.watchDescargados(AssetTipo.cover).first,
    database.assetsDao.watchDescargados(AssetTipo.artist).first,
    SecureStore().readPairing().catchError((Object _) => null),
  ).wait;

  // audio_service / just_audio solo tienen implementación en móvil. En
  // escritorio/web se usa un handler "preview" (UI sin audio real).
  final bool mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final NbAudioHandler audioHandler = mobile
      ? await AudioService.init(
          builder: NbAudioHandler.new,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.nbsound.audio',
            androidNotificationChannelName: 'NB Sound',
            androidStopForegroundOnPause: false,
            androidNotificationIcon: 'drawable/ic_stat_music',
          ),
        )
      : NbAudioHandler(preview: true);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        audioHandlerProvider.overrideWithValue(audioHandler),
        appAudioDirProvider.overrideWithValue(audioDir),
        initialThemeProvider.overrideWithValue(initialTheme),
        initialIdiomaProvider.overrideWithValue(idiomaInicial),
        initialShuffleProvider.overrideWithValue(initialShuffle),
        initialRepeatProvider.overrideWithValue(initialRepeat),
        initialCoversLocalesProvider.overrideWithValue(coversLocales),
        initialArtistasLocalesProvider.overrideWithValue(artistasLocales),
        initialPairingProvider.overrideWithValue(pairing),
      ],
      child: const NbSoundApp(),
    ),
  );
}
