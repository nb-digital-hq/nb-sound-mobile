# Licencias

> **Estado:** Aplicable. Decisión: [ADR-003](../adr/003-licensing-model.md).

## Decisión vigente

| Elemento | Decisión |
|---|---|
| Licencia del código | **Apache License 2.0** |
| Licencia de la documentación | Apache License 2.0 |
| Modelo de NB Digital | Aplicaciones para personas de código abierto; módulos y servicios institucionales con licencia comercial, separados |
| Procedencia de las contribuciones | **DCO** (`Signed-off-by`), sin acuerdo de cesión |
| Aviso de copyright | `Copyright 2026 The NB Sound Mobile Authors`; cada contribuidor conserva el suyo |
| Marcas | "NB", "NB Digital", "NB Sound" y "NB Sound Mobile", fuera de la licencia; ver [marcas](trademark.md) |

`LICENSE` y `NOTICE` están en la raíz del repositorio.

## Qué significa

* **Para quien usa la app:** puede usarla, modificarla, redistribuirla e incorporarla en productos propios,
  incluidos los comerciales, conservando el aviso de copyright, la licencia, `NOTICE` y la indicación de los
  cambios. No obtiene derecho a usar el nombre ni el logotipo.
* **Para quien contribuye:** conserva el copyright de su aportación y la licencia bajo Apache 2.0, declarando su
  origen con `git commit -s`.
* **Para una institución:** Apache 2.0 está aprobada por la Open Source Initiative e incluye concesión de patentes.

## La frontera con lo comercial

| Componente | Licencia |
|---|---|
| NB Sound Mobile: app, código nativo, herramientas y documentación | Apache 2.0 |
| Fuentes Manrope y Space Grotesk | SIL Open Font License 1.1 |
| Dependencias | La de cada una ([avisos](third-party-notices.md)), todas permisivas |
| Módulos y servicios institucionales de NB Digital | Licencia comercial, fuera de este repositorio |

Ningún componente de la app depende de un producto comercial. Un cambio que introduzca esa dependencia se rechaza.

## Consecuencias operativas

* **Dependencias:** solo Apache-2.0, MIT, BSD, ISC y Zlib; sin GPL, AGPL, LGPL ni binarios propietarios
  ([política de dependencias](../architecture/dependency-policy.md)). El escáner QR usa ZXing en lugar de ML Kit por
  esta razón ([ADR-005](../adr/005-qr-scanner.md)).
* **Contenido de demostración:** el catálogo de las capturas y del video es ficticio y generado por la app; el
  repositorio no contiene música, portadas ni letras de terceros.
