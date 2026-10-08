# Integración de mejoras varias — 2026-10-07

## Resultado y alcance

Se integró `origin/feature/mejoras-varias` en el `develop` local de
`JaBaca67/Nikara-Hackathonic`, conservando el historial de ambas ramas.
El nombre real de la rama remota es `feature/mejoras-varias`.
La integración es viable, pero requirió resolver 11 conflictos y adaptar
las pruebas a las funcionalidades más recientes de `develop`.

Referencias revisadas:

- `develop` inicial: `1af9b60`.
- Rama de mejoras: `55622c1`.
- Ancestro común: `b85992c661fdb4096771b7a139428f65baeb6a13`.
- Respaldo del trabajo local original:
  `backup/develop-antes-mejoras-varias-20261007`.
- Divergencia inicial: 4 commits propios de `develop` y 10 de la rama de mejoras.

La rama local queda preparada para un push posterior del propietario.
Esta integración no ejecuta un push ni aplica cambios SQL a Supabase.

## Funcionalidades de la rama integrada

| Área | Comportamiento integrado | Conexión con el trabajo de develop |
| --- | --- | --- |
| Avisos | Animaciones, acciones como Deshacer/Reintentar y mensajes de éxito, información y error | Los puntos de llamada existentes usan los componentes compartidos; se mantienen los tokens visuales |
| Confirmaciones | Diálogo compartido para acciones destructivas y salir de actividades | Aplicado a rutas, publicaciones, cuenta, organizaciones y perfiles según cada operación |
| Carga y doble toque | Botones con spinner, bloqueo durante operaciones y componentes reutilizables | Se conserva el estado de cada pantalla y se evitan envíos repetidos mientras la petición está pendiente |
| Creación de rutas | Validación del nombre, duración de 1 a 30 días, selección de lugares y navegación entre pasos | Conserva servicios, datos de rutas y catálogo de develop; retroceder y cerrar confirman cuando corresponde |
| Reseñas | La hoja espera el resultado de publicación, muestra spinner y conserva el borrador para reintentar | Conserva las restricciones de cuenta, reglas de negocio y limpieza de medios existentes |
| Favoritos | Precarga al entrar, copia local por usuario, notificación de cambios y Deshacer al quitar | Inicio, mapa, detalle y perfil comparten el servicio; se mantiene el aislamiento entre cuentas |
| ECO | Confirmación para salir, avisos, reintento, validación de actividad vencida/inscripción/cupo y bloqueo de doble toque | Conserva Momentos, foro, geografía, categorías y campos nuevos de las actividades |
| Perfil | Controles accesibles de al menos 48 dp y acciones diferenciadas | Se conserva Editar perfil porque en develop tiene una función distinta de Configuración |
| Mapa | Se integran los avisos y favoritos compatibles | Se conserva Directions mediante la Edge Function `get-directions` y la configuración nativa de mapas |

### Commits examinados

| Commit | Contenido |
| --- | --- |
| `c77851a` | Primera entrega de avisos, wizard y mapa |
| `d3be42b` | Lectura de MAPS_API_KEY desde .env y aviso de clave ausente |
| `b26d699` | Navegación y validaciones del wizard |
| `4d19a1a` | Animaciones y acciones en avisos |
| `b007858` | Confirmaciones y protección de doble toque |
| `8bb86fe` | Envío de reseñas, spinner y reintento |
| `21d441a` | Precarga y copia local de favoritos por usuario |
| `fff36b2` | Favoritos y Deshacer al quitar |
| `4cda0f2` | Inscripción/salida ECO con confirmaciones, avisos y bloqueo |
| `55622c1` | Eliminación del lápiz duplicado del perfil antiguo |

Los commits con título WIP se evaluaron por el código final acumulado y las
pruebas, no por su título. Las dos modificaciones de mapa y perfil señaladas
arriba necesitaron adaptación porque `develop` ya había cambiado su arquitectura
y el significado de sus acciones.

## Resolución de los conflictos

| Archivo | Decisión |
| --- | --- |
| `lib/core/config/maps_config.dart` | Se mantiene eliminado; el archivo obsoleto y su prueba no se reintroducen |
| `lib/core/services/directions_service.dart` | Se conserva el servicio de develop que llama a Supabase |
| `lib/features/business/data/review_service.dart` | Se conservan permisos y limpieza; se integra el mensaje de reintento sin ocultar errores de negocio |
| `lib/features/eco/data/eco_service.dart` | Se combinan los modelos nuevos con las excepciones de participación; un rechazo del servidor por cupo tiene su mensaje específico |
| `lib/features/eco/presentation/screens/eco_detail_screen.dart` | Se conserva Momentos y FaceGuard; se combinan cupo lleno, carga y confirmaciones |
| `lib/features/eco/presentation/screens/eco_main_screen.dart` | Se conservan geografía y categorías; se integra el bloqueo individual de cada tarjeta y la actualización desde el servidor |
| `lib/features/home/presentation/screens/home_screen.dart` | Se conserva descubrimiento y se integra el aviso de favoritos |
| `lib/features/map/presentation/screens/map_screen.dart` | Se conserva el mapa actual, sus paneles y seguimiento; se elimina la comprobación obsoleta de .env |
| `lib/features/profile/presentation/screens/profile_screen.dart` | Se conservan pasaporte, perfil público y edición; se integra favoritos con reintento y Deshacer |
| `lib/main.dart` | Se conserva la inicialización actual, sin dotenv; se fija orientación vertical antes del arranque |
| `lib/shared/widgets/main_layout.dart` | Se conservan la procedencia del usuario y OriginCompletionGate; se agrega la precarga de favoritos |

También se corrigieron dos regresiones detectadas por las pruebas: desbordamiento
del título del perfil con cinco controles y falta de separación entre el panel
del mapa y su asistente.

## Últimos cambios locales y orientación

Se incorporan también los cambios ECO que aparecieron en el directorio durante
la integración: filtros Disponibles/Participando/Finalizadas, consulta de
actividades futuras y pasadas, imágenes laterales de 160 px, títulos del catálogo
sin el prefijo Demo y actualización del validador y sus pruebas. Las descripciones
conservan la identificación de demostración. El SQL de renombre queda versionado
como archivo; no se ejecutó contra la base de datos desde esta integración.

El bloqueo vertical solicitado se implementa en tres capas:

- Flutter: `DeviceOrientation.portraitUp` antes de inicializar la app.
- Android: `screenOrientation="portrait"` tanto en SplashActivity como en MainActivity.
- iOS: únicamente `UIInterfaceOrientationPortrait` para iPhone/iPad y pantalla completa en iPad.

No se agregaron dependencias. Las claves privadas y los archivos de configuración
local excluidos por Git permanecen fuera del commit.

## Validación

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub --reporter expanded`: 465 pruebas aprobadas.
- `python -m unittest discover -s scripts -p 'test_*.py'`: 9 pruebas aprobadas.
- Android debug: compilación, instalación y arranque satisfactorios en Samsung A56.
- La actividad instalada informa `requestedOrientation=SCREEN_ORIENTATION_PORTRAIT`.
- XML de Android y plist de iOS: lectura y comprobación de sus valores de orientación.
- Revisión visual en el teléfono de Inicio y pantallas abiertas durante la comprobación;
  sin desbordamientos visibles en las capturas revisadas.
- Pruebas de Directions: petición a la Edge Function, pasos/distancia, error del servidor
  y ausencia de ruta, con HTTP simulado.
- Pruebas ECO: cupo completo, carrera por el último cupo, duplicados, doble toque,
  confirmación, reintento y cambios de estado.
- Pruebas del wizard y ECO adaptadas para HTTP/geolocalización/Realtime simulados,
  sin depender de servicios remotos reales.
- El analizador excluye `build/**`, que contenía un proyecto temporal ajeno al código de la app.

Los logs y capturas de comprobación están en `build/`, excluido de Git.
La ejecución de pruebas conserva avisos de descarga de Google Fonts en el entorno
simulado; no provocaron fallos en la suite final.

### Límites prácticos

La copia de favoritos permite mostrar el último estado conocido sin conexión.
Las escrituras remotas requieren red: no se añadió una cola de cambios offline.
El listado del perfil puede mostrar el error de lectura con reintento aunque los
corazones conserven la copia local.

Las pruebas de escritura utilizan servicios simulados. No se hicieron inscripciones,
reseñas, eliminaciones ni cambios SQL reales como parte de la comprobación.
iOS no se compiló ni ejecutó desde Windows. La revisión visual no equivale a una
recertificación completa de todas las pantallas de la aplicación.

## Push posterior

Desde `C:\nikara_app`, con la rama `develop` activa:

```powershell
git status
git push origin develop
```

El merge conserva ambos historiales; el push no necesita `--force`.
Si alguien actualizó `develop` remoto después de esta revisión, Git puede exigir
incorporar esos commits antes de aceptar el push.
