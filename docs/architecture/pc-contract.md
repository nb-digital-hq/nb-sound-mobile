# Contrato con el PC

> **Estado:** Implementado. Protocolo `1`, compatible con NB Sound 1.0, que lo comprueba con respuestas doradas en
> su propia suite.

Todos los cuerpos son JSON en UTF-8. Las marcas de tiempo son ISO-8601 UTC con milisegundos y sufijo `Z`, de modo
que el orden alfabético es el cronológico. El teléfono ignora los campos que no conoce: los cambios del PC son
aditivos y un cambio incompatible se reflejaría en `version_protocolo`.

## 1. Transporte y descubrimiento

* HTTPS y WSS con certificado autofirmado y persistente en el PC. El teléfono fija su huella SHA-256 al emparejar
  y en cada conexión acepta el certificado solo si coincide (`lib/core/network/tls_pinning.dart`).
* Puerto: el primero libre del rango 8731 a 8799; viaja en el QR.
* mDNS: servicio `_nbsound._tcp.local.`, usado para reencontrar al PC si cambia su dirección.

## 2. Autenticación

* `POST /api/v1/pair` con el token efímero del QR (un solo uso, cinco minutos) devuelve un `device_token`
  persistente, que se guarda en el llavero del sistema.
* El resto de llamadas lleva `Authorization: Bearer <device_token>`. Sin autenticación solo `GET /api/v1/ping` y
  `POST /api/v1/pair`. Un 401 significa que el PC revocó el teléfono: hay que volver a emparejar.

## 3. El QR

```json
{ "host": "192.168.1.40", "puerto": 8731, "token": "<efímero>", "version": 1,
  "tls": true, "tls_fingerprint": "<64 hex>", "servicio": "NB Sound" }
```

Sin cámara, el mismo emparejamiento se hace con la dirección y un código de 8 caracteres que muestra el PC.

## 4. Rutas HTTP

| Método | Ruta | Propósito |
|---|---|---|
| GET | `/api/v1/ping` | Presencia y versión. Con el token, el PC muestra el teléfono como conectado |
| POST | `/api/v1/pair` | Emparejamiento |
| GET | `/api/v1/manifest?since=&limit=` | Cambios del catálogo desde una versión, paginados |
| GET, POST | `/api/v1/seleccion` | Qué parte del catálogo recibe este teléfono |
| GET | `/api/v1/track/{id}/audio` | Audio, con `Range` y `X-NB-Sound-Hash` |
| GET | `/api/v1/track/{id}/lyrics` | Letra sincronizada (LRC) y plana |
| GET | `/api/v1/track/{id}/stems` | Instrumental del karaoke, con `Range` |
| GET | `/api/v1/asset/{tipo}/{id}` | Portada (`cover`, `album`) o foto (`artist`) |
| POST | `/api/v1/history` | Sube historial y favoritos |
| WS | `/api/v1/control` | Estado y órdenes del reproductor del PC |

### 4.1 Presencia

`GET /api/v1/ping` responde `{"ok": true, "servicio": "NB Sound", "version_protocolo": 1}`. El teléfono lo envía
con su token cada 25 segundos en primer plano.

### 4.2 Emparejamiento

Petición `{"token", "nombre_dispositivo", "plataforma"}`; respuesta `{"ok", "device_token", "dispositivo_id",
"nombre"}` o `401 {"error": "token_invalido_o_expirado"}`.

### 4.3 Manifiesto

Devuelve las entidades con `sync_version > since`: `pistas`, `albums`, `artistas`, `playlists`, `tombstones` y
`perfil`, junto con `sync_version_actual`, `next_since` y `has_more`. El teléfono pide páginas de 500 y aplica cada
una en una transacción; si una página falla, repite con el mismo `since`. Las URL de medios son relativas.

### 4.4 Selección

`{"modo": "todo" | "nada" | "artistas" | "playlists", ...ids}`. Al ampliar el alcance el teléfono reinicia el delta
desde 0. Los borrados viajan siempre.

### 4.5 Audio y verificación

Sin `Range`, 200 con el archivo; con `Range`, 206, lo que permite reanudar. `hash_sha256` y `X-NB-Sound-Hash` son el
SHA-256 de los primeros 512 KB y los últimos 512 KB del archivo (igual al SHA-256 completo hasta 1 MB). Si no
coincide, el archivo se conserva marcado "descargado, sin verificar": TLS ya protege el transporte y el tamaño se
comprueba por `Range`.

### 4.6 Imágenes

Respuesta con el archivo de imagen o 404 si no hay. Un 404 se recuerda para no repetir la petición.

### 4.7 Letra

`{"synced_lyrics": "[mm:ss.cc] …", "plain_lyrics": "…"}` o `404 {"error": "sin_lyrics"}`.

### 4.8 Instrumental

FLAC del karaoke, con `Range`, o `404 {"error": "sin_stems"}`.

### 4.9 Historial y favoritos

`{"historial": [{pista_id, reproducido_en, duracion_seg?, completada?}], "favoritos": [{pista_id, favorita,
actualizada_en}]}`. El historial se añade siempre. Un favorito del teléfono gana solo si su `actualizada_en` es
estrictamente más reciente que el del PC.

## 5. Control remoto

WebSocket con el mismo token. El PC envía un primer mensaje `estado` al conectar y otro en cada cambio:

```json
{ "tipo": "estado", "reproduciendo": true,
  "pista": { "id": 1, "titulo": "…", "artista": "…", "album": "…", "duracion_seg": 180, "cover_url": "…" },
  "posicion_seg": 42.3, "volumen": 80, "modo_repeticion": "ninguno",
  "aleatorio": false, "karaoke_activo": false, "karaoke_disponible": true,
  "indice_cola": 4, "dj_activo": false }
```

`modo_repeticion` usa el vocabulario del PC: `ninguno`, `uno`, `todo`. Con `dj_activo` el PC tiene el control y el
teléfono deshabilita sus órdenes.

### 5.1 Cola

Mensaje `{"tipo": "cola", "items": [...], "indice": n}`, que el PC publica ante cada cambio de la cola y al recibir
`queue`.

### 5.2 Órdenes

`{"tipo": "comando", "accion": "<acción>", ...}`:

| Acción | Argumentos |
|---|---|
| `play_pause`, `next`, `prev`, `stop`, `queue`, `karaoke`, `clear_queue` | — |
| `seek` | `posicion_seg` |
| `set_volume` | `volumen` (0 a 100) |
| `play_index` | `indice` |
| `repeat` | `modo` |
| `shuffle` | `activo` |
| `set_queue` | `ids`, `indice`, `posicion_seg?`, `reproducir?` |
| `move_queue` | `desde`, `hasta` |
| `remove_queue` | `indice` |
| `reproducir_pista` | `pista_id`, `posicion_seg` |
| `encolar_pista` | `pista_id` |

Cada orden recibe `{"tipo": "ack", ...}`; el estado que cuenta es el siguiente mensaje `estado`.

## 6. Versiones de sincronización

`sync_version` es un contador global y creciente del PC. El teléfono no la interpreta: guarda la última
`sync_version_actual` aplicada.

## 7. Autoridad

Ver [ADR-002](../adr/002-data-ownership.md).
