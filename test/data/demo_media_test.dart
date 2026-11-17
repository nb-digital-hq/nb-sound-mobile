import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/seed/demo_media.dart';
import 'package:nb_sound_mobile/data/db/seed/dev_seed.dart';

void main() {
  test(
    'la pieza sintetizada es un WAV PCM mono de 16 kHz con la duración pedida',
    () {
      final Uint8List wav = sintetizarPieza((3, 0));
      final ByteData d = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(d.getUint16(22, Endian.little), 1); // canales
      expect(d.getUint32(24, Endian.little), 16000);
      expect(d.getUint32(40, Endian.little), 3 * 16000 * 2);
      expect(wav.length, 44 + 3 * 16000 * 2);
    },
  );

  test('el catálogo de demostración es coherente: cada pista apunta a un álbum '
      'y un artista existentes y cada playlist a pistas existentes', () {
    final Set<int> albums = <int>{for (final a in demoAlbums) a.$1};
    final Set<int> artistas = <int>{for (final a in demoArtistas) a.$1};
    final Set<int> pistas = <int>{for (final p in demoPistas) p.$1};
    for (final p in demoPistas) {
      expect(albums, contains(p.$4));
      expect(artistas, contains(p.$3));
    }
    for (final pl in demoPlaylists) {
      expect(pistas.containsAll(pl.$4), isTrue);
    }
  });
}
