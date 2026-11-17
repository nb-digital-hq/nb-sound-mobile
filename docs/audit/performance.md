# Rendimiento

> **Estado:** Implementado. Medido en un TCL 50 Pro NXTPAPER (Android 16) con la edición de publicación.

| Presupuesto | Valor | Cómo se cumple |
|---|---|---|
| Arranque en frío hasta la primera pantalla | Por debajo de 1 s | Preferencias y precargas en paralelo antes del primer frame; sincronización en segundo plano |
| Cambio de pista | La interfaz cambia en el mismo frame | Salto optimista con ráfagas fundidas ([reproductor](../architecture/player.md)) |
| Portada al cambiar de pista | Sin placeholder | Precarga de las vecinas en todos sus tamaños |
| Portadas al abrir la app | Una sola resolución por portada, a su fuente definitiva | Precarga de ids en disco y del PC emparejado ([sin conexión](../architecture/offline.md)) |
| Desplazamiento en bibliotecas de miles de pistas | Sin saltos | Listas perezosas, imágenes decodificadas al tamaño mostrado, caché de imágenes de 200 MB |
| Interfaz durante la sincronización | Sin bloqueo | Base de datos en un aislado; una transacción por página |

Las pruebas de `test/features/player/` y `test/features/remote_control/salto_optimista_test.dart` cubren la lógica
de los saltos; la fluidez se comprueba en el dispositivo con el paquete de publicación.
