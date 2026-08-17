<div align="center">

# 🌺 Níkara

### Turismo sostenible, comercio local y jornadas ECO en Nicaragua

[![Flutter](https://img.shields.io/badge/Flutter-3.44.5-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%5E3.12.2-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Google Maps](https://img.shields.io/badge/Google_Maps-API-4285F4?style=for-the-badge&logo=googlemaps&logoColor=white)](https://developers.google.com/maps)
[![Status](https://img.shields.io/badge/Estado-En_desarrollo-FFCC33?style=for-the-badge)](#)

> 🌴 *Conectando viajeros con negocios locales y jornadas de impacto ambiental — un turismo que le devuelve algo a Nicaragua.*

</div>

---

## 📑 Índice

- [🌎 Descripción general](#-descripción-general)
- [👥 Perfiles de usuario](#-perfiles-de-usuario)
- [🛠️ Tecnologías utilizadas](#-tecnologías-utilizadas)
- [🏗️ Arquitectura y base de datos](#-arquitectura-y-base-de-datos)
- [🚀 Instalación y ejecución](#-instalación-y-ejecución)
- [📦 Comandos útiles](#-comandos-útiles)

---

## 🌎 Descripción general

**Níkara** es una aplicación móvil desarrollada en **Flutter** (con soporte adicional para Web y Windows Desktop) que conecta a **turistas** con **negocios locales** — hospedaje, gastronomía, tours, artesanía — y con **jornadas ECO** de impacto ambiental (limpiezas de playas, reforestación, voluntariado).

El objetivo es promover un turismo responsable que:

- 🏘️ Fortalece la **economía local** dando visibilidad a emprendedores turísticos.
- 🌱 Impulsa el **cuidado ambiental** mediante jornadas ecológicas organizadas por fundaciones y usuarios.
- 🗺️ Facilita la **exploración** con mapas interactivos, rutas personalizadas e itinerarios por días.

> 💡 **Nota:** la interfaz está íntegramente en español y el diseño se deriva 1:1 del archivo Figma **"UI-NÍKARA"** — es la fuente de verdad visual del proyecto.

---

## 👥 Perfiles de usuario

El sistema define **4 roles**, gestionados sobre la tabla `profiles` de Supabase:

| Rol | Ícono | Descripción |
|---|:---:|---|
| **Turista** | 🧳 | Descubrimiento de lugares y negocios, creación de itinerarios personalizados y exploración del mapa interactivo. |
| **Emprendedor** | 🏪 | Registro y gestión de sus propios negocios turísticos y gastronómicos (perfil, ubicación, fotos, contacto). |
| **Administrador** | 🛡️ | Moderación de contenido, aprobación de comercios publicados por emprendedores y gestión general de la plataforma. |
| **Auditor** | 📊 | Supervisión de métricas de la plataforma y verificación del cumplimiento de impacto sostenible en las jornadas ECO. |

---

## 🛠️ Tecnologías utilizadas

| Categoría | Tecnología | Detalle |
|---|---|---|
| 📱 **Frontend** | Flutter (Dart) | Android e iOS — con soporte adicional para Web y Windows Desktop |
| ☁️ **Backend & BD** | Supabase | PostgreSQL + Auth + Storage |
| 🗺️ **Mapas & Geolocalización** | Google Maps API | SDK para Flutter (`google_maps_flutter`) + Directions API para ruteo ("Cómo llegar") + `geolocator` |
| 🔐 **Autenticación** | Supabase Auth | Correo/contraseña, Google Sign-In, Sign in with Apple |
| 🎨 **UI** | `google_fonts`, `font_awesome_flutter`, `flutter_svg` | Fuente personalizada **Leelawadee** |
| 💾 **Persistencia local** | `shared_preferences` | Sesión de invitado, favoritos, extras de perfil |

---

## 🏗️ Arquitectura y base de datos

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

### Esquema de base de datos (Supabase / PostgreSQL)

El backend vive completamente en Supabase. El esquema se construye ejecutando en orden los scripts SQL de `supabase/sql/` (`001_...` → `013_...`), que cubren: perfiles y roles, negocios con geolocalización (`PostGIS`), organizaciones, jornadas ECO y participantes, rutas/itinerarios por días, notificaciones, reseñas y favoritos.

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

> ⚠️ **Importante:** ninguna migración de `supabase/sql/` se aplica automáticamente — cada una debe ejecutarse **a mano y en orden** desde el SQL Editor del dashboard de Supabase. El detalle completo de cada tabla, incluyendo el diagrama DBML, está en [`docs/database_erd.md`](docs/database_erd.md).

---

## 🚀 Instalación y ejecución

### ✅ Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `3.44.5` (Dart `^3.12.2`) — verificar con `flutter --version`
- [Git](https://git-scm.com/)
- Emulador Android/iOS configurado, o dispositivo físico conectado (también corre en Chrome o Windows Desktop)

### 1️⃣ Clonar el repositorio

```bash
git clone <url-del-repositorio>
cd nikara_app
```

### 2️⃣ Instalar dependencias

```bash
flutter pub get
```

### 3️⃣ Configurar las claves de entorno

> ⚠️ **Importante:** la app necesita una clave de la API de Google (Directions) para el ruteo "Cómo llegar". Sin este paso, `flutter run` sigue funcionando con una key de respaldo embebida, pero **se recomienda configurar la propia** para desarrollo real.

```bash
cp dart_defines.json.example dart_defines.json
```

Editar `dart_defines.json`:

```json
{
  "GOOGLE_MAPS_API_KEY": "tu_clave_aqui"
}
```

> 💡 **Nota:** la URL y `anon key` de Supabase ya están configuradas en `lib/core/supabase/supabase_config.dart` (son públicas por diseño; el proyecto usa RLS deshabilitada intencionalmente). Para apuntar a un proyecto Supabase propio, reemplazar esos valores ahí. Adicionalmente, para renderizar el mapa nativo, configurar la key del SDK de Maps en `android/local.properties` (Android) y `ios/Flutter/Maps.xcconfig` (iOS).

### 4️⃣ Inicializar la base de datos

Ejecutar en orden, sobre el proyecto Supabase (SQL Editor del dashboard o CLI), todos los scripts de `supabase/sql/` desde `001_profiles_trigger_and_rls.sql` hasta `013_final_schema_additions.sql`.

### 5️⃣ Ejecutar la aplicación

```bash
flutter run --dart-define-from-file=dart_defines.json
```

<details>
<summary>🌐 Otros targets disponibles</summary>

```bash
flutter run -d chrome     # Web
flutter run -d windows    # Windows Desktop
```

</details>

---

## 📦 Comandos útiles

| Comando | Descripción |
|---|---|
| `flutter analyze` | 🔍 Linting estático |
| `dart format .` | 🧹 Formateo de código |
| `flutter test` | ✅ Ejecutar la suite de pruebas |
| `flutter build apk / web / windows` | 📦 Build de release |

---

<div align="center">

**🌺 Níkara — Descubre Nicaragua, apoya lo local, cuida el planeta 🌎🍃**

</div>
