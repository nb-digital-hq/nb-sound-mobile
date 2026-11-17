import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/lyrics/presentation/letra_view.dart';

void main() {
  testWidgets('línea corta: misma forma, crece al resaltarse', (
    WidgetTester t,
  ) async {
    final AjusteLinea a = ajustarLineaLetra(
      texto: 'Hola mundo',
      maxWidth: 340,
      maxHeight: 54,
      escala: 1,
    );
    expect(a.renglones, 1);
    expect(a.fontSize, 16);
    expect(a.fontSizeActiva, 20);
  });

  testWidgets('línea larga: renglones fijos, sin elipsis y dentro del alto', (
    WidgetTester t,
  ) async {
    const String texto = 'Seguiré cantando hasta el amanecer';
    final AjusteLinea a = ajustarLineaLetra(
      texto: texto,
      maxWidth: 300,
      maxHeight: 54,
      escala: 1,
    );
    expect(a.renglones, lessThanOrEqualTo(2));
    expect(a.texto.replaceAll('\n', ' '), texto);
    expect(a.fontSizeActiva, greaterThanOrEqualTo(a.fontSize));
    final TextPainter p = TextPainter(
      text: TextSpan(
        text: a.texto,
        style: estiloLineaLetra(a.fontSizeActiva, FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(p.width, lessThanOrEqualTo(300.5));
    expect(p.height, lessThanOrEqualTo(54.5));
  });

  testWidgets('LineaLetra no cambia de renglones al activarse', (
    WidgetTester t,
  ) async {
    Widget linea(bool activa) => MaterialApp(
      home: Center(
        child: LineaLetra(
          texto: 'Una línea bastante larga de la canción que ocupa espacio',
          activa: activa,
          escala: 1,
          maxWidth: 300,
          maxHeight: 54,
          color: Colors.grey,
          colorActiva: Colors.white,
        ),
      ),
    );
    await t.pumpWidget(linea(false));
    final String antes = t.widget<Text>(find.byType(Text)).data!;
    await t.pumpWidget(linea(true));
    await t.pumpAndSettle();
    expect(t.widget<Text>(find.byType(Text)).data, antes);
    expect(t.takeException(), isNull);
  });
}
