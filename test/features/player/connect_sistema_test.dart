import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/player/application/playback.dart';
import 'package:nb_sound_mobile/features/player/application/player_controller.dart';
import 'package:nb_sound_mobile/features/remote_control/data/remote_dtos.dart';

void main() {
  group('mediaItemRemoto (notificación en modo Connect)', () {
    test('usa la portada local del álbum extraído de cover_url', () {
      int? pedido;
      final item = mediaItemRemoto(
        const RemotePistaDto(
          id: 7,
          titulo: 'Tema',
          artista: 'Artista',
          album: 'Disco',
          duracionSeg: 200.5,
          coverUrl: '/api/v1/asset/cover/42',
        ),
        (int albumId) {
          pedido = albumId;
          return Uri.file('/covers/42.jpg');
        },
      );
      expect(pedido, 42);
      expect(item.id, 'pc-7');
      expect(item.title, 'Tema');
      expect(item.duration, const Duration(milliseconds: 200500));
      expect(item.artUri, Uri.file('/covers/42.jpg'));
    });

    test('sin cover_url no hay portada', () {
      final item = mediaItemRemoto(
        const RemotePistaDto(id: 1, titulo: 'X'),
        (_) => fail('no debe pedir portada'),
      );
      expect(item.artUri, isNull);
    });
  });

  test('modos de repetición local ⇄ vocabulario del PC (ida y vuelta)', () {
    for (final RepeatMode m in RepeatMode.values) {
      expect(repeatModeDePc(modoRepeticionPc(m)), m);
    }
    expect(repeatModeDePc('desconocido'), RepeatMode.off);
  });
}
