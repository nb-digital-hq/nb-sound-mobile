# ADR-005: Escáner QR con ZXing

> **Estado:** Aceptado.

**Fecha:** 2026-11-17

## Contexto

El emparejamiento empieza escaneando el QR que muestra NB Sound en el PC. El paquete habitual en Flutter usa en
Android Google ML Kit, un binario propietario que se distribuye dentro del APK.

## Alternativas consideradas

1. **ML Kit.** Detección rápida, pero mete en la app un componente cerrado con sus propios términos, incompatible
   con el modelo de [licencias](003-licensing-model.md).
2. **ZXing (`flutter_zxing`, MIT, sobre zxing-cpp con licencia Apache-2.0)** por FFI, con la cámara de CameraX.
3. **Solo código manual.** Ya existe como respaldo, pero obliga a teclear.

## Decisión

`flutter_zxing`, limitado a códigos QR, con el emparejamiento por dirección IP y código de 8 caracteres como
alternativa sin cámara.

## Consecuencias

* Todo lo que se distribuye es código abierto. El APK no lleva servicios de Google.
* R8 no necesita reglas para el escáner: el código nativo se resuelve por símbolo desde Dart.
