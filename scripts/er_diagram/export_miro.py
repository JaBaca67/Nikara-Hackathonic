"""Publica el modelo ER (2FN) en un board de Miro vía su REST API v2.

Crea items **nativos** de Miro (frames, shapes y connectors), no una imagen:
quedan editables, movibles y con los colores de marca de Níkara. Solo usa la
librería estándar de Python — sin dependencias nuevas.

PREPARACIÓN (una sola vez)
--------------------------
1. Entrá a https://developers.miro.com/ con la cuenta del board → *Your apps*
   → **Create new app**. Marcala como app de tu equipo.
2. En *Permissions*, habilitá los scopes `boards:read` y `boards:write`.
3. *Install app and get OAuth token* → copiá el token.
4. El board id está en su URL: `https://miro.com/app/board/<BOARD_ID>/`
   (la parte antes del `=`, p. ej. `uXjVK...k=` → el id incluye el `=`).

USO
---
La forma recomendada de pasar las credenciales es por archivo local: pegar el
token en `scripts/er_diagram/.miro_token` y el board id en `.miro_board`. Los
dos están gitignored y así el token no pasa por el historial del shell ni por
una sesión de Claude Code (el hook SessionEnd archiva la conversación entera en
la bóveda, que es un repo git).

    python scripts/er_diagram/export_miro.py --dry-run   # plan, sin tocar Miro
    python scripts/er_diagram/export_miro.py             # publica
    python scripts/er_diagram/export_miro.py --replace   # borra lo anterior y republica

También se aceptan las variables `MIRO_ACCESS_TOKEN` / `MIRO_BOARD_ID`, o los
flags `--token` / `--board`. El estado de lo creado queda en `.miro_state.json`,
también gitignored.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL = HERE / "model_2nf.json"
STATE = HERE / ".miro_state.json"
# Credenciales locales, nunca versionadas (ver .gitignore).
TOKEN_FILE = HERE / ".miro_token"
BOARD_FILE = HERE / ".miro_board"
API = "https://api.miro.com/v2"

# Paleta de marca de Níkara (lib/theme/app_colors.dart). Un color de relleno
# por módulo; el texto siempre oscuro porque ningún Fill de marca admite texto
# blanco encima (contraste).
MODULE_STYLE = {
    "Identidad y cuentas": {"fill": "#fdbe02", "border": "#8f6d0a"},
    "Negocios": {"fill": "#ffffff", "border": "#121212"},
    "Módulo ECO": {"fill": "#c2ca5b", "border": "#6b7033"},
    "Rutas y viajes": {"fill": "#ff8243", "border": "#c44b0e"},
    "Interacción social": {"fill": "#f7f3ec", "border": "#6b7033"},
    "Avisos y automatización": {"fill": "#fdfdfd", "border": "#fdbe02"},
}
DEFAULT_STYLE = {"fill": "#fdfdfd", "border": "#121212"}

# Geometría del layout. Las tablas se apilan dentro del frame de su módulo.
TABLE_WIDTH = 300
ROW_HEIGHT = 16
HEADER_HEIGHT = 44
TABLE_GAP = 48
FRAME_PADDING = 60
FRAME_GAP = 140
FRAME_TOP = 0


class MiroError(RuntimeError):
    pass


def read_credential_file(path: Path) -> str | None:
    """Lee una credencial de un archivo local gitignored.

    Existe para que el token no tenga que pasar por el historial del shell ni
    por una sesión de Claude Code (el hook SessionEnd archiva la conversación
    entera en la bóveda, que es un repo git). Ignora líneas vacías y
    comentarios, así el archivo puede llevar una nota de qué es.
    """
    if not path.is_file():
        return None
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.strip()
        if value and not value.startswith("#"):
            return value
    return None


def request(
    method: str, path: str, token: str, payload: dict | None = None, retries: int = 4
) -> dict:
    """Llamada a la API con reintento exponencial en 429 y 5xx."""
    url = path if path.startswith("http") else f"{API}{path}"
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    for attempt in range(retries + 1):
        req = urllib.request.Request(url, data=body, method=method)
        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("Accept", "application/json")
        if body is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                raw = response.read().decode("utf-8")
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:500]
            retriable = error.code == 429 or 500 <= error.code < 600
            if retriable and attempt < retries:
                wait = float(error.headers.get("Retry-After") or 2**attempt)
                print(f"    {error.code}: esperando {wait:.0f}s…", file=sys.stderr)
                time.sleep(wait)
                continue
            if error.code == 401:
                raise MiroError(
                    "Token inválido o expirado. Regeneralo en developers.miro.com "
                    "→ tu app → Install app and get OAuth token. Si la app tiene "
                    "activada la expiración de tokens, el que obtenés dura 1 hora."
                ) from error
            if error.code == 403:
                raise MiroError(
                    "El token no tiene permiso sobre este board. Revisá que la app "
                    "tenga el scope `boards:write` y esté instalada en el equipo dueño."
                ) from error
            if error.code == 404:
                raise MiroError(
                    f"Board no encontrado ({path}). Verificá MIRO_BOARD_ID — es la "
                    "parte de la URL después de /board/, incluido el `=` final."
                ) from error
            raise MiroError(f"{method} {path} -> {error.code}: {detail}") from error
        except urllib.error.URLError as error:
            if attempt < retries:
                time.sleep(2**attempt)
                continue
            raise MiroError(f"No se pudo conectar con Miro: {error.reason}") from error
    raise MiroError("Se agotaron los reintentos.")


def escape(text: str) -> str:
    return (
        text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    )


def table_html(table: dict) -> str:
    """Contenido del shape: nombre + atributos, con PK/FK marcados."""
    lines = [f"<p><strong>{escape(table['name'].upper())}</strong></p>"]
    for column in table["columns"]:
        if column.get("pk"):
            marker = "<strong>PK</strong>"
        elif column.get("references"):
            marker = "<em>FK</em>"
        else:
            marker = "&nbsp;&nbsp;&nbsp;"
        name = escape(column["name"])
        if column["name"] in table.get("transitive_debt", []):
            name = f"{name} ◇"
        lines.append(
            f"<p>{marker} {name} <span>: {escape(column['type'])}</span></p>"
        )
    return "".join(lines)


def table_height(table: dict) -> int:
    return HEADER_HEIGHT + ROW_HEIGHT * len(table["columns"])


def plan_layout(model: dict) -> tuple[list[dict], list[dict]]:
    """Calcula la posición de cada frame y cada tabla. Miro usa el centro."""
    by_module: dict[str, list[dict]] = {}
    for table in model["tables"]:
        by_module.setdefault(table["module"], []).append(table)
    # Dentro de cada módulo, la tabla más grande primero: deja la "entidad
    # fuerte" arriba y sus hijas debajo.
    for tables in by_module.values():
        tables.sort(key=lambda t: (-len(t["columns"]), t["name"]))

    frames, shapes = [], []
    x = 0.0
    for module in model["modules"]:
        tables = by_module.get(module, [])
        if not tables:
            continue
        content_height = sum(table_height(t) for t in tables) + TABLE_GAP * (
            len(tables) - 1
        )
        frame_width = TABLE_WIDTH + FRAME_PADDING * 2
        frame_height = content_height + FRAME_PADDING * 2
        frames.append(
            {
                "module": module,
                "x": x + frame_width / 2,
                "y": FRAME_TOP + frame_height / 2,
                "width": frame_width,
                "height": frame_height,
            }
        )
        cursor = FRAME_TOP + FRAME_PADDING
        for table in tables:
            height = table_height(table)
            shapes.append(
                {
                    "table": table,
                    "module": module,
                    "x": x + frame_width / 2,
                    "y": cursor + height / 2,
                    "frame_x": x + frame_width / 2,
                    "frame_y": FRAME_TOP + frame_height / 2,
                    "width": TABLE_WIDTH,
                    "height": height,
                }
            )
            cursor += height + TABLE_GAP
        x += frame_width + FRAME_GAP
    return frames, shapes


def build_shape_payload(item: dict, parent_id: str | None = None) -> dict:
    """Shape de una tabla.

    Sin `parent_id` la posición es absoluta del board y el frame queda debajo
    (en el canvas de Miro igual se comporta como contenedor al arrastrarlo).
    Con `parent_id`, Miro trata x/y como desplazamiento respecto al **centro**
    del frame, así que se convierte acá.
    """
    style = MODULE_STYLE.get(item["module"], DEFAULT_STYLE)
    x = item["x"] - item["frame_x"] if parent_id else item["x"]
    y = item["y"] - item["frame_y"] if parent_id else item["y"]
    payload = {
        "data": {"shape": "rectangle", "content": table_html(item["table"])},
        "style": {
            "fillColor": style["fill"],
            "borderColor": style["border"],
            "borderWidth": "2",
            "color": "#121212",
            "fontSize": "11",
            "textAlign": "left",
            "textAlignVertical": "top",
        },
        "position": {"x": x, "y": y, "origin": "center"},
        "geometry": {"width": item["width"], "height": item["height"]},
    }
    if parent_id:
        payload["parent"] = {"id": parent_id}
    return payload


def build_connector_payload(relation: dict, ids: dict[str, str]) -> dict | None:
    start, end = ids.get(relation["from"]), ids.get(relation["to"])
    if not start or not end:
        return None
    # Cardinalidad en texto: Miro no tiene notación crow's foot nativa, así que
    # va como caption ("1 — N" / "1 — 1") junto al nombre de la FK.
    label = f"{relation['kind']}  {relation['fk']}"
    polymorphic = relation.get("polymorphic", False)
    return {
        "startItem": {"id": start},
        "endItem": {"id": end},
        "shape": "elbowed",
        "captions": [{"content": escape(label), "position": "50%"}],
        "style": {
            "strokeColor": "#c44b0e" if polymorphic else "#121212",
            "strokeStyle": "dashed" if polymorphic else "normal",
            "strokeWidth": "1",
            "startStrokeCap": "none",
            "endStrokeCap": "arrow" if not polymorphic else "none",
            "fontSize": "10",
            "textOrientation": "horizontal",
        },
    }


def create_board(token: str, name: str) -> dict:
    """Crea un board en el team de la app.

    El team no se elige: la API lo toma de la instalación del token, que es
    justamente la razón por la que el board queda donde el token puede
    escribirlo.
    """
    # Sin bloque `policy`: configurar permisos de compartición por API requiere
    # un plan de pago, y mandarlo en un plan gratuito devuelve 403 aunque la
    # creación del board sí esté permitida. El board queda con los permisos por
    # defecto del team, que es lo que se quiere.
    return request(
        "POST",
        "/boards",
        token,
        {
            "name": name,
            "description": "Modelo ER (2FN) generado desde supabase/sql.",
        },
    )


def list_boards(token: str) -> int:
    """Imprime los boards que el token alcanza.

    Un token de Miro se emite por **instalación en un team**, no por cuenta: solo
    ve los boards de ese team. Si el board que buscás no aparece acá, vive en
    otro team — o lo creás en este, o reinstalás la app en aquel.
    """
    response = request("GET", "/boards?limit=50", token)
    boards = response.get("data", [])
    if not boards:
        print(
            "El token no alcanza ningún board.\n"
            "El team donde instalaste la app está vacío: creá el board ahí "
            "(selector de team arriba a la izquierda en Miro), o reinstalá la app "
            "eligiendo el team donde ya tenés el board."
        )
        return 1
    print(f"{len(boards)} board(s) alcanzables con este token:\n")
    for board in boards:
        team = (board.get("team") or {}).get("name", "?")
        print(f"  {board['id']}")
        print(f"      nombre: {board.get('name', '(sin nombre)')}")
        print(f"      team:   {team}")
    print(
        f"\nCopiá el id del que quieras en {BOARD_FILE.name} "
        "(o pasalo con --board)."
    )
    return 0


def load_state() -> dict:
    if STATE.is_file():
        return json.loads(STATE.read_text(encoding="utf-8"))
    return {}


def save_state(state: dict) -> None:
    STATE.write_text(
        json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def delete_previous(board: str, token: str) -> int:
    state = load_state()
    items = state.get("items", [])
    if not items:
        print("No hay items previos registrados.")
        return 0
    removed = 0
    # Los connectors se borran primero: borrar un shape con connectors
    # colgando deja referencias huérfanas.
    for item in sorted(items, key=lambda i: i["type"] != "connector"):
        path = (
            f"/boards/{board}/connectors/{item['id']}"
            if item["type"] == "connector"
            else f"/boards/{board}/items/{item['id']}"
        )
        try:
            request("DELETE", path, token)
            removed += 1
        except MiroError as error:
            print(f"  no se pudo borrar {item['type']} {item['id']}: {error}")
    save_state({})
    print(f"{removed} items borrados.")
    return removed


def main() -> int:
    parser = argparse.ArgumentParser(description="Publica el ER 2FN en Miro.")
    parser.add_argument("--token", default=os.environ.get("MIRO_ACCESS_TOKEN"))
    parser.add_argument("--board", default=os.environ.get("MIRO_BOARD_ID"))
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="imprime el plan (items, tamaños, posiciones) sin llamar a la API",
    )
    parser.add_argument(
        "--replace",
        action="store_true",
        help="borra los items de una corrida anterior antes de publicar",
    )
    parser.add_argument(
        "--parent-frames",
        action="store_true",
        help=(
            "cuelga cada tabla del frame de su módulo (parent.id). Agrupa de "
            "verdad, pero Miro interpreta la posición como relativa al frame: "
            "si el resultado queda corrido, volvé a correr sin este flag."
        ),
    )
    parser.add_argument(
        "--create-board",
        metavar="NOMBRE",
        help=(
            "crea un board nuevo con ese nombre en el team de la app y guarda su "
            "id en .miro_board. Útil cuando el team está recién creado y vacío."
        ),
    )
    parser.add_argument(
        "--list-boards",
        action="store_true",
        help=(
            "lista los boards que este token alcanza, con su id. Solo aparecen "
            "los del team donde se instaló la app — si el board que buscás no "
            "está, es que vive en otro team."
        ),
    )
    args = parser.parse_args()

    if not MODEL.is_file():
        print(
            "Falta model_2nf.json. Corré antes:\n"
            "  python scripts/er_diagram/extract_schema.py\n"
            "  python scripts/er_diagram/model_2nf.py",
            file=sys.stderr,
        )
        return 1
    model = json.loads(MODEL.read_text(encoding="utf-8"))
    frames, shapes = plan_layout(model)

    if args.dry_run:
        print(f"Plan para {len(model['tables'])} tablas y {len(model['relations'])} relaciones\n")
        for frame in frames:
            print(
                f"  FRAME  {frame['module']:28} "
                f"{frame['width']:.0f}x{frame['height']:.0f} @ "
                f"({frame['x']:.0f}, {frame['y']:.0f})"
            )
        print()
        for shape in shapes:
            table = shape["table"]
            print(
                f"  SHAPE  {table['name']:34} {len(table['columns']):2} attrs  "
                f"h={shape['height']:.0f} @ ({shape['x']:.0f}, {shape['y']:.0f})"
            )
        print(f"\n  CONNECTORS  {len(model['relations'])} "
              f"({sum(1 for r in model['relations'] if r.get('polymorphic'))} punteados)")
        print(
            f"  Total de llamadas a la API: "
            f"{len(frames) + len(shapes) + len(model['relations'])}"
        )
        # Muestra lo que se enviaría: permite revisar el formato sin token.
        sample = next(s for s in shapes if s["table"]["name"] == "eco_participants")
        print()
        print("  Payload de ejemplo (shape):")
        print(json.dumps(build_shape_payload(sample), ensure_ascii=False, indent=2))
        sample_rel = next(r for r in model["relations"] if r.get("polymorphic"))
        print()
        print("  Payload de ejemplo (connector polimórfico):")
        print(
            json.dumps(
                build_connector_payload(
                    sample_rel,
                    {sample_rel["from"]: "ID_A", sample_rel["to"]: "ID_B"},
                ),
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    if not args.token:
        args.token = read_credential_file(TOKEN_FILE)
    if not args.board:
        args.board = read_credential_file(BOARD_FILE)

    if not args.token:
        print(
            "Falta el token. Tres formas de darlo, de la más segura a la menos:\n"
            f"  1. Escribirlo en {TOKEN_FILE.name} (gitignored, nunca sale de tu máquina).\n"
            "  2. Variable de entorno MIRO_ACCESS_TOKEN.\n"
            "  3. --token (queda en el historial del shell).\n\n"
            "Cómo obtenerlo: developers.miro.com -> Your apps -> tu app -> "
            "Install app and get OAuth token (scopes boards:read + boards:write).",
            file=sys.stderr,
        )
        return 1
    if args.list_boards:
        try:
            return list_boards(args.token)
        except MiroError as error:
            print(f"\nError de Miro: {error}", file=sys.stderr)
            return 1

    if args.create_board:
        try:
            board = create_board(args.token, args.create_board)
        except MiroError as error:
            print(f"\nError de Miro: {error}", file=sys.stderr)
            return 1
        args.board = board["id"]
        BOARD_FILE.write_text(
            "# Board del ER de Níkara, creado con --create-board.\n"
            f"{args.board}\n",
            encoding="utf-8",
        )
        print(f"Board creado: {board.get('name')} ({args.board})")
        print(f"  id guardado en {BOARD_FILE.name}")
        print(f"  {board.get('viewLink', '')}")

    if not args.board:
        print(
            f"Falta el board: escribilo en {BOARD_FILE.name}, exportá MIRO_BOARD_ID "
            "o pasá --board.\n"
            "Es la parte de la URL después de /board/ (incluye el `=` final).\n"
            "Si no sabés cuál es, corré: python scripts/er_diagram/export_miro.py --list-boards",
            file=sys.stderr,
        )
        return 1

    try:
        board = request("GET", f"/boards/{args.board}", args.token)
        print(f"Board: {board.get('name', '(sin nombre)')}")

        if args.replace:
            delete_previous(args.board, args.token)

        created: list[dict] = []
        frame_ids: dict[str, str] = {}
        print(f"\nCreando {len(frames)} frames…")
        for frame in frames:
            response = request(
                "POST",
                f"/boards/{args.board}/frames",
                args.token,
                {
                    "data": {
                        "title": frame["module"],
                        "format": "custom",
                        "type": "freeform",
                    },
                    "position": {"x": frame["x"], "y": frame["y"], "origin": "center"},
                    "geometry": {"width": frame["width"], "height": frame["height"]},
                    "style": {"fillColor": "#ffffff"},
                },
            )
            frame_ids[frame["module"]] = response["id"]
            created.append({"type": "frame", "id": response["id"]})

        print(f"Creando {len(shapes)} tablas…")
        ids: dict[str, str] = {}
        for shape in shapes:
            parent = frame_ids.get(shape["module"]) if args.parent_frames else None
            response = request(
                "POST",
                f"/boards/{args.board}/shapes",
                args.token,
                build_shape_payload(shape, parent),
            )
            ids[shape["table"]["name"]] = response["id"]
            created.append({"type": "shape", "id": response["id"]})

        print(f"Creando {len(model['relations'])} relaciones…")
        skipped = 0
        for relation in model["relations"]:
            payload = build_connector_payload(relation, ids)
            if payload is None:
                skipped += 1
                continue
            response = request(
                "POST", f"/boards/{args.board}/connectors", args.token, payload
            )
            created.append({"type": "connector", "id": response["id"]})

        save_state({"board": args.board, "items": created})
        print(
            f"\nListo: {len(created)} items en el board."
            + (f" ({skipped} relaciones omitidas)" if skipped else "")
        )
        print(f"https://miro.com/app/board/{args.board}/")
        return 0
    except MiroError as error:
        print(f"\nError de Miro: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
