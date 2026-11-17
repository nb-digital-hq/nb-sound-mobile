# ADR-001: Flutter, Drift y Riverpod

> **Estado:** Aceptado.

**Fecha:** 2026-11-17

## Contexto

NB Sound Mobile es el acompañante de NB Sound en el teléfono: navega una biblioteca de miles de pistas, reproduce
en segundo plano, guarda música para escucharla sin conexión y controla el reproductor del PC. La suite NB Digital
reserva dos pilas: Rust con Tauri para escritorio y Flutter para móvil y televisión.

## Alternativas consideradas

1. **Nativo por plataforma (Kotlin y Swift).** Máximo control, pero dos bases de código para un equipo pequeño.
2. **Tauri móvil.** Comparte la pila del escritorio, pero el audio en segundo plano, la sesión multimedia del
   sistema y los widgets de pantalla de inicio exigen igualmente código nativo y el soporte es joven.
3. **Flutter.** Una base de código para Android e iOS, rendimiento gráfico estable y paquetes maduros para audio
   en segundo plano (`just_audio`, `audio_service`).

## Decisión

Flutter (Dart 3) con:

| Pieza | Elección | Motivo |
|---|---|---|
| Persistencia | Drift sobre SQLite | Consultas tipadas y reactivas; la biblioteca se ordena y filtra en SQL |
| Estado | Riverpod | Dependencias explícitas y sustituibles en pruebas |
| Navegación | go_router | Rutas declarativas, compatibles con los accesos de los widgets |
| Audio | just_audio, audio_service, audio_session | Reproducción en segundo plano, cola, notificación y pantalla de bloqueo |
| Red | dio y web_socket_channel | Fijación TLS por huella y WebSocket del control remoto |

## Consecuencias

* Lo que depende de servicios propios de Android (MediaStore, efectos de audio, alias del lanzador, widgets,
  instalador de paquetes) se implementa en Kotlin detrás de canales y no existe en iOS
  ([plataformas](007-platforms-and-distribution.md)).
* El código generado (`*.g.dart`, `*.freezed.dart`) no se versiona: se produce con `build_runner`.
