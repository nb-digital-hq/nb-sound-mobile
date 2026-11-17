# Atajos del proyecto. Cada receta es un comando de Flutter o Dart, para que
# la CI y la verificación local ejecuten exactamente lo mismo.

setup:
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs

run:
    flutter run

demo:
    flutter run --dart-define=NB_SEED=true

test:
    flutter test

guardianes:
    dart run tool/guardianes/todos.dart

verify: setup
    dart format --output=none --set-exit-if-changed lib test tool
    flutter analyze
    flutter test
    dart run tool/guardianes/todos.dart

apk:
    flutter build apk --release --split-per-abi
    flutter build apk --release
