# ADR-006: Internacionalización

> **Estado:** Aceptado.

**Fecha:** 2026-11-17

## Contexto

La interfaz tiene unos cuatrocientos textos. La suite publica sus aplicaciones en español, inglés y portugués.

## Alternativas consideradas

1. **ARB con `gen_l10n`.** Claves artificiales y una capa generada; cada texto pasa por un `BuildContext`.
2. **Texto fuente en español como clave**, con catálogos de traducción y un guardián que los compare.

## Decisión

* Los textos se escriben en español dentro de `tr('...')`; `lib/core/i18n/en.dart` y `pt.dart` traducen desde ese
  texto. Los marcadores `{nombre}` se sustituyen en el idioma activo.
* El idioma se elige en Configuración (del sistema, español, inglés o portugués) y se guarda en el teléfono. Al
  cambiarlo se reconstruye la interfaz entera.
* Los textos de Android fuera de Flutter (widgets, nombres de los widgets) usan recursos `values`, `values-en` y
  `values-pt`.
* `tool/guardianes/i18n.dart` falla si un texto no tiene traducción, si los marcadores no coinciden o si una
  traducción sobra.

## Consecuencias

* Un texto sin traducir no queda vacío: cae en español y el guardián lo señala.
* El catálogo de la PC (títulos, artistas) no se traduce: es contenido de la persona.
* Ver [internacionalización](../architecture/i18n.md).
