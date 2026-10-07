"""Vectoriza Mascota-Icono.jpg. Requiere Pillow, numpy y scikit-image.

Ejecutar desde cualquier directorio: python docs/mascota/vectorizar.py
"""
from pathlib import Path
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image
from skimage import measure, filters

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'images'
rgb = np.asarray(Image.open(OUT / 'Mascota-Icono.jpg').convert('RGB'))
height, width = rgb.shape[:2]
r, g, b = [rgb[:, :, i].astype(float) for i in range(3)]
masks = {
    'brown': (r < 150) & (g < 85) & (b < 65) & (r > g * 1.3),
    'orange': (r > 180) & (g < 140) & (b < 90),
    'green': (g > 65) & (g > r * 1.15) & (r < 160) & (b < 100),
}
colors = {'brown': '#491B00', 'orange': '#FC4403', 'green': '#5B821C'}


def contours(mask):
    labels = measure.label(mask)
    sizes = np.bincount(labels.ravel())
    mask = (labels > 0) & (sizes[labels] >= 80)
    smooth = filters.gaussian(mask.astype(float), sigma=0.8)
    return [measure.approximate_polygon(c[:, ::-1], tolerance=0.8)
            for c in measure.find_contours(smooth, 0.5)
            if len(c) > 30]


def clip_polygon(points, box):
    # Sutherland-Hodgman: divide la silueta en piezas sin rasterizarla.
    points = list(map(tuple, points))
    if points and points[0] == points[-1]:
        points.pop()
    for axis, limit, sign in [(0, box[0], 1), (0, box[2], -1),
                              (1, box[1], 1), (1, box[3], -1)]:
        if not points:
            break
        result = []
        previous = points[-1]
        prev_inside = (previous[axis] - limit) * sign >= 0
        for current in points:
            inside = (current[axis] - limit) * sign >= 0
            if inside != prev_inside:
                t = (limit - previous[axis]) / (current[axis] - previous[axis])
                result.append(tuple(previous[i] + t * (current[i] - previous[i])
                                    for i in range(2)))
            if inside:
                result.append(current)
            previous, prev_inside = current, inside
        points = result
    return points


def path(points):
    if len(points) < 3:
        return ''
    return 'M' + ' L'.join(f'{x:.1f},{y:.1f}' for x, y in points) + ' Z'


brown_components = measure.label(masks['brown'])
regions = sorted(measure.regionprops(brown_components), key=lambda a: a.area, reverse=True)
main_brown = contours(brown_components == regions[0].label)
antennae = contours(np.isin(brown_components, [p.label for p in regions[1:] if p.area > 80]))
colored = {name: contours(masks[name]) for name in ['orange', 'green']}
# Cortes en las uniones con el cuerpo. Todos los SVG conservan el mismo lienzo
# para que puedan superponerse y transformarse alrededor de estos puntos.
parts = [
    ('ala-superior-izquierda', (0, 0, 437, 600), 'orange', (437, 600)),
    ('ala-superior-derecha', (510, 0, width, 600), 'orange', (510, 600)),
    ('ala-inferior-izquierda', (0, 600, 437, height), 'green', (437, 600)),
    ('ala-inferior-derecha', (510, 600, width, height), 'green', (510, 600)),
    ('cuerpo', (437, 0, 510, height), None, (473.5, 600)),
]
groups = []
for name, box, color, pivot in parts:
    brown_d = ' '.join(filter(None, [path(clip_polygon(c, box)) for c in main_brown]))
    content = f'<path fill="{colors["brown"]}" fill-rule="evenodd" d="{brown_d}"/>'
    if color:
        color_d = ' '.join(filter(None, [path(clip_polygon(c, box)) for c in colored[color]]))
        content += f'\n    <path fill="{colors[color]}" d="{color_d}"/>'
    groups.append((name, f'<g id="{name}" data-pivot="{pivot[0]} {pivot[1]}">\n    {content}\n  </g>'))
ant_d = ' '.join(path(c) for c in antennae)
groups.append(('antenas', f'<g id="antenas"><path fill="{colors["brown"]}" d="{ant_d}"/></g>'))


def svg(content):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}" role="img" aria-labelledby="titulo">\n'
            '<title id="titulo">Mariposa de Nikara</title>\n'
            f'  {content}\n</svg>\n')


master = svg('\n  '.join(group for _, group in groups))
(OUT / 'mascota_nikara.svg').write_text(master, encoding='utf-8')
for name, group in groups:
    (OUT / f'mascota_nikara_{name.replace("-", "_")}.svg').write_text(svg(group), encoding='utf-8')

demo = '''<!doctype html>
<html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mariposa de Nikara — SVG animado</title>
<style>
body { margin:0; min-height:100vh; display:grid; place-content:center; gap:20px; background:#f2f2e9; color:#491b00; font:16px system-ui; text-align:center; }
svg { width:min(75vw,420px); height:auto; overflow:visible; }
svg g { transform-box:view-box; }
#ala-superior-izquierda { transform-origin:437px 600px; animation:izquierda 1.6s ease-in-out infinite; }
#ala-inferior-izquierda { transform-origin:437px 600px; animation:izquierda 1.6s ease-in-out infinite; }
#ala-superior-derecha { transform-origin:510px 600px; animation:derecha 1.6s ease-in-out infinite; }
#ala-inferior-derecha { transform-origin:510px 600px; animation:derecha 1.6s ease-in-out infinite; }
@keyframes izquierda { 50% { transform:rotate(3deg) scaleX(.65); } }
@keyframes derecha { 50% { transform:rotate(-3deg) scaleX(.65); } }
button { padding:10px 20px; border:1px solid #491b00; border-radius:20px; background:white; cursor:pointer; font:inherit; }
body.pausa svg g { animation-play-state:paused; }
@media (prefers-reduced-motion:reduce) { svg g { animation:none !important; } }
</style>
<main>__SVG__<p>Mariposa vectorizada · alas independientes</p>
<button type="button" aria-pressed="false" onclick="const paused=document.body.classList.toggle('pausa'); this.setAttribute('aria-pressed',paused); this.textContent=paused?'Reanudar':'Pausar';">Pausar</button></main>
</html>
'''
(Path(__file__).parent / 'preview.html').write_text(demo.replace('__SVG__', master), encoding='utf-8')
for file in OUT.glob('mascota_nikara*.svg'):
    ET.parse(file)
print(f'SVG completo, {len(groups)} piezas y preview.html generados. Lienzo: {width} x {height}.')
