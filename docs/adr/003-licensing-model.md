# ADR-003: Modelo de licencias

> **Estado:** Aceptado.

**Fecha:** 2026-11-17

## Contexto

NB Digital publica sus aplicaciones para personas como código abierto y vende, por separado, módulos y servicios
de gobernanza a instituciones. NB Sound Mobile es una aplicación para personas.

## Alternativas consideradas

1. **Licencia permisiva con frontera arquitectónica.** Adopción máxima y contribución sin acuerdos de cesión.
2. **Licencia recíproca con licencia dual.** Exigiría un acuerdo de cesión a cada contribuidor.
3. **Sin publicar el código.** Contradice el modelo de la suite.

## Decisión

| Elemento | Decisión |
|---|---|
| Licencia del código y de la documentación | Apache License 2.0 |
| Procedencia de contribuciones | DCO: `Signed-off-by` en cada commit |
| Aviso de copyright | `Copyright 2026 The NB Sound Mobile Authors` |
| Marcas | "NB", "NB Digital", "NB Sound" y "NB Sound Mobile" y sus logotipos quedan fuera de la licencia |
| Frontera comercial | Los módulos institucionales de NB Digital son productos distintos; la app no depende de ninguno |

Apache 2.0 aporta, frente a MIT, la concesión expresa de patentes, la exclusión expresa de las marcas y la
obligación de conservar `NOTICE`.

## Consecuencias

* Todo lo que se distribuye dentro de la app es compatible con Apache 2.0 y abierto: nada GPL, AGPL ni LGPL, y
  ningún componente propietario ([ADR-005](005-qr-scanner.md)). Lo hace cumplir `tool/guardianes/licencias.dart`.
* Ningún código de la app llama a un servicio comercial ni comprueba licencias. Ver
  [licencias](../legal/licensing.md) e [institución](../institution/README.md).
