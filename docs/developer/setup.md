# Puesta en marcha

> **Estado:** Aplicable.

## Herramientas

* Flutter estable 3.41 o posterior (Dart 3.11), Android SDK 36 y JDK 17 o posterior.
* `just` para los atajos (opcional: cada receta es un comando de Flutter o Dart).
* Para iOS: macOS con Xcode.

## Primeros comandos

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # código generado
just verify                                                # o los comandos de abajo
flutter run                                                # dispositivo o emulador Android
```

`just verify` equivale a:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/guardianes/todos.dart
```

## Sin PC: la edición de demostración

```bash
flutter run --dart-define=NB_SEED=true
```

Siembra un catálogo ficticio (artistas, álbumes, playlists, historial) y genera en el propio dispositivo sus
portadas, un audio sintetizado y letras originales. Es la edición con la que se hacen las capturas y el video. Solo
actúa sobre una base vacía.
