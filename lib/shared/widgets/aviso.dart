import 'package:flutter/material.dart';

/// Confirmación breve de una acción (“Añadida a la cola”).
/// Sustituye al aviso anterior en vez de apilarlos.
void avisar(BuildContext context, String mensaje) {
  final ScaffoldMessengerState? m = ScaffoldMessenger.maybeOf(context);
  if (m == null) {
    return;
  }
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(milliseconds: 1800),
      ),
    );
}
