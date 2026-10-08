"""Extrae el esquema físico real de Postgres desde `supabase/sql/*.sql`.

POR QUÉ UN EXTRACTOR Y NO UN JSON ESCRITO A MANO
------------------------------------------------
El esquema vive repartido en 44 migraciones que se aplican en orden: una tabla
se crea en un archivo y cinco archivos después le agregan tres columnas.
Transcribir eso a mano envejece mal y se equivoca en silencio. Este script lee
las migraciones en orden y reconstruye el estado final.

LÍMITE CONOCIDO: `businesses` se creó desde el dashboard de Supabase, no desde
`supabase/sql/`, así que ninguna migración tiene su `create table`. Sus
columnas base se declaran acá en `TABLES_WITHOUT_DDL` (tomadas de
`docs/database_erd.md`, que sí las documenta); las migraciones solo la
extienden.

SALIDA: `schema_physical.json` — el esquema tal como está hoy en la base, con
sus atributos multivaluados (`text[]`) intactos. La normalización a 2FN es un
paso aparte (`model_2nf.py`), para que el modelo normalizado se pueda comparar
contra lo que realmente existe.

Uso:
    python scripts/er_diagram/extract_schema.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SQL_DIR = REPO / "supabase" / "sql"
OUT = Path(__file__).resolve().parent / "schema_physical.json"

# Tablas sin `create table` en las migraciones. `businesses` nació en el
# dashboard; estas son sus columnas base según docs/database_erd.md, antes de
# que las migraciones 003/007/013/018/020/021/037/042 la extiendan.
TABLES_WITHOUT_DDL: dict[str, list[dict]] = {
    "businesses": [
        {"name": "id", "type": "uuid", "pk": True},
        {"name": "owner_id", "type": "uuid", "references": "profiles.id"},
        {"name": "name", "type": "text"},
        {"name": "category", "type": "text"},
        {"name": "description", "type": "text"},
        {"name": "city", "type": "text"},
        {"name": "address_text", "type": "text"},
        {"name": "location", "type": "geography(Point,4326)"},
        {"name": "phone", "type": "text"},
        {"name": "instagram_handle", "type": "text"},
        {"name": "photos", "type": "text[]"},
        {"name": "is_verified", "type": "boolean"},
        {"name": "created_at", "type": "timestamptz"},
    ],
    # `profiles` tampoco tiene `create table` en las migraciones: 001 solo le
    # pone el trigger de alta y las policies. Columnas base según
    # docs/database_erd.md; 013 y 039 le agregan avatar_url, procedencia y
    # perfil público por `alter table`.
    "profiles": [
        {"name": "id", "type": "uuid", "pk": True, "references": "users.id"},
        {"name": "full_name", "type": "text"},
        {"name": "email", "type": "text"},
        {"name": "phone", "type": "text"},
        {"name": "role", "type": "user_role"},
        {"name": "points", "type": "integer"},
    ],
}

# Se ignoran: tablas del sistema y de extensiones que no son del modelo.
IGNORED = {"spatial_ref_sys", "buckets", "objects"}

CREATE_RE = re.compile(
    r"create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?(\w+)\s*\((.*?)\n\);",
    re.IGNORECASE | re.DOTALL,
)
ALTER_RE = re.compile(
    r"alter\s+table\s+(?:only\s+)?(?:public\.)?(\w+)\s+(.*?);",
    re.IGNORECASE | re.DOTALL,
)
ADD_COLUMN_RE = re.compile(
    r"add\s+column\s+(?:if\s+not\s+exists\s+)?(\w+)\s+([^,]+?)(?=,\s*add\s+column|,\s*$|$)",
    re.IGNORECASE | re.DOTALL,
)
DROP_COLUMN_RE = re.compile(
    r"drop\s+column\s+(?:if\s+exists\s+)?(\w+)", re.IGNORECASE
)
REFERENCES_RE = re.compile(
    r"references\s+(?:public\.|auth\.)?(\w+)\s*\(\s*(\w+)\s*\)", re.IGNORECASE
)
PK_INLINE_RE = re.compile(r"\bprimary\s+key\b", re.IGNORECASE)
PK_TABLE_RE = re.compile(
    r"primary\s+key\s*\(([^)]+)\)", re.IGNORECASE
)
TYPE_RE = re.compile(
    r"^((?:geography|geometry)\s*\([^)]*\)|[a-z_]+(?:\s*\[\s*\])?|[a-z ]+?)(?=\s|$)",
    re.IGNORECASE,
)


def strip_comments(sql: str) -> str:
    """Quita comentarios de línea sin romper los literales con `--` dentro."""
    out = []
    for line in sql.splitlines():
        in_str = False
        cut = None
        i = 0
        while i < len(line):
            ch = line[i]
            if ch == "'":
                in_str = not in_str
            elif not in_str and line.startswith("--", i):
                cut = i
                break
            i += 1
        out.append(line[:cut] if cut is not None else line)
    return "\n".join(out)


def split_columns(body: str) -> list[str]:
    """Parte el cuerpo de un `create table` por comas de primer nivel."""
    parts, depth, current = [], 0, []
    for ch in body:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(ch)
    if current:
        parts.append("".join(current))
    return [p.strip() for p in parts if p.strip()]


def normalize_type(raw: str) -> str:
    raw = " ".join(raw.split())
    match = TYPE_RE.match(raw)
    kind = match.group(1).strip() if match else raw.split(" ")[0]
    # `text []` -> `text[]`, `double precision` se conserva entero.
    if raw.lower().startswith("double precision"):
        kind = "double precision"
    return kind.replace(" [ ]", "[]").replace(" []", "[]")


def parse_column(clause: str) -> dict | None:
    """Convierte una cláusula de columna en un dict; None si es constraint."""
    lowered = clause.strip().lower()
    if lowered.startswith(
        ("primary key", "unique", "constraint", "check", "foreign key", "exclude")
    ):
        return None
    tokens = clause.strip().split(None, 1)
    if len(tokens) < 2:
        return None
    name, rest = tokens[0], tokens[1]
    # `audit_logs."timestamp"` va entrecomillado en el SQL porque es palabra
    # reservada; el modelo guarda el nombre limpio y marca que necesita quotes.
    quoted = name.startswith('"') and name.endswith('"')
    column = {"name": name.strip('"'), "type": normalize_type(rest)}
    if quoted:
        column["quoted"] = True
    if PK_INLINE_RE.search(rest):
        column["pk"] = True
    ref = REFERENCES_RE.search(rest)
    if ref:
        column["references"] = f"{ref.group(1)}.{ref.group(2)}"
    if "not null" in rest.lower():
        column["not_null"] = True
    return column


def main() -> int:
    if not SQL_DIR.is_dir():
        print(
            f"No se encontró {SQL_DIR}.\n"
            "`supabase/` está gitignored (repo público): pedí la carpeta al equipo "
            "o usá el schema_physical.json ya versionado.",
            file=sys.stderr,
        )
        return 1

    tables: dict[str, dict] = {
        name: {"name": name, "columns": list(cols), "source": "dashboard (sin DDL)"}
        for name, cols in TABLES_WITHOUT_DDL.items()
    }

    for path in sorted(SQL_DIR.glob("*.sql")):
        sql = strip_comments(path.read_text(encoding="utf-8"))

        for name, body in CREATE_RE.findall(sql):
            if name in IGNORED:
                continue
            table = tables.setdefault(
                name, {"name": name, "columns": [], "source": path.name}
            )
            existing = {c["name"] for c in table["columns"]}
            for clause in split_columns(body):
                pk_table = PK_TABLE_RE.match(clause.strip())
                if pk_table:
                    for col in (c.strip() for c in pk_table.group(1).split(",")):
                        for c in table["columns"]:
                            if c["name"] == col:
                                c["pk"] = True
                    continue
                column = parse_column(clause)
                if column and column["name"] not in existing:
                    table["columns"].append(column)
                    existing.add(column["name"])

        for name, action in ALTER_RE.findall(sql):
            if name in IGNORED or name not in tables:
                # Un alter sobre una tabla que no conocemos (p. ej. storage) se
                # ignora en vez de inventar la tabla.
                if name not in tables:
                    continue
            table = tables[name]
            existing = {c["name"] for c in table["columns"]}
            for col_name, definition in ADD_COLUMN_RE.findall(action):
                if col_name in existing:
                    continue
                column = {"name": col_name, "type": normalize_type(definition)}
                ref = REFERENCES_RE.search(definition)
                if ref:
                    column["references"] = f"{ref.group(1)}.{ref.group(2)}"
                if "not null" in definition.lower():
                    column["not_null"] = True
                table["columns"].append(column)
                existing.add(col_name)
            for col_name in DROP_COLUMN_RE.findall(action):
                table["columns"] = [
                    c for c in table["columns"] if c["name"] != col_name
                ]

    payload = {
        "generated_from": "supabase/sql/*.sql",
        "migrations": len(list(SQL_DIR.glob("*.sql"))),
        "tables": [tables[name] for name in sorted(tables)],
    }
    OUT.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    multivalued = [
        f"{t['name']}.{c['name']}"
        for t in payload["tables"]
        for c in t["columns"]
        if c["type"].endswith("[]")
    ]
    print(f"{len(payload['tables'])} tablas -> {OUT.name}")
    print(f"Atributos multivaluados (no cumplen 1FN): {len(multivalued)}")
    for item in multivalued:
        print(f"  - {item}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
