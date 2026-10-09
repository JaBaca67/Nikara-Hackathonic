"""Dibujo de una tabla ER en Miro, al estilo de un diagrama entidad-relación.

POR QUÉ VARIOS ITEMS POR TABLA
------------------------------
La primera versión metía todo en un solo shape: el nombre y los atributos como
párrafos dentro del mismo rectángulo. Se lee, pero no se parece a un diagrama
ER — no hay cabecera de color ni columnas separadas para PK/FK, nombre y tipo.
Miro no tiene tablas en su REST API v2, así que la tabla se **compone**:

    ┌──────────────────────────────┐
    │        BUSINESSES            │  <- cabecera, color del módulo
    ├──────┬───────────┬───────────┤
    │  PK  │    id     │   uuid    │  <- tres shapes contiguos; el texto va
    │  FK  │ owner_id  │   uuid    │     DENTRO de cada uno
    └──────┴───────────┴───────────┘

TEXTO SIEMPRE VISIBLE
---------------------
En Miro, lo que se crea después queda por encima, así que un item mal ubicado
puede tapar un texto. Acá eso no puede pasar: el texto de cada columna vive
**dentro del shape de esa columna**, el último que se crea. Los separadores
verticales son los bordes de esos tres shapes, no items sueltos encima (además,
Miro rechaza shapes de menos de 8px de ancho, así que una línea fina no era
viable). El marco exterior va primero y es el ancla de los connectors.
"""

from __future__ import annotations

# Reparto horizontal de las tres columnas, en fracción del ancho de la tabla.
# Tomado de la proporción del diagrama de referencia (23% / 36% / 41%).
COL_MARKER = 0.23
COL_NAME = 0.36
COL_TYPE = 0.41

BORDER = "#fdbe02"  # dorado de marca, igual para todas las tablas
BODY_FILL = "#ffffff"
TEXT_DARK = "#121212"
TEXT_LIGHT = "#fdfdfd"


def contrast_text(hex_color: str) -> str:
    """Devuelve el color de texto legible sobre ese fondo.

    Evita el error que ya se corrigió una vez en la app: texto blanco sobre un
    Fill de marca claro (el badge ECO medía 1.74:1 contra el mínimo AA de 4.5).
    Acá se decide por luminancia relativa en vez de a ojo.
    """
    value = hex_color.lstrip("#")
    channels = [int(value[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [
        c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels
    ]
    luminance = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    # Ratio de contraste WCAG contra texto claro y contra texto oscuro; gana el
    # mayor. Con los Fill claros de marca (gold, olive) siempre gana el oscuro.
    against_light = (1.0 + 0.05) / (luminance + 0.05)
    against_dark = (luminance + 0.05) / 0.05
    return TEXT_LIGHT if against_light > against_dark else TEXT_DARK


def escape(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _pretty_type(raw: str) -> str:
    """Tipo en el estilo del diagrama de referencia: `Uuid`, `Text_array`."""
    mapping = {
        "timestamptz": "Timestamptz",
        "double precision": "Float8",
        "boolean": "Bool",
        "user_role": "User_role",
    }
    if raw in mapping:
        return mapping[raw]
    if raw.startswith("geography"):
        return "Geography(point,4326)"
    if raw.endswith("[]"):
        return f"{raw[:-2].capitalize()}_array"
    return raw.capitalize()


def _paragraphs(lines: list[str], align: str = "center") -> str:
    # El párrafo vacío mantiene la altura de la fila cuando no hay marcador.
    return "".join(
        f'<p style="text-align:{align}">{line or "&nbsp;"}</p>' for line in lines
    )


def build_items(item: dict, module_color: str, row_height: int,
                header_height: int) -> list[dict]:
    """Payloads de los items de una tabla, en el orden en que deben crearse.

    Cinco items: el marco exterior (ancla de los connectors), la cabecera de
    color y las tres columnas. **El texto va dentro del shape de su columna**,
    no en items aparte: así ningún elemento puede quedar encima de él, que es
    una garantía estructural y no algo que haya que revisar a ojo. Los
    separadores verticales del diagrama son los bordes de esas tres columnas.

    Cada payload trae `_kind` y `_role`; el llamador guarda el id del que tenga
    `_role == "body"` para engancharle las relaciones.
    """
    table = item["table"]
    width, height = item["width"], item["height"]
    left = item["x"] - width / 2
    top = item["y"] - height / 2

    marker_w = width * COL_MARKER
    name_w = width * COL_NAME
    type_w = width * COL_TYPE

    body_top = top + header_height
    body_height = height - header_height

    payloads: list[dict] = []

    # 1. Marco exterior: ancla de los connectors, debajo de todo.
    payloads.append(
        {
            "_kind": "shape",
            "_role": "body",
            "data": {"shape": "rectangle", "content": ""},
            "style": {
                "fillColor": BODY_FILL,
                "borderColor": BORDER,
                "borderWidth": "2",
            },
            "position": {"x": item["x"], "y": item["y"], "origin": "center"},
            "geometry": {"width": width, "height": height},
        }
    )

    # 2. Cabecera con el color del módulo.
    payloads.append(
        {
            "_kind": "shape",
            "_role": "header",
            "data": {
                "shape": "rectangle",
                "content": (
                    f'<p style="text-align:center">'
                    f"<strong>{escape(table['name'].upper())}</strong></p>"
                ),
            },
            "style": {
                "fillColor": module_color,
                "borderColor": BORDER,
                "borderWidth": "2",
                "color": contrast_text(module_color),
                "fontSize": "14",
                "textAlign": "center",
                "textAlignVertical": "middle",
            },
            "position": {
                "x": item["x"],
                "y": top + header_height / 2,
                "origin": "center",
            },
            "geometry": {"width": width, "height": header_height},
        }
    )

    # 3. Las tres columnas, cada una con su propio texto adentro.
    markers, names, types = [], [], []
    for column in table["columns"]:
        if column.get("pk"):
            markers.append("<strong>PK</strong>")
        elif column.get("references"):
            markers.append("<strong>FK</strong>")
        else:
            markers.append("")
        label = escape(column["name"])
        if column["name"] in table.get("transitive_debt", []):
            label = f"{label} ◇"
        names.append(label)
        types.append(escape(_pretty_type(column["type"])))

    columns = (
        (markers, marker_w, left + marker_w / 2),
        (names, name_w, left + marker_w + name_w / 2),
        (types, type_w, left + marker_w + name_w + type_w / 2),
    )
    for content, column_width, center_x in columns:
        payloads.append(
            {
                "_kind": "shape",
                "_role": "column",
                "data": {"shape": "rectangle", "content": _paragraphs(content)},
                "style": {
                    "fillColor": BODY_FILL,
                    "borderColor": BORDER,
                    "borderWidth": "1",
                    "color": TEXT_DARK,
                    "fontSize": "12",
                    "textAlign": "center",
                    # Centrado vertical, no "top": el interlineado real de Miro
                    # es menor que la fila reservada, así que anclarlo arriba
                    # dejaría un hueco al pie de las tablas largas. Las tres
                    # columnas tienen la misma cantidad de párrafos y el mismo
                    # alto, así que centradas quedan alineadas entre sí.
                    "textAlignVertical": "middle",
                },
                "position": {
                    "x": center_x,
                    "y": body_top + body_height / 2,
                    "origin": "center",
                },
                "geometry": {"width": column_width, "height": body_height},
            }
        )

    return payloads


def legend_items(modules: dict[str, str], x: float, y: float) -> list[dict]:
    """Leyenda de colores por módulo, arriba a la izquierda del diagrama."""
    payloads = [
        {
            "_kind": "text",
            "_role": "legend",
            "data": {
                "content": '<p><strong>Modelo ER — 2FN</strong></p>'
                "<p>Color de cabecera = módulo. Flecha punteada = relación "
                "polimórfica (la integridad la valida la app). ◇ = dependencia "
                "transitiva (3FN), fuera de alcance.</p>"
            },
            "style": {"color": TEXT_DARK, "fontSize": "16", "textAlign": "left"},
            "position": {"x": x + 240, "y": y - 70, "origin": "center"},
            "geometry": {"width": 520},
        }
    ]
    for index, (module, color) in enumerate(modules.items()):
        payloads.append(
            {
                "_kind": "shape",
                "_role": "legend",
                "data": {
                    "shape": "rectangle",
                    "content": f'<p style="text-align:center">{escape(module)}</p>',
                },
                "style": {
                    "fillColor": color,
                    "borderColor": BORDER,
                    "borderWidth": "2",
                    "color": contrast_text(color),
                    "fontSize": "12",
                    "textAlign": "center",
                    "textAlignVertical": "middle",
                },
                "position": {
                    "x": x + 110 + (index % 3) * 240,
                    "y": y + 10 + (index // 3) * 46,
                    "origin": "center",
                },
                "geometry": {"width": 220, "height": 36},
            }
        )
    return payloads
