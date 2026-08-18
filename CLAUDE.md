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
- **Colores**: siempre desde `AppColors` (`lib/theme/app_colors.dart`). Nunca `Color(0xFFFFFFFF)`/`Color(0xFF000000)` puros ni hex literales sueltos — el sistema de diseño usa deliberadamente blanco/negro "suavizados" (`surface100`, `neutral1100`).
- **Diseño**: la fuente de verdad es el archivo Figma "UI-NÍKARA"; los comentarios en `app_colors.dart`/`app_theme.dart` referencian nodos de Figma — mantén esa trazabilidad al agregar tokens nuevos.
- **Tests de widgets**: `AuthService` toca `Supabase.instance` de forma síncrona, así que **todo** widget test necesita en `setUpAll`: `SharedPreferences.setMockInitialValues({})` seguido de `Supabase.initialize(url: ..., publishableKey: 'test-anon-key-not-real')` con credenciales falsas — no hace falta un proyecto real. Repetir `setMockInitialValues({})` en `setUp` porque otros servicios leen `SharedPreferences` en cada test. Usar `tester.pump()` con duración explícita en vez de `pumpAndSettle()` en pantallas con `AuroraBackgroundWidget` (animación infinita que nunca deja que `pumpAndSettle` termine).
- **Auditoría de overflow**: `test/overflow_audit_test.dart` renderiza pantallas con datos deliberadamente peores que cualquier input real (nombres/descripciones larguísimas) para forzar `RenderFlex overflow`. Al agregar una pantalla nueva con texto dinámico de negocio, considera agregarla a ese archivo.

## Reglas estrictas — qué NO hacer

- **No** agregues archivos a `lib/widgets/` — es una carpeta legacy de un solo archivo (`aurora_background_widget.dart`). Los widgets cross-feature van en `lib/shared/widgets/`; los widgets específicos de una feature van en `lib/features/<feature>/presentation/widgets/`.
- **No** extiendas `lib/models/mock_data.dart` como fuente de datos real — es un remanente de antes de conectar Supabase (una sola referencia viva en todo `lib/`). Supabase es la fuente de verdad.
- **No** introduzcas un paquete de state management (Provider, Riverpod, Bloc, GetX) sin acordarlo antes explícitamente con el usuario — el patrón actual de servicios singleton es una decisión deliberada, no un descuido.
- **No** subas ni loguees la `service_role key` de Supabase en ningún archivo del cliente. La `anon key` en `supabase_config.dart` es intencional y pública (RLS está deshabilitada a propósito en este proyecto, según el comentario de esa clase); la `service_role key` nunca debe aparecer en `lib/`.
- **No** hagas `flutter build`/`flutter run` con `--release` sin que el usuario lo pida — son operaciones lentas, prefierir `flutter analyze` + `flutter test` para validar cambios.
- **No** agregues dependencias nuevas en `pubspec.yaml` sin verificar antes que no exista ya una forma de resolverlo con lo instalado (revisa `dependencies:` completo antes de proponer un paquete nuevo).
- **No** captures excepciones de Supabase de forma silenciosa (`catch (_) {}` sin mensaje) — siempre propaga o traduce el error, nunca lo tragues.
