# Avisos de terceros

> **Estado:** Implementado. Se genera con `dart run tool/guardianes/licencias.dart --escribir`.

`THIRD-PARTY-NOTICES.md`, en la raíz, contiene el texto completo de la licencia de cada paquete que se distribuye
con la app, a partir de `pubspec.lock`. La CI falla si no coincide con las dependencias. Cada publicación lo
adjunta.

Además de los paquetes de Dart, la app incluye las fuentes Manrope y Space Grotesk (SIL Open Font License 1.1) y,
a través de esos paquetes, bibliotecas nativas con licencias permisivas: AndroidX y CameraX (Apache-2.0),
zxing-cpp (Apache-2.0) y SQLite (dominio público).
