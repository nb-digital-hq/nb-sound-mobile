# Modelo de amenazas

> **Estado:** Aplicable.

| Amenaza | Mitigación |
|---|---|
| Un equipo de la red local se hace pasar por el PC | El certificado se fija por su huella SHA-256 al emparejar (el QR la trae) y se comprueba en cada conexión HTTPS, WSS, imagen y audio |
| Alguien en la red reutiliza un QR | El token del QR es de un solo uso y caduca a los cinco minutos |
| Robo del `device_token` | Vive en el llavero del sistema; el PC solo guarda su SHA-256 y puede revocar el teléfono |
| Una actualización manipulada | Solo se instala si el tamaño y la huella SHA-256 coinciden con los que publica GitHub; Android exige además la misma firma que la app instalada |
| Fuga por registros | No hay registros (`tool/guardianes/registro.dart`) |
| Una dependencia que abre conexiones propias | Toda construcción de clientes de red está en `lib/core/network/` (`tool/guardianes/red.dart`) |
| Música local enviada al PC | Identificadores negativos; el traspaso y las órdenes los filtran (`test/features/player/`) |
| Pérdida de datos en una actualización | Migraciones con prueba desde la versión 1 |

Fuera de alcance: un dispositivo con acceso de superusuario y un PC comprometido, que por diseño ya tiene la música.
