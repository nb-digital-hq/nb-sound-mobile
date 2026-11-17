# Visión general

> **Estado:** Implementado.

NB Sound Mobile es el acompañante de NB Sound en el teléfono. El PC cataloga y sirve la música por la red local;
el teléfono la navega, la reproduce, la guarda para escucharla sin conexión y controla el reproductor del PC.

```text
 Teléfono                                                    PC (NB Sound)
┌───────────────────────────────────────────────┐         ┌───────────────────┐
│ Interfaz (Flutter)                            │         │ Servidor móvil    │
│  Inicio · Buscar · Biblioteca · Playlists     │         │ HTTPS + WSS       │
│  Reproductor · Perfil · Ajustes               │         │ (huella fijada)   │
├───────────────────────────────────────────────┤         │                   │
│ Estado (Riverpod)                             │  QR     │                   │
│  sync · descargas · reproductor · connect     │◄───────►│ /pair             │
├───────────────────────────────────────────────┤  LAN    │ /manifest         │
│ Datos                                         │◄───────►│ /track/{id}/...   │
│  Drift (SQLite) · archivos sin conexión       │         │ /asset/...        │
│  llavero del sistema (token y huella)         │◄───────►│ /control (WS)     │
├───────────────────────────────────────────────┤         └───────────────────┘
│ lib/core/network: única puerta de red         │
└───────────────────────────────────────────────┘
```

## Módulos

| Carpeta | Responsabilidad |
|---|---|
| `lib/app` | Arranque de la interfaz, pestañas, atajos de teclado |
| `lib/core` | Inyección, red, i18n, enrutado, búsqueda difusa, llavero, utilidades |
| `lib/data` | Esquema Drift, DAOs, DTOs del contrato y el catálogo de demostración |
| `lib/features/sync` | Emparejamiento, descubrimiento mDNS, manifiesto y selección |
| `lib/features/library` | Inicio, búsqueda, biblioteca, detalles, playlists |
| `lib/features/player` | Reproductor, cola, saltos, temporizador, traspaso |
| `lib/features/remote_control` | Control del PC por WebSocket |
| `lib/features/offline` | Cola de descargas, verificación, resolución de portadas |
| `lib/features/local_media` | Música guardada en el teléfono (Android) |
| `lib/features/lyrics`, `karaoke`, `equalizer`, `profile`, `about` | Funciones de la experiencia |
| `lib/shared` | Tema, componentes y utilidades de interfaz |
| `android/app/src/main/kotlin` | MediaStore, carátulas locales, widgets, alias del ícono, instalador |

## Arranque

1. Abre la base de datos y, en la edición de demostración, siembra el catálogo ficticio.
2. Lee preferencias (tema, idioma, aleatorio, repetición) y precarga lo que las portadas necesitan para salir
   estables en el primer frame: qué portadas están en disco y el PC emparejado.
3. Inicia el servicio de audio y monta la interfaz. La sincronización con el PC arranca en segundo plano.
