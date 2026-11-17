# Política de dependencias

> **Estado:** Aplicable. La licencia la comprueba `tool/guardianes/licencias.dart`.

Una dependencia nueva se justifica en su pull request por tres criterios:

1. **Coste:** qué añade al tamaño del APK y al arranque, y si el SDK ya lo resuelve.
2. **Licencia:** solo Apache-2.0, MIT, BSD, ISC o Zlib en lo que se distribuye. Nada GPL, AGPL o LGPL, ninguna MPL
   y ningún binario propietario (como Google ML Kit o los servicios de Google Play).
3. **Mantenimiento:** publicaciones recientes y compatibilidad con la versión estable de Flutter.

`THIRD-PARTY-NOTICES.md` se regenera con `dart run tool/guardianes/licencias.dart --escribir`; la CI falla si está
desactualizado. Las fuentes empaquetadas (Manrope y Space Grotesk) tienen la SIL Open Font License 1.1.
