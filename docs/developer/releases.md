# Publicación

> **Estado:** Implementado. Lista de quien publica una versión.

## Versionado

Versionado semántico. La versión se cambia a la vez en `pubspec.yaml` (con el `+build` incrementado),
`lib/core/plataforma.dart`, `CHANGELOG.md` y `CITATION.cff`; `tool/guardianes/version.dart` comprueba que
coincidan, con la misma fecha.

## Lista

1. `just verify` en verde y la CI de `main` en verde.
2. APK de publicación firmados en local: por ABI y universal ([empaquetado](packaging.md)).
3. Prueba en un dispositivo real instalando encima de la versión anterior: la biblioteca, el historial y las
   descargas sobreviven.
4. Ejecutar `ediciones.yml` y descargar el `.ipa` sin firmar.
5. Montar la carpeta de la publicación:

| Archivo | Qué es |
|---|---|
| `NB-Sound-Mobile-<v>-arm64-v8a.apk`, `-armeabi-v7a.apk`, `-x86_64.apk` | APK por arquitectura (los que usa el actualizador) |
| `NB-Sound-Mobile-<v>-universal.apk` | APK para cualquier arquitectura |
| `NB-Sound-Mobile-<v>-ios-unsigned.ipa` | iOS, sin probar |
| `THIRD-PARTY-NOTICES.md` | Avisos de terceros |
| `SHA256SUMS`, `SHA256SUMS.sig` | Huellas y su firma Ed25519 |

6. Firmar la lista:

```bash
sha256sum NB-Sound-Mobile-* THIRD-PARTY-NOTICES.md > SHA256SUMS
openssl pkeyutl -sign -inkey <clave-privada.der> -keyform DER -rawin -in SHA256SUMS -out SHA256SUMS.sig
openssl pkeyutl -verify -pubin -inkey docs/architecture/api/clave-de-publicacion.pem \
  -rawin -in SHA256SUMS -sigfile SHA256SUMS.sig
```

7. Crear la publicación `v<versión>` con esos archivos; las notas salen de `CHANGELOG.md` y dicen qué está
   verificado y qué no.

## Actualización en Android

Acerca de, "Buscar actualizaciones" consulta la última publicación, elige el APK de la ABI del dispositivo (el
universal solo si no hay por ABI), comprueba tamaño y SHA-256 y lo entrega al instalador del sistema.

## Soporte

Recibe correcciones la última versión publicada.
