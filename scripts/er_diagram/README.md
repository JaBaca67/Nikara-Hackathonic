# Modelo ER (2FN) → Miro

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
| `--dry-run` | Imprime el plan completo (frames, tablas, posiciones, cantidad de llamadas) y dos payloads de ejemplo. **No toca Miro ni necesita token.** |
| `--replace` | Borra los items de la corrida anterior (según `.miro_state.json`) antes de publicar. Para iterar sin ensuciar el board. |
| `--parent-frames` | Cuelga cada tabla del frame de su módulo. Agrupa de verdad, pero Miro interpreta la posición como relativa al frame; si el resultado queda corrido, volvé a correr sin el flag. |
| `--list-boards` | Lista los boards que el token alcanza, con id y team. Útil para confirmar que la app quedó instalada donde está el board. |
| `--token` / `--board` | Alternativa a los archivos y a las variables de entorno, para una corrida puntual. Queda en el historial del shell. |

Son ~80 llamadas a la API. El script reintenta solo ante `429` y `5xx`
respetando `Retry-After`.

**El token nunca se versiona.** `.miro_token`, `.miro_board` y `.miro_state.json`
están los tres en `.gitignore`.

## Qué dibuja

27 entidades agrupadas en 6 frames por módulo, con los colores de marca:

| Módulo | Relleno | Entidades |
|---|---|---|
| Identidad y cuentas | Gold `#FDBE02` | 5 |
| Negocios | Blanco | 7 |
| Módulo ECO | Olive `#C2CA5B` | 4 |
| Rutas y viajes | Orange `#FF8243` | 3 |
| Interacción social | Beige `#F7F3EC` | 3 |
| Avisos y automatización | Surface `#FDFDFD` | 5 |

- **PK** y *FK* marcados en cada atributo, con su tipo.
- Cada relación lleva su cardinalidad (`1:N` / `1:1`) y el nombre de la FK.
- Las **relaciones polimórficas** van punteadas en naranja: salen de una
  columna que apunta a varias tablas según un discriminador
  (`reviews.target_type`, `user_favorites.item_type`,
  `notifications.type`), así que la integridad referencial la valida la
  aplicación, no la base.
- El rombo `◇` marca atributos con **dependencia transitiva** (3FN), fuera del
  alcance del entregable pero señalados para no fingir que no existen.

El análisis de normalización completo —qué se descompuso y por qué— está en
[`docs/er_2fn.md`](../../docs/er_2fn.md).

## Mantenimiento

Si alguien agrega una tabla en una migración nueva, `extract_schema.py` la
detecta sola y `model_2nf.py` **falla a propósito** con
`Tablas sin módulo asignado: [...]`. Es deliberado: una tabla nueva tiene que
decidir en qué módulo del diagrama vive, y es más barato que aparezca el error
a que la tabla quede fuera del board sin que nadie lo note.
