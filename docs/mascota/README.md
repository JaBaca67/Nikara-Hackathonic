# Mascota vectorizada

Fuente: `assets/images/Mascota-Icono.jpg`.

`assets/images/mascota_nikara.svg` es un SVG vectorial con seis grupos:
cuatro alas, cuerpo y antenas. No contiene una imagen JPEG incrustada.
Los contornos se extraen por color, se suavizan y se simplifican a segmentos
vectoriales; conservan las pequeñas asimetrías del dibujo original.
Los colores se normalizan a la paleta del isotipo: marrón `#491B00`,
naranja `#FC4403` y verde `#5B821C`.
El fondo y las separaciones claras son transparentes, por lo que adoptan el
color de la superficie donde se coloque la mascota.

Abrir `preview.html` en un navegador para ver un ejemplo de aleteo CSS.
El ejemplo incluye un botón para pausar y respeta la preferencia de movimiento
reducido. `preview.png` es una vista estática de los contornos vectorizados.
La animación de ejemplo pertenece al HTML; el SVG maestro conserva solo el dibujo.

## Flutter

El proyecto ya declara `flutter_svg` y registra `assets/images/` en
`pubspec.yaml`. Para mostrar el dibujo completo:

```dart
SvgPicture.asset('assets/images/mascota_nikara.svg', width: 120)
```

Para animar las alas por separado, se exportaron también seis SVG individuales:

| Pieza | Archivo en `assets/images/` | Punto de giro en el lienzo |
| --- | --- | --- |
| Ala superior izquierda | `mascota_nikara_ala_superior_izquierda.svg` | (437, 600) |
| Ala superior derecha | `mascota_nikara_ala_superior_derecha.svg` | (510, 600) |
| Ala inferior izquierda | `mascota_nikara_ala_inferior_izquierda.svg` | (437, 600) |
| Ala inferior derecha | `mascota_nikara_ala_inferior_derecha.svg` | (510, 600) |
| Cuerpo | `mascota_nikara_cuerpo.svg` | (473.5, 600) |
| Antenas | `mascota_nikara_antenas.svg` | — |

Todos conservan el lienzo de **1024 × 1028**. Superponer las piezas en un
`Stack` con el mismo tamaño y ajustar el ancho de cada ala con `Transform`
controlado desde un `AnimationController`. Mantener cuerpo y antenas por encima
de las alas. Para un widget de tamaño `(w, h)`, escalar el punto de giro como
`Offset(x * w / 1024, y * h / 1028)` y conservar la proporción original.
Las alas están divididas en su unión con el cuerpo, por lo que el punto de giro
coincide con ese corte. El SVG por sí solo no incorpora un controlador de
animación de Flutter.

La aplicación integra estas piezas en `NikaraButterfly`: aparece en la
bienvenida del asistente y en su botón flotante. Aletea
suavemente en reposo y más rápido al pensar; con movimiento reducido queda
abierta y estática. Los SVG se reutilizan entre fotogramas.

## Regenerar

Con Python y los paquetes Pillow, numpy y scikit-image instalados:

```text
python docs/mascota/vectorizar.py
```

Regenera el SVG maestro, las seis piezas y el HTML. La vista PNG es una
comprobación estática adicional, no un recurso necesario para la animación.
