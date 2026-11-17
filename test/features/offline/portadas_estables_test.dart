import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/di/providers.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/offline/application/image_resolver.dart';
import 'package:nb_sound_mobile/features/player/application/cover_prefetch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // La caché de portadas remotas pide un directorio temporal a path_provider.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall _) async => Directory.systemTemp.path,
      );
  // Sin emparejamiento guardado.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall _) async => null,
      );

  // Regresión: al arrancar, las portadas pasaban por placeholder y red antes
  // de llegar a la del disco, porque el conjunto de portadas descargadas aún
  // no había salido de la base. Con los ids precargados en main, la primera
  // resolución ya es el archivo local.
  test('una portada descargada se resuelve a disco desde el primer frame', () {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final Directory base = Directory.systemTemp.createTempSync('nb_portadas');
    addTearDown(() => base.deleteSync(recursive: true));
    final ProviderContainer c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appAudioDirProvider.overrideWithValue(Directory('${base.path}/audio')),
        initialCoversLocalesProvider.overrideWithValue(<int>{7}),
      ],
    );
    addTearDown(c.dispose);

    final ImageProvider? img = c
        .read(coverResolverProvider)
        .imageFor('/api/v1/asset/cover/7');
    expect(img, isA<FileImage>());
    expect((img! as FileImage).file.path, endsWith('covers/7.img'));
  });

  test('el fondo del reproductor usa la misma miniatura sea cual sea el tamaño '
      'pedido, así la precarga la deja lista para el cambio de pista', () {
    final FileImage f = FileImage(File('/x/covers/1.img'));
    final ImageProvider a = coverAmbiente(ResizeImage(f, width: 1080));
    final ImageProvider b = coverAmbiente(ResizeImage(f, width: 132));
    expect(a, b);
    expect((a as ResizeImage).width, 64);
  });
}
