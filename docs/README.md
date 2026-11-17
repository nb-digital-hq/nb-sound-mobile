# NB Sound Mobile: documentación

> **Estado:** Aplicable.

Este directorio es la fuente única de verdad de NB Sound Mobile. Lo que no está aquí no es oficial, y si el código
y un documento discrepan hay un defecto que se corrige en uno de los dos.

## Cómo está organizada

| Sección | Pregunta que responde | Audiencia |
|---|---|---|
| [user](user/README.md) | ¿Cómo se usa la aplicación? | Personas que escuchan su música |
| [institution](institution/README.md) | ¿Qué relación tiene NB Sound Mobile con la oferta institucional? | Dirección, TI, áreas legales |
| [architecture](architecture/README.md) | ¿Cómo está construida la app y qué contratos rigen? | Ingeniería |
| [adr](adr/README.md) | ¿Qué se decidió y por qué? | Ingeniería |
| [developer](developer/README.md) | ¿Cómo se trabaja en el código, se prueba y se publica? | Contribuidores |
| [audit](audit/README.md) | ¿Qué garantías de privacidad, seguridad y rendimiento se pueden comprobar? | Auditores, ingeniería |
| [design](design/README.md) | ¿Cómo se ve, se siente y se usa la interfaz? | Diseño, producto, ingeniería |
| [legal](legal/README.md) | ¿Bajo qué condiciones se usa, se contribuye y se distribuye? | Todos |
| [assets](assets/branding/README.md) | Recursos gráficos, capturas y video de la documentación | Todos |

## Documentos de entrada recomendados

- Para **usar** la aplicación: [instalación](user/installation.md) y [primeros pasos](user/getting-started.md).
- Para **construir**: [Constitución](architecture/constitution.md), [arquitectura](architecture/README.md) y
  [puesta en marcha](developer/setup.md).
- Para **contribuir**: [cómo contribuir](../CONTRIBUTING.md) y [normas de código](developer/coding-standards.md).
- Para **auditar**: [privacidad](audit/privacy.md), [modelo de amenazas](audit/threat-model.md) y
  [cadena de suministro](audit/supply-chain.md).

## Convención de estados

Todo documento declara su estado en sus primeras líneas, para distinguir lo implementado de lo que no lo está.

| Etiqueta | Significado |
|---|---|
| **Implementado** | El código refleja lo descrito y puede verificarse en el repositorio |
| **Aceptado** | Una decisión (ADR) vigente; el código la cumple |
| **Aplicable** | Norma o guía vigente |

## Principios de esta documentación

- **Fuente única de verdad.** Cada hecho tiene un documento propietario; el resto enlaza.
- **Texto plano versionado.** Markdown en Git, revisable como el código.
- **Honestidad de estado.** Describir como existente algo que no existe es peor que no documentarlo. Lo que no se
  ha comprobado en un dispositivo real se dice.
- **Registro impersonal y profesional**, sin emoticonos. La documentación está en español; los archivos de
  comunidad de la raíz del repositorio, en inglés.
- **La documentación forma parte del criterio de terminación.** Un cambio con impacto en la arquitectura o en el
  uso no está hecho hasta que su documento lo refleja. `tool/guardianes/docs.dart` comprueba títulos, etiquetas
  de estado, enlaces, emoticonos y rutas de una máquina concreta.
