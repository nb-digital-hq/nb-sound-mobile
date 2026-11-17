# Connect

> **Estado:** Implementado. `lib/features/remote_control/` y `lib/features/player/application/playback.dart`.

Con el PC emparejado y en la misma red, la persona elige dónde suena la música: "Este teléfono" o "Mi PC".

## Controlar el PC

`RemoteController` abre el WebSocket `/api/v1/control` ([contrato](pc-contract.md) §5), refleja el estado y la cola
del PC y envía órdenes. Se reconecta con espera creciente y, si el PC no vuelve, pasa a "sin conexión" sin dejar de
reintentar.

Siguiente y anterior son optimistas: la interfaz muestra al instante la pista vecina de la cola del PC y, si se
pulsa varias veces seguidas, solo se envía al PC el destino final (`play_index`). Los mensajes del PC que aún hablan
de la pista anterior no hacen retroceder la interfaz. Con aleatorio activo, con la cola desalineada o en un
extremo se envía la orden clásica y manda el PC.

## El sistema refleja al PC

Mientras se controla el PC, la notificación y la pantalla de bloqueo muestran lo que suena allí, sus botones mandan
sobre el PC, y las teclas de volumen del teléfono cambian el volumen del PC (sesión de reproducción remota de
Android).

## Traspaso

* **Al PC:** se envía la cola completa del teléfono (sin la música local, que el PC no tiene), la pista y la
  posición. Si el teléfono estaba en pausa, el PC queda en pausa. El aleatorio se reactiva después de cargar la
  cola para que el PC arranque en la pista correcta.
* **Al teléfono:** se toma la cola del PC, se mapea a la biblioteca local y se continúa en la misma posición; el PC
  se pausa.
* Aleatorio y repetición viajan con la sesión en ambos sentidos.

## DJ Privado

Si el PC está en una sesión de DJ Privado, el teléfono lo muestra y deshabilita sus órdenes hasta que termine.
