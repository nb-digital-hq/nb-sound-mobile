import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/search/fuzzy.dart';

void main() {
  group('normalizar', () {
    test('minúsculas, sin acentos, puntuación a espacio', () {
      expect(normalizar('Café  Tacvba!'), 'cafe tacvba');
      expect(normalizar('  Ñandú  '), 'nandu');
      expect(normalizar('AC/DC'), 'ac dc');
      expect(normalizar('Sigur Rós'), 'sigur ros');
    });
    test('vacío y solo símbolos', () {
      expect(normalizar(''), '');
      expect(normalizar('—··—'), '');
    });
    test('los apóstrofes no parten palabras (símbolos perdonados)', () {
      // "Ain't" y "aint" deben normalizar igual para que la búsqueda perdone el
      // apóstrofe (recto o tipográfico).
      expect(normalizar("If It Ain't Me"), 'if it aint me');
      expect(normalizar('If It Ain’t Me'), 'if it aint me');
      expect(normalizar('if it aint me'), 'if it aint me');
      expect(normalizar("Don't"), 'dont');
    });
  });

  group("búsqueda perdona apóstrofes (caso del usuario)", () {
    test('"if it aint me" encuentra "If It Ain\'t Me"', () {
      final String objetivo = normalizar("If It Ain't Me");
      final List<String> tokens = tokenizar(objetivo);
      // Sin apóstrofe en la query coincide exactamente (1.0); con apóstrofe igual.
      expect(puntuarTexto(normalizar('if it aint me'), objetivo, tokens), 1.0);
      expect(puntuarTexto(normalizar("if it ain't me"), objetivo, tokens), 1.0);
    });
  });

  group('distanciaAcotada', () {
    test('iguales ⇒ 0', () {
      expect(distanciaAcotada('midnight', 'midnight', 2), 0);
    });
    test('dentro de la cota', () {
      expect(distanciaAcotada('midnght', 'midnight', 2), 1); // borrar 1
      expect(distanciaAcotada('mxdnxght', 'midnight', 2), 2); // 2 sustituciones
    });
    test('supera la cota ⇒ -1', () {
      expect(distanciaAcotada('xyz', 'midnight', 2), -1);
      expect(distanciaAcotada('midnight', 'morning', 2), -1);
    });
    test('objetivo más largo que la consulta: sin falsos "distancia 1"', () {
      // Regresión: celdas fuera de la banda valían 0 y cualquier palabra más
      // larga salía a distancia 1 ("taki" encontraba "Índigo", "Aurora"...).
      for (final String w in <String>['indigo', 'harder', 'aurora', 'walker']) {
        expect(distanciaAcotada('taki', w, 2), -1, reason: w);
      }
      expect(distanciaAcotada('taki', 'takis', 2), 1);
      expect(distanciaAcotada('taki', 'tokyo', 2), -1);
      expect(distanciaAcotada('beyonse', 'beyonce', 2), 1);
    });
    test('coincide con Levenshtein completo en pares al azar', () {
      int lev(String a, String b) {
        final List<List<int>> d = List<List<int>>.generate(
          a.length + 1,
          (int i) => List<int>.generate(
            b.length + 1,
            (int j) => i == 0 ? j : (j == 0 ? i : 0),
          ),
        );
        for (int i = 1; i <= a.length; i++) {
          for (int j = 1; j <= b.length; j++) {
            final int c = a[i - 1] == b[j - 1] ? 0 : 1;
            d[i][j] = <int>[
              d[i - 1][j] + 1,
              d[i][j - 1] + 1,
              d[i - 1][j - 1] + c,
            ].reduce((int x, int y) => x < y ? x : y);
          }
        }
        return d[a.length][b.length];
      }

      const List<String> ws = <String>[
        'taki',
        'indigo',
        'camilo',
        'bad',
        'bunny',
        'marisol',
        'marsol',
        'ivonne',
        'ivone',
        'midnight',
        'midnite',
        'kenia',
        'carol',
        'to',
        'tu',
      ];
      for (final String a in ws) {
        for (final String b in ws) {
          for (int k = 0; k <= 3; k++) {
            final int real = lev(a, b);
            expect(
              distanciaAcotada(a, b, k),
              real <= k ? real : -1,
              reason: '$a/$b k=$k',
            );
          }
        }
      }
    });
  });

  group('puntuarTexto (ranking)', () {
    List<String> tk(String s) => tokenizar(normalizar(s));

    test('exacto = 1.0', () {
      expect(
        puntuarTexto('midnight city', 'midnight city', tk('midnight city')),
        1.0,
      );
    });

    test('prefijo > subcadena > token-substring', () {
      final double prefijo = puntuarTexto(
        'mid',
        'midnight city',
        tk('midnight city'),
      );
      final double subcadena = puntuarTexto(
        'ght',
        'midnight city',
        tk('midnight city'),
      );
      expect(prefijo, greaterThan(subcadena));
      expect(prefijo, greaterThan(0.85));
    });

    test('typo en un token sigue coincidiendo (tolerancia)', () {
      // "midnght" → token "midnight" con distancia 1.
      final double s = puntuarTexto(
        'midnght',
        'midnight city',
        tk('midnight city'),
      );
      expect(s, greaterThan(0.3));
    });

    test('coincidencia exacta puntúa por encima de un typo', () {
      final double exacto = puntuarTexto(
        'midnight',
        'midnight city',
        tk('midnight city'),
      );
      final double conTypo = puntuarTexto(
        'midnght',
        'midnight city',
        tk('midnight city'),
      );
      expect(exacto, greaterThan(conTypo));
    });

    test('sin relación ⇒ 0', () {
      expect(puntuarTexto('zzqwx', 'midnight city', tk('midnight city')), 0);
    });

    test('acentos no estorban (se comparan ya normalizados)', () {
      final String objetivo = normalizar('Rosalía');
      final double s = puntuarTexto('rosalia', objetivo, tokenizar(objetivo));
      expect(s, 1.0);
    });
  });

  group('maxDistPara', () {
    test('más permisivo cuanto más larga la consulta', () {
      expect(maxDistPara(2), 0);
      expect(maxDistPara(3), 1);
      expect(maxDistPara(4), 1);
      expect(maxDistPara(5), 1);
      expect(maxDistPara(7), 2);
      expect(maxDistPara(9), 3);
    });
    test('prefijo de palabra entera gana a prefijo a mitad de palabra', () {
      List<String> tk(String s) => tokenizar(normalizar(s));
      expect(
        puntuarTexto('hola', 'hola remix', tk('hola remix')),
        greaterThan(puntuarTexto('hola', 'holanda', tk('holanda'))),
      );
    });
    test('subsecuencia solo si es compacta', () {
      List<String> tk(String s) => tokenizar(normalizar(s));
      expect(
        puntuarTexto('mdnght', 'midnight city', tk('midnight city')),
        greaterThan(0),
      );
      // h…o…l…a repartidas por un título largo: no es coincidencia.
      expect(
        puntuarTexto('hola', 'hello my love again', tk('hello my love again')),
        0,
      );
    });
    test('consultas cortas no casan con palabras a 2 errores', () {
      List<String> tk(String s) => tokenizar(normalizar(s));
      expect(puntuarTexto('hola', 'a ella', tk('a ella')), 0);
      expect(puntuarTexto('hola', 'a partir de hoy', tk('a partir de hoy')), 0);
      expect(
        puntuarTexto('taki', 'harder to breathe', tk('harder to breathe')),
        0,
      );
      // Un error sí se perdona.
      expect(
        puntuarTexto('tsaki', 'taki taki', tk('taki taki')),
        greaterThan(0),
      );
    });
  });
}
