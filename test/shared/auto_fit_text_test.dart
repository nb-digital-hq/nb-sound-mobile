import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/shared/widgets/auto_fit_text.dart';

void main() {
  testWidgets('reduce la letra para no partir una palabra larga', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 90,
            child: AutoFitText(
              'Canciones por descubrir',
              minFontSize: 6,
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
    final Text t = tester.widget<Text>(find.byType(Text));
    final double usado = t.style!.fontSize!;
    expect(usado, lessThan(20));
    // La palabra más larga cabe entera en una línea con el tamaño elegido.
    final TextPainter p = TextPainter(
      text: TextSpan(
        text: 'Canciones',
        style: TextStyle(fontSize: usado),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(p.width, lessThanOrEqualTo(90.5));
  });

  testWidgets('texto que ya cabe conserva su tamaño', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            child: AutoFitText('Hola', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.byType(Text)).style!.fontSize, 16);
  });
}
