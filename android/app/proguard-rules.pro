# Reglas de R8 para release.
#
# El escáner QR usa zxing-cpp por FFI (flutter_zxing): el código nativo se
# resuelve por símbolo desde Dart y R8 no lo ve, así que no necesita reglas.
# CameraX y los plugins de Flutter traen sus propias reglas de consumidor.
#
# Los widgets de pantalla de inicio se instancian por reflexión desde el
# manifiesto (AppWidgetProvider); se conservan para que R8 no los elimine.
-keep class com.nbsound.nb_sound_mobile.widget.** { *; }
