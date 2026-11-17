# Almacenamiento

> **Estado:** Implementado. Esquema en `lib/data/db/tables.dart`, versión 7, con migraciones probadas desde la 1
> (`test/data/migraciones_test.dart`).

## Base de datos

Un archivo SQLite (`nb_sound.sqlite`) en el directorio de documentos de la app, abierto con Drift en un aislado
propio para no bloquear la interfaz.

| Tablas | Contenido | Quién escribe |
|---|---|---|
| `artistas`, `albums`, `pistas`, `playlists`, `playlist_pistas` | Réplica del catálogo del PC y música local del teléfono (`origen`: `pc` o `local`; ids negativos para lo local) | Aplicador del manifiesto; escaneo local |
| `historial_local`, `favoritos_local` | Escuchas y favoritos del teléfono | Reproductor e interfaz |
| `playlists_locales`, `playlist_local_pistas` | Playlists propias del teléfono | Interfaz |
| `playlists_guardadas` | Playlists del PC que la persona sigue para tenerlas sin conexión | Interfaz |
| `descargas_audio`, `assets_descargados` | Estado de cada descarga (audio, letra, instrumental) y de cada imagen | Cola de descargas |
| `local_media_ocultas` | Pistas locales que la persona quitó de la app | Interfaz |
| `sync_estado` | Pares clave-valor: versión de sincronización, preferencias, sesión del reproductor | Varios |
| `pc_emparejado` | Datos no sensibles del PC (nombre, dirección) | Emparejamiento |

Reglas:

* El aplicador del manifiesto solo toca las tablas del catálogo y respeta las filas con `origen = local`.
* Cada página del manifiesto se aplica en una transacción.
* Una migración publicada no se edita: se añade la siguiente con su paso en `onUpgrade` y se amplía la prueba.

## Archivos sin conexión

Bajo el directorio de documentos (`lib/features/offline/data/offline_store.dart`):

| Carpeta | Archivo |
|---|---|
| `audio/` | `{pistaId}.audio` |
| `covers/` | `{albumId}.img` |
| `artists/` | `{artistaId}.img` |
| `stems/` | `{pistaId}.audio` |
| `lyrics/` | `{pistaId}.json` |

Las portadas remotas que no están descargadas viven en la caché de imágenes (hasta 10 000, un año), y las carátulas
de la música local en la caché del sistema de la app.

## Secretos

El `device_token` y la huella del certificado del PC se guardan en el llavero del sistema
(`flutter_secure_storage`: Keystore en Android, Keychain en iOS), nunca en la base ni en preferencias.
