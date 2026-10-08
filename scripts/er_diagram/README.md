# Modelo ER (2FN) → editores web

La alternativa a Miro está preparada en
[`docs/diagramacion_bd/README.md`](../../docs/diagramacion_bd/README.md):
archivos nativos para **drawDB**, **diagrams.net** y **dbdiagram.io**, tanto del
esquema físico como de la propuesta 2FN. Generar con
`python scripts/er_diagram/export_web.py` después de actualizar el esquema y
el modelo. El modelo actual incluye 18 tablas físicas, 9 tablas propuestas y
la entidad externa `auth.users`: **28 entidades y 50 relaciones**. La siguiente
sección conserva el flujo anterior de Miro y sus notas históricas.

Genera el modelo entidad-relación de Níkara normalizado hasta la **2FN** y lo
publica en un board de Miro como items nativos (frames, shapes y connectors),
no como imagen: queda editable y movible.

Todo el pipeline usa solo la librería estándar de Python — sin dependencias.

## Flujo

```
supabase/sql/*.sql
        │  extract_schema.py      lee las 46 migraciones en orden
        ▼
schema_physical.json              lo que hay HOY en Postgres (con los text[])
        │  model_2nf.py           aplica 1FN y verifica 2FN
        ▼
model_2nf.json                    27 entidades · 47 relaciones
        ├─ export_mermaid.py  →   docs/er_2fn.md   (versionado, GitHub lo renderiza)
        └─ export_miro.py     →   board de Miro
              ├─ layout.py        dónde va cada tabla (minimiza cruces)
              └─ render.py        cómo se dibuja cada tabla
```

```bash
python scripts/er_diagram/extract_schema.py    # 1. leer el esquema real
python scripts/er_diagram/model_2nf.py         # 2. normalizar a 2FN
python scripts/er_diagram/export_mermaid.py    # 3a. diagrama en el repo
python scripts/er_diagram/export_miro.py       # 3b. diagrama en Miro
```

> `extract_schema.py` necesita la carpeta `supabase/`, que está gitignored (el
> repo es público). Si no la tenés, saltá el paso 1: `schema_physical.json` y
> `model_2nf.json` están versionados y los pasos 2 y 3 funcionan igual.

## Publicar en Miro

### 1. Token (una sola vez)

1. https://developers.miro.com/ → **Your apps** → *Create new app*, asociada al
   equipo dueño del board.
2. *Permissions* → habilitar **`boards:read`** y **`boards:write`**.
3. *Install app and get OAuth token* → copiar el token.

> Si la app tiene activada la expiración de tokens, el que obtenés dura 1 hora;
> ante un `401` volvé a este mismo botón y copiá uno nuevo.

### 2. Board id

Está en la URL del board: `https://miro.com/app/board/uXjVK4D...=/`
→ el id es `uXjVK4D...=`, **incluido el `=` final**.

> **El board tiene que pertenecer al mismo team donde instalaste la app.** El
> token se emite por instalación en un team, no por cuenta: un board de otro
> team devuelve `404` aunque el token sea válido y lo veas en el navegador. Si
> el team de la app está vacío, creá el board ahí; si el board ya existe en otro
> team, reinstalá la app eligiendo ese team.

Para confirmar cuáles alcanza tu token, sin adivinar el id:

```bash
python scripts/er_diagram/export_miro.py --list-boards
```

### 3. Guardar las credenciales

**Forma recomendada — archivo local.** Pegá cada valor en su archivo; los dos
están gitignored y así el token no pasa por el historial del shell ni por una
sesión de Claude Code (el hook `SessionEnd` archiva la conversación entera en la
bóveda, que es un repo git).

```
scripts/er_diagram/.miro_token    <- el token, en una línea
scripts/er_diagram/.miro_board    <- el board id, en una línea
```

Admiten líneas de comentario con `#`, por si querés anotar de qué app salió.

También funcionan las variables de entorno, si preferís:

```powershell
$env:MIRO_ACCESS_TOKEN = "..."    # PowerShell
$env:MIRO_BOARD_ID = "uXjVK4D...="
```

```bash
export MIRO_ACCESS_TOKEN="..."    # bash
export MIRO_BOARD_ID="uXjVK4D...="
```

### 4. Correr

```bash
python scripts/er_diagram/export_miro.py --dry-run   # revisar el plan primero
python scripts/er_diagram/export_miro.py             # publicar
```

| Flag | Qué hace |
|---|---|
| `--dry-run` | Imprime el plan completo: métrica de cruces, columnas, posiciones, solapamientos (debe dar 0) y los items de una tabla de muestra. **No toca Miro ni necesita token.** |
| `--replace` | Borra los items de la corrida anterior (según `.miro_state.json`) antes de publicar. Para iterar sin ensuciar el board. |
| `--create-board NOMBRE` | Crea un board en el team de la app y guarda su id en `.miro_board`. Para cuando el team es nuevo y está vacío. |
| `--list-boards` | Lista los boards que el token alcanza, con id y team. Útil para confirmar que la app quedó instalada donde está el board. |
| `--token` / `--board` | Alternativa a los archivos y a las variables de entorno, para una corrida puntual. Queda en el historial del shell. |

Son ~190 llamadas a la API (5 items por tabla, más la leyenda y las relaciones). El script reintenta solo ante `429` y `5xx`
respetando `Retry-After`.

**El token nunca se versiona.** `.miro_token`, `.miro_board` y `.miro_state.json`
están los tres en `.gitignore`.

## Qué dibuja

Cada tabla se compone de **5 shapes**: el marco exterior (al que se enganchan
las relaciones), la cabecera con el color de su módulo, y las tres columnas
—marcador PK/FK, nombre del atributo y tipo—. Miro no tiene tablas en su REST
API v2, así que se arma por partes:

```
┌────────────────────────────────┐
│          BUSINESSES            │  cabecera, color del módulo
├──────┬────────────┬────────────┤
│  PK  │     id     │    Uuid    │  el texto va DENTRO del shape de su
│  FK  │  owner_id  │    Uuid    │  columna, así nada puede taparlo
└──────┴────────────┴────────────┘
```

El color del texto de cada cabecera no se elige a mano: `render.contrast_text`
lo decide por luminancia, de modo que nunca se repite el bug de texto blanco
sobre un Fill claro (el badge ECO llegó a medir 1.74:1 contra el mínimo AA de
4.5).

| Módulo | Cabecera | Token |
|---|---|---|
| Identidad y cuentas | `#FDBE02` | `goldFill` |
| Negocios | `#C2CA5B` | `oliveFill` |
| Módulo ECO | `#3A7D3A` | `success` |
| Rutas y viajes | `#FF8243` | `orangeFill` |
| Interacción social | `#6B7033` | `oliveText` |
| Avisos y automatización | `#CC5510` | `destructive` |

- Cada relación lleva su cardinalidad (`1:N` / `1:1`) y el nombre de la FK.
- Las **relaciones polimórficas** van punteadas en naranja: salen de una
  columna que apunta a varias tablas según un discriminador
  (`reviews.target_type`, `user_favorites.item_type`, `notifications.type`),
  así que la integridad referencial la valida la aplicación, no la base.
- El rombo `◇` marca atributos con **dependencia transitiva** (3FN), fuera del
  alcance del entregable pero señalados para no fingir que no existen.

## Cómo se ordena (y por qué importa)

La primera versión ponía una columna por módulo temático. Se lee como índice,
pero deja el board lleno de flechas cruzadas: `profiles` es un hub al que
apuntan 12 tablas repartidas por todos los módulos, así que sus relaciones
cruzaban el diagrama entero. `layout.py` invierte el criterio — manda el grafo,
y el módulo se comunica por color:

1. **Columnas por dependencia**: una tabla va una columna a la derecha de la
   más profunda a la que referencia, así toda FK apunta hacia la derecha y las
   tablas hija quedan pegadas a su padre.
2. **Orden dentro de cada columna** por búsqueda local con dos movimientos
   (reinsertar una tabla, intercambiar dos), midiendo los cruces reales entre
   segmentos y usando la longitud total como desempate.
3. **Multi-arranque** con semilla fija: la búsqueda local llega a mínimos
   distintos según de dónde parta, así que se corre 13 veces y gana la mejor.

Resultado medido sobre el modelo actual: **115 → 32 cruces** (−72%). El
`--dry-run` imprime esa métrica y la lista de solapamientos entre tablas, que
debe ser **0** — un solapamiento es texto tapado.

El análisis de normalización completo —qué se descompuso y por qué— está en
[`docs/er_2fn.md`](../../docs/er_2fn.md).

## Mantenimiento

Si alguien agrega una tabla en una migración nueva, `extract_schema.py` la
detecta sola y `model_2nf.py` **falla a propósito** con
`Tablas sin módulo asignado: [...]`. Es deliberado: una tabla nueva tiene que
decidir en qué módulo del diagrama vive, y es más barato que aparezca el error
a que la tabla quede fuera del board sin que nadie lo note.
