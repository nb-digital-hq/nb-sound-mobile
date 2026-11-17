# Instalación

> **Estado:** Implementado. Android verificado; iOS sin probar en un dispositivo real.

## Android (7.0 o posterior)

1. En la página de publicaciones de `github.com/nb-digital-hq/nb-sound-mobile`, descarga el APK de tu teléfono:
   `arm64-v8a` para casi todos los teléfonos actuales, `armeabi-v7a` para los antiguos de 32 bits, `x86_64` para
   emuladores y Chromebook con Intel o AMD. Si dudas, el `universal` sirve en todos.
2. Ábrelo y permite instalar apps de esa fuente cuando Android lo pida.

Para actualizar: Ajustes (avatar) → General → Acerca de → **Buscar actualizaciones** → **Instalar**. La app
descarga el APK de tu arquitectura, comprueba su huella y abre el instalador. Tus datos se conservan.

## iOS (13 o posterior)

La publicación incluye un `.ipa` **sin firma de Apple y sin probar en un dispositivo real**. Para instalarlo hay que
firmarlo con un certificado propio (por ejemplo, con una cuenta de desarrollador). En iOS no están la música local
del teléfono, el ecualizador, el ícono alternativo, los widgets ni el actualizador.

## Comprobar la descarga

Cada publicación trae `SHA256SUMS` y su firma `SHA256SUMS.sig`. El procedimiento está en
[cadena de suministro](../audit/supply-chain.md).
