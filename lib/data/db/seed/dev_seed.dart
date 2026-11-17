import 'package:drift/drift.dart';

import '../database.dart';

/// Activa el catálogo de demostración en el primer arranque. Apagado en las
/// compilaciones publicadas: el catálogo real llega del PC por sincronización.
/// Se enciende con `--dart-define=NB_SEED=true` para probar la app sin PC y
/// para producir las capturas y el video de la documentación.
const bool kSeedDevData = bool.fromEnvironment('NB_SEED', defaultValue: false);

// Todo el catálogo de demostración es ficticio y propio del proyecto: artistas,
// álbumes, títulos y letras se inventaron para la app, y la media se genera en
// el dispositivo (seed/demo_media.dart). Así ni el repositorio ni las capturas
// contienen obras con derechos de terceros.

/// Álbum de demostración: (id, título, artistaId, año).
const List<(int, String, int, int)> demoAlbums = <(int, String, int, int)>[
  (1, 'Mareas de cobre', 1, 2024),
  (2, 'Ciudad en vela', 1, 2022),
  (3, 'Northern Static', 2, 2023),
  (4, 'Jardín de antenas', 3, 2025),
  (5, 'Low Tide Radio', 4, 2021),
  (6, 'Cumbia de satélites', 5, 2024),
  (7, 'Horizonte lento', 6, 2023),
  (8, 'Glass Orchard', 2, 2025),
];

/// Artista de demostración: (id, nombre).
const List<(int, String)> demoArtistas = <(int, String)>[
  (1, 'Lúa Marino'),
  (2, 'The Paper Lanterns'),
  (3, 'Colectivo Brisa'),
  (4, 'Ivo Calder'),
  (5, 'Los Satélites'),
  (6, 'Nadia Ferro'),
];

/// Pista de demostración: (id, título, artistaId, albumId, duraciónSeg, favorita).
const List<(int, String, int, int, int, bool)> demoPistas =
    <(int, String, int, int, int, bool)>[
      (1, 'Faro encendido', 1, 1, 150, true),
      (2, 'Sal en la piel', 1, 1, 165, false),
      (3, 'Las doce y cuarto', 1, 1, 180, false),
      (4, 'Ciudad en vela', 1, 2, 200, true),
      (5, 'Tranvía nocturno', 1, 2, 150, false),
      (6, 'Kilometer Zero', 2, 3, 165, true),
      (7, 'Paper Moons', 2, 3, 180, false),
      (8, 'Static Hearts', 2, 3, 200, false),
      (9, 'Jardín de antenas', 3, 4, 150, true),
      (10, 'Frecuencia modulada', 3, 4, 165, false),
      (11, 'Polen y ruido', 3, 4, 180, false),
      (12, 'Low Tide Radio', 4, 5, 200, false),
      (13, 'Harbour Lights', 4, 5, 150, true),
      (14, 'Cumbia de satélites', 5, 6, 165, true),
      (15, 'Órbita bailable', 5, 6, 180, false),
      (16, 'Antena parabólica', 5, 6, 200, false),
      (17, 'Horizonte lento', 6, 7, 150, false),
      (18, 'Agua de domingo', 6, 7, 165, true),
      (19, 'Glass Orchard', 2, 8, 180, false),
      (20, 'Quiet Machinery', 2, 8, 200, true),
    ];

/// Playlist de demostración: (id, nombre, tipo, pistas en orden).
const List<(int, String, String, List<int>)> demoPlaylists =
    <(int, String, String, List<int>)>[
      (1, 'Me gusta', 'me-gusta', <int>[1, 4, 6, 9, 13, 14, 18, 20]),
      (2, 'Para la carretera', 'manual', <int>[14, 6, 2, 12, 15, 8, 10]),
      (3, 'Calma de tarde', 'manual', <int>[17, 18, 13, 7, 19, 3]),
      (4, 'Lo mejor de Lúa Marino', 'this-is', <int>[1, 4, 2, 5, 3]),
    ];

/// Ruta de portada de álbum con la forma que usa el PC: el resolutor de
/// imágenes la sirve desde disco cuando la portada consta como descargada.
String demoCoverPath(int albumId) => '/api/v1/asset/cover/$albumId';

String demoArtistPath(int artistaId) => '/api/v1/asset/artist/$artistaId';

/// Siembra el catálogo de demostración solo si está habilitado ([kSeedDevData])
/// y la base está vacía.
Future<bool> applyDevSeedIfEmpty(AppDatabase db) async {
  if (!kSeedDevData) {
    return false;
  }
  if (await db.catalogDao.contarPistas() > 0) {
    return false;
  }
  await seedDevData(db);
  return true;
}

/// Inserta el catálogo de demostración (idempotente). Lo usan las pruebas y
/// [applyDevSeedIfEmpty].
Future<void> seedDevData(AppDatabase db) async {
  String albumTitulo(int id) =>
      demoAlbums.firstWhere(((int, String, int, int) a) => a.$1 == id).$2;
  String artistaNombre(int id) =>
      demoArtistas.firstWhere(((int, String) a) => a.$1 == id).$2;

  await db.catalogDao.upsertArtistas(<ArtistasCompanion>[
    for (final (int id, String nombre) a in demoArtistas)
      ArtistasCompanion.insert(
        id: Value(a.$1),
        nombre: a.$2,
        imagenPath: Value(demoArtistPath(a.$1)),
        syncVersion: const Value(1),
      ),
  ]);

  await db.catalogDao.upsertAlbums(<AlbumsCompanion>[
    for (final (int id, String titulo, int artistaId, int anio) a in demoAlbums)
      AlbumsCompanion.insert(
        id: Value(a.$1),
        titulo: a.$2,
        artistaId: Value(a.$3),
        anio: Value(a.$4),
        coverPath: Value(demoCoverPath(a.$1)),
        syncVersion: const Value(1),
      ),
  ]);

  final Map<int, int> numero = <int, int>{};
  await db.catalogDao.upsertPistas(<PistasCompanion>[
    for (final (
          int id,
          String titulo,
          int artistaId,
          int albumId,
          int dur,
          bool _,
        )
        t
        in demoPistas)
      PistasCompanion.insert(
        id: Value(t.$1),
        titulo: t.$2,
        artistaNombre: artistaNombre(t.$3),
        albumTitulo: Value(albumTitulo(t.$4)),
        albumId: Value(t.$4),
        artistaId: Value(t.$3),
        trackNumber: Value(
          numero.update(t.$4, (int v) => v + 1, ifAbsent: () => 1),
        ),
        duracionSeg: Value(t.$5.toDouble()),
        coverPath: Value(demoCoverPath(t.$4)),
        audioPath: Value('/api/v1/track/${t.$1}/audio'),
        syncVersion: const Value(1),
      ),
  ]);

  for (final (int id, String nombre, String tipo, List<int> pistas) pl
      in demoPlaylists) {
    await db.catalogDao.upsertPlaylists(<PlaylistsCompanion>[
      PlaylistsCompanion.insert(
        id: Value(pl.$1),
        nombre: pl.$2,
        tipo: Value(pl.$3),
        syncVersion: const Value(1),
      ),
    ]);
    await db.catalogDao.upsertPlaylistPistas(<PlaylistPistasCompanion>[
      for (int i = 0; i < pl.$4.length; i++)
        PlaylistPistasCompanion.insert(
          playlistId: pl.$1,
          pistaId: pl.$4[i],
          posicion: i,
        ),
    ]);
  }

  for (final (int, String, int, int, int, bool) t in demoPistas) {
    if (t.$6) {
      await db.favoritesDao.setFavorita(t.$1, true);
    }
  }
}
