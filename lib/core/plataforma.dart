import 'package:flutter/foundation.dart';

/// Funciones que dependen de servicios propios de Android (MediaStore, alias
/// del lanzador, widgets de pantalla de inicio, instalador de paquetes y
/// efectos de audio). En iOS esas entradas no se muestran en lugar de fallar.
bool get esAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Versión de la app. La comprueba `tool/guardianes/version.dart` contra
/// `pubspec.yaml`, `CHANGELOG.md` y `CITATION.cff`.
const String kVersionApp = '1.0.0';
