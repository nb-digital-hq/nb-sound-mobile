import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Última re-selección de una pestaña ya activa (`tab` + contador para que cada
/// toque dispare aunque sea la misma pestaña). La emite el `AppShell`.
class TabReselectController extends Notifier<({int tab, int n})> {
  @override
  ({int tab, int n}) build() => (tab: -1, n: 0);

  void reseleccionar(int tab) => state = (tab: tab, n: state.n + 1);
}

final NotifierProvider<TabReselectController, ({int tab, int n})>
tabReselectProvider =
    NotifierProvider<TabReselectController, ({int tab, int n})>(
      TabReselectController.new,
    );

/// Envuelve la pantalla raíz de una pestaña: al volver a tocar su pestaña
/// estando ya en ella, sube la lista al principio (). Usa el
/// `PrimaryScrollController` de la ruta, que heredan las listas verticales.
class ScrollArribaAlReseleccionar extends ConsumerWidget {
  const ScrollArribaAlReseleccionar({
    super.key,
    required this.tab,
    required this.child,
  });

  final int tab;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<({int tab, int n})>(tabReselectProvider, (_, next) {
      if (next.tab != tab) {
        return;
      }
      final ScrollController? c = PrimaryScrollController.maybeOf(context);
      if (c == null) {
        return;
      }
      for (final ScrollPosition p in c.positions) {
        p.animateTo(
          0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    });
    return child;
  }
}
