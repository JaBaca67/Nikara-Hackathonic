# Nikara

App Flutter (móvil/web/desktop) de turismo y negocios locales en Nicaragua. UI en español, backend en Supabase (Postgres + Auth). Diseño derivado 1:1 del archivo Figma "UI-NÍKARA".

## Stack

- **Flutter** 3.44.5 / **Dart** ^3.12.2 (ver `flutter --version`).
- **Backend**: Supabase (`supabase_flutter`) — Auth + tabla `profiles` (roles: `turista`, `emprendedor`, `admin`, `auditor`). Credenciales en `lib/core/supabase/supabase_config.dart`.
- **Estado**: sin paquete de state management. Patrón: servicios singleton (`XService()` factory que devuelve una instancia cacheada) con getters síncronos, más `StatefulWidget`/`setState` en la UI. Ver `lib/core/services/auth_service.dart` como referencia canónica.
- **Mapas**: `google_maps_flutter` + `geolocator`. Ruteo real ("Cómo llegar") vía `DirectionsService` (`lib/core/services/directions_service.dart`) llamando a la Directions API de Google directamente desde Dart — necesita `GOOGLE_MAPS_API_KEY` vía `--dart-define-from-file=dart_defines.json` (ver `lib/core/config/maps_config.dart`), independiente de la key nativa del SDK de Maps en `android/local.properties`/`ios/Flutter/Maps.xcconfig`.
- **Persistencia local**: `shared_preferences` (sesión de invitado, favoritos, extras de perfil).
- **UI**: `google_fonts`, `font_awesome_flutter`, `flutter_svg`. Sin fuentes empaquetadas — toda la tipografía sale de `google_fonts` (League Spartan + Nunito).

## Arquitectura de carpetas

```
lib/
  core/            # compartido entre features: models, services, supabase, utils
  features/<name>/ # feature-first: data/ domain/ presentation/
  shared/          # widgets/services reutilizados entre features (main_layout, guest_guard, etc.)
  theme/           # AppColors + AppTheme (tokens ligados a Figma)
  widgets/         # LEGACY — ver reglas abajo, no agregar nada aquí
  models/          # LEGACY (mock_data.dart), casi sin uso real — no extender
```

No todas las features tienen los tres subniveles (`data/domain/presentation`); agrégalos según se necesiten, siguiendo el ejemplo de `features/business/`.

## Comandos

```bash
flutter pub get                    # instalar dependencias
flutter run --dart-define-from-file=dart_defines.json  # levantar con la Directions API key (copia dart_defines.json.example)
flutter run -d chrome              # levantar en web
flutter run -d windows             # levantar en Windows desktop
flutter analyze                    # linting estático (flutter_lints)
dart format .                      # formateo
dart format --output=none --set-exit-if-changed .   # check de formato sin escribir (para CI/hooks)
flutter test                       # correr toda la suite
flutter test test/widget_test.dart # correr un solo archivo
flutter build apk / web / windows  # build de release
```

No hay codegen (sin `build_runner`, `freezed` ni `json_serializable`) — los modelos se serializan a mano vía `fromRow`/`toJson` manuales.

## Convenciones

- **Idioma**: identificadores de código en inglés; strings visibles al usuario y mensajes de error siempre en español. Los comentarios documentan el *por qué* (una restricción no obvia, una decisión de diseño), no el *qué* — el código ya se explica solo con buenos nombres.
- **Servicios singleton**: `factory XService() => instance;` + constructor privado `XService._internal()`. No conviertas esto en Provider/Riverpod/Bloc sin discutirlo primero (ver regla abajo).
- **Errores de Supabase**: capturar excepciones específicas primero (`PostgrestException`, `AuthException`), fallback genérico al final, y traducir siempre a un mensaje amigable en español (patrón `_friendlyAuthError` en `auth_service.dart`). Los métodos que llaman a Supabase devuelven un result object (ej. `AuthResult`) o lanzan una excepción propia (`AuthServiceException`) con `message` en español — nunca dejes escapar un `PostgrestException` crudo hacia la UI.
- **Colores y tipografía**: siempre desde `AppColors`/`AppTextStyles` (`lib/theme/`) — nunca un hex literal suelto ni un `Color(0x...)` inline en una pantalla. Ver "Sistema de diseño" abajo para la disciplina completa (primitivos vs. semánticos, tiers de pantalla).
- **Diseño**: la fuente de verdad son (a) el archivo Figma "UI-NÍKARA" para layout/estructura de pantallas existentes, y (b) los prototipos del usuario en Claude Design para pantallas nuevas o rediseños (ver "Flujo Claude Design" abajo). Los comentarios en `app_colors.dart`/`app_theme.dart` referencian su origen (nodo de Figma o token semántico) — mantén esa trazabilidad al agregar tokens nuevos.
- **Tests de widgets**: `AuthService` toca `Supabase.instance` de forma síncrona, así que **todo** widget test necesita en `setUpAll`: `SharedPreferences.setMockInitialValues({})` seguido de `Supabase.initialize(url: ..., publishableKey: 'test-anon-key-not-real')` con credenciales falsas — no hace falta un proyecto real. Repetir `setMockInitialValues({})` en `setUp` porque otros servicios leen `SharedPreferences` en cada test. Usar `tester.pump()` con duración explícita en vez de `pumpAndSettle()` en pantallas con `AuroraBackgroundWidget` (animación infinita que nunca deja que `pumpAndSettle` termine).
- **Auditoría de overflow**: `test/overflow_audit_test.dart` renderiza pantallas con datos deliberadamente peores que cualquier input real (nombres/descripciones larguísimas) para forzar `RenderFlex overflow`. Al agregar una pantalla nueva con texto dinámico de negocio, considera agregarla a ese archivo.
- **Validación visual antes de dar por terminada una pantalla**: ver "Protocolo de validación visual" abajo — es obligatorio, no opcional, para cualquier cambio que toque UI.

## Sistema de diseño

Fuente de verdad visual: Figma "UI-NÍKARA" para pantallas ya existentes, prototipos del usuario en Claude Design para pantallas nuevas/rediseños. Este sistema resuelve un problema real detectado en auditoría: `app_colors.dart` acumuló ~110 constantes (muchas duplicadas — colores distintos con el mismo hue, nombrados sin relación entre sí) y `AppTextStyles` mezclaba tipografía con color en el mismo getter, dos capas que deberían ser independientes. Lo de abajo es la disciplina que reemplaza ese patrón — no es una sugerencia de estilo, es la regla.

### Primitivos de marca (los únicos 3 colores "de marca" que existen)

Cada uno tiene como máximo 2 variantes — `Fill` (relleno de badges/pills/cards/CTA) y `Text` (texto/íconos interactivos, verificado a contraste ≥4.5:1 WCAG AA contra `background` y `surface`). Nunca se usa un tono intermedio inventado; si un caso de uso no encaja en Fill o Text, se discute antes de crear un tercer escalón.

| Rol | Hex | Contraste vs. background/surface | Uso |
|---|---|---|---|
| `goldFill` | `#FDBE02` | — (no se usa como texto) | Rellenos, CTAs primarios, acentos decorativos, badges. |
| `oliveFill` | `#C2CA5B` | — | Rellenos del badge/tag ECO, acentos decorativos claros. |
| `oliveText` | `#707536` | 4.68 / 4.82 | Links, texto interactivo, íconos con significado ECO. Reemplaza al antiguo `accent300` (`#8B922A`, que medía solo 3.21 — **incumplía AA para texto normal**; esto no es solo limpieza, corrige un bug de accesibilidad real). |
| `orangeFill` | `#FF8243` | — | Gradientes, fondos de tarjeta destacada, acentos decorativos. |
| `orangeText` | `#C44B0E` | 4.60 / 4.74 | Texto/íconos que necesitan el acento naranja (precios destacados, highlights puntuales). |

**Gold nunca es color de texto.** Su variante oscurecida a contraste seguro (`#8F6D0A`) deja de leerse como dorado y se lee como bronce — se decidió deliberadamente no usarla; Gold vive solo como relleno con texto oscuro (`textPrimary`/`textInverted`) encima.

### Tokens semánticos (neutros + estado)

- `background` = `backgroundCream` (`#FFF9F0`), `surface` = `surface100` (`#FDFDFD`) — fondo de pantalla vs. fondo de tarjetas/inputs.
- `textPrimary` = `neutral1100` (`#121212`), `textSecondary` = un neutro cálido consolidado (el refactor debe unificar los ~8 grises casi duplicados hoy dispersos — `neutral600/700/800`, `settingsTextMuted`, `authBodyMuted`, etc. — en un único token; no crear una variante nueva por pantalla).
- `textInverted` = `surface100`/blanco, para texto sobre fondos oscuros o sobre un `Fill` de marca saturado.
- `border` = `cardBorder` (negro @ ~12%), ya existente — no se toca.
- `error` = `formError` (`#D64545`) para validación inline de formularios; `destructive` = `settingsDanger` (`#CC5510`) para confirmaciones de acción destructiva (eliminar, cerrar sesión). Son dos tokens deliberadamente distintos, no uno — así ya se documentaba antes de esta auditoría y sigue siendo correcto. *Nota pendiente*: ambos miden 4.1–4.3:1 de contraste, ligeramente bajo el 4.5:1 estricto; aceptable para texto en negrita/con ícono de apoyo, pero es un ajuste menor a considerar en el refactor si se usan alguna vez como texto largo sin negrita.
- `ecoAccent` = alias del par `oliveFill`/`oliveText` — el módulo ECO no tiene un cuarto color propio, hereda la familia Olive.

Cualquier necesidad de color que no encaje en esta lista se **discute antes de escribir código**, nunca se resuelve agregando una constante nueva a `app_colors.dart` sobre la marcha.

### Tiers de pantalla

Dos categorías oficiales, declaradas explícitamente al crear o revisar una pantalla:

- **Expresiva**: Auth (Splash/Login/Registro) y cualquier futura pantalla de onboarding o celebración. Única categoría autorizada a usar el gradiente completo de los 3 `Fill` (`AppGradients.authBackgroundColors`) y a sentirse "de marca" en toda la superficie.
- **Funcional**: todo lo demás — Inicio, Mapa, Perfil, Ajustes, detalle de negocio, wizard de registro de negocio, módulo ECO. Fondo/superficie siempre desde `background`/`surface`, texto siempre desde la escala neutra, y **como máximo un acento de marca visible a la vez** (ej. un CTA en `goldFill`, o un badge en `ecoAccent`) — nunca combinar los 3 `Fill` en una pantalla Funcional, eso es lo que hoy hace que ECO y los perfiles externos se sientan "con ideas distintas sin razón".

Al tocar una pantalla existente que no respete su tier, es motivo válido de refactor incluso si no fue lo que se pidió explícitamente — pero se avisa primero, no se cambia en silencio.

### Tipografía (`AppTextStyles`)

Cada getter define únicamente `fontSize`, `fontWeight` y `height` (line-height). Nunca fija un `color`. El color se aplica en el widget por composición (`Text('...', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary))`) o heredado del `ColorScheme`/`DefaultTextStyle` del árbol. Esto es un cambio de comportamiento respecto al código actual (donde ~60 de los ~90 getters ya traen color fijo) — el refactor de `app_theme.dart` debe extraer esos colores hacia el call site.

### Flujo Claude Design

El usuario prototipa en su dashboard de Claude Design de forma independiente y guarda capturas en `01_Nikara/Fuentes_Raw/raw/claude_design/`. Cuando referencie una imagen con `@nombre_imagen.png`:

1. Analiza visualmente disposición de componentes, jerarquía, espaciados y formas — el usuario no la va a describir en texto.
2. Traduce esa disposición a widgets de Flutter usando exclusivamente los tokens de este sistema de diseño (primitivos Fill/Text, semánticos, `AppTextStyles`) — nunca un hex nuevo leído "a ojo" de la captura, aunque la imagen muestre un tono que no está en la paleta. Si el prototipo pide un color fuera de los primitivos, se marca como pregunta abierta antes de codificar, no se inventa un token para resolverlo.
3. Declara explícitamente el tier (Expresiva/Funcional) de la pantalla resultante antes de escribir código, y lo justifica si el prototipo del usuario sugiere lo contrario.

### Skill de captura de tareas pendientes (`capturar-tarea-pendiente`)

Skill de usuario (no vive en este repo) que dispara sola cuando José dice
algo como "guardá esto para después" o "queda pendiente" en cualquier
sesión de Claude Code — incluida una abierta en este repo. Guarda la idea
como nota estructurada en `01_Nikara/Proyecto_Flutter/Tareas_Pendientes/`
de la bóveda (o en `00_Sistema/Skills/` si es una idea de skill nueva, no
una tarea de este proyecto). No hace falta hacer nada especial para que
funcione — solo mencionar que algo queda pendiente.

### Skill de auditoría de diseño (`nikara-design-audit`)

Skill instalada a nivel de usuario (`~/.claude/skills/nikara-design-audit/`,
no vive en este repo) — disponible en cualquier sesión de Claude Code sin
importar la carpeta. Dispara sola al pedir "auditar el diseño", "revisar
consistencia visual", o al tocar cualquier pantalla nueva (modo checklist
preventivo antes de darla por terminada). Incluye un script determinístico
(`scripts/scan_dart_tokens.py`) que detecta colores/tipografía fuera de
tokens, desvíos de la escala `AppSpacing`/`AppRadius` (`lib/theme/
app_spacing.dart`, nuevo — ver arriba, no está en Figma/Claude Design,
se derivó de la frecuencia real de uso en el código), y violaciones de tier
(2+ `Fill` de marca en una pantalla Funcional).

**Estado tras la auditoría del 2026-08-25** (ejecutada con la skill sobre
`lib/` entero, 46 archivos visuales):

*Resuelto:*

- **La familia verde se consolidó de 5 colores a 2.** `accent300` (3.21,
  incumplía AA) y `ecoActive` (3.77, también incumplía — 58 usos en 20
  archivos, no estaba documentado) colapsaron en `oliveText` `#707536`.
  `ecoForest` `#3A7D3A` se renombró a `success`: no era un verde ECO, se
  usaba en "contraseña fuerte", gamificación y pantalla de éxito — es un
  token de estado, igual que `error` y `destructive`. Las tres constantes
  viejas están eliminadas; 105 call sites migrados.
- **Bug de accesibilidad crítico corregido.** Todos los badges ECO pintaban
  texto blanco sobre el relleno lima: contraste **1.74:1** contra el mínimo
  AA de 4.5:1. La causa raíz es instructiva — el sistema ya tenía la regla
  correcta escrita *para Gold* ("relleno claro lleva texto oscuro encima")
  pero nunca se aplicó a Olive, que es igual de claro (luminancia 1.69 vs
  1.60). Ahora es tinta sobre lima: 10.61:1. **Regla general: ningún `Fill`
  de marca lleva texto blanco encima — los tres son claros.**
- **`app_colors.dart` tiene una capa canónica al inicio** con los primitivos
  y los semánticos. Es la única capa que deberían tocar las pantallas
  nuevas; la paleta histórica de Figma quedó debajo, marcada "en
  consolidación".
- **El badge ECO existía 6 veces** (4 paddings y 3 estilos tipográficos
  distintos para un pill de 3 letras) — hoy es `EcoBadge` en
  `lib/shared/widgets/eco_badge.dart`, el primer widget que consume
  `AppSpacing`/`AppRadius`.
- **Tier de `eco_main_screen.dart`**: badge "Empieza pronto", CTA "Unirme",
  spinner y "Reintentar" pasaron de Gold a Olive.

*Pendiente:*

- **Coexistencia Gold + Olive en Inicio y Mapa.** El escaneo dejó de marcar
  `home_screen.dart` y `map_screen.dart`, pero **sólo porque el color se
  movió dentro de `EcoBadge`** — visualmente el chip de categoría dorado y
  el badge ECO oliva siguen viéndose al mismo tiempo. No confundir "el
  script ya no lo detecta" con "está resuelto": es una decisión de diseño
  todavía abierta.
- **265 desvíos de la grilla de 4pt** en pantallas existentes. Los literales
  que ya coincidían con la escala se migraron (adopción: de 0 a 394
  referencias); lo que queda **sí cambiaría el render**, por eso no se tocó.
  Dato útil para atacarlo: **6 reglas cubren el 61% y ninguna mueve más de
  2px** — radio `14→12` (41 casos), padding `10→8` (40), padding `14→12` (35),
  radio `18→16` (19), padding `6→4` (15), padding `18→16` (12). Concentrados
  en `register_business_wizard` (43), `profile_screen` (27), `map_screen`
  (22), `create_route_wizard_screen` (22) y `home_screen` (20).
- **Targets táctiles por debajo de 48x48**: `_HeaderIconButton` es 36x36 y
  `DetailCoverIconButton` 40x40. Ampliarlos desplaza layout — requiere
  revisión visual.
- El refactor de `AppTextStyles` (~60 de ~90 getters todavía fijan `color`).

**Resuelto en el segundo bloque del mismo día** (todo de cero cambio visual,
`analyze` limpio y 88/88 tests verdes tras cada paso):

- **Accesibilidad de 6 a 23 anotaciones.** El patrón que conviene repetir: en
  vez de anotar call sites sueltos, se agregó un `label` **requerido** a los
  tres wrappers de ícono ya existentes (`DetailCoverIconButton`,
  `_HeaderIconButton`, `_CircleIconButton`), así el compilador obliga a
  etiquetar cualquier uso futuro. Para íconos sin wrapper, usar el parámetro
  nativo `semanticLabel` de `Icon` — no envuelve nada, no puede alterar
  layout.
- **87 call sites migrados a los tokens semánticos** (`settingsDanger` →
  `destructive`, `neutral1100` → `textPrimary`, `backgroundCream` →
  `background`, `formError` → `error`, `cardBorder` → `border`).
- **Segundo componente duplicado consolidado**: el botón circular de "volver"
  estaba reimplementado byte a byte idéntico en tres archivos → hoy es
  `CircleBackButton` en `lib/shared/widgets/circle_back_button.dart`.
- **Los 8 `TextStyle(...)` inline NO son deuda** — falso positivo del escaneo,
  ya verificado: 4 son `TextPainter` sobre canvas de `dart:ui` (bitmaps de los
  pines del mapa, donde `google_fonts` no puede resolver familia) y 4 aplican
  sólo color heredando la tipografía del tema, que es justo lo que pide la
  regla de composición. No volver a reportarlos.
- `authLink` `#6E7522` es un sexto oliva casi idéntico a `oliveText` —
  candidato a colapsar, sin tocar por ahora (vive en Auth, tier Expresiva).

*(`business_icons.dart` dispara el chequeo de tier pero es falso positivo —
es una tabla `categoría → color`, nunca muestra dos `Fill` a la vez.
`eco_badge.dart` también, por mencionar `[AppColors.goldFill]` en un
comentario.)*

## Protocolo de validación visual

Herramienta: `claude-in-chrome` (ya disponible en este entorno). **No se agrega Playwright ni ningún otro MCP nuevo para esto.**

Al terminar de codificar o refactorizar cualquier pantalla, antes de darla por terminada:

1. Levantar `flutter run -d chrome`.
2. Configurar el navegador en emulación de dispositivo móvil con un ancho fijo entre 375px y 390px (equivalente a iPhone/Pixel) — Níkara es una app móvil nativa, validar en viewport de escritorio no dice nada útil sobre overflows reales.
3. Capturar la pantalla emulada y compararla contra la captura de Claude Design de origen (si existe) o contra el nodo de Figma correspondiente.
4. Revisar explícitamente: `RenderFlex overflow`, texto cortado, botones/CTAs mal alineados o fuera del viewport.
5. Si algo no coincide, corregir antes de reportar la tarea como completa — no describir la discrepancia como "pendiente" y seguir adelante.

## Supabase & Security Guidelines

RLS está deshabilitado deliberadamente en este proyecto — hoy el cliente de Flutter es el único punto que decide qué fila le pertenece a quién. Dos categorías de consulta que **no se tratan igual**:

### Consultas públicas — nunca se filtran por dueño

Listar negocios (`getBusinesses`, `getBusinessesInBounds`, `getAllCategories` en `business_storage_service.dart`), listar jornadas ECO, ver el detalle de un negocio/organización de otro usuario: son lecturas intencionalmente cross-usuario — es la función central de la app (un turista tiene que ver negocios que no son suyos). Agregar `.eq('owner_id', currentUser.id)` aquí no es "más seguro", rompe la funcionalidad.

### Consultas "mis X" y mutaciones — el filtro de dueño es obligatorio

- **Lecturas personales** (`getMyOrganizations`, "mis negocios", "mis jornadas organizadas", "mis inscripciones ECO"): siempre `.eq('owner_id'|'organizer_id'|'user_id', supabase.auth.currentUser!.id)`. El id nunca llega como parámetro libre desde la UI sin validarlo contra la sesión activa.
- **`update`/`delete`** sobre `businesses`/`organizations`/`routes` (`owner_id`), `eco_activities` (`organizer_id`), `eco_participants` (`user_id`): el filtro de dueño va **en la misma sentencia** de la mutación (`.eq('id', id).eq('owner_id', currentUser.id)`), no en un `select` + comparación manual antes de mutar. Dos gaps concretos que corrige esta regla: `business_storage_service.dart:178` borra por `.delete().eq('id', id)` sin `owner_id`; `eco_service.dart` valida `organizer_id` con un `select` separado (~líneas 443-450) en vez de filtrarlo en el propio `update`/`delete`.
- **Inserciones**: la columna de dueño se estampa siempre con `supabase.auth.currentUser!.id`, nunca con un valor recibido de la UI.
- Ninguna mutación se ejecuta sin comprobar antes que `supabase.auth.currentUser` no sea nulo — lanzar la excepción de servicio en español correspondiente si lo es (patrón ya usado en `createOrganization`).

### Qué protege esto y qué no

Filtrar así en Dart prepara el código para cuando RLS se active (la consulta ya solo toca lo que le pertenece al usuario, activar RLS no cambia el resultado — impacto cero) y evita bugs propios. **No es seguridad real hoy**: con RLS apagado, cualquiera que llame directamente a la REST API de Postgrest con la `anon key` sin pasar por la app de Flutter puede leer o mutar cualquier fila sin que este filtro exista para detenerlo. Es higiene de código y preparación, no un sustituto de activar RLS en producción.

## Reglas estrictas — qué NO hacer

- **No** agregues archivos a `lib/widgets/` — es una carpeta legacy de un solo archivo (`aurora_background_widget.dart`). Los widgets cross-feature van en `lib/shared/widgets/`; los widgets específicos de una feature van en `lib/features/<feature>/presentation/widgets/`.
- **No** extiendas `lib/models/mock_data.dart` como fuente de datos real — es un remanente de antes de conectar Supabase (una sola referencia viva en todo `lib/`). Supabase es la fuente de verdad.
- **No** introduzcas un paquete de state management (Provider, Riverpod, Bloc, GetX) sin acordarlo antes explícitamente con el usuario — el patrón actual de servicios singleton es una decisión deliberada, no un descuido.
- **No** subas ni loguees la `service_role key` de Supabase en ningún archivo del cliente. La `anon key` en `supabase_config.dart` es intencional y pública (RLS está deshabilitada a propósito en este proyecto, según el comentario de esa clase); la `service_role key` nunca debe aparecer en `lib/`.
- **No** hagas `flutter build`/`flutter run` con `--release` sin que el usuario lo pida — son operaciones lentas, prefierir `flutter analyze` + `flutter test` para validar cambios.
- **No** agregues dependencias nuevas en `pubspec.yaml` sin verificar antes que no exista ya una forma de resolverlo con lo instalado (revisa `dependencies:` completo antes de proponer un paquete nuevo).
- **No** captures excepciones de Supabase de forma silenciosa (`catch (_) {}` sin mensaje) — siempre propaga o traduce el error, nunca lo tragues.

### Seguridad en Git — qué nunca debe salir del entorno local

- **Bajo ningún concepto** se commitea: `.env`, `dart_defines.json`, `android/local.properties`, `ios/Flutter/Maps.xcconfig`, la carpeta `.claude/`, ni archivos `desktop.ini` (basura de sincronización de OneDrive/Windows, aparecen por decenas en este repo). Todos están en `.gitignore`.
- `.claude/` está en `.gitignore` pero **no se retiró del tracking** lo que ya estaba versionado antes de esta regla (`settings.json`, los `SKILL.md` de los skills del equipo) — eso se mantiene intencional y visible para el resto del equipo. La regla nueva solo evita que basura futura (logs de sesión, skills experimentales sueltos, `desktop.ini`) se cuele con un `git add .`/`git add -A` descuidado.
- Antes de cualquier commit, revisa `git status` — si aparece algo de la lista de arriba como `??` o modificado, es señal de que el `.gitignore` no lo está cubriendo y hay que arreglarlo antes de commitear, no ignorarlo manualmente archivo por archivo.
- La `anon key` de Supabase en `supabase_config.dart` es pública a propósito (RLS deshabilitada intencionalmente, ver regla arriba); la `service_role key` nunca debe aparecer en `lib/` bajo ninguna circunstancia.

### Segundo Cerebro Integration

Este proyecto está enlazado a una bóveda de Obsidian ("segundo cerebro" de JOSE) en `G:\My Drive\JARVIS_JOSE`. Si la unidad `G:\` no está montada en esta máquina, continuar el trabajo normalmente sin la bóveda — no es una dependencia dura del proyecto.

La bóveda **sí** es un repositorio git (`github.com/JaBaca67/JARVIS_JOSE`, privado): el plugin `obsidian-git` auto-commitea y pushea cada ~30 min. Eso es su respaldo y su historial — antes de una reorganización grande, commitear un punto de restauración. No hace falta commitear a mano cada cambio pequeño; el auto-commit lo cubre.

La bóveda está organizada **por dominio de vida**, no solo por Níkara: `00_Sistema` (control), `01_Nikara`, `02_UAM` (universidad), `03_Personal`, `04_Recursos`, `05_Diario`, `06_Inbox` (captura única), `Templates`.

**División de fuentes de verdad**: la bóveda de Obsidian es la fuente de verdad *lógica* del Command Center (qué existe, cómo se relaciona, qué skills/convenciones aplican — el "por qué" y el "qué"); Claude Design y las capturas en `01_Nikara/Fuentes_Raw/raw/claude_design/` son la fuente de verdad *estética móvil* (cómo se ve una pantalla — el "cómo"). No se mezclan: una decisión visual se resuelve mirando Claude Design/Figma, nunca inventándola a partir de una nota de la bóveda; una pregunta de arquitectura o de qué skill/convención aplica se resuelve mirando la bóveda, nunca Claude Design.

- **Antes de actuar**, lee `G:\My Drive\JARVIS_JOSE\00_Sistema\vault_index.md` — es el mapa de navegación de la bóveda y ahorra tener que recorrer todas las carpetas.
- **Después de hacer cambios relevantes**, registra una línea en `G:\My Drive\JARVIS_JOSE\00_Sistema\log.md` (formato `YYYY-MM-DD — acción — detalle`).
- El mapa conceptual del código (vistas de Flutter, servicios/conceptos técnicos, tablas de Supabase) vive como notas individuales en `00_Sistema/01_Graph_Imports/`, cada una enlazada de vuelta al archivo fuente real con `[[lib/...]]` / `[[supabase/sql/...]]`. Al agregar una vista, servicio o tabla nueva, considera agregar su nota correspondiente ahí.
- El registro de skills activas/planeadas (nativas de Obsidian y propias de Níkara) vive en `00_Sistema/Skills/`, una nota por skill con frontmatter `type: jarvis_skill` — antes de asumir que una skill "existe" o está activa, revisa su `status` ahí en vez de asumirlo por el nombre.
- Al crear notas de negocios locales o jornadas ECO en la bóveda, usa las plantillas en `Templates/` (`Template_Negocio_Local.md`, `Template_Jornada_Eco.md`, `Template_Proyecto_Flutter.md`).
- Respeta la identidad visual de Níkara en cualquier nota o diagrama que generes: Gold `#FDBE02` (solo relleno), Olive `#C2CA5B` relleno / `#707536` texto, Orange `#FF8243` relleno / `#C44B0E` texto, Cream `#FFF9F0`; tipografías **League Spartan** (títulos) y **Nunito** (cuerpo) — ver "Sistema de diseño" arriba y `lib/theme/app_colors.dart`.
