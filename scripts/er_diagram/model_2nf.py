"""Normaliza el esquema físico de Níkara hasta la 2FN.

QUÉ HACE
--------
Lee `schema_physical.json` (lo que hay hoy en Postgres) y aplica, de forma
declarativa y auditable, las descomposiciones necesarias para que el modelo
cumpla 1FN y 2FN. El resultado es `model_2nf.json`, que alimenta tanto el
export a Mermaid como el export a Miro.

EL ANÁLISIS, EN CORTO
---------------------
**1FN — atributos multivaluados.** Postgres permite columnas `text[]`, pero un
atributo multivaluado rompe 1FN: la celda deja de ser atómica. El esquema tiene
9 columnas así, y cada una se descompone en una tabla hija con PK compuesta.

**2FN — dependencias parciales.** Solo pueden darse en tablas con clave
primaria compuesta: un atributo no clave que dependa de *parte* de la clave.
Se revisan eco_participants, notification_event_receipts y
notification_completed_trips, además de las claves alternativas UNIQUE.
Las fotos y medios se identifican por (entidad_id, position); la URL depende
de ambas columnas. Las demás tablas hijas no tienen atributos fuera de la PK.
La evaluación depende de las reglas de negocio detalladas en
docs/diagramacion_bd/README.md, no únicamente de la sintaxis SQL.

FUERA DE ALCANCE (y por qué se declara en vez de callarse)
----------------------------------------------------------
`route_stops` copia `title`, `subtitle`, `category`, `image_path`, `latitude` y
`longitude` del negocio o la jornada que referencia, y `eco_activities` copia
`organizer_name`/`organizer_verified` de la organización. Son datos que dependen
de un atributo no clave, no de parte de la PK — eso es una **dependencia
transitiva (3FN)**, no una violación de 2FN. Se marcan en el modelo para que el
diagrama las muestre como deuda conocida, pero no se descomponen: el entregable
pide hasta 2FN, y en el código son un snapshot deliberado (la parada conserva lo
que se vio al armarla aunque el negocio cambie después).

Uso:
    python scripts/er_diagram/model_2nf.py
"""

from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "schema_physical.json"
OUT = HERE / "model_2nf.json"

# ---------------------------------------------------------------------------
# 1FN: cada array se convierte en una tabla hija.
#   parent  -> tabla de la que sale
#   column  -> columna `text[]` que se elimina
#   table   -> tabla hija nueva
#   fk      -> columna que apunta al padre (hereda su PK)
#   value   -> columna que guarda cada elemento del array
#   ordered -> True si el orden importa (fotos); agrega `position` a la PK
# ---------------------------------------------------------------------------
FIRST_NF_DECOMPOSITIONS = [
    {
        "parent": "businesses",
        "column": "photos",
        "table": "business_photos",
        "fk": "business_id",
        "value": "photo_url",
        "value_type": "text",
        "ordered": True,
        "note": "El orden define cuál es la foto de portada.",
    },
    {
        "parent": "businesses",
        "column": "amenities",
        "table": "business_amenities",
        "fk": "business_id",
        "value": "amenity",
        "value_type": "text",
        "ordered": False,
    },
    {
        "parent": "businesses",
        "column": "activities",
        "table": "business_activities",
        "fk": "business_id",
        "value": "activity",
        "value_type": "text",
        "ordered": False,
    },
    {
        "parent": "businesses",
        "column": "eco_practices",
        "table": "business_eco_practices",
        "fk": "business_id",
        "value": "practice",
        "value_type": "text",
        "ordered": False,
    },
    {
        "parent": "businesses",
        "column": "day_pass_includes",
        "table": "day_pass_items",
        "fk": "business_id",
        "value": "item",
        "value_type": "text",
        "ordered": False,
        "note": "Qué incluye el day pass de hospedaje.",
    },
    {
        "parent": "eco_activities",
        "column": "requirements",
        "table": "eco_activity_requirements",
        "fk": "activity_id",
        "value": "requirement",
        "value_type": "text",
        "ordered": False,
        "note": "Checklist de 'Requisitos y qué llevar'.",
    },
    {
        "parent": "reviews",
        "column": "media_urls",
        "table": "review_media",
        "fk": "review_id",
        "value": "media_url",
        "value_type": "text",
        "ordered": True,
    },
    {
        "parent": "routes",
        "column": "image_urls",
        "table": "route_images",
        "fk": "route_id",
        "value": "image_url",
        "value_type": "text",
        "ordered": True,
    },
    {
        "parent": "origin_places",
        "column": "aliases",
        "table": "origin_place_aliases",
        "fk": "municipality_code",
        "fk_type": "text",
        "value": "alias",
        "value_type": "text",
        "ordered": False,
        "note": "Variantes de nombre para búsqueda y normalización.",
    },
]

# Agrupación visual del diagrama. No es parte del modelo relacional: existe
# para que un board con 24 tablas se pueda leer.
MODULES = {
    "Identidad y cuentas": [
        "auth_users",
        "profiles",
        "legal_identities",
        "audit_logs",
        "origin_places",
        "origin_place_aliases",
    ],
    "Negocios": [
        "businesses",
        "business_photos",
        "business_amenities",
        "business_activities",
        "business_eco_practices",
        "day_pass_items",
        "business_posts",
    ],
    "Módulo ECO": [
        "organizations",
        "eco_activities",
        "eco_activity_requirements",
        "eco_participants",
    ],
    "Rutas y viajes": ["routes", "route_images", "route_stops"],
    "Interacción social": ["reviews", "review_media", "user_favorites"],
    "Avisos y automatización": [
        "notifications",
        "device_push_tokens",
        "notification_automation_settings",
        "notification_event_receipts",
        "notification_completed_trips",
    ],
}

# Mantener auth.users como entidad externa: 013 redirige tres FK a profiles,
# pero 023 y 037 crean otras FK directas hacia auth.users.
REFERENCE_REWRITES = {"users.id": "auth_users.id"}

# Relaciones que no se pueden derivar de una FK porque la columna es
# polimórfica (una sola columna que apunta a dos tablas según un
# discriminador). No es una violación de forma normal, pero sí deja la
# integridad referencial fuera de la base, así que el diagrama lo muestra.
POLYMORPHIC_RELATIONS = [
    {
        "table": "reviews",
        "discriminator": "target_type",
        "key": "target_id",
        "targets": ["businesses", "eco_activities"],
    },
    {
        "table": "user_favorites",
        "discriminator": "item_type",
        "key": "item_id",
        "targets": ["businesses", "eco_activities", "routes"],
    },
    {
        "table": "notifications",
        "discriminator": "type",
        "key": "reference_id",
        "targets": ["businesses", "eco_activities", "organizations"],
    },
]

# Dependencias transitivas conocidas (3FN) — se declaran, no se resuelven.
TRANSITIVE_DEBT = {
    "route_stops": [
        "title",
        "subtitle",
        "category",
        "image_path",
        "latitude",
        "longitude",
    ],
    "eco_activities": ["organizer_name", "organizer_verified"],
}


def load_physical() -> dict:
    if not SOURCE.is_file():
        raise SystemExit(
            f"Falta {SOURCE.name}. Corré antes: python scripts/er_diagram/extract_schema.py"
        )
    return json.loads(SOURCE.read_text(encoding="utf-8"))


def build() -> dict:
    physical = load_physical()
    archive_tables = {"reviews_backup"}
    tables = {t["name"]: json.loads(json.dumps(t)) for t in physical["tables"]
              if t["name"] not in archive_tables}
    tables["auth_users"] = {
        "name": "auth_users", "schema": "auth", "physical_name": "users",
        "columns": [{"name": "id", "type": "uuid", "pk": True, "not_null": True}],
        "source": "Supabase Auth (entidad externa; solo clave referenciada)",
        "external": True,
    }

    # --- 1FN: sacar los arrays a tablas hijas -------------------------------
    created = []
    for rule in FIRST_NF_DECOMPOSITIONS:
        parent = tables.get(rule["parent"])
        if parent is None:
            raise SystemExit(f"La tabla padre {rule['parent']} no existe en el esquema.")
        before = len(parent["columns"])
        parent["columns"] = [
            c for c in parent["columns"] if c["name"] != rule["column"]
        ]
        if len(parent["columns"]) == before:
            raise SystemExit(
                f"{rule['parent']}.{rule['column']} ya no existe: revisá la regla."
            )

        parent_pk = next(c for c in parent["columns"] if c.get("pk"))
        columns = [
            {
                "name": rule["fk"],
                "type": rule.get("fk_type", parent_pk["type"]),
                "pk": True,
                "not_null": True,
                "references": f"{rule['parent']}.{parent_pk['name']}",
            }
        ]
        if rule["ordered"]:
            columns.append(
                {"name": "position", "type": "integer", "pk": True, "not_null": True}
            )
            columns.append(
                {"name": rule["value"], "type": rule["value_type"], "not_null": True}
            )
        else:
            columns.append(
                {
                    "name": rule["value"],
                    "type": rule["value_type"],
                    "pk": True,
                    "not_null": True,
                }
            )

        tables[rule["table"]] = {
            "name": rule["table"],
            "columns": columns,
            "source": f"1FN: descompone {rule['parent']}.{rule['column']}",
            "derived": True,
            "note": rule.get("note", ""),
        }
        created.append(rule["table"])

    # --- Relaciones derivadas de las FK ------------------------------------
    relations = []
    for table in tables.values():
        pk_names = {c["name"] for c in table["columns"] if c.get("pk")}
        for column in table["columns"]:
            ref = column.get("references")
            if not ref:
                continue
            ref = REFERENCE_REWRITES.get(ref, ref)
            column["references"] = ref
            target = ref.split(".")[0]
            if target not in tables:
                continue
            # 1:1 cuando la FK es toda la PK o tiene restricción UNIQUE.
            one_to_one = pk_names == {column["name"]} or column.get("unique")
            relations.append(
                {
                    "from": target,
                    "to": table["name"],
                    "fk": column["name"],
                    "from_columns": [ref.split(".")[1]],
                    "to_columns": [column["name"]],
                    "kind": "1:1" if one_to_one else "1:N",
                    "optional": not column.get("not_null", False),
                }
            )
        for fk in table.get("foreign_keys", []):
            target = fk["references_table"]
            if target not in tables:
                continue
            relations.append({
                "from": target, "to": table["name"], "fk": ", ".join(fk["columns"]),
                "from_columns": fk["references_columns"], "to_columns": fk["columns"],
                "kind": "1:N", "optional": any(not c.get("not_null") for c in table["columns"] if c["name"] in fk["columns"]),
                "not_valid": fk.get("not_valid", False), "composite": True,
            })

    # `legal_identities.user_id` es unique en la base (una identidad por
    # cuenta); el extractor no lee los `unique (...)` de nivel de tabla.
    for relation in relations:
        if relation["to"] == "legal_identities" and relation["fk"] == "user_id":
            relation["kind"] = "1:1"

    # --- Relaciones polimórficas (FK lógica, no declarada en la base) -------
    for poly in POLYMORPHIC_RELATIONS:
        if poly["table"] not in tables:
            continue
        for target in poly["targets"]:
            if target not in tables:
                continue
            relations.append(
                {
                    "from": target,
                    "to": poly["table"],
                    "fk": f"{poly['key']} ({poly['discriminator']})",
                    "kind": "1:N",
                    "optional": True,
                    "polymorphic": True,
                }
            )

    module_of = {
        name: module for module, names in MODULES.items() for name in names
    }
    missing = [n for n in tables if n not in module_of]
    if missing:
        raise SystemExit(f"Tablas sin módulo asignado: {missing}")

    for name, table in tables.items():
        table["module"] = module_of[name]
        table["pk"] = [c["name"] for c in table["columns"] if c.get("pk")]
        if name in TRANSITIVE_DEBT:
            table["transitive_debt"] = TRANSITIVE_DEBT[name]

    payload = {
        "normal_form": "2FN",
        "source_tables": len(physical["tables"]) - len(archive_tables),
        "excluded_archive_tables": [
            {"name": name, "reason": "Copia de respaldo sin clave primaria ni UNIQUE, fuera del ciclo de la aplicación; incluida solo en el esquema físico."}
            for name in sorted(archive_tables) if name in {t["name"] for t in physical["tables"]}
        ],
        "tables_created_for_1nf": created,
        "total_tables": len(tables),
        "modules": list(MODULES),
        "tables": [tables[name] for name in sorted(tables)],
        "relations": sorted(
            relations, key=lambda r: (r["from"], r["to"], r["fk"])
        ),
        "notes": {
            "2nf": (
                "PK compuestas heredadas: eco_participants(activity_id, user_id), "
                "notification_event_receipts(user_id, event_key) y "
                "notification_completed_trips(user_id, trip_id). Se considera la "
                "inscripción, el evento por usuario y el viaje por usuario como unidad "
                "de identificación. Sus atributos no clave dependen de la clave completa "
                "bajo esas reglas de negocio. En fotos y medios, la URL depende de "
                "(entidad_id, position); en las otras tablas nuevas todos los atributos "
                "integran la PK. Las claves alternativas UNIQUE con columnas NOT NULL "
                "se revisan también; un identificador simple no elimina por sí solo "
                "las posibles dependencias parciales de claves alternativas."
            ),
            "out_of_scope_3nf": TRANSITIVE_DEBT,
        },
    }
    return payload


def main() -> int:
    payload = build()
    OUT.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"Modelo 2FN -> {OUT.name}")
    print(
        f"  {payload['source_tables']} tablas físicas "
        f"+ {len(payload['tables_created_for_1nf'])} creadas por 1FN "
        f"+ 1 entidad externa (auth.users) "
        f"= {payload['total_tables']} entidades"
    )
    for archive in payload["excluded_archive_tables"]:
        print(f"  Archivo del esquema físico fuera del ER normalizado: {archive['name']} (sin PK)")
    print(f"  {len(payload['relations'])} relaciones "
          f"({sum(1 for r in payload['relations'] if r.get('polymorphic'))} polimórficas)")
    for name in payload["tables_created_for_1nf"]:
        print(f"  + {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
