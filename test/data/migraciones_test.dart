import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';

void main() {
  test('una base de la versión 1 sube a la actual sin perder catálogo ni '
      'favoritos', () async {
    final Directory dir = Directory.systemTemp.createTempSync('nb_migra');
    addTearDown(() => dir.deleteSync(recursive: true));
    final File archivo = File('${dir.path}/nb.sqlite');

    // 1. Esquema actual con datos de la persona.
    final AppDatabase actual = AppDatabase.forTesting(NativeDatabase(archivo));
    await actual.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(
        id: const Value(1),
        titulo: 'Faro encendido',
        artistaNombre: 'Lúa Marino',
      ),
    ]);
    await actual.favoritesDao.setFavorita(1, true);
    await actual.close();

    // 2. Antes de que Drift lea la versión, se deshace cada paso de migración
    //    para volver al esquema 1; al abrir se aplican todas otra vez.
    const List<String> aVersion1 = <String>[
      'DROP TABLE local_media_ocultas',
      'ALTER TABLE pistas DROP COLUMN origen',
      'ALTER TABLE albums DROP COLUMN origen',
      'ALTER TABLE artistas DROP COLUMN origen',
      'ALTER TABLE playlists_locales DROP COLUMN descripcion',
      'DROP TABLE playlists_guardadas',
      'DROP TABLE assets_descargados',
      'ALTER TABLE descargas_audio DROP COLUMN lyrics_estado',
      'ALTER TABLE descargas_audio DROP COLUMN stems_estado',
      'ALTER TABLE descargas_audio DROP COLUMN stems_bytes',
      'ALTER TABLE descargas_audio DROP COLUMN stems_total_bytes',
      'DROP TABLE playlist_local_pistas',
      'DROP TABLE playlists_locales',
      'PRAGMA user_version = 1',
    ];
    final AppDatabase migrada = AppDatabase.forTesting(
      NativeDatabase(
        archivo,
        setup: (dynamic db) {
          for (final String sql in aVersion1) {
            db.execute(sql);
          }
        },
      ),
    );
    addTearDown(migrada.close);
    expect(await migrada.catalogDao.contarPistas(), 1);
    expect(await migrada.favoritesDao.esFavorita(1), isTrue);
    final Pista p = (await migrada.catalogDao.getPistasPorIds(<int>[1]))[1]!;
    expect(p.origen, 'pc');
    // Las tablas nuevas existen y se pueden usar.
    expect(await migrada.select(migrada.playlistsLocales).get(), isEmpty);
    expect(await migrada.select(migrada.localMediaOcultas).get(), isEmpty);
    expect(await migrada.select(migrada.assetsDescargados).get(), isEmpty);
  });
}
