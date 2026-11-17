# Constitución

> **Estado:** Aplicable. Se modifica únicamente mediante un ADR aceptado.

Ningún cambio se integra en `main` si rompe una de estas reglas. Cada regla dice qué la hace cumplir: una regla
sin mecanismo es una intención.

## 1. Nada sale del teléfono sin que la persona lo pida

La app solo habla con el PC que la persona emparejó y, en Android, con GitHub cuando pulsa "Buscar
actualizaciones". No hay telemetría, analítica, informes de fallos ni cuentas.

**Mecanismo:** `tool/guardianes/red.dart` rechaza cualquier cliente de red fuera de `lib/core/network/` y cualquier
conexión en el código nativo ([ADR-004](../adr/004-network-exit.md)).

## 2. Nada de la persona en los registros

La app no escribe registros: ni `print` en Dart ni `Log` en Kotlin. Títulos, rutas y direcciones del PC no llegan
nunca al logcat.

**Mecanismo:** `tool/guardianes/registro.dart`.

## 3. Lo de la persona es intocable

Historial, favoritos, playlists locales, descargas y preferencias sobreviven a una sincronización, a un cambio de
PC y a una actualización de la app. La música local del teléfono no se borra nunca desde la app: ocultarla la quita
de la biblioteca, no del almacenamiento.

**Mecanismo:** las tablas propias del teléfono no se tocan desde el aplicador del manifiesto, y las migraciones de
Drift tienen prueba ([almacenamiento](storage.md)).

## 4. El PC manda en su catálogo

El teléfono no edita metadatos del PC ni inventa versiones de sincronización. Lo que el PC borra desaparece del
teléfono con su lápida, salvo lo descargado, que se conserva hasta que la persona lo quite.

**Mecanismo:** pruebas de `test/features/sync/` contra el contrato ([ADR-002](../adr/002-data-ownership.md)).

## 5. Lo que se distribuye es abierto

Todo componente dentro del APK o del `.ipa` es compatible con Apache 2.0 y de código abierto.

**Mecanismo:** `tool/guardianes/licencias.dart` clasifica cada paquete del `pubspec.lock` y regenera los avisos
([ADR-003](../adr/003-licensing-model.md)).

## 6. Toda la interfaz en tres idiomas

Ningún texto visible queda solo en español.

**Mecanismo:** `tool/guardianes/i18n.dart` ([ADR-006](../adr/006-internationalization.md)).

## 7. La documentación es parte del cambio

Un cambio con impacto en la arquitectura o en el uso no está terminado hasta que su documento lo refleja, con su
etiqueta de estado.

**Mecanismo:** revisión y `tool/guardianes/docs.dart`.
