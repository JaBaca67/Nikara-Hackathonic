<div align="center">
  <img src="assets/images/logo_nikara.svg" alt="Níkara" width="320" />

  <br />

  <em>Turismo sostenible, comercio local y jornadas ECO en Nicaragua</em>

  <br /><br />

  [![Flutter](https://img.shields.io/badge/Flutter-3.44.5-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-%5E3.12.2-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
  [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
  [![Google Maps](https://img.shields.io/badge/Google_Maps-API-4285F4?style=for-the-badge&logo=googlemaps&logoColor=white)](https://developers.google.com/maps)
  ![Status](https://img.shields.io/badge/Estado-En_desarrollo-6B4226?style=for-the-badge)
</div>

<br />

<div align="center">
  <sub>Conectando viajeros con negocios locales y jornadas de impacto ambiental — un turismo que le devuelve algo a Nicaragua.</sub>
</div>

<br />

<div align="center">

![](https://img.shields.io/badge/Índice-6B4226?style=flat-square)

**[Descripción general](#descripción-general)** · **[Perfiles de usuario](#perfiles-de-usuario)** · **[Tecnologías](#tecnologías-utilizadas)** · **[Arquitectura y BD](#arquitectura-y-base-de-datos)** · **[Instalación](#instalación-y-ejecución)** · **[Comandos](#comandos-útiles)**

</div>

<br />

![](https://img.shields.io/badge/Resumen-6B4226?style=flat-square)

## Descripción general

**Níkara** es una plataforma digital de turismo sostenible que conecta a viajeros con destinos turísticos conocidos y emergentes de Nicaragua mediante mapas interactivos, navegación GPS y experiencias comunitarias verificadas.

La plataforma permite descubrir lugares auténticos, apoyar pequeños emprendimientos locales y distribuir mejor el flujo turístico hacia zonas menos visitadas, contribuyendo al desarrollo económico de las comunidades y a la conservación del patrimonio natural y cultural.

- **Economía local** — visibilidad y herramientas de gestión para emprendedores turísticos y gastronómicos.
- **Cuidado ambiental** — jornadas ecológicas organizadas por fundaciones y usuarios, con impacto medible.
- **Turismo distribuido** — mapas y rutas que también llevan al viajero a destinos emergentes, no solo a los ya masificados.

> [!NOTE]
> La interfaz está íntegramente en español y el diseño se deriva 1:1 del archivo Figma **"UI-NÍKARA"** — es la fuente de verdad visual del proyecto.

<br />

![](https://img.shields.io/badge/Roles-F0B500?style=flat-square)

## Perfiles de usuario

El sistema define **4 roles**, gestionados sobre la tabla `profiles` de Supabase:

| Rol | Descripción |
|---|---|
| ![Turista](https://img.shields.io/badge/-Turista-F0B500?style=flat-square) | Descubrimiento de lugares y negocios, creación de itinerarios personalizados y exploración del mapa interactivo. |
| ![Emprendedor](https://img.shields.io/badge/-Emprendedor-F0B500?style=flat-square) | Registro y gestión de sus propios negocios turísticos y gastronómicos (perfil, ubicación, fotos, contacto). |
| ![Administrador](https://img.shields.io/badge/-Administrador-F0B500?style=flat-square) | Moderación de contenido, aprobación de comercios publicados por emprendedores y gestión general de la plataforma. |
| ![Auditor](https://img.shields.io/badge/-Auditor-F0B500?style=flat-square) | Supervisión de métricas de la plataforma y verificación del cumplimiento de impacto sostenible en las jornadas ECO. |

<br />

![](https://img.shields.io/badge/Stack-02569B?style=flat-square)

## Tecnologías utilizadas

| Categoría | Tecnología | Detalle |
|---|---|---|
| ![Frontend](https://img.shields.io/badge/-Frontend-02569B?style=flat-square&logo=flutter&logoColor=white) | Flutter (Dart) | Android e iOS |
| ![Backend](https://img.shields.io/badge/-Backend%20%26%20BD-3ECF8E?style=flat-square&logo=supabase&logoColor=white) | Supabase | PostgreSQL + Auth + Storage |
| ![Mapas](https://img.shields.io/badge/-Mapas-4285F4?style=flat-square&logo=googlemaps&logoColor=white) | Google Maps API | SDK para Flutter (`google_maps_flutter`) + Directions API para ruteo ("Cómo llegar") + `geolocator` |
| ![Auth](https://img.shields.io/badge/-Autenticación-DB4437?style=flat-square&logo=google&logoColor=white) | Supabase Auth | Correo/contraseña, Google Sign-In, Facebook |
| ![UI](https://img.shields.io/badge/-UI-6B4226?style=flat-square) | `google_fonts`, `font_awesome_flutter`, `flutter_svg` | Tipografía **League Spartan** (títulos) + **Nunito** (cuerpo) |
| ![Persistencia](https://img.shields.io/badge/-Persistencia%20local-6B4226?style=flat-square) | `shared_preferences` | Sesión de invitado, favoritos, extras de perfil |

### Sistema de diseño

Derivado 1:1 del archivo Figma **"UI-NÍKARA"** — 2 tipografías y 3 colores principales:

![League Spartan](https://img.shields.io/badge/Aa-League_Spartan-121212?style=flat-square) ![Nunito](https://img.shields.io/badge/Aa-Nunito-121212?style=flat-square)

![](https://img.shields.io/badge/%20-FDBE02?style=flat-square) `Gold #FDBE02` &nbsp;&nbsp; ![](https://img.shields.io/badge/%20-C2CA5B?style=flat-square) `Lima #C2CA5B` &nbsp;&nbsp; ![](https://img.shields.io/badge/%20-FF8243?style=flat-square) `Coral #FF8243`

<br />

![](https://img.shields.io/badge/Arquitectura-3ECF8E?style=flat-square)

## Arquitectura y base de datos

### Estructura de carpetas

El proyecto sigue una organización **feature-first**:

```
lib/
├── core/            # Compartido entre features: models, services, supabase, utils
├── features/        # auth · business · eco · home · map · profile · routes · settings
│   └── <feature>/
│       ├── data/           # Servicios (singleton) que hablan con Supabase
│       ├── domain/         # Modelos
│       └── presentation/   # Screens + widgets
├── shared/          # Widgets reutilizados entre features (main_layout, guest_guard, etc.)
└── theme/           # AppColors + AppTheme (tokens ligados a Figma)
```

### Modelo de datos

El backend vive completamente en Supabase (PostgreSQL). El diagrama resume las entidades principales y sus relaciones:

```mermaid
erDiagram
    PROFILES ||--o{ BUSINESSES : "owner_id"
    PROFILES ||--o{ ORGANIZATIONS : "owner_id"
    PROFILES ||--o{ ROUTES : "owner_id"
    PROFILES ||--o{ ECO_ACTIVITIES : "organizer_id"
    PROFILES ||--o{ ECO_PARTICIPANTS : "user_id"
    ORGANIZATIONS ||--o{ ECO_ACTIVITIES : "organization_id"
    ECO_ACTIVITIES ||--o{ ECO_PARTICIPANTS : "activity_id"
    ROUTES ||--o{ ROUTE_STOPS : "route_id"
    BUSINESSES ||--o{ ROUTE_STOPS : "business_id"
    ECO_ACTIVITIES ||--o{ ROUTE_STOPS : "eco_activity_id"
```

<br />

![](https://img.shields.io/badge/Setup-4285F4?style=flat-square)

## Instalación y ejecución

### Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `3.44.5` (Dart `^3.12.2`) — verificar con `flutter --version`
- [Git](https://git-scm.com/)
- Emulador Android/iOS configurado, o dispositivo físico conectado

### 1. Clonar el repositorio

```bash
git clone <url-del-repositorio>
cd nikara_app
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Configurar las claves de entorno

> [!IMPORTANT]
> La app necesita una clave de la API de Google (Directions) para el ruteo "Cómo llegar". Sin este paso, `flutter run` sigue funcionando con una key de respaldo embebida, pero **se recomienda configurar la propia** para desarrollo real.

```bash
cp dart_defines.json.example dart_defines.json
```

Editar `dart_defines.json`:

```json
{
  "GOOGLE_MAPS_API_KEY": "tu_clave_aqui"
}
```

> [!NOTE]
> La URL y `anon key` de Supabase ya están configuradas en `lib/core/supabase/supabase_config.dart` (son públicas por diseño; el proyecto usa RLS deshabilitada intencionalmente). Para apuntar a un proyecto Supabase propio, reemplazar esos valores ahí. Adicionalmente, para renderizar el mapa nativo, configurar la key del SDK de Maps en `android/local.properties` (Android) y `ios/Flutter/Maps.xcconfig` (iOS).

### 4. Ejecutar la aplicación

```bash
flutter run --dart-define-from-file=dart_defines.json
```

<br />

![](https://img.shields.io/badge/Comandos-261D0C?style=flat-square)

## Comandos útiles

| Comando | Descripción |
|---|---|
| `flutter analyze` | Linting estático |
| `dart format .` | Formateo de código |
| `flutter test` | Ejecutar la suite de pruebas |
| `flutter build apk` | Build de release |

<br />

---

<div align="center">
  <img src="assets/images/logo_nikara.svg" alt="Níkara" width="140" />

  <br />

  <sub><strong>Descubre Nicaragua · Apoya lo local · Cuida el planeta</strong></sub>
</div>
