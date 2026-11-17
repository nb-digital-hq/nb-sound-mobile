# Pruebas

> **Estado:** Implementado.

| Suite | Qué cubre |
|---|---|
| `test/data` | DAOs, DTOs del contrato, migraciones desde la versión 1, catálogo y media de demostración |
| `test/features/sync` | QR, emparejamiento, descubrimiento, manifiesto paginado, lápidas, favoritos |
| `test/features/offline` | Descargas completas, reanudación, verificación, resiliencia, portadas estables |
| `test/features/player` | Cola, aleatorio, saltos, traspaso, temporizador, autoplay |
| `test/features/remote_control` | Mensajes del WebSocket contra un servidor local, saltos optimistas |
| `test/features/library`, `lyrics`, `local_media`, `about`, `equalizer` | Lógica de cada función |
| `test/core`, `test/shared`, `test/app` | Búsqueda difusa, i18n, componentes, navegación atrás |

## Guardianes

`dart run tool/guardianes/todos.dart` ejecuta:

| Guardián | Comprueba |
|---|---|
| `red` | Ningún cliente de red fuera de `lib/core/network/`; ninguna conexión nativa |
| `registro` | Ningún registro en Dart ni en Kotlin |
| `secretos` | Ni claves privadas ni almacenes de firma ni configuración de herramientas de agentes |
| `i18n` | Toda clave traducida en inglés y portugués, con los mismos marcadores; ninguna sobrante |
| `licencias` | Licencias permitidas y `THIRD-PARTY-NOTICES.md` al día |
| `version` | Misma versión y fecha en `pubspec.yaml`, la app, `CHANGELOG.md` y `CITATION.cff` |
| `docs` | Títulos, estados, enlaces, emoticonos, rutas locales y pendientes |

## En un dispositivo

La lógica la cubren las suites; la experiencia se comprueba con el paquete de publicación instalado, nunca con
`flutter run`, usando la edición de demostración o un PC con datos de prueba.
