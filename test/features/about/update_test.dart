import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/about/data/update_service.dart';

ApkPublicado _a(String n) => ApkPublicado(nombre: n, url: 'u/$n', bytes: 1);

void main() {
  test('compararVersiones', () {
    expect(compararVersiones('0.1.3', '0.1.2'), greaterThan(0));
    expect(compararVersiones('0.1.2', '0.1.2'), 0);
    expect(compararVersiones('0.2.0', '0.10.0'), lessThan(0));
    expect(compararVersiones('1.0', '0.9.9'), greaterThan(0));
    expect(compararVersiones('0.1.2+4', '0.1.2'), 0);
  });

  final List<ApkPublicado> apks = <ApkPublicado>[
    _a('NB-Sound-0.1.3-universal.apk'),
    _a('NB-Sound-0.1.3-armeabi-v7a.apk'),
    _a('NB-Sound-0.1.3-arm64-v8a.apk'),
  ];

  test('elige el APK de la ABI preferida, nunca el universal', () {
    expect(
      elegirApk(apks, <String>['arm64-v8a', 'armeabi-v7a'])!.nombre,
      'NB-Sound-0.1.3-arm64-v8a.apk',
    );
    expect(
      elegirApk(apks, <String>['armeabi-v7a'])!.nombre,
      'NB-Sound-0.1.3-armeabi-v7a.apk',
    );
    expect(elegirApk(apks, <String>['x86_64']), isNull);
  });

  test('sin APKs por ABI usa el universal', () {
    expect(
      elegirApk(
        <ApkPublicado>[_a('NB-Sound-1.0.0-universal.apk')],
        <String>['arm64-v8a'],
      )!.nombre,
      'NB-Sound-1.0.0-universal.apk',
    );
  });

  test('Publicacion.fromJson lee tag, notas, APKs y digest', () {
    final Publicacion p = Publicacion.fromJson(<String, dynamic>{
      'tag_name': 'v0.1.3',
      'body': ' Novedades ',
      'html_url': 'https://x',
      'assets': <Object>[
        <String, dynamic>{
          'name': 'NB-Sound-0.1.3-arm64-v8a.apk',
          'browser_download_url': 'https://d',
          'size': 10,
          'digest': 'sha256:ABC',
        },
        <String, dynamic>{'name': 'notas.txt', 'size': 1},
      ],
    });
    expect(p.version, '0.1.3');
    expect(p.notas, 'Novedades');
    expect(p.apks.single.sha256, 'abc');
  });
}
