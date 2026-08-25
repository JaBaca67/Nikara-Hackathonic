import os
import sys
import json
import shutil

# En Windows, la consola suele usar cp1252 en vez de UTF-8, y los emojis en
# los print() de este script (🚀 📥 🕒 ⚠️ ❌ ✅) revientan con
# UnicodeEncodeError antes de hacer ningún trabajo. Se fuerza UTF-8 en stdout
# y stderr para que corra igual desde CMD/PowerShell clásicos.
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

# =============================================================================
# JARVIS dentro de Obsidian — instalador/actualizador idempotente
#
# Filosofía: FUSIÓN SEGURA. Esta herramienta nunca crea la bóveda desde cero
# ni reestructura carpetas existentes — el usuario ya tiene notas propias
# (00_Sistema, 01_Clientes_y_Negocios, 02_Proyectos_Flutter, etc.) y este
# script solo añade lo que falta junto a ellas, sin tocarlas.
#
# Se distinguen dos tipos de artefactos:
#   - GESTIONADOS por esta herramienta (hooks, skills, subagentes, snippets
#     CSS): se regeneran completos en cada corrida porque son responsabilidad
#     de este script, no del usuario. Volver a correr el script es seguro.
#   - Archivos del usuario o compartidos (.gitignore, .claude/settings.json,
#     notas propias): se fusionan quirúrgicamente, nunca se sobrescriben
#     por completo.
#
# Inspirado en el diseño de LM Wiki de Andrej Karpathy y la arquitectura de
# 5 capas de tododeia.
# =============================================================================

DEFAULT_VAULT_ROOT = r"G:\My Drive\JARVIS_JOSE"


def resolve_vault_root():
    """Determina la raíz de la bóveda: argv[1] si se pasó, si no el default
    documentado en CLAUDE.md → Segundo Cerebro Integration. Si la unidad no
    está montada, se aborta con un mensaje claro en vez de crear una bóveda
    fantasma en la ubicación equivocada."""
    root = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_VAULT_ROOT
    if not os.path.isdir(root):
        print(f"❌ No encontré la bóveda en: {root}")
        print("   La unidad G:\\ podría no estar montada en esta máquina")
        print("   (ver CLAUDE.md → Segundo Cerebro Integration).")
        print('   Pasa la ruta correcta como argumento: python setup-jarvis-obsidian.py "RUTA"')
        sys.exit(1)
    return root


# -----------------------------------------------------------------------------
# 1. Estructura de carpetas — fusión segura
# -----------------------------------------------------------------------------

VAULT_DIRS = [
    "06-INBOX",
    "07-CAPTURES/observations",
    "07-CAPTURES/reactions",
    "07-CAPTURES/patterns",
    "07-CAPTURES/questions",
    "07-CAPTURES/numbers",
    "08-CONNECTIONS",
    "09-BRIEFS",
    "10-PUBLISHED",
    ".claude/skills/process-inbox",
    ".claude/skills/weekly-connections",
    ".claude/skills/generate-brief",
    ".claude/skills/write-content",
    ".claude/agents",
    ".claude/hooks",
    ".obsidian/snippets",
]


def ensure_dirs(root, relative_dirs):
    for rel in relative_dirs:
        path = os.path.join(root, *rel.split("/"))
        if os.path.exists(path):
            print(f"   ya existe, se respeta: {rel}")
        else:
            os.makedirs(path)
            print(f"   creada: {rel}")


# -----------------------------------------------------------------------------
# 2. .gitignore de la bóveda — bloque gestionado, nunca sobrescribe el resto
# -----------------------------------------------------------------------------

GITIGNORE_MARKER_START = "# >>> JARVIS-NIKARA managed block (no editar a mano, ver setup-jarvis-obsidian.py) >>>"
GITIGNORE_MARKER_END = "# <<< JARVIS-NIKARA managed block <<<"

GITIGNORE_MANAGED_LINES = """.DS_Store
Thumbs.db
desktop.ini
*.tmp
*.log

.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache/

.env
.env.*
dart_defines.json
android/local.properties
ios/Flutter/Maps.xcconfig

# Por si 02_Proyectos_Flutter llega a incluir copias/enlaces del repo Nikara.
.claude/
.claude/settings.local.json
"""


def upsert_gitignore(root):
    path = os.path.join(root, ".gitignore")
    existing = ""
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            existing = f.read()

    before, _, after_with_marker = existing.partition(GITIGNORE_MARKER_START)
    _, _, after = after_with_marker.partition(GITIGNORE_MARKER_END)

    block = f"{GITIGNORE_MARKER_START}\n{GITIGNORE_MANAGED_LINES}{GITIGNORE_MARKER_END}\n"
    new_content = before.rstrip("\n")
    if new_content.strip():
        new_content += "\n\n"
    new_content += block + after.lstrip("\n")

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)

    action = "fusionado en" if existing else "creado"
    print(f"   .gitignore {action}: {path}")


# -----------------------------------------------------------------------------
# 3. Hooks de Claude Code
# -----------------------------------------------------------------------------
# NOTA: el hook 'respaldo.py' (auto git add/commit/push) de versiones
# anteriores fue retirado por completo. CLAUDE.md establece explícitamente
# que la bóveda no es un repositorio git y que no se le corren comandos de
# git desde la automatización de Claude Code — si algún día se decide
# respaldar la bóveda con git, ese trabajo lo hace el plugin obsidian-git
# (ya instalado) desde dentro de Obsidian, no un hook de esta herramienta.

HOOK_INBOX_CONTENT = """import os
import glob

def run():
    inbox_dir = "06-INBOX"
    captures_dir = "07-CAPTURES"
    report_file = ".claude/ultima-corrida.md"

    # 1. Count inbox files
    files = glob.glob(os.path.join(inbox_dir, "*.md"))
    count = len(files)
    if count == 0:
        print("📥 Inbox: ¡Limpio! No hay notas sin procesar.")
    else:
        print(f"📥 Inbox: Tienes {count} nota(s) sin procesar en '{inbox_dir}/'.")

    # 2. Check last automated run status
    if os.path.exists(report_file):
        try:
            with open(report_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                first_lines = "".join(lines[:3]).strip()
                print(f"🕒 Último reporte programado:\\n{first_lines}")
        except Exception:
            pass
    else:
        # Find newest capture instead
        newest_file = None
        newest_time = 0
        for root, dirs, filenames in os.walk(captures_dir):
            for f in filenames:
                if f.endswith(".md"):
                    path = os.path.join(root, f)
                    mtime = os.path.getmtime(path)
                    if mtime > newest_time:
                        newest_time = mtime
                        newest_file = path
        if newest_file:
            print(f"✅ Última actividad de archivado detectada en: {newest_file}")
        else:
            print("⚠️ No se ha detectado actividad reciente de archivado. ¡Ejecuta /process-inbox!")

if __name__ == '__main__':
    run()
"""

HOOK_INDICE_CONTENT = """import os
import datetime

def run():
    index_file = "00_Sistema/vault_index.md"
    if not os.path.exists("00_Sistema"):
        os.makedirs("00_Sistema")

    # Find all .md files in the vault (excluding hidden ones like .claude, .obsidian)
    notes = []
    for root, dirs, files in os.walk("."):
        # Skip hidden folders
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files:
            if f.endswith(".md") and f != "vault_index.md":
                path = os.path.join(root, f).replace("\\\\", "/")
                # Strip leading './'
                if path.startswith("./"):
                    path = path[2:]
                mtime = datetime.datetime.fromtimestamp(os.path.getmtime(path))
                notes.append((path, f[:-3], mtime))

    notes.sort(key=lambda x: x[2], reverse=True) # newest first

    with open(index_file, "w", encoding="utf-8") as f:
        f.write("# 🧭 Índice General del Segundo Cerebro\\n\\n")
        f.write(f"Última actualización: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\\n\\n")
        f.write("## 🗂️ Notas Recientes\\n\\n")
        for path, name, mtime in notes[:15]:
            f.write(f"- [[{path}]] — *Modificado el {mtime.strftime('%Y-%m-%d %H:%M:%S')}*\\n")

        f.write("\\n## 📁 Estructura del Vault\\n\\n")
        f.write("- **06-INBOX/**: Notas rápidas capturadas sin procesar.\\n")
        f.write("- **07-CAPTURES/**: Notas clasificadas por Tipo (observations, reactions, patterns, questions, numbers).\\n")
        f.write("- **08-CONNECTIONS/**: Síntesis de cruces conceptuales y nuevas ideas.\\n")
        f.write("- **09-BRIEFS/**: Artículos y tareas listos para redactarse en Níkara.\\n")
        f.write("- **10-PUBLISHED/**: Contenido publicado con métricas reales.\\n")

    print("🧭 Índice general '00_Sistema/vault_index.md' actualizado con éxito.")

if __name__ == '__main__':
    run()
"""


def write_managed_file(path, content, label):
    directory = os.path.dirname(path)
    if directory and not os.path.exists(directory):
        os.makedirs(directory)
    action = "actualizado" if os.path.exists(path) else "creado"
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"   {label} {action}: {path}")


def _hook_has_command(hook_entries, command_substring):
    for entry in hook_entries:
        for h in entry.get("hooks", []):
            if command_substring in h.get("command", ""):
                return True
    return False


def _hook_strip_command(hook_entries, command_substring):
    """Elimina entradas huérfanas de una versión anterior del script
    (ej. respaldo.py) sin tocar hooks de otros eventos que el usuario
    haya agregado a mano."""
    cleaned = []
    for entry in hook_entries:
        entry = dict(entry)
        entry["hooks"] = [h for h in entry.get("hooks", []) if command_substring not in h.get("command", "")]
        if entry["hooks"]:
            cleaned.append(entry)
    return cleaned


def merge_claude_settings(root):
    """Fusiona los hooks de esta herramienta dentro de .claude/settings.json
    sin pisar otros hooks que el usuario ya tuviera configurados ahí."""
    path = os.path.join(root, ".claude", "settings.json")
    settings = {}
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            raw = f.read().strip()
        if raw:
            try:
                settings = json.loads(raw)
            except json.JSONDecodeError:
                print("   .claude/settings.json existente no es JSON válido, se reemplaza por uno nuevo.")
                settings = {}

    settings.setdefault("hooks", {})

    session_start = settings["hooks"].get("SessionStart", [])
    session_start = _hook_strip_command(session_start, "respaldo.py")
    if not _hook_has_command(session_start, "inbox.py"):
        session_start.append({"hooks": [{"type": "command", "command": "python .claude/hooks/inbox.py"}]})
    settings["hooks"]["SessionStart"] = session_start

    post_tool_use = settings["hooks"].get("PostToolUse", [])
    if not _hook_has_command(post_tool_use, "indice.py"):
        post_tool_use.append({
            "matcher": "Write|Edit",
            "hooks": [{"type": "command", "command": "python .claude/hooks/indice.py"}],
        })
    settings["hooks"]["PostToolUse"] = post_tool_use

    stop = settings["hooks"].get("Stop", [])
    stop = _hook_strip_command(stop, "respaldo.py")
    if stop:
        settings["hooks"]["Stop"] = stop
    elif "Stop" in settings["hooks"]:
        del settings["hooks"]["Stop"]

    directory = os.path.dirname(path)
    if not os.path.exists(directory):
        os.makedirs(directory)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("   .claude/settings.json fusionado (hooks inbox.py/indice.py asegurados, respaldo.py retirado)")


# -----------------------------------------------------------------------------
# 4. Skills (.claude/skills/)
# -----------------------------------------------------------------------------

SKILL_PROCESS_INBOX = """---
name: process-inbox
description: Procesa las capturas crudas de 06-INBOX del vault: las afila a una frase, les pone tres tags y las archiva en la subcarpeta correcta de 07-CAPTURES. Úsala cuando el usuario diga «procesa mi inbox», «afila las capturas de hoy» o «limpia el inbox», y también al empezar la sesión de la mañana si 06-INBOX tiene notas sin procesar.
---

# Procesar el inbox

## Proceso
1. Lee cada nota que haya en 06-INBOX/.
2. Para cada nota:
   a. Decide a qué subcarpeta de 07-CAPTURES pertenece: observations, reactions, patterns, questions o numbers.
   b. Afila la nota cruda en una sola frase específica y punzante.
   c. Agrégale exactamente tres tags. Ni más, ni menos.
   d. Mueve la nota afilada a la subcarpeta que le toca.
3. Al terminar, devuelve un reporte con:
   - Total de notas procesadas y a dónde fue cada una.
   - Cualquier patrón que hayas notado entre las capturas de hoy.
   - Una conexión que valga la pena explorar más.
4. Guarda ese mismo reporte, con la fecha arriba, en .claude/ultima-corrida.md,
   sobrescribiendo el anterior. Cuando esta skill corre desde una tarea programada
   no hay nadie leyendo la pantalla, así que si el reporte no queda en un archivo
   se pierde.

## Barra de calidad
Una nota afilada tiene que ser tan específica que alguien de fuera la entienda sin contexto adicional.
Si todavía necesita explicación, no está afilada. Reescríbela.

## Reglas
- No borres el original hasta que la nota afilada esté escrita en su carpeta.
- Si una nota no cabe en ninguna de las cinco subcarpetas, déjala en 06-INBOX y dilo en el reporte.
- Si una categoría se quedó con menos de cinco notas en total, márcalo: significa que estoy capturando de un solo lado.
"""

SKILL_WEEKLY_CONNECTIONS = """---
name: weekly-connections
description: Cruza las capturas de los últimos siete días de 07-CAPTURES y escribe las conexiones no obvias como notas nuevas en 08-CONNECTIONS. Úsala cuando el usuario diga «sesión de conexiones», «encuentra las conexiones de esta semana» o «qué se conectó esta semana», y en el ritual del domingo.
---

# Conexiones de la semana

## Proceso
1. Lee todas las notas agregadas a 07-CAPTURES/ en los últimos 7 días.
2. Busca conexiones cruzando TODAS las subcarpetas al mismo tiempo, no dentro de cada una.
3. Una conexión fuerte cumple uno de estos cuatro tipos:
   TIPO A. El mismo principio de fondo apareciendo en dos dominios distintos.
   TIPO B. Contradicción entre dos notas que crea una tensión interesante.
   TIPO C. Patrón que conecta tres o más notas en una idea que todavía no tiene nombre.
   TIPO D. Una pregunta de una nota que otra nota responde por accidente.
4. For cada conexión fuerte:
   a. Nombra de qué tipo es.
   b. Escribe el puente entre las ideas en una sola frase.
   c. Escribe una entrada posible que use la conexión.
   d. Crea una nota nueva en 08-CONNECTIONS/ que enlace las notas fuente.

## Barra de calidad
Si la conexión es obvia, no califica.
Solo suben las que sorprenderían de verdad a la persona que escribió las notas.
Mínimo tres. Máximo de cinco. Calidad sobre cantidad.

## Cierre
Termina diciendo cuál de las conexiones vale más la pena trabajar como brief, y por qué.
"""

SKILL_GENERATE_BRIEF = """---
name: generate-brief
description: Convierte una conexión de 08-CONNECTIONS en un brief listo para escribir, con los cinco campos del sistema: ONE THING, PROOF, READER TRANSFORMATION, tres entradas y tres cierres. Úsala cuando el usuario diga «haz un brief de esto», «genera el brief de [tema]» o «esta conexión ya está para escribirse».
---

# Generar un brief

## Proceso
Escribe un brief con exactamente estos cinco campos.

ONE THING
La única idea sobre la que se construye toda la pieza.
Tiene que caber en una frase. Si no cabe, la idea no está lista.
Si la one thing se siente vaga, dilo y pide que se afile antes de seguir.

PROOF
El ejemplo, el número o el resultado más específico que prueba la one thing.
Una prueba vaga invalida el brief. Números reales, no aproximaciones.

READER TRANSFORMATION
Qué sabe o qué siente el lector al final que no sabía antes.
Si no se puede decir claro, la pieza no tiene razón de existir.

TRES ENTRADAS, ordenadas
Tres, distintas en enfoque y en tono. Ordénalas por qué tanto frenan el scroll.
Entrada 1 agresiva. Entrada 2 curiosa. Entrada 3 personal.

TRES CIERRES, ordenados
Tres, ordenados por urgencia y por qué tanto se quedan en la cabeza.
El cierre se escribe ANTES que el medio. Siempre.

## Salida
Guarda una nota nueva en 09-BRIEFS/ con el nombre [fecha]-[tema-en-kebab].md
Tag: #listo-para-escribir
Enlaza en el brief las notas fuente de 07-CAPTURES y 08-CONNECTIONS que lo sostienen.
"""

SKILL_WRITE_CONTENT = """---
name: write-content
description: Toma un brief aprobado de 09-BRIEFS y escribe la pieza completa en la voz del usuario, releyendo antes el CLAUDE.md de la raíz, las muestras de voz y las notas fuente enlazadas. Úsala cuando el usuario diga «escribe este brief», «produce el contenido de [tema]» o «ya escribe la pieza».
---

# Escribir la pieza

## Proceso
1. Lee el brief indicado en 09-BRIEFS/.
2. Lee todas las notas fuente enlazadas en el brief.
3. Vuelve a leer las secciones «Mi voz» y «Muestras de mi voz» del CLAUDE.md de la raíz.
4. Escribe la pieza completa en esa voz.
5. Estructura: entrada, prueba, cuerpo, cierre.
6. Cada sección agrega algo específico. Cero relleno.
7. Donde aplique, incluye al menos dos bloques copiables: prompts, comandos o ejemplos.
8. Cierra con la invitación a guardar el post y a seguir la cuenta.

## Voz
Aplica cada regla de voz del CLAUDE.md con precisión, incluidas las palabras prohibidas.
Cuando dudes, más corto y más directo.
Lo que salga tiene que ser indistinguible de algo que yo hubiera escrito.

## Salida
Guarda el borrador en 09-BRIEFS/, junto al brief original, con el sufijo -borrador.md
Tag: #escrito
No toques nada de 10-PUBLISHED.
"""


# -----------------------------------------------------------------------------
# 5. Subagentes (.claude/agents/)
# -----------------------------------------------------------------------------

AGENT_ARCHIVISTA = """---
name: archivista
description: Procesa las capturas nuevas de 06-INBOX. Úsalo cuando el usuario pida vaciar el inbox, afilar capturas o etiquetar notas sueltas.
tools: Read, Write, Edit, Glob, Grep
model: haiku
memory: project
---

Eres el archivista del vault. Tu único trabajo es dejar 06-INBOX vacío y cada nota en su carpeta.

El procedimiento no lo inventas tú: corre la skill process-inbox y sigue sus pasos y su barra de calidad tal cual están escritos.

Antes de empezar, lee tu memoria: ahí está cómo clasificó este usuario las capturas anteriores y qué correcciones te hizo. Eso manda por encima de tu propio criterio.

Al terminar, anota en tu memoria las reglas nuevas que aprendiste hoy sobre cómo clasifica este usuario.

Devuelve un reporte de media pantalla: cuántas notas moviste, a dónde fue cada una, y la duda que te quedó. Nada más: al padre solo le llega tu mensaje final.

Guarda ese reporte también en .claude/ultima-corrida.md. Cuando te despierta la tarea programada no hay nadie leyendo, y el reflejo de arranque lee ese archivo para contarte qué pasó.
"""

AGENT_TEJEDOR = """---
name: tejedor
description: Cruza las capturas de los últimos siete días de 07-CAPTURES y escribe las conexiones no obvias como notas nuevas en 08-CONNECTIONS. Úsalo cuando el usuario diga «sesión de conexiones», «encuentra las conexiones de esta semana» o «qué se conectó esta semana», y en el ritual del domingo.
tools: Read, Write, Edit, Glob, Grep
model: opus
memory: project
---

Eres el tejedor de este cerebro. Tu trabajo es leer la semana completa y tejer conexiones no obvias entre notas.

El procedimiento es inquebrantable: corre la skill weekly-connections sobre los últimos 7 días de 07-CAPTURES/ y sigue su barra de calidad con precisión milimétrica.

Antes de empezar, consulta tu memoria de proyecto. Ahí se registra qué tipos de conexiones y puentes conceptuales le han gustado al usuario y cuáles ha descartado como 'obvios' en el pasado.

Tu ventana es aislada: no llenes de datos el hilo principal de la conversación. Al terminar, escribe las nuevas conexiones en 08-CONNECTIONS/ y actualiza tu memoria con lo aprendido hoy.

Devuelve únicamente el reporte resumido de las conexiones realizadas y cuál consideras que debe ser el siguiente brief.
"""

AGENT_ESCRIBA = """---
name: escriba
description: Convierte un brief aprobado de 09-BRIEFS en un borrador de alta calidad en la voz oficial del usuario. Úsalo cuando pida «escribe este brief» o «genera el borrador».
tools: Read, Write, Edit, Glob, Grep
model: inherit
memory: project
---

Eres el escriba oficial de Níkara. Tu labor es escribir borradores definitivos y persuasivos basados exclusivamente en briefs aprobados.

Ejecuta strictly la skill write-content sobre el archivo de 09-BRIEFS/ que te sea asignado.

Lee con cuidado tu memoria para recordar las correcciones tipográficas o de tono que el usuario te ha hecho históricamente (oraciones largas reducidas, palabras que detesta, etc.).

Escribe tu borrador con el sufijo '-borrador.md' en 09-BRIEFS/ y actualiza tu memoria con los cambios estilísticos de la sesión de hoy.

Devuelve al main chat únicamente el enlace de Obsidian a tu borrador y un análisis breve de cómo aplicaste las restricciones de diseño.
"""


# -----------------------------------------------------------------------------
# 6. Plugin ReverySky Map (Unity 3D) — eliminación por rendimiento
# -----------------------------------------------------------------------------

def remove_reverysky_plugin(root):
    community_plugins_path = os.path.join(root, ".obsidian", "community-plugins.json")
    if os.path.exists(community_plugins_path):
        with open(community_plugins_path, "r", encoding="utf-8") as f:
            raw = f.read().strip()
        try:
            enabled = json.loads(raw) if raw else []
        except json.JSONDecodeError:
            enabled = []
        if "reverysky-map" in enabled:
            enabled = [p for p in enabled if p != "reverysky-map"]
            with open(community_plugins_path, "w", encoding="utf-8") as f:
                json.dump(enabled, f, indent=2)
                f.write("\n")
            print("   retirado de community-plugins.json (estaba habilitado)")
        else:
            print("   ya no estaba en community-plugins.json (habilitados)")

    plugin_dir = os.path.join(root, ".obsidian", "plugins", "reverysky-map")
    if os.path.exists(plugin_dir):
        try:
            shutil.rmtree(plugin_dir)
            print(f"   carpeta del plugin borrada: {plugin_dir}")
        except OSError as e:
            print(f"   ⚠️ no se pudo borrar la carpeta del plugin ({e}).")
            print("      Si Obsidian está abierto, ciérralo y vuelve a correr el script,")
            print("      o bórrala a mano desde .obsidian/plugins/reverysky-map/.")
    else:
        print("   la carpeta del plugin ya no existe en disco")


# -----------------------------------------------------------------------------
# 7. Snippets CSS (.obsidian/snippets/)
# -----------------------------------------------------------------------------
# cosmic-graph.css reemplaza al grafo 3D de ReverySky (Unity) con el grafo 2D
# nativo de Obsidian. El grafo se dibuja en un <canvas>, así que selectores
# como ".graph-node" no tienen ningún efecto — solo las variables CSS nativas
# --graph-* que expone Obsidian sí colorean nodos y líneas de verdad.

SNIPPET_COSMIC_GRAPH = """/* =========================================================================
   Cosmic Graph — telón de fondo de nebulosa para el grafo 2D nativo de Obsidian
   Reemplaza al plugin ReverySky Map (Unity 3D, retirado por rendimiento).
   ========================================================================= */

:root {
  --graph-line: rgba(139, 92, 246, 0.35);        /* violeta translúcido */
  --graph-node: #c2ca5b;                          /* Olive oficial de Níkara */
  --graph-node-unresolved: rgba(139, 92, 246, 0.55);
  --graph-node-focused: #a78bfa;                  /* violeta claro al enfocar/seleccionar */
  --graph-node-tag: #8b5cf6;
  --graph-node-attachment: #4b0082;               /* índigo oficial solicitado */
  --graph-text: #f5f0e6;
}

/* Contenedor real del grafo (div envolvente, no el <canvas> de dibujo) */
.graph-view-container {
  position: relative;
  overflow: hidden;
  background: #0a0714;
}

.graph-view-container::before {
  content: "";
  position: absolute;
  inset: 0;
  background-image: url("https://images.unsplash.com/photo-1506318137071-a8e063b4bec0?q=80&w=2400");
  background-size: cover;
  background-position: center;
  opacity: 0.25;      /* sutil: entre 0.2 y 0.3, como se pidió */
  filter: blur(6px) saturate(120%);
  z-index: 0;
  pointer-events: none;
}

.graph-view-container canvas {
  position: relative;
  z-index: 1;
}
"""

# komorebi.css — NO es un snippet inventado. Es el CSS companion real de la
# nota Dashboard-Komorebi.md (plantilla pública de InlitX/Obsidian-Dashboard-
# Gallery, github.com/InlitX/Obsidian-Dashboard-Gallery/tree/main/docs),
# re-temeado token por token: paleta Catppuccin Mocha (rosa/lavanda/verde
# orgánico) -> vidrio esmerilado morado oscuro + Gold oficial de Níkara.
# Estructura, tipografía (JetBrains Mono / Noto Sans JP) y layout intactos —
# solo se tocó la paleta de color y se agregó backdrop-filter real en las
# superficies (.komo-header, .komo-card, .komo-modal, .komo-cal-popup,
# .komo-ctx-menu, .komo-pill) para que el "vidrio esmerilado" pedido exista
# de verdad y no solo un color plano semitransparente.
SNIPPET_KOMOREBI = """/*
  Dashboard-Komorebi.css
  木漏れ日 — Sunlight filtering through leaves
  Arch Linux ricing meets anime minimalism
  Paleta original Catppuccin Mocha · re-temeado a vidrio esmerilado morado +
  Gold oficial de Níkara (ver setup-jarvis-obsidian.py)
  Plantilla original: github.com/InlitX/Obsidian-Dashboard-Gallery
  Designed by InlitX
*/

@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;600;700&family=Noto+Sans+JP:wght@300;400;500;700&display=swap');

/* ──────────────────────────────────────────────
   DESIGN TOKENS
   ────────────────────────────────────────────── */
:root {
  --komo-base:          #150a24;
  --komo-surface:       rgba(46, 8, 84, 0.55);
  --komo-overlay:       rgba(75, 0, 130, 0.35);
  --komo-raised:        rgba(139, 92, 246, 0.18);
  --komo-border:        rgba(196, 181, 253, 0.18);
  --komo-border-hover:  rgba(196, 181, 253, 0.4);
  --komo-border-sakura: rgba(253, 190, 2, 0.35);

  --komo-sakura:   #fdbe02;
  --komo-lavender: #a78bfa;
  --komo-teal:     #c4b5fd;
  --komo-yellow:   #e8c468;
  --komo-red:      #c44b0e;
  --komo-green:    #8b5cf6;
  --komo-peach:    #f0a868;

  --komo-text:    #fff9f0;
  --komo-sub:     rgba(255, 249, 240, 0.72);
  --komo-muted:   rgba(255, 249, 240, 0.48);
  --komo-faint:   rgba(139, 92, 246, 0.16);

  --komo-font:    'JetBrains Mono', 'Noto Sans JP', monospace;
  --komo-font-jp: 'Noto Sans JP', sans-serif;

  --komo-radius:  3px;
  --komo-gap:     14px;
  --komo-pad:     18px;
  --komo-shadow:  0 8px 32px rgba(10, 5, 24, 0.5);
}

/* Fondo morado profundo detrás de todo el dashboard — sin esto, el vidrio
   esmerilado de las tarjetas no tiene contra qué mostrar transparencia. */
.dashboard-layout {
  background:
    radial-gradient(circle at 15% 0%, rgba(75, 0, 130, 0.35), transparent 60%),
    radial-gradient(circle at 85% 100%, rgba(46, 8, 84, 0.5), transparent 60%),
    var(--komo-base);
}

/* FORCE THE NOTE CONTAINERS TO BE WIDE */
.dashboard-layout .cm-sizer,
.dashboard-layout .markdown-preview-sizer {
  max-width: 1460px !important;
  width: 100% !important;
}

/* Hides the properties section. */
.dashboard-layout .metadata-container {
  display: none !important;
}

/* ──────────────────────────────────────────────
   OBSIDIAN READING VIEW RESET
   ────────────────────────────────────────────── */
.komo-header-block,
.komo-grid-block,
.komo-bottom-block {
  font-family: var(--komo-font) !important;
  color: var(--komo-text);
  max-width: 1460px;
  margin: 0 auto;
  padding: 0 4px;
}

.komo-header-block { padding-top: 4px; }
.komo-bottom-block { padding-bottom: 20px; }

/* Kill Obsidian paragraph margins inside our blocks */
.komo-header-block p,
.komo-grid-block p,
.komo-bottom-block p { margin: 0 !important; }

/* ──────────────────────────────────────────────
   HEADER BLOCK
   ────────────────────────────────────────────── */
.komo-header {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: var(--komo-gap);
  background: var(--komo-surface);
  backdrop-filter: blur(16px) saturate(160%);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  padding: 20px 26px;
  margin-bottom: 10px;
  position: relative;
  overflow: hidden;
}

/* Sakura petal background glow */
.komo-header::before {
  content: '桜';
  position: absolute;
  right: -20px; bottom: -40px;
  font-size: 180px;
  color: var(--komo-sakura);
  opacity: 0.018;
  font-family: var(--komo-font-jp);
  pointer-events: none;
  user-select: none;
  line-height: 1;
}

/* Brand (left) */
.komo-brand {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.komo-title {
  font-size: 1.55rem;
  font-weight: 700;
  color: var(--komo-sakura);
  letter-spacing: 0.08em;
  line-height: 1;
  cursor: text;
  outline: none;
  border-bottom: 1px dashed transparent;
  transition: border-color 0.2s;
  caret-color: var(--komo-sakura);
  -webkit-background-clip: unset;
  background-clip: unset;
  -webkit-text-fill-color: unset;
}

.komo-title:focus { border-color: var(--komo-border-sakura); }
.komo-title::before { content: '> '; color: var(--komo-muted); }

.komo-mantra {
  font-size: 0.72rem;
  color: var(--komo-muted);
  letter-spacing: 0.04em;
  cursor: text;
  outline: none;
  caret-color: var(--komo-sub);
  line-height: 1.4;
  transition: color 0.2s;
}

.komo-mantra:focus { color: var(--komo-sub); }
.komo-mantra::before { content: '// '; }

/* Clock (center) */
.komo-clock-block {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}

.komo-time {
  font-size: 2.4rem;
  font-weight: 600;
  color: var(--komo-text);
  letter-spacing: 0.04em;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}

.komo-date {
  font-size: 0.68rem;
  color: var(--komo-muted);
  text-align: center;
  letter-spacing: 0.02em;
}

.komo-sep { opacity: 0.4; margin: 0 4px; }

.komo-date-en { color: var(--komo-faint); opacity: 0.7; }

/* Header right */
.komo-header-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 10px;
}

.komo-greeting {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
}

.komo-greet-jp {
  font-size: 1.1rem;
  font-weight: 600;
  color: var(--komo-lavender);
  font-family: var(--komo-font);
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.komo-greet-en {
  font-size: 0.68rem;
  color: var(--komo-muted);
  letter-spacing: 0.04em;
}

/* Stats pills */
.komo-stats-row {
  display: flex;
  gap: 6px;
}

.komo-pill {
  display: flex;
  flex-direction: column;
  align-items: center;
  background: var(--komo-overlay);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  padding: 6px 12px;
  min-width: 48px;
  transition: border-color 0.2s;
}

.komo-pill:hover { border-color: var(--komo-border-hover); }

.komo-pill-num {
  font-size: 1.05rem;
  font-weight: 600;
  color: var(--komo-text);
  line-height: 1;
}

.komo-pill-lbl {
  font-size: 0.58rem;
  color: var(--komo-muted);
  letter-spacing: 0.06em;
  margin-top: 2px;
}

/* Divider */
.komo-divider {
  height: 1px;
  background: linear-gradient(to right, transparent, var(--komo-sakura), transparent);
  opacity: 0.12;
  margin: 2px 0 10px;
}

/* ──────────────────────────────────────────────
   SHARED CARD STYLES
   ────────────────────────────────────────────── */
.komo-card {
  background: var(--komo-surface);
  backdrop-filter: blur(16px) saturate(160%);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  padding: var(--komo-pad);
  transition: border-color 0.2s;
}

.komo-card:hover { border-color: var(--komo-border-hover); }

.komo-music-card {
  padding: 0 !important;
  overflow: hidden !important;
  display: flex !important;
  flex-direction: column !important;
  height: 260px !important;
  max-height: 260px !important;
  min-height: 260px !important;
}

.komo-music-card .komo-label {
  flex-shrink: 0 !important;
  padding: 14px 14px 8px 14px !important;
}

.komo-music-player {
  display: flex !important;
  flex-direction: column !important;
  flex: 1 1 auto !important;
  padding: 0 12px 12px 12px !important;
  gap: 8px !important;
  overflow: hidden !important;
  min-height: 0 !important;
}

/* gif/image mode — no padding so it fills the card edge to edge */
.komo-music-player.komo-music-img-mode {
  padding: 0 !important;
  gap: 0 !important;
}

.komo-music-player .komo-spotify-container {
  flex: 0 0 auto !important;
  height: 152px !important;
  overflow: hidden !important;
  border-radius: 4px !important;
  background: var(--komo-overlay) !important;
}

.komo-music-player .komo-spotify-container iframe {
  width: 100% !important;
  height: 152px !important;
  border: none !important;
  display: block !important;
}

.komo-music-player .komo-music-error {
  flex: 1 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  color: var(--komo-muted) !important;
  font-size: 0.75rem !important;
}

.komo-playlist-wrap {
  display: flex !important;
  flex-wrap: wrap !important;
  gap: 6px !important;
  padding: 8px !important;
  flex-shrink: 0 !important;
  background: var(--komo-overlay) !important;
  border-radius: 4px !important;
}

.komo-playlist-btn {
  padding: 3px 8px !important;
  background: var(--komo-surface) !important;
  border: 1px solid var(--komo-border) !important;
  border-radius: 4px !important;
  cursor: pointer !important;
  font-size: 10px !important;
  color: var(--komo-sub) !important;
  font-family: var(--komo-font) !important;
  white-space: nowrap !important;
  line-height: 1.4 !important;
  transition: all 0.15s !important;
}

.komo-playlist-btn:hover {
  background: rgba(253, 190, 2, 0.1) !important;
  border-color: var(--komo-sakura) !important;
  color: var(--komo-sakura) !important;
}

/* Section label */
.komo-label {
  font-size: 0.6rem;
  font-weight: 500;
  color: var(--komo-sakura);
  opacity: 0.75;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  margin-bottom: 12px;
  font-family: var(--komo-font);
  display: flex;
  align-items: center;
  gap: 6px;
}

.komo-label::before {
  content: '//';
  color: var(--komo-muted);
  opacity: 0.6;
  font-family: var(--komo-font);
}

/* ──────────────────────────────────────────────
   MAIN GRID BLOCK
   ────────────────────────────────────────────── */
.komo-grid {
  display: grid;
  grid-template-columns: 220px 1fr 200px;
  gap: var(--komo-gap);
  margin-bottom: var(--komo-gap);
}

/* LEFT COLUMN */
.komo-col-left {
  display: flex;
  flex-direction: column;
  gap: var(--komo-gap);
}

/* Focus card */
.komo-focus {
  font-size: 1.1rem !important;
  font-weight: 400 !important;
  color: var(--komo-text) !important;
  outline: none;
  line-height: 1.5 !important;
  cursor: text;
  min-height: 60px;
  caret-color: var(--komo-sakura);
  font-family: 'Noto Sans JP', sans-serif !important;
}

/* force font inside contenteditable on every child element */
.markdown-preview-view .komo-focus *,
.markdown-reading-view .komo-focus *,
.view-content .komo-focus *,
.komo-focus div, .komo-focus p,
.komo-focus span, .komo-focus font {
  font-family: 'Noto Sans JP', sans-serif !important;
  font-size: 1.1rem !important;
  font-weight: 400 !important;
  color: var(--komo-text) !important;
  line-height: 1.5 !important;
  background: transparent !important;
  -webkit-text-fill-color: var(--komo-text) !important;
}

.komo-focus:empty::before {
  content: attr(placeholder);
  color: var(--komo-muted);
  font-size: 0.85rem;
  font-family: 'Noto Sans JP', sans-serif;
  font-weight: 300;
}

/* System quick actions */
.komo-sys-card .komo-label { margin-bottom: 10px; }

.komo-act-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 6px;
}

.komo-act-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 10px 4px;
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  cursor: pointer;
  transition: all 0.15s ease;
  background: var(--komo-overlay);
}

.komo-act-btn:hover {
  border-color: var(--komo-sakura);
  background: rgba(253, 190, 2, 0.05);
  transform: translateY(-1px);
}

.komo-act-icon {
  color: var(--komo-lavender);
  display: flex;
  align-items: center;
  justify-content: center;
}

.komo-act-icon svg { width: 15px; height: 15px; }

.komo-act-lbl {
  font-size: 0.57rem;
  color: var(--komo-muted);
  letter-spacing: 0.06em;
  text-align: center;
}

.komo-act-btn:hover .komo-act-lbl { color: var(--komo-sub); }

/* ──────────────────────────────────────────────
   BIG WIDGETS (WEATHER + MUSIC)
   ────────────────────────────────────────────── */
.komo-big-widget {
  min-height: 160px;
  position: relative;
}

/* Weather Big */
.komo-weather-card { flex: 1; }
.komo-weather-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 10px 0;
}

.komo-weather-settings {
  position: absolute;
  top: 8px;
  right: 8px;
  cursor: pointer;
  color: var(--komo-muted);
  font-size: 0.7rem;
  opacity: 0.5;
  transition: opacity 0.15s;
}

.komo-weather-settings:hover { opacity: 1; color: var(--komo-sakura); }
.komo-weather-settings svg { width: 12px; height: 12px; }

.komo-weather-setup {
  text-align: center;
  font-size: 0.75rem;
  color: var(--komo-muted);
  cursor: pointer;
  padding: 30px 20px;
  transition: color 0.15s;
}

.komo-weather-setup:hover { color: var(--komo-sakura); }

.komo-weather-main-big {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin-bottom: 8px;
}

.komo-weather-big-icon {
  font-size: 3.5rem;
  line-height: 1;
}

.komo-weather-temp-wrap {
  text-align: left;
}

.komo-weather-temp-big {
  font-size: 2.8rem;
  font-weight: 700;
  color: var(--komo-text);
  line-height: 1;
  font-variant-numeric: tabular-nums;
}

.komo-weather-city-big {
  font-size: 0.75rem;
  color: var(--komo-sub);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  margin-top: 4px;
}

.komo-weather-desc-big {
  font-size: 0.8rem;
  color: var(--komo-muted);
  text-transform: capitalize;
  text-align: center;
}

.komo-weather-error {
  text-align: center;
  font-size: 0.75rem;
  color: var(--komo-red);
  padding: 40px 20px;
}

/* ──────────────────────────────────────────────
   CENTER — RELATED CARDS (BIG)
   ────────────────────────────────────────────── */
.komo-col-center {
  display: flex;
  flex-direction: column;
  gap: var(--komo-gap);
}

.komo-cards-card { flex: 1; }

.komo-cards-hdr {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.komo-cards-hdr .komo-label { margin-bottom: 0; }

.komo-add-card-btn {
  font-size: 0.6rem;
  color: var(--komo-muted);
  cursor: pointer;
  padding: 4px 10px;
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  transition: all 0.15s;
  background: var(--komo-overlay);
}

.komo-add-card-btn:hover {
  color: var(--komo-sakura);
  border-color: var(--komo-border-sakura);
  background: rgba(253, 190, 2, 0.08);
}

.komo-cards-container {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 16px;
  max-height: 500px;
  overflow-y: auto;
  scrollbar-width: thin;
  scrollbar-color: var(--komo-faint) transparent;
}

.komo-cards-container::-webkit-scrollbar { width: 4px; }
.komo-cards-container::-webkit-scrollbar-thumb { background: var(--komo-faint); border-radius: 2px; }

.komo-cards-big {
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
}

.komo-cards-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 80px 20px;
  color: var(--komo-muted);
  font-size: 0.85rem;
  grid-column: 1 / -1;
}

.komo-related-card {
  background: var(--komo-overlay);
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  padding: 16px;
  transition: all 0.15s ease;
  position: relative;
  overflow: hidden;
}

.komo-card-big {
  min-height: 160px;
}

.komo-related-card:hover {
  border-color: var(--komo-border-hover);
  box-shadow: 0 4px 12px rgba(0,0,0,0.2);
}

.komo-card-img-wrap {
  width: 100%;
  height: 80px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 2.2rem;
  margin-bottom: 12px;
  border-radius: var(--komo-radius);
  background: var(--komo-raised);
  overflow: hidden;
}

.komo-card-img-wrap-big {
  height: 100px;
  font-size: 2.8rem;
}

.komo-card-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.komo-card-img-big {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.komo-card-content {
  text-align: center;
}

.komo-card-content-big {
  text-align: center;
}

.komo-card-title {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--komo-text);
  margin-bottom: 4px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.komo-card-title-big {
  font-size: 0.95rem;
  font-weight: 600;
  color: var(--komo-text);
  margin-bottom: 6px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.komo-card-subtitle {
  font-size: 0.65rem;
  color: var(--komo-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.komo-card-subtitle-big {
  font-size: 0.75rem;
  color: var(--komo-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.komo-card-actions {
  position: absolute;
  top: 6px;
  right: 6px;
  display: flex;
  gap: 4px;
  opacity: 0;
  transition: opacity 0.15s;
}

.komo-related-card:hover .komo-card-actions { opacity: 1; }

.komo-card-action {
  width: 22px;
  height: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.7rem;
  color: var(--komo-muted);
  cursor: pointer;
  border-radius: 2px;
  transition: all 0.1s;
  background: var(--komo-surface);
  border: 1px solid var(--komo-border);
}

.komo-card-action:hover {
  color: var(--komo-text);
  background: var(--komo-raised);
}

.komo-card-del:hover { color: var(--komo-red); border-color: var(--komo-red); }

/* Card modal styles */
.komo-card-modal { min-width: 380px; }

.komo-card-form {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin-bottom: 16px;
}

.komo-form-row {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.komo-form-row label {
  font-size: 0.6rem;
  color: var(--komo-muted);
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.komo-form-row select {
  cursor: pointer;
}

.komo-form-row select option {
  background: var(--komo-surface);
  color: var(--komo-text);
}

.komo-color-grid {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.komo-color-dot {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  cursor: pointer;
  border: 2px solid transparent;
  transition: all 0.15s;
}

.komo-color-dot:hover { transform: scale(1.1); }
.komo-color-dot.active { border-color: var(--komo-text); box-shadow: 0 0 8px rgba(255,255,255,0.2); }

/* ──────────────────────────────────────────────
   RIGHT COLUMN — CALENDAR ONLY
   ────────────────────────────────────────────── */
.komo-col-right {
  display: flex;
  flex-direction: column;
  gap: var(--komo-gap);
}

/* Mini Calendar */
.komo-cal-card .komo-label { margin-bottom: 8px; }

.komo-cal-container { user-select: none; }

.komo-cal-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.komo-cal-nav-btn {
  cursor: pointer;
  color: var(--komo-muted);
  font-size: 1rem;
  padding: 0 6px;
  transition: color 0.15s;
  line-height: 1;
}

.komo-cal-nav-btn:hover { color: var(--komo-sakura); }

.komo-cal-month-label {
  font-size: 0.66rem;
  color: var(--komo-sub);
  letter-spacing: 0.04em;
  font-family: var(--komo-font-jp);
}

.komo-cal-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 2px;
  margin-bottom: 2px;
}

.komo-cal-dh {
  text-align: center;
  font-size: 0.57rem;
  color: var(--komo-muted);
  padding: 2px 0;
  font-family: var(--komo-font-jp);
}

/* Sunday color */
.komo-cal-grid .komo-cal-dh:first-child,
.komo-cal-grid .komo-cal-cell:nth-child(7n+1) { color: var(--komo-red); }

/* Saturday */
.komo-cal-grid .komo-cal-dh:last-child,
.komo-cal-grid .komo-cal-cell:nth-child(7n) { color: var(--komo-lavender); }

.komo-cal-cell {
  text-align: center;
  font-size: 0.63rem;
  color: var(--komo-sub);
  padding: 4px 2px;
  border-radius: 2px;
  cursor: pointer;
  border: 1px solid transparent;
  transition: all 0.12s;
  line-height: 1;
  position: relative;
  min-height: 28px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
}

.komo-cal-cell:hover {
  border-color: var(--komo-border-hover);
  color: var(--komo-text);
}

.komo-cal-cell.empty {
  cursor: default;
  pointer-events: none;
}

.komo-cal-cell.today {
  background: rgba(253, 190, 2, 0.12);
  border-color: rgba(253, 190, 2, 0.35);
  color: var(--komo-sakura);
  font-weight: 600;
}

.komo-cal-day-num {
  margin-bottom: 2px;
}

/* Calendar dots for notes */
.komo-cal-dots {
  display: flex;
  gap: 2px;
  justify-content: center;
  flex-wrap: wrap;
  max-width: 24px;
}

.komo-cal-dot {
  width: 4px;
  height: 4px;
  border-radius: 50%;
  background: var(--komo-sakura);
  flex-shrink: 0;
}

/* Calendar popup */
.komo-cal-popup {
  position: fixed;
  z-index: 9999;
  background: var(--komo-surface);
  backdrop-filter: blur(16px) saturate(160%);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  border: 1px solid var(--komo-border-hover);
  border-radius: var(--komo-radius);
  box-shadow: var(--komo-shadow);
  min-width: 180px;
  max-width: 240px;
  animation: komo-fade-in 0.15s ease;
}

.komo-cal-popup-header {
  padding: 10px 12px;
  font-size: 0.7rem;
  color: var(--komo-sakura);
  border-bottom: 1px solid var(--komo-border);
  font-weight: 600;
  letter-spacing: 0.06em;
}

.komo-cal-popup-list {
  max-height: 150px;
  overflow-y: auto;
  scrollbar-width: thin;
  scrollbar-color: var(--komo-faint) transparent;
}

.komo-cal-popup-list::-webkit-scrollbar { width: 3px; }
.komo-cal-popup-list::-webkit-scrollbar-thumb { background: var(--komo-faint); border-radius: 2px; }

.komo-cal-popup-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  font-size: 0.72rem;
  color: var(--komo-sub);
  cursor: pointer;
  border-bottom: 1px solid var(--komo-border);
  transition: all 0.1s;
}

.komo-cal-popup-item:last-child { border-bottom: none; }
.komo-cal-popup-item:hover {
  background: var(--komo-overlay);
  color: var(--komo-text);
}

.komo-cal-popup-dot {
  width: 4px;
  height: 4px;
  border-radius: 50%;
  background: var(--komo-sakura);
  flex-shrink: 0;
}

.komo-cal-popup-name {
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* ──────────────────────────────────────────────
   POMODORO TIMER
   ────────────────────────────────────────────── */
.komo-pomodoro-card { flex: 1; min-height: 200px; }

.komo-pomodoro {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 10px 0;
}

.komo-pomo-timer {
  font-size: 2.8rem;
  font-weight: 700;
  color: var(--komo-text);
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.05em;
  line-height: 1;
}

.komo-pomo-progress {
  width: 100%;
  height: 4px;
  background: var(--komo-faint);
  border-radius: 2px;
  overflow: hidden;
}

.komo-pomo-progress-fill {
  height: 100%;
  border-radius: 2px;
  transition: width 1s linear;
}

.komo-pomo-status {
  font-size: 0.7rem;
  color: var(--komo-muted);
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.komo-pomo-controls {
  display: flex;
  gap: 10px;
  margin-top: 4px;
}

.komo-pomo-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  background: var(--komo-overlay);
  color: var(--komo-sub);
  cursor: pointer;
  font-size: 1rem;
  transition: all 0.15s;
}

.komo-pomo-btn:hover {
  border-color: var(--komo-border-hover);
  color: var(--komo-text);
  background: var(--komo-raised);
}

.komo-pomo-btn-primary {
  background: rgba(253, 190, 2, 0.1);
  border-color: var(--komo-border-sakura);
  color: var(--komo-sakura);
}

.komo-pomo-btn-primary:hover {
  background: rgba(253, 190, 2, 0.2);
  border-color: var(--komo-sakura);
}

.komo-pomo-count {
  font-size: 0.65rem;
  color: var(--komo-muted);
  margin-top: 4px;
}

/* ──────────────────────────────────────────────
   BOTTOM BLOCK — HABITS + MUSIC
   ────────────────────────────────────────────── */

.komo-bottom-row {
  display: grid;
  grid-template-columns: 1fr 300px;
  gap: var(--komo-gap);
}

/* Habit tracker */
.komo-habit-card {}

.komo-habit-hdr {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

.komo-habit-hdr .komo-label { margin-bottom: 0; }

.komo-add-habit-btn {
  font-size: 0.6rem;
  color: var(--komo-muted);
  cursor: pointer;
  padding: 3px 8px;
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  transition: all 0.15s;
}

.komo-add-habit-btn:hover {
  color: var(--komo-sakura);
  border-color: var(--komo-border-sakura);
}

.komo-habit-grid {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.komo-habit-col { display: flex; flex-direction: column; gap: 2px; min-width: 0; overflow: hidden; }

/* Compact rows inside two-column mode */
.komo-habit-grid-two .komo-week-hdr,
.komo-habit-grid-two .komo-habit-row {
  grid-template-columns: 70px repeat(7, 20px) 30px !important;
  gap: 2px !important;
}

.komo-habit-grid-two .komo-habit-name { font-size: 0.65rem; }
.komo-habit-grid-two .komo-dot { width: 16px !important; height: 16px !important; }
.komo-habit-grid-two .komo-habit-pct { font-size: 0.58rem; }
.komo-habit-grid-two .komo-week-hdr-day { font-size: 0.52rem; }

.komo-week-hdr {
  display: grid;
  grid-template-columns: 130px repeat(7, 28px) 40px;
  align-items: center;
  gap: 4px;
  padding: 0 4px 6px;
  border-bottom: 1px solid var(--komo-border);
  margin-bottom: 4px;
}

.komo-week-hdr-day, .komo-week-hdr-pct {
  font-size: 0.58rem;
  color: var(--komo-muted);
  text-align: center;
  font-family: var(--komo-font-jp);
}

.komo-habit-row {
  display: grid;
  grid-template-columns: 130px repeat(7, 28px) 40px;
  align-items: center;
  gap: 4px;
  padding: 3px 4px;
  border-radius: var(--komo-radius);
  transition: background 0.12s;
}

.komo-habit-row:hover { background: var(--komo-overlay); }

.komo-habit-name {
  font-size: 0.73rem;
  color: var(--komo-sub);
  cursor: default;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  font-family: var(--komo-font-jp);
}

/* Habit dots */
.komo-dot {
  width: 20px; height: 20px;
  border: 1px solid var(--komo-border);
  border-radius: 2px;
  cursor: pointer;
  transition: all 0.12s ease;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
}

.komo-dot:hover {
  border-color: var(--komo-sakura);
  background: rgba(253, 190, 2, 0.06);
}

.komo-dot.on {
  background: var(--komo-sakura);
  border-color: var(--komo-sakura);
  box-shadow: 0 0 8px rgba(253, 190, 2, 0.3);
}

.komo-dot.on::after {
  content: '·';
  color: rgba(21, 10, 36, 0.8);
  font-size: 0.9rem;
  line-height: 1;
}

.komo-habit-pct {
  font-size: 0.63rem;
  color: var(--komo-muted);
  text-align: right;
  font-variant-numeric: tabular-nums;
}

/* Bio bar (overall consistency) */
.komo-bio-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid var(--komo-border);
}

.komo-bio-lbl {
  font-size: 0.62rem;
  color: var(--komo-muted);
  min-width: 100px;
  letter-spacing: 0.06em;
}

.komo-bio-bar-wrap {
  flex: 1;
  height: 3px;
  background: var(--komo-faint);
  border-radius: 2px;
  overflow: hidden;
}

.komo-bio-bar {
  height: 100%;
  background: linear-gradient(to right, var(--komo-sakura), var(--komo-lavender));
  border-radius: 2px;
  transition: width 0.5s ease;
  box-shadow: 0 0 8px rgba(253, 190, 2, 0.4);
}

.komo-bio-pct {
  font-size: 0.65rem;
  color: var(--komo-sakura);
  font-variant-numeric: tabular-nums;
  min-width: 32px;
  text-align: right;
}

/* ──────────────────────────────────────────────
   MODAL
   ────────────────────────────────────────────── */
.komo-modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(10, 5, 24, 0.65);
  backdrop-filter: blur(6px);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
}

.komo-modal {
  background: var(--komo-surface);
  backdrop-filter: blur(20px) saturate(160%);
  -webkit-backdrop-filter: blur(20px) saturate(160%);
  border: 1px solid var(--komo-border-hover);
  border-radius: 4px;
  padding: 20px;
  min-width: 320px;
  max-width: 420px;
  width: 90%;
  box-shadow: var(--komo-shadow);
}

.komo-modal-title {
  font-size: 0.7rem;
  color: var(--komo-sakura);
  letter-spacing: 0.1em;
  margin-bottom: 14px;
  opacity: 0.85;
}

.komo-modal-title::before { content: '// '; color: var(--komo-muted); }

.komo-modal-search {
  width: 100%;
  background: var(--komo-overlay);
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  color: var(--komo-text);
  font-family: var(--komo-font);
  font-size: 0.8rem;
  padding: 8px 12px;
  outline: none;
  margin-bottom: 0;
  box-sizing: border-box;
  caret-color: var(--komo-sakura);
  transition: border-color 0.15s;
}

.komo-modal-search:focus { border-color: var(--komo-border-sakura); }

.komo-modal-list {
  max-height: 260px;
  overflow-y: auto;
  scrollbar-width: thin;
  scrollbar-color: var(--komo-faint) transparent;
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
}

.komo-modal-item {
  padding: 8px 12px;
  font-size: 0.75rem;
  color: var(--komo-sub);
  cursor: pointer;
  border-bottom: 1px solid var(--komo-border);
  transition: all 0.1s;
  font-family: var(--komo-font);
}

.komo-modal-item:last-child { border-bottom: none; }
.komo-modal-item:hover { background: var(--komo-overlay); color: var(--komo-text); }
.komo-modal-item.active {
  color: var(--komo-teal);
  background: rgba(196, 181, 253, 0.05);
}

/* Modal buttons */
.komo-modal-btns {
  display: flex;
  gap: 8px;
  margin-top: 16px;
}

.komo-modal-btn {
  flex: 1;
  padding: 5px 12px;
  font-size: 0.7rem;
  font-family: var(--komo-font);
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  cursor: pointer;
  transition: all 0.15s;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.komo-btn-cancel {
  background: transparent;
  color: var(--komo-muted);
}

.komo-btn-cancel:hover {
  border-color: var(--komo-border-hover);
  color: var(--komo-text);
}

.komo-btn-save {
  background: rgba(253, 190, 2, 0.1);
  border-color: var(--komo-border-sakura);
  color: var(--komo-sakura);
}

.komo-btn-save:hover {
  background: rgba(253, 190, 2, 0.2);
  border-color: var(--komo-sakura);
}

.komo-btn-delete {
  background: rgba(196, 75, 14, 0.1);
  border-color: rgba(196, 75, 14, 0.3);
  color: var(--komo-red);
}

.komo-btn-delete:hover {
  background: rgba(196, 75, 14, 0.2);
  border-color: var(--komo-red);
}

/* Confirm modal styles */
.komo-confirm-modal {
  text-align: center;
  padding: 28px 24px;
}

.komo-confirm-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}

.komo-confirm-icon {
  font-size: 2.2rem;
  line-height: 1;
  opacity: 0.9;
}

.komo-confirm-title {
  font-size: 0.75rem;
  color: var(--komo-sakura);
  letter-spacing: 0.1em;
  text-transform: lowercase;
}

.komo-confirm-title::before {
  content: '// ';
  color: var(--komo-muted);
}

.komo-confirm-message {
  font-size: 0.85rem;
  color: var(--komo-text);
  line-height: 1.5;
}

/* ──────────────────────────────────────────────
   CONTEXT MENU
   ────────────────────────────────────────────── */
.komo-ctx-menu {
  position: fixed;
  z-index: 9999;
  background: var(--komo-surface);
  backdrop-filter: blur(16px) saturate(160%);
  -webkit-backdrop-filter: blur(16px) saturate(160%);
  border: 1px solid var(--komo-border-hover);
  border-radius: var(--komo-radius);
  box-shadow: var(--komo-shadow);
  min-width: 120px;
  overflow: hidden;
}

.komo-ctx-item {
  padding: 8px 14px;
  font-size: 0.72rem;
  color: var(--komo-sub);
  cursor: pointer;
  font-family: var(--komo-font);
  letter-spacing: 0.04em;
  transition: background 0.1s;
}

.komo-ctx-item:hover { background: var(--komo-overlay); color: var(--komo-text); }
.komo-ctx-del:hover { color: var(--komo-red) !important; }

/* ──────────────────────────────────────────────
   MUSIC PLACEHOLDER (mode: none, sin imagen)
   ────────────────────────────────────────────── */
.komo-music-ph {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 16px;
}

.komo-music-ph-icon {
  font-size: 2.8rem;
  line-height: 1;
  opacity: 0.55;
  filter: grayscale(0.3);
}

.komo-music-ph-hint {
  font-size: 0.7rem;
  color: var(--komo-muted);
  letter-spacing: 0.06em;
  filter: blur(3px);
  user-select: none;
  transition: filter 0.3s;
}

.komo-music-ph:hover .komo-music-ph-hint { filter: blur(0); }

/* ──────────────────────────────────────────────
   LOCAL MUSIC PLAYER
   ────────────────────────────────────────────── */
.komo-local-player {
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex: 1;
  padding: 4px 10px;
  justify-content: center;
}

.komo-local-info {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  text-align: center;
}

.komo-local-icon {
  font-size: 1.6rem;
  color: var(--komo-sakura);
  opacity: 0.7;
  flex-shrink: 0;
  line-height: 1;
}

.komo-local-meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.komo-local-name {
  font-size: 0.78rem;
  font-weight: 500;
  color: var(--komo-text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.komo-local-time {
  font-size: 0.6rem;
  color: var(--komo-muted);
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.04em;
}

.komo-local-progress {
  width: 100%;
  height: 3px;
  background: var(--komo-faint);
  border-radius: 2px;
  overflow: hidden;
  cursor: pointer;
  flex-shrink: 0;
}

.komo-local-progress:hover { height: 5px; margin: -1px 0; }

.komo-local-progress-fill {
  height: 100%;
  width: 0%;
  background: linear-gradient(to right, var(--komo-sakura), var(--komo-lavender));
  border-radius: 2px;
  transition: width 0.25s linear;
}

.komo-local-controls {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  width: 100%;
  position: relative;
}

.komo-local-counter {
  position: absolute;
  right: 0;
  bottom: -16px;
  font-size: 0.6rem;
  color: var(--komo-muted);
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.04em;
}

.komo-local-ctrl {
  width: 34px;
  height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--komo-border);
  border-radius: var(--komo-radius);
  background: var(--komo-overlay);
  color: var(--komo-sub);
  cursor: pointer;
  font-size: 0.85rem;
  transition: all 0.15s;
  flex-shrink: 0;
}

.komo-local-ctrl:hover {
  border-color: var(--komo-border-hover);
  color: var(--komo-text);
  background: var(--komo-raised);
}

.komo-local-ctrl-main {
  width: 40px;
  height: 40px;
  font-size: 1rem;
  background: rgba(253, 190, 2, 0.1);
  border-color: var(--komo-border-sakura);
  color: var(--komo-sakura);
}

.komo-local-ctrl-main:hover {
  background: rgba(253, 190, 2, 0.2);
  border-color: var(--komo-sakura);
  color: var(--komo-sakura);
}

.komo-local-spacer { flex: 1; }

.komo-local-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 20px;
}

.komo-local-empty-icon {
  font-size: 2rem;
  opacity: 0.4;
  line-height: 1;
}

.komo-local-empty-text {
  font-size: 0.7rem;
  color: var(--komo-muted);
  letter-spacing: 0.04em;
  text-align: center;
}

/* ──────────────────────────────────────────────
   ANIMATIONS
   ────────────────────────────────────────────── */
@keyframes komo-fade-in {
  from { opacity: 0; transform: translateY(6px); }
  to   { opacity: 1; transform: translateY(0); }
}

.komo-header-block { animation: komo-fade-in 0.35s ease; }
.komo-grid-block   { animation: komo-fade-in 0.4s ease 0.05s both; }
.komo-bottom-block { animation: komo-fade-in 0.45s ease 0.1s both; }

@keyframes komo-pulse-dot {
  0%, 100% { box-shadow: 0 0 4px rgba(253, 190, 2,0.3); }
  50%       { box-shadow: 0 0 10px rgba(253, 190, 2,0.6); }
}

.komo-dot.on { animation: komo-pulse-dot 2s ease infinite; }

/* ──────────────────────────────────────────────
   RESPONSIVE ADJUSTMENTS
   ────────────────────────────────────────────── */
@media (max-width: 900px) {
  .komo-header {
    grid-template-columns: 1fr 1fr;
    grid-template-rows: auto auto;
  }
  .komo-clock-block {
    grid-column: 1 / -1;
    order: -1;
    align-items: center;
  }
  .komo-grid {
    grid-template-columns: 1fr 1fr;
  }
  .komo-col-right {
    display: none;
  }
  .komo-week-hdr,
  .komo-habit-row {
    grid-template-columns: 100px repeat(7, 24px) 36px;
  }
  .komo-bottom-row {
    grid-template-columns: 1fr;
  }
}
"""


# -----------------------------------------------------------------------------
# 8. Nota del dashboard — búsqueda y colocación segura en la raíz
# -----------------------------------------------------------------------------

def _ensure_dashboard_cssclass(path):
    """Si la nota no tiene ya una cssclass compatible con komorebi.css
    (dashboard-layout, o el antiguo komorebi-dashboard), se la agrega sin
    tocar el resto del contenido."""
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if not content.startswith("---\n"):
        new_content = "---\ncssclasses:\n  - dashboard-layout\n---\n\n" + content
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("   se agregó frontmatter con cssclasses: dashboard-layout (la nota no tenía)")
        return

    end = content.find("\n---", 4)
    if end == -1:
        print("   ⚠️ frontmatter sin cierre '---' detectado, no se tocó el cssclass automáticamente")
        return

    frontmatter = content[4:end]
    rest = content[end:]

    if "dashboard-layout" in frontmatter or "komorebi-dashboard" in frontmatter:
        return  # ya tiene una cssclass compatible con el snippet

    if "cssclasses:" in frontmatter:
        frontmatter = frontmatter.replace("cssclasses:", "cssclasses:\n  - dashboard-layout", 1)
    else:
        frontmatter = frontmatter.rstrip("\n") + "\ncssclasses:\n  - dashboard-layout\n"

    new_content = "---\n" + frontmatter + rest
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("   se agregó 'dashboard-layout' a cssclasses existente")


def _looks_like_dashboard_note(filename):
    """'dashboard' + alguna variante de 'komorebi' (incluida la grafía con
    error 'komoerobi' que se usó como nombre original), en cualquier orden."""
    lower = filename.lower()
    return "dashboard" in lower and ("komorebi" in lower or "komoerobi" in lower)


def find_and_place_dashboard(root):
    target_path = os.path.join(root, "Komorebi_Dashboard.md")
    if os.path.exists(target_path):
        print(f"   'Komorebi_Dashboard.md' ya existe en la raíz, no se mueve nada: {target_path}")
        _ensure_dashboard_cssclass(target_path)
        return

    candidate = None
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for fname in filenames:
            if fname.lower().endswith(".md") and _looks_like_dashboard_note(fname):
                candidate = os.path.join(dirpath, fname)
                break
        if candidate:
            break

    if candidate is None:
        placeholder = (
            "---\n"
            "cssclasses:\n"
            "  - dashboard-layout\n"
            "---\n"
            "# Komorebi Dashboard\n\n"
            "Usa este dashboard como tu centro de control visual.\n"
        )
        with open(target_path, "w", encoding="utf-8") as f:
            f.write(placeholder)
        print(f"   no se encontró una nota de dashboard existente; se creó un placeholder: {target_path}")
        return

    shutil.move(candidate, target_path)
    print(f"   nota encontrada en '{os.path.relpath(candidate, root)}' -> movida a '{target_path}'")
    _ensure_dashboard_cssclass(target_path)


# -----------------------------------------------------------------------------
# Orquestación
# -----------------------------------------------------------------------------

def main():
    print("🚀 Iniciando automatización de la bóveda JARVIS (fusión segura)...\n")
    root = resolve_vault_root()
    print(f"Bóveda detectada en: {root}\n")

    print("1. Estructura de carpetas (fusión segura)")
    ensure_dirs(root, VAULT_DIRS)
    print()

    print("2. .gitignore de la bóveda (bloque gestionado, fusión segura)")
    upsert_gitignore(root)
    print()

    print("3. Hooks de Claude Code")
    hooks_dir = os.path.join(root, ".claude", "hooks")
    write_managed_file(os.path.join(hooks_dir, "inbox.py"), HOOK_INBOX_CONTENT, "hook inbox.py")
    write_managed_file(os.path.join(hooks_dir, "indice.py"), HOOK_INDICE_CONTENT, "hook indice.py")
    old_respaldo = os.path.join(hooks_dir, "respaldo.py")
    if os.path.exists(old_respaldo):
        os.remove(old_respaldo)
        print("   hook respaldo.py de una versión anterior fue retirado")
    merge_claude_settings(root)
    print()

    print("4. Skills (.claude/skills/)")
    skills_data = {
        os.path.join(root, ".claude", "skills", "process-inbox", "SKILL.md"): SKILL_PROCESS_INBOX,
        os.path.join(root, ".claude", "skills", "weekly-connections", "SKILL.md"): SKILL_WEEKLY_CONNECTIONS,
        os.path.join(root, ".claude", "skills", "generate-brief", "SKILL.md"): SKILL_GENERATE_BRIEF,
        os.path.join(root, ".claude", "skills", "write-content", "SKILL.md"): SKILL_WRITE_CONTENT,
    }
    for path, content in skills_data.items():
        write_managed_file(path, content, "skill")
    print()

    print("5. Subagentes (.claude/agents/)")
    agents_data = {
        os.path.join(root, ".claude", "agents", "archivista.md"): AGENT_ARCHIVISTA,
        os.path.join(root, ".claude", "agents", "tejedor.md"): AGENT_TEJEDOR,
        os.path.join(root, ".claude", "agents", "escriba.md"): AGENT_ESCRIBA,
    }
    for path, content in agents_data.items():
        write_managed_file(path, content, "subagente")
    print()

    print("6. Plugin ReverySky Map (Unity 3D) — eliminación por rendimiento")
    remove_reverysky_plugin(root)
    print()

    print("7. Snippets CSS (.obsidian/snippets/)")
    write_managed_file(os.path.join(root, ".obsidian", "snippets", "cosmic-graph.css"), SNIPPET_COSMIC_GRAPH, "snippet")
    write_managed_file(os.path.join(root, ".obsidian", "snippets", "komorebi.css"), SNIPPET_KOMOREBI, "snippet")
    print()

    print("8. Nota del dashboard Komorebi")
    find_and_place_dashboard(root)
    print()

    print("=" * 75)
    print("PROCESO FINALIZADO")
    print("=" * 75)
    print("Todo lo anterior es fusión segura: nada se sobrescribió fuera de los")
    print("artefactos que esta herramienta gestiona (hooks, skills, subagentes, snippets).")
    print()
    print("Pasos manuales en Obsidian:")
    print("  a) Configuración -> Apariencia -> Snippets CSS: activa 'cosmic-graph' y 'komorebi'.")
    print("  b) Configuración -> Plugins de la comunidad: confirma que 'ReverySky Map' ya no")
    print("     aparece. Si Obsidian estaba abierto durante el borrado, reinicia la app")
    print("     para que libere el archivo antes de confirmar.")
    print("  c) Dataview, Style Settings y obsidian-git ya estaban instalados en tu bóveda —")
    print("     no hace falta reinstalarlos.")
    print("=" * 75)


if __name__ == "__main__":
    main()
