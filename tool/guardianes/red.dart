import 'dart:io';

import 'comun.dart';

// La única puerta de red es lib/core/network/. Fuera de ella no se construye
// ningún cliente HTTP, socket, WebSocket ni imagen o audio remotos; así cada
// salida del dispositivo pasa por un punto revisable (docs/audit/privacy.md).
final List<(RegExp, String)> _prohibido = <(RegExp, String)>[
  (RegExp(r'\bDio\s*\('), 'cliente Dio'),
  (RegExp(r'\bHttpClient\s*\('), 'HttpClient'),
  (RegExp(r'\b(Raw)?(Secure)?Socket\.connect\b'), 'socket'),
  (RegExp(r'WebSocketChannel\.connect|IOWebSocketChannel'), 'WebSocket'),
  (RegExp(r'\b(Cached)?NetworkImage(Provider)?\s*\('), 'imagen remota'),
  (RegExp(r"package:http/"), 'paquete http'),
  (
    RegExp(r'AudioSource\.uri\('),
    'audio por URI (marcar "red: no" si es local)',
  ),
];

void main() {
  final Informe inf = Informe('red');
  for (final File f in archivos(<String>['lib/'], <String>['.dart'])) {
    if (f.path.startsWith('lib/core/network/')) {
      continue;
    }
    final List<String> lineas = f.readAsLinesSync();
    for (int i = 0; i < lineas.length; i++) {
      final String l = lineas[i];
      if (l.trimLeft().startsWith('//') || l.contains('// red: no')) {
        continue;
      }
      for (final (RegExp re, String que) in _prohibido) {
        if (re.hasMatch(l)) {
          inf.fallo('${f.path}:${i + 1}', '$que fuera de lib/core/network/');
        }
      }
    }
  }
  // Lado nativo: Android no abre conexiones propias (solo instala el APK que
  // el lado Dart ya descargó y verificó).
  for (final File f in archivos(
    <String>['android/app/src/'],
    <String>['.kt', '.java'],
  )) {
    final List<String> lineas = f.readAsLinesSync();
    for (int i = 0; i < lineas.length; i++) {
      if (RegExp(
        r'HttpURLConnection|URL\(|OkHttp|Socket\(',
      ).hasMatch(lineas[i])) {
        inf.fallo('${f.path}:${i + 1}', 'conexión de red en código nativo');
      }
    }
  }
  exit(inf.cerrar());
}
