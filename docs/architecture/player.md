# Reproductor

> **Estado:** Implementado. `lib/features/player/`.

## Piezas

| Pieza | Papel |
|---|---|
| `NbAudioHandler` | Puente con `just_audio` y la sesión multimedia del sistema (notificación, pantalla de bloqueo, auriculares) |
| `PlayerController` | Estado que ve la interfaz: cola, índice, posición, modos, karaoke |
| `NbShuffleOrder` | Orden aleatorio que respeta lo puesto "a continuación" y "en cola" |
| `playback.dart` | Destino (este teléfono o el PC) y traspaso entre ambos |
| `sleep_timer.dart` | Temporizador por minutos o al terminar la canción |
| `cover_prefetch.dart` | Precarga de las portadas vecinas |

## Fuentes de audio

En orden: instrumental del karaoke (descargado o del PC), archivo descargado, música local (`content://`) y
transmisión desde el PC. La resolución está en `NbAudioHandler._toAudioSource`; la transmisión se construye en la
puerta de red.

## Saltos de pista

Siguiente, anterior y tocar la cola actualizan la interfaz en el mismo frame. El motor nativo se pone al día detrás:

* el primer salto de una ráfaga va directo al motor;
* los siguientes dentro de 220 ms se funden y solo se carga el último;
* mientras el salto está pendiente se ignoran los índices y posiciones que el motor aún emite de la pista anterior;
* historial, sesión y autoplay se registran una vez, para la pista final.

La pantalla del reproductor no se reconstruye con la posición (solo la barra de progreso la sigue), y su fondo
difuminado se pinta desde una miniatura de 64 px. Las portadas de la siguiente, la anterior y la de después se
decodifican por adelantado en todos los tamaños en que se muestran.

## Cola

"Reproducir a continuación" inserta justo detrás de la actual; "añadir a la cola" detrás de lo ya encolado, antes
del resto de la colección, también con aleatorio. Al llegar al final sin repetición, el autoplay añade pistas
relacionadas de la biblioteca.

## Sesión

La cola, el índice y la posición se guardan al cambiar de pista y al pasar a segundo plano, y se restauran en pausa
al abrir la app. Quitar la app de recientes detiene la reproducción y el servicio.

## Ecualizador y efectos

En Android: ecualizador del sistema por bandas, presets, normalizador de volumen (`LoudnessEnhancer`) y omitir
silencios. Velocidad de 0,5× a 2×.
