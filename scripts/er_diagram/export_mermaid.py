"""Genera el ER en Mermaid desde `model_2nf.json`.

Sirve para dos cosas: revisar el modelo rápido (GitHub renderiza `erDiagram` en
cualquier `.md`) y tener el diagrama versionado en el repo, independiente de
Miro.

Uso:
    python scripts/er_diagram/export_mermaid.py            # -> docs/er_2fn.md
    python scripts/er_diagram/export_mermaid.py --stdout    # imprime y no escribe
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
MODEL = HERE / "model_2nf.json"
OUT = REPO / "docs" / "er_2fn.md"

# Mermaid no acepta tipos con paréntesis ni corchetes en el bloque de atributos.
TYPE_ALIASES = {
    "geography(Point,4326)": "geography_point",
    "double precision": "float8",
    "timestamptz": "timestamptz",
}


def mermaid_type(raw: str) -> str:
    return TYPE_ALIASES.get(raw, raw.replace("[]", "_array"))


def cardinality(relation: dict) -> str:
    """Notación crow's foot de Mermaid para el lado 'uno' y el lado 'muchos'."""
    left = "||"
    if relation["kind"] == "1:1":
        right = "o|" if relation["optional"] else "||"
    else:
        right = "o{"
    return f"{left}--{right}"


def render(model: dict) -> str:
    lines = ["erDiagram"]

    by_module: dict[str, list[dict]] = {}
    for table in model["tables"]:
        by_module.setdefault(table["module"], []).append(table)

    for module in model["modules"]:
        lines.append(f"    %% ---- {module} ----")
        for table in by_module.get(module, []):
            lines.append(f"    {table['name'].upper()} {{")
            for column in table["columns"]:
                key = ""
                if column.get("pk"):
                    key = "PK"
                elif column.get("references"):
                    key = "FK"
                comment = []
                if column.get("references"):
                    comment.append(f"-> {column['references']}")
                if column["name"] in table.get("transitive_debt", []):
                    comment.append("3FN: dependencia transitiva")
                suffix = f' "{"; ".join(comment)}"' if comment else ""
                lines.append(
                    f"        {mermaid_type(column['type'])} {column['name']}"
                    f"{(' ' + key) if key else ''}{suffix}"
                )
            lines.append("    }")

    lines.append("")
    lines.append("    %% ---- Relaciones ----")
    for relation in model["relations"]:
        label = relation["fk"]
        if relation.get("polymorphic"):
            label = f"{label} *"
        lines.append(
            f"    {relation['from'].upper()} {cardinality(relation)} "
            f"{relation['to'].upper()} : \"{label}\""
        )
    return "\n".join(lines)


def document(model: dict, diagram: str) -> str:
    created = model["tables_created_for_1nf"]
    debt = model["notes"]["out_of_scope_3nf"]
    polymorphic = [r for r in model["relations"] if r.get("polymorphic")]

    rows = []
    for table in model["tables"]:
        if not table.get("derived"):
            continue
        origin = table["source"].replace("1FN: descompone ", "")
        rows.append(
            f"| `{origin}` | `{table['name']}` | {', '.join(table['pk'])} |"
        )

    return f"""# Modelo ER hasta la 2FN — Níkara

> Generado por `scripts/er_diagram/export_mermaid.py` a partir de
> `model_2nf.json`. **No editar a mano**: cambiá el modelo y volvé a generar.

El esquema físico de Supabase tiene **{model['source_tables']} tablas**. Llevarlo a
2FN agrega **{len(created)}** entidades (descomposición de atributos multivaluados),
para un total de **{model['total_tables']}** entidades y **{len(model['relations'])}** relaciones.

## 1FN — atributos multivaluados descompuestos

Postgres permite columnas `text[]`, pero un atributo multivaluado rompe 1FN: la
celda deja de ser atómica. Cada array se convierte en una tabla hija con clave
primaria compuesta.

| Columna original | Tabla nueva | PK |
|---|---|---|
{chr(10).join(rows)}

## 2FN — dependencias parciales

{model['notes']['2nf']}

## Fuera de alcance: dependencias transitivas (3FN)

Se declaran para que el diagrama sea honesto, pero **no** se descomponen — el
entregable pide hasta 2FN, y en el código son un snapshot deliberado (la parada
de una ruta conserva lo que se vio al armarla aunque el negocio cambie después).

{chr(10).join(f"- `{table}`: {', '.join(f'`{c}`' for c in columns)}" for table, columns in debt.items())}

## Relaciones polimórficas

{len(polymorphic)} relaciones (marcadas con `*` en el diagrama) salen de una columna
que apunta a varias tablas según un discriminador — `reviews(target_type,
target_id)`, `user_favorites(item_type, item_id)` y `notifications(type,
reference_id)`. No viola ninguna forma normal, pero deja la integridad
referencial fuera de la base: se valida en la aplicación.

## Diagrama

```mermaid
{diagram}
```
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stdout", action="store_true", help="imprime sin escribir")
    args = parser.parse_args()

    if not MODEL.is_file():
        raise SystemExit("Falta model_2nf.json. Corré antes: python scripts/er_diagram/model_2nf.py")
    model = json.loads(MODEL.read_text(encoding="utf-8"))
    diagram = render(model)

    if args.stdout:
        print(diagram)
        return 0

    OUT.write_text(document(model, diagram), encoding="utf-8")
    print(f"{OUT.relative_to(REPO)} actualizado ({len(diagram.splitlines())} líneas de diagrama)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
