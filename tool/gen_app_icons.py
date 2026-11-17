#!/usr/bin/env python3
"""Genera TODOS los íconos de la app a partir de un único SVG.

Fuente de verdad: `assets/images/logo.svg` (un círculo de fondo + la figura).
Cambiar el logo de la app = reemplazar ese SVG y volver a ejecutar:

    python3 tool/gen_app_icons.py

Salidas (todas se regeneran; no editar a mano):
  - Android, ícono por defecto: `mipmap-*/ic_launcher.png` (legado, circular) y
    el adaptativo (`drawable-*/ic_launcher_foreground.png` con solo la figura +
    `values/colors.xml` con el color de fondo del SVG).
  - Android, íconos por tema: `drawable-nodpi/ic_app_<tema>.png`, el mismo logo
    con el fondo del color del tema (tabla `tool/app_icon_colors.json`).
  - Selector "Ícono de la app": `assets/app_icons/logo_<tema>.png` y
    `logo_default.png`.
  - `assets/images/logo.png` / `logo_lg.png` (logo de referencia).
  - iOS: `AppIcon.appiconset/*.png` (cuadrado opaco, sin alfa).
  - Los `<activity-alias>` del AndroidManifest (uno por tema + el por defecto),
    que es lo que conmuta el ícono del lanzador en runtime.

Requiere `rsvg-convert` (librsvg) y Pillow.
"""
import io
import json
import os
import re
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SVG = os.path.join(ROOT, 'assets/images/logo.svg')
COLORS = os.path.join(HERE, 'app_icon_colors.json')
RES = os.path.join(ROOT, 'android/app/src/main/res')
MANIFEST = os.path.join(ROOT, 'android/app/src/main/AndroidManifest.xml')
IOS = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
PKG = 'com.nbsound.nb_sound_mobile'

# Alias de íconos que ya no existen. Se conservan (deshabilitados, con el ícono
# por defecto) solo para que un teléfono que los tenía activos no se quede sin
# ícono en el lanzador al actualizar; la app migra la elección al por defecto.
ALIAS_RETIRADOS = ['nothing']

DENSIDADES = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0,
              'xxxhdpi': 4.0}

CIRCLE_RE = re.compile(r'<circle\b[^>]*/>')
FILL_RE = re.compile(r'fill="(#[0-9A-Fa-f]{6})"')


def leer_svg():
    with open(SVG, encoding='utf-8') as fh:
        svg = fh.read()
    circulo = CIRCLE_RE.search(svg)
    assert circulo, 'el SVG debe tener un <circle> de fondo'
    fondo = FILL_RE.search(circulo.group(0)).group(1)
    radio = float(re.search(r'\br="([\d.]+)"', circulo.group(0)).group(1))
    lado = float(re.search(r'viewBox="0 0 ([\d.]+)', svg).group(1))
    return svg, circulo.group(0), fondo, radio, lado


def render(svg, px):
    """Rasteriza [svg] (texto) a un PIL.Image RGBA de px×px."""
    out = subprocess.run(
        ['rsvg-convert', '-w', str(px), '-h', str(px), '-f', 'png'],
        input=svg.encode('utf-8'), stdout=subprocess.PIPE, check=True).stdout
    return Image.open(io.BytesIO(out)).convert('RGBA')


def guardar(img, *ruta):
    destino = os.path.join(*ruta)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    img.save(destino, optimize=True)


def limpiar(carpeta, patron):
    if not os.path.isdir(carpeta):
        return
    for f in os.listdir(carpeta):
        if re.fullmatch(patron, f):
            os.remove(os.path.join(carpeta, f))


def alias(name, icon, enabled):
    return (
        f'        <activity-alias\n'
        f'            android:name="{PKG}.{name}"\n'
        f'            android:enabled="{"true" if enabled else "false"}"\n'
        f'            android:exported="true"\n'
        f'            android:targetActivity=".MainActivity"\n'
        f'            android:icon="{icon}">\n'
        f'            <intent-filter>\n'
        f'                <action android:name="android.intent.action.MAIN"/>\n'
        f'                <category android:name="android.intent.category.LAUNCHER"/>\n'
        f'            </intent-filter>\n'
        f'        </activity-alias>'
    )


def actualizar_manifest(claves):
    with open(MANIFEST, encoding='utf-8') as fh:
        xml = fh.read()
    lineas = ['        <!-- AppIconStart -->',
              '        <!-- Generado por tool/gen_app_icons.py; no editar a mano. -->',
              alias('AppIconDefault', '@mipmap/ic_launcher', True)]
    lineas += [alias(f'AppIcon_{k}', f'@drawable/ic_app_{k}', False)
               for k in claves]
    lineas += [alias(f'AppIcon_{k}', '@mipmap/ic_launcher', False)
               for k in ALIAS_RETIRADOS]
    lineas.append('        <!-- AppIconEnd -->')
    bloque = '\n'.join(lineas) + '\n'
    patron = re.compile(
        r'[ \t]*<!-- AppIconStart -->.*?<!-- AppIconEnd -->\n', re.S)
    assert patron.search(xml), 'faltan los marcadores AppIconStart/AppIconEnd'
    xml = patron.sub(lambda _: bloque, xml)
    with open(MANIFEST, 'w', encoding='utf-8') as fh:
        fh.write(xml)


def main():
    svg, circulo, fondo, radio, lado = leer_svg()
    with open(COLORS, encoding='utf-8') as fh:
        temas = json.load(fh)
    claves = sorted(temas)

    # ── Logo de referencia + ícono por defecto (legado) ────────────────────
    guardar(render(svg, 192), ROOT, 'assets/images/logo.png')
    guardar(render(svg, 512), ROOT, 'assets/images/logo_lg.png')
    for dens, k in DENSIDADES.items():
        guardar(render(svg, round(48 * k)), RES, f'mipmap-{dens}',
                'ic_launcher.png')

    # ── Ícono adaptativo: solo la figura sobre el color de fondo del SVG ────
    # El lienzo adaptativo mide 108dp y la máscara visible 72dp: el círculo del
    # SVG se hace coincidir con esa máscara, así la figura queda exactamente
    # como en el logo sea cual sea la forma del lanzador.
    figura = svg.replace(circulo, '')
    escala = 72.0 / 108.0 * (lado / (2 * radio))
    for dens, k in DENSIDADES.items():
        lienzo = round(108 * k)
        tam = round(lienzo * escala)
        img = Image.new('RGBA', (lienzo, lienzo), (0, 0, 0, 0))
        img.alpha_composite(render(figura, tam),
                            ((lienzo - tam) // 2, (lienzo - tam) // 2))
        guardar(img, RES, f'drawable-{dens}', 'ic_launcher_foreground.png')
    with open(os.path.join(RES, 'values/colors.xml'), 'w',
              encoding='utf-8') as fh:
        fh.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                 f'    <color name="ic_launcher_background">{fondo}</color>\n'
                 '</resources>\n')

    # ── Íconos por tema: mismo logo, fondo del color del tema ──────────────
    limpiar(os.path.join(RES, 'drawable-nodpi'), r'ic_app_.+\.png')
    limpiar(os.path.join(ROOT, 'assets/app_icons'), r'logo_.+\.png')
    guardar(render(svg, 256), ROOT, 'assets/app_icons/logo_default.png')
    for clave in claves:
        tematizado = svg.replace(
            circulo, circulo.replace(fondo, temas[clave]))
        guardar(render(tematizado, 192), RES, 'drawable-nodpi',
                f'ic_app_{clave}.png')
        guardar(render(tematizado, 256), ROOT, 'assets/app_icons',
                f'logo_{clave}.png')

    # ── iOS: cuadrado opaco (sin alfa), fondo a sangre ─────────────────────
    if os.path.isdir(IOS):
        cuadrado = svg.replace(
            circulo,
            f'<rect width="{lado:g}" height="{lado:g}" fill="{fondo}"/>')
        for f in sorted(os.listdir(IOS)):
            if f.endswith('.png'):
                ruta = os.path.join(IOS, f)
                with Image.open(ruta) as previo:
                    px = previo.size[0]
                render(cuadrado, px).convert('RGB').save(ruta, optimize=True)

    actualizar_manifest(claves)
    print(f'Íconos generados desde {os.path.relpath(SVG, ROOT)}: '
          f'por defecto + {len(claves)} temas.')


if __name__ == '__main__':
    sys.exit(main())
