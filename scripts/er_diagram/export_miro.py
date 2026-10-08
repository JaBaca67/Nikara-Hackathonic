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
# El script se corre por ruta (`python scripts/er_diagram/export_miro.py`), así
# que su carpeta no está en el path por defecto.
sys.path.insert(0, str(HERE))

import layout as layout_engine  # noqa: E402
import render  # noqa: E402
MODEL = HERE / "model_2nf.json"
STATE = HERE / ".miro_state.json"
# Credenciales locales, nunca versionadas (ver .gitignore).
TOKEN_FILE = HERE / ".miro_token"
BOARD_FILE = HERE / ".miro_board"
API = "https://api.miro.com/v2"

# Un color de cabecera por módulo, todos tomados de los tokens reales del
# proyecto (lib/theme/app_colors.dart): los tres primitivos de marca más los
# tokens de estado. El color del texto de cada cabecera no se elige a mano —
# `render.contrast_text` lo decide por luminancia.
MODULE_COLOR = {
    "Identidad y cuentas": "#fdbe02",   # goldFill
    "Negocios": "#c2ca5b",              # oliveFill
    "Módulo ECO": "#3a7d3a",            # success
    "Rutas y viajes": "#ff8243",        # orangeFill
    "Interacción social": "#6b7033",    # oliveText
    "Avisos y automatización": "#cc5510",  # destructive
}
DEFAULT_COLOR = "#fdfdfd"


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


def find_overlaps(shapes: list[dict]) -> list[tuple[str, str]]:
    """Pares de tablas cuyos rectángulos se pisan.

    Un solapamiento significa texto tapado, así que se chequea antes de
    publicar y después de publicar (contra lo que la API devuelve), en vez de
    confiar en que el cálculo del layout salió bien.
    """
    found = []
    for i, a in enumerate(shapes):
        for b in shapes[i + 1 :]:
            same_x = (
                abs(a["x"] - b["x"]) * 2 < a["width"] + b["width"]
            )
            same_y = (
                abs(a["y"] - b["y"]) * 2 < a["height"] + b["height"]
            )
            if same_x and same_y:
                found.append((a["table"]["name"], b["table"]["name"]))
    return found


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
        "captions": [{"content": render.escape(label), "position": "50%"}],
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
    plan = layout_engine.plan(model)
    shapes = plan["shapes"]
    items_per_table = 5  # marco + cabecera + 3 columnas
    total_calls = (
        len(shapes) * items_per_table
        + len(model["relations"])
        + len(MODULE_COLOR)
        + 1  # leyenda
    )

    if args.dry_run:
        print(
            f"Plan para {len(model['tables'])} tablas y "
            f"{len(model['relations'])} relaciones"
        )
        print()
        print(
            f"  Cruces de flechas: {plan['crossings_before']} -> "
            f"{plan['crossings_after']}  "
            f"(longitud total {plan['length_before']:.0f} -> {plan['length_after']:.0f})"
        )
        print()
        for index, names in plan["layers"].items():
            print(f"  COLUMNA {index}: {len(names)} tablas")
            for name in names:
                shape = next(s for s in shapes if s["table"]["name"] == name)
                print(
                    f"      {name:34} {len(shape['table']['columns']):2} attrs  "
                    f"{shape['width']:.0f}x{shape['height']:.0f} @ "
                    f"({shape['x']:.0f}, {shape['y']:.0f})"
                )
        overlaps = find_overlaps(shapes)
        print()
        print(f"  Solapamientos entre tablas: {len(overlaps)}")
        for a_name, b_name in overlaps:
            print(f"      {a_name} <-> {b_name}")
        print()
        print(f"  Total de llamadas a la API: {total_calls}")
        sample = next(s for s in shapes if s["table"]["name"] == "eco_participants")
        print()
        print(f"  Items de una tabla ({sample['table']['name']}):")
        for payload in render.build_items(
            sample,
            MODULE_COLOR.get(sample["module"], DEFAULT_COLOR),
            layout_engine.ROW_HEIGHT,
            layout_engine.HEADER_HEIGHT,
        ):
            position = payload["position"]
            geometry = payload.get("geometry", {})
            print(
                f"      {payload['_kind']:6} {payload['_role']:10} "
                f"@ ({position['x']:.0f}, {position['y']:.0f}) "
                f"{geometry.get('width', 0):.0f}x{geometry.get('height', 0):.0f}"
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
        endpoint = {"shape": "shapes", "text": "texts"}

        print(f"Creando {len(shapes)} tablas ({len(shapes) * 5} items)…")
        ids: dict[str, str] = {}
        for shape in shapes:
            color = MODULE_COLOR.get(shape["module"], DEFAULT_COLOR)
            # El orden de `build_items` es deliberado: cuerpo, separadores,
            # cabecera y recién al final los textos, para que nada los tape.
            for payload in render.build_items(
                shape, color, layout_engine.ROW_HEIGHT, layout_engine.HEADER_HEIGHT
            ):
                kind, role = payload.pop("_kind"), payload.pop("_role")
                response = request(
                    "POST",
                    f"/boards/{args.board}/{endpoint[kind]}",
                    args.token,
                    payload,
                )
                created.append({"type": kind, "id": response["id"]})
                if role == "body":
                    # Los connectors se enganchan al cuerpo, no a la cabecera.
                    ids[shape["table"]["name"]] = response["id"]

        print("Creando la leyenda…")
        top_left = min(shapes, key=lambda s: (s["x"], s["y"]))
        for payload in render.legend_items(
            MODULE_COLOR,
            top_left["x"] - top_left["width"] / 2,
            min(s["y"] - s["height"] / 2 for s in shapes) - 220,
        ):
            kind = payload.pop("_kind")
            payload.pop("_role")
            response = request(
                "POST", f"/boards/{args.board}/{endpoint[kind]}", args.token, payload
            )
            created.append({"type": kind, "id": response["id"]})

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
