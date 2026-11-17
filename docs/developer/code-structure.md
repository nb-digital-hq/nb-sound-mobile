# Estructura del código

> **Estado:** Implementado. La responsabilidad de cada módulo está en [visión general](../architecture/system-overview.md).

```text
lib/
  app/            Interfaz raíz, pestañas, atajos de teclado
  core/           di, i18n, network (única puerta de red), router, search, security, utils
  data/           Drift: tablas, DAOs, migraciones; DTOs del contrato; catálogo de demostración
  features/       Una carpeta por función: application (estado), data (acceso), presentation (pantallas)
  shared/         Tema, componentes y utilidades de interfaz
android/app/src/main/kotlin/   MediaStore, carátulas, widgets, ícono alternativo, instalador
ios/Runner/                    Proyecto iOS
test/             Espejo de lib/
tool/guardianes/  Guardianes de verificación
tool/gen_app_icons.py          Íconos desde el SVG del logotipo
```

Convenciones: identificadores y comentarios en español; un `Notifier` por estado; las pantallas leen estado con
`ref.watch` y nunca llaman a la red ni a la base directamente.
