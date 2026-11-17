# ADR-002: El PC es la fuente de verdad del catálogo

> **Estado:** Aceptado.

**Fecha:** 2026-11-17

## Contexto

NB Sound en el PC cataloga, enriquece y analiza la música (portadas, letras, instrumentales). El teléfono tiene
menos espacio, menos batería y no ve los archivos originales. A la vez, lo que la persona escucha y marca en el
teléfono ocurre allí.

## Alternativas consideradas

1. **El teléfono como catálogo independiente.** Duplicaría el trabajo de catalogación y divergiría del PC.
2. **Sincronización bidireccional completa.** Conflictos en metadatos que el teléfono no puede resolver bien.
3. **Autoridad repartida por tipo de dato.**

## Decisión

| Dato | Quién manda | Cómo viaja |
|---|---|---|
| Catálogo: pistas, álbumes, artistas, playlists del PC, portadas, letras, instrumentales | PC | Manifiesto delta, solo lectura en el teléfono |
| Historial de escuchas del teléfono | Teléfono | Se sube y el PC lo añade |
| Favoritos | La escritura más reciente | Marca de tiempo por favorito |
| Playlists locales, música del teléfono, preferencias | Teléfono | No salen del teléfono |

La sincronización viaja solo por la red local, iniciada por el QR del PC; no hay nube ni cuenta.

## Consecuencias

* La música local del teléfono usa identificadores negativos en las mismas tablas, y ninguna operación hacia el PC
  acepta un identificador negativo ([almacenamiento](../architecture/storage.md)).
* Un re-sync nunca pisa descargas, playlists locales ni preferencias: viven en tablas propias.
* El contrato con el PC es aditivo: el teléfono ignora campos desconocidos ([contrato](../architecture/pc-contract.md)).
