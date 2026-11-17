# Convenciones de interfaz

> **Estado:** Implementado.

## Navegación

* Cuatro pestañas: Inicio, Buscar, Biblioteca y Playlists. El perfil y los ajustes (General) se abren desde el
  avatar de la barra superior.
* Volver a tocar la pestaña activa sube al principio. El botón atrás del sistema en otra pestaña vuelve a Inicio;
  en Inicio pide una segunda pulsación para salir.
* El mini reproductor queda sobre la barra inferior; al tocarlo se abre el reproductor.

## Gestos

| Gesto | Dónde | Acción |
|---|---|---|
| Deslizar horizontal | Mini reproductor | Pista siguiente o anterior |
| Deslizar hacia arriba | Mini reproductor | Abrir el reproductor |
| Deslizar hacia abajo | Reproductor | Cerrarlo |
| Deslizar horizontal | Reproductor | Cambiar entre Portada, Letra y Cola |
| Deslizar a la derecha | Fila de pista | Añadir a la cola |
| Pellizcar | Letra | Agrandar y entrar en modo inmersivo |
| Tocar una línea | Letra | Saltar a ese momento |

Todo lo que hace un gesto tiene también un botón o una entrada de menú.

## Componentes

* Avisos breves flotantes para confirmar acciones (añadir a la cola, favoritos, descargas); un aviso sustituye al
  anterior en lugar de apilarse.
* Hojas inferiores para menús de pista y selectores.
* Portadas con respaldo tipado (disco, persona, nota, lista) cuando no hay imagen.
* Sin emoticonos ni letras usadas como iconos.

## Adaptación

Los teléfonos quedan en vertical; tablets y Chromebook rotan y usan rejillas más densas. Con teclado físico:
Espacio reproduce o pausa, las flechas avanzan o retroceden 10 s y Ctrl con flecha cambia de pista.

## Accesibilidad

Botones con etiqueta semántica, áreas táctiles de al menos 48 dp, texto que respeta el tamaño de letra del sistema
sin cortar palabras (`AutoFitText`) y temas de alto contraste.
