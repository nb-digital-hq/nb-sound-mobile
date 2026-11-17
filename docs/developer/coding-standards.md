# Normas de código

> **Estado:** Aplicable.

* `analysis_options.yaml` con `flutter_lints` y reglas estrictas de tipos; `flutter analyze` sin avisos.
* `dart format` sin cambios.
* Identificadores, comentarios y documentación en español. Los comentarios explican **por qué**: lo descartado y la
  razón cuando la decisión no es obvia. No narran el historial del código.
* Sin emoticonos en ninguna parte ni marcas de trabajo pendiente.
* Textos visibles siempre con `tr('...')` ([internacionalización](../architecture/i18n.md)).
* Nada de red fuera de `lib/core/network/` y nada de registros ([Constitución](../architecture/constitution.md)).
* Los errores esperables se convierten en estados de la interfaz con un mensaje para la persona; ninguna pantalla
  muestra trazas.
* Cada propiedad nueva lleva su prueba y cada defecto corregido, su prueba de regresión. Las pruebas se nombran por
  la propiedad que comprueban.
