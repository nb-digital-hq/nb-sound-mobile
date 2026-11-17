# Privacidad

> **Estado:** Implementado. Lo hacen cumplir `lib/core/network/salidas.dart` con `tool/guardianes/red.dart`,
> `tool/guardianes/registro.dart` y el llavero del sistema.

## Principios

* **Sin cuenta.** Ninguna función pide iniciar sesión ni datos personales.
* **Sin telemetría.** No hay analítica, informes de fallos ni métricas de uso, ni anónimos ni opcionales.
* **Sin nube.** La música viaja del PC al teléfono por la red local; NB Digital no opera servidores que la vean.
* **Sin registros.** La app no escribe registros, ni en Dart ni en el código nativo.

## Qué sale del teléfono

| Destino | Qué se envía | Cuándo |
|---|---|---|
| El PC emparejado | Nombre y plataforma del teléfono al emparejar; historial de escuchas, favoritos y la selección; peticiones de catálogo, medios y órdenes del reproductor | Al emparejar, sincronizar, reproducir o controlar el PC |
| `api.github.com` y `github.com` | Una petición sin credenciales ni identificadores del dispositivo, con agente `NB-Sound-Mobile` | Solo al pulsar "Buscar actualizaciones" o "Instalar" (Android) |

Nada más. La música local del teléfono nunca se envía al PC: sus identificadores son negativos y el traspaso los
filtra.

## Qué se guarda en el teléfono

* Base de datos con el catálogo recibido, historial, favoritos, playlists, estado de descargas y preferencias.
* Archivos descargados y cachés de imágenes, dentro del espacio privado de la app.
* `device_token` y huella del PC en el llavero del sistema.
* Nombre y foto de perfil, si la persona los pone: no salen del teléfono.

Desinstalar la app borra todo lo anterior. "Desconectar" en Sincronización borra el emparejamiento y conserva la
música descargada.

## Permisos

| Permiso | Para qué | Plataforma |
|---|---|---|
| Red e información de red | Hablar con el PC en la red local | Android, iOS (red local) |
| Cámara | Escanear el QR del PC; solo mientras el escáner está abierto | Android, iOS |
| Notificaciones, servicio en primer plano | Reproducción en segundo plano y sus controles | Android |
| Audio del dispositivo | Leer la música guardada en el teléfono | Android |
| Instalar paquetes | Instalar una actualización que la persona pidió | Android |
| Galería | Elegir la foto de perfil | iOS |
