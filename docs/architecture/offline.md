# Sin conexión

> **Estado:** Implementado. `lib/features/offline/`.

## Descargas

* Se descarga por pista, álbum, playlist, selección o la biblioteca entera ("Descargar todo automáticamente").
* Cada pista se descarga completa: audio, portada, foto del artista, letra e instrumental. Las partes son
  independientes; el fallo de una no aborta las demás y se reintenta en la siguiente sincronización.
* El audio se reanuda con `Range`. Al terminar se comprueba el tamaño y la huella ([contrato](pc-contract.md)
  §4.5).
* Las playlists guardadas se mantienen al día: lo que el PC añade se descarga en la siguiente sincronización.
* Antes de encolar, la app comprueba el enlace con el PC: sin PC emparejado propone emparejar; con el PC
  desconectado encola y avisa de que bajará al reconectar.
* Lo que el PC borra se elimina también del teléfono, salvo la descarga, que se conserva hasta que la persona la
  quite.

## Portadas estables

* `CoverResolver` sirve una imagen descargada desde disco y, si no, la del PC con caché en disco de larga vida.
* Antes del primer frame se precargan los ids de portadas y fotos en disco y el PC emparejado, de modo que cada
  portada se resuelve una sola vez, a su fuente definitiva.
* Toda imagen se decodifica al tamaño en que se muestra.
* Las carátulas de la música local se generan en un grupo de tres hilos nativos, en JPEG, y se guardan en la caché
  de la app: en arranques siguientes son una lectura de archivo.

## Espacio

Descargas muestra el espacio ocupado por audio, karaoke e imágenes.
