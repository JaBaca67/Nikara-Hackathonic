"""Layout jerárquico del ER, con minimización de cruces de aristas.

POR QUÉ EXISTE
--------------
La primera versión acomodaba las tablas por módulo temático (Negocios, ECO,
Rutas…), una columna por módulo. Se lee bien como índice, pero produce un
board lleno de flechas cruzadas: `profiles` es un hub al que apuntan 12 tablas
repartidas por todos los módulos, así que sus relaciones atraviesan el ancho
entero del diagrama.

Acá el layout lo dirige el **grafo**, no el tema:

1. **Capas** (columnas) por dependencia: una tabla va una columna a la derecha
   de la más profunda a la que referencia. Así toda FK apunta hacia la derecha
   y las tablas hija quedan pegadas a su padre.
2. **Orden dentro de cada capa** por minimización de cruces: se parte de un
   orden agrupado por módulo y se mejora con búsqueda local (reinserción de un
   nodo en la mejor posición de su columna), midiendo cruces reales entre
   segmentos. Es la idea del método de Sugiyama, con la medición hecha sobre la
   geometría final en vez de sobre capas abstractas — más simple y más honesta,
   porque cuenta exactamente lo que se va a ver.
3. El color sigue comunicando el módulo, así que la agrupación temática no se
   pierde: se mueve del eje X al color.

El criterio de desempate es la longitud total de las aristas: entre dos órdenes
con los mismos cruces, gana el que deja las flechas más cortas.
"""

from __future__ import annotations

import random
from itertools import combinations

# Geometría. Las columnas son anchas a propósito: los connectors de Miro son
# "elbowed" y necesitan espacio para doblar sin pisar una tabla.
TABLE_WIDTH = 560
ROW_HEIGHT = 20
HEADER_HEIGHT = 52
COLUMN_GAP = 300
ROW_GAP = 64


def table_height(table: dict) -> int:
    return HEADER_HEIGHT + ROW_HEIGHT * len(table["columns"])


def assign_layers(tables: list[dict], relations: list[dict]) -> dict[str, int]:
    """Columna de cada tabla: una más a la derecha que su dependencia más profunda.

    Solo se consideran las FK declaradas; las relaciones polimórficas se
    excluyen del cálculo porque una columna que apunta a tres tablas distintas
    no define una jerarquía (y metería ciclos).
    """
    depends_on: dict[str, set[str]] = {t["name"]: set() for t in tables}
    for relation in relations:
        if relation.get("polymorphic"):
            continue
        if relation["to"] in depends_on and relation["from"] != relation["to"]:
            depends_on[relation["to"]].add(relation["from"])

    layer: dict[str, int] = {}

    def resolve(name: str, seen: frozenset[str] = frozenset()) -> int:
        if name in layer:
            return layer[name]
        # Un ciclo entre FK no debería existir, pero si aparece se corta acá en
        # vez de reventar con recursión infinita.
        if name in seen:
            return 0
        parents = depends_on.get(name, set())
        value = 0 if not parents else 1 + max(
            resolve(parent, seen | {name}) for parent in parents
        )
        layer[name] = value
        return value

    for table in tables:
        resolve(table["name"])
    return layer


def _segments(order: dict[str, list[str]], heights: dict[str, int],
              relations: list[dict], layer: dict[str, int]) -> list[tuple]:
    """Centro de cada tabla y segmento de cada relación, en coordenadas finales."""
    centers: dict[str, tuple[float, float]] = {}
    for index, names in sorted(order.items()):
        total = sum(heights[n] for n in names) + ROW_GAP * (len(names) - 1)
        y = -total / 2
        x = index * (TABLE_WIDTH + COLUMN_GAP)
        for name in names:
            centers[name] = (x, y + heights[name] / 2)
            y += heights[name] + ROW_GAP

    segments = []
    for relation in relations:
        a, b = centers.get(relation["from"]), centers.get(relation["to"])
        if a and b and a != b:
            segments.append((a, b))
    return segments


def _crosses(s1: tuple, s2: tuple) -> bool:
    """¿Se cruzan dos segmentos? Comparten extremo no cuenta como cruce."""
    (p1, p2), (p3, p4) = s1, s2
    if p1 in (p3, p4) or p2 in (p3, p4):
        return False

    def side(a, b, c) -> float:
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    d1, d2 = side(p3, p4, p1), side(p3, p4, p2)
    d3, d4 = side(p1, p2, p3), side(p1, p2, p4)
    return ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0))


def score(order: dict[str, list[str]], heights: dict[str, int],
          relations: list[dict], layer: dict[str, int]) -> tuple[int, float]:
    """(cruces, longitud total). Se minimiza en ese orden lexicográfico."""
    segments = _segments(order, heights, relations, layer)
    crossings = sum(1 for s1, s2 in combinations(segments, 2) if _crosses(s1, s2))
    length = sum(
        ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5 for a, b in segments
    )
    return crossings, length


def layer_bounds(name: str, layer: dict[str, int],
                 relations: list[dict]) -> tuple[int, int]:
    """Rango de columnas en que la tabla puede estar sin invertir una FK.

    El mínimo lo fijan las tablas que referencia (tiene que quedar a su
    derecha); el máximo, las que la referencian a ella. Mover una tabla dentro
    de ese rango nunca hace que una flecha apunte hacia atrás.
    """
    low, high = 0, max(layer.values())
    for relation in relations:
        if relation.get("polymorphic"):
            continue
        if relation["to"] == name and relation["from"] in layer:
            low = max(low, layer[relation["from"]] + 1)
        if relation["from"] == name and relation["to"] in layer:
            high = min(high, layer[relation["to"]] - 1)
    return low, max(low, high)


def optimize(order: dict[int, list[str]], heights: dict[str, int],
             relations: list[dict], layer: dict[str, int],
             passes: int = 8) -> tuple[dict[int, list[str]], dict[str, int], tuple[int, float]]:
    """Búsqueda local con dos movimientos.

    1. **Reinserción**: mover una tabla a otra altura de su misma columna.
    2. **Promoción**: moverla a otra columna dentro de su rango válido. Esto es
       lo que descongestiona el abanico de `profiles` — una tabla como
       `reviews`, que depende de `profiles` pero también apunta (de forma
       polimórfica) a `businesses`, se acomoda sola cerca de este último.

    Se acepta un candidato solo si baja (cruces, longitud) en ese orden.
    """
    best = {k: list(v) for k, v in order.items()}
    best_layer = dict(layer)
    best_score = score(best, heights, relations, best_layer)

    def place(columns, layers, name, column_index, position):
        columns = {k: list(v) for k, v in columns.items()}
        layers = dict(layers)
        columns[layers[name]].remove(name)
        columns.setdefault(column_index, [])
        columns[column_index].insert(position, name)
        layers[name] = column_index
        # Las columnas vacías se conservan: borrarlas acá renumeraría las capas
        # a mitad de la búsqueda. Se compactan al final, en `plan`.
        return columns, layers

    def swap(columns, layers, a, b):
        """Intercambia dos tablas de posición (misma o distinta columna)."""
        columns = {k: list(v) for k, v in columns.items()}
        layers = dict(layers)
        la, lb = layers[a], layers[b]
        ia, ib = columns[la].index(a), columns[lb].index(b)
        columns[la][ia], columns[lb][ib] = b, a
        layers[a], layers[b] = lb, la
        return columns, layers

    names = sorted(heights)
    for _ in range(passes):
        improved = False
        for name in names:
            low, high = layer_bounds(name, best_layer, relations)
            for column_index in range(low, high + 1):
                # `best` cambia en cuanto se acepta un candidato, así que la
                # posición actual se vuelve a leer en cada iteración.
                origin = best_layer[name]
                size = len(best.get(column_index, []))
                span = size + (1 if column_index != origin else 0)
                for position in range(span):
                    if column_index == origin and position == best[origin].index(name):
                        continue
                    candidate, candidate_layer = place(
                        best, best_layer, name, column_index, position
                    )
                    candidate_score = score(
                        candidate, heights, relations, candidate_layer
                    )
                    if candidate_score < best_score:
                        best, best_layer, best_score = (
                            candidate,
                            candidate_layer,
                            candidate_score,
                        )
                        improved = True

        # Intercambios: sacan al optimizador de mínimos locales donde ningún
        # movimiento de una sola tabla mejora, pero el de dos sí.
        for a, b in combinations(names, 2):
            la, lb = best_layer[a], best_layer[b]
            if la == lb and abs(best[la].index(a) - best[la].index(b)) > 6:
                continue  # intercambios muy lejanos dentro de una columna: ruido
            low_a, high_a = layer_bounds(a, best_layer, relations)
            low_b, high_b = layer_bounds(b, best_layer, relations)
            if not (low_a <= lb <= high_a and low_b <= la <= high_b):
                continue
            candidate, candidate_layer = swap(best, best_layer, a, b)
            candidate_score = score(candidate, heights, relations, candidate_layer)
            if candidate_score < best_score:
                best, best_layer, best_score = (
                    candidate,
                    candidate_layer,
                    candidate_score,
                )
                improved = True
        if not improved:
            break
    return best, best_layer, best_score


def plan(model: dict, restarts: int = 12) -> dict:
    """Devuelve posiciones finales y las métricas de calidad del layout."""
    tables = {t["name"]: t for t in model["tables"]}
    relations = model["relations"]
    layer = assign_layers(model["tables"], relations)
    heights = {name: table_height(table) for name, table in tables.items()}

    # Orden inicial: agrupado por módulo, para que el color quede en bloques y
    # la búsqueda local arranque de algo ya legible.
    module_rank = {module: i for i, module in enumerate(model["modules"])}
    order: dict[int, list[str]] = {}
    for name in sorted(
        tables, key=lambda n: (module_rank.get(tables[n]["module"], 99), n)
    ):
        order.setdefault(layer[name], []).append(name)

    before = score(order, heights, relations, layer)

    # Multi-arranque: la búsqueda local llega a mínimos distintos según de dónde
    # parta, así que se corre varias veces —una desde el orden agrupado por
    # módulo, el resto desde órdenes barajados— y gana el mejor resultado.
    # La semilla es fija para que el layout sea reproducible.
    rng = random.Random(20261008)
    order, layer, after = optimize(order, heights, relations, layer)
    base_layer = assign_layers(model["tables"], relations)
    for _ in range(restarts):
        shuffled: dict[int, list[str]] = {}
        for name in sorted(tables):
            shuffled.setdefault(base_layer[name], []).append(name)
        for column in shuffled.values():
            rng.shuffle(column)
        candidate, candidate_layer, candidate_score = optimize(
            shuffled, heights, relations, dict(base_layer)
        )
        if candidate_score < after:
            order, layer, after = candidate, candidate_layer, candidate_score

    # Compactar: si la búsqueda vació una columna, se cierra el hueco para que
    # no quede una franja muerta en el board.
    order = {
        position: names
        for position, (_, names) in enumerate(
            (index, names) for index, names in sorted(order.items()) if names
        )
    }

    shapes = []
    for index, names in sorted(order.items()):
        total = sum(heights[n] for n in names) + ROW_GAP * (len(names) - 1)
        y = -total / 2
        x = index * (TABLE_WIDTH + COLUMN_GAP)
        for name in names:
            shapes.append(
                {
                    "table": tables[name],
                    "module": tables[name]["module"],
                    "layer": index,
                    "x": x,
                    "y": y + heights[name] / 2,
                    "width": TABLE_WIDTH,
                    "height": heights[name],
                }
            )
            y += heights[name] + ROW_GAP

    return {
        "shapes": shapes,
        "layers": {index: list(names) for index, names in sorted(order.items())},
        "crossings_before": before[0],
        "crossings_after": after[0],
        "length_before": before[1],
        "length_after": after[1],
    }
