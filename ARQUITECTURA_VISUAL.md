# ARQUITECTURA VISUAL & FLUJOS DE USUARIO

## 1. DIAGRAMA DE ARQUITECTURA GENERAL

```
┌─────────────────────────────────────────────────────────────────────┐
│                     NÍKARA MOBILE APP (Flutter)                     │
└─────────────────────────────────────────────────────────────────────┘

                              ┌──────────────┐
                              │   UI Layer   │
                              │  (Flutter)   │
                              └──────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
              ┌─────▼────────┐  ┌────▼──────┐   ┌────▼──────────┐
              │ Auth Screens │  │ Map Screen│   │Profile Screen │
              ├──────────────┤  ├───────────┤   ├───────────────┤
              │- Login       │  │- Markers  │   │- Mis Negocios │
              │- Register    │  │- Search   │   │- Favoritos    │
              │- Guest Mode  │  │- Filters  │   │- Settings     │
              └──────┬────────┘  └─────┬─────┘   └────┬──────────┘
                     │                │              │
                     └────────────────┼──────────────┘
                                      │
                        ┌─────────────▼──────────────┐
                        │   Services Layer (Singleton)
                        │  (lib/core/services/)       │
                        └──────────────────────────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         │                            │                            │
    ┌────▼──────────┐  ┌─────────────▼──┐  ┌──────────────────┐
    │ AuthService   │  │BusinessStorage │  │FavoritesService  │
    ├───────────────┤  │Service          │  ├──────────────────┤
    │- signUp()     │  ├─────────────────┤  │- toggleFavorite()│
    │- signIn()     │  │- getBusinesses()│  │- idsNotifier     │
    │- signOut()    │  │- addBusiness()  │  │- local storage   │
    │- currentUser  │  │- updateBusiness│  │  (SharedPrefs)   │
    │- roles        │  │- deleteBusinessi│  │                  │
    │- stream       │  │- local extras   │  │                  │
    └────┬──────────┘  └────┬────────────┘  └──────┬───────────┘
         │                  │                      │
         │        ┌─────────┴──────┐               │
         │        │                │               │
         │   ┌────▼─────────┐  ┌───▼────────────┐  │
         │   │LocationService   │GuestSession   │  │
         │   ├────────────────┤├───────────────┤  │
         │   │- getPosition() ││- isGuest      │  │
         │   │- distanceKm()  ││- enterGuest() │  │
         │   │- cached pos    ││- exitGuest()  │  │
         │   └────────────────┘└───────────────┘  │
         │                                         │
         └─────────────────────┬───────────────────┘
                               │
              ┌────────────────▼──────────────┐
              │   Storage Layer              │
              ├──────────────────────────────┤
              │ ┌──────────────────────────┐ │
              │ │ SharedPreferences (Local)│ │
              │ │- favorites_ids           │ │
              │ │- guest_mode              │ │
              │ │- profile_extras          │ │
              │ │- business_local_extras   │ │
              │ └──────────────────────────┘ │
              └──────────────────────────────┘
                               │
              ┌────────────────▼──────────────────┐
              │   Backend (Supabase)             │
              ├──────────────────────────────────┤
              │ PostgreSQL + PostGIS + Auth      │
              │                                  │
              │  ┌──────────────────────────┐   │
              │  │ auth.users (Supabase)    │   │
              │  │- id (UUID)               │   │
              │  │- email / password        │   │
              │  │- session management      │   │
              │  └──────────────────────────┘   │
              │                                  │
              │  ┌──────────────────────────┐   │
              │  │ profiles (PostgreSQL)    │   │
              │  │- id, full_name, email    │   │
              │  │- role, phone, avatar_url │   │
              │  │- points, timestamps      │   │
              │  └──────────────────────────┘   │
              │                                  │
              │  ┌──────────────────────────┐   │
              │  │ businesses               │   │
              │  │- id, name, category      │   │
              │  │- description, city       │   │
              │  │- location (PostGIS)      │   │
              │  │- owner_id, phone, photos │   │
              │  │- is_verified             │   │
              │  └──────────────────────────┘   │
              │                                  │
              │  ┌──────────────────────────┐   │
              │  │ reviews (PENDIENTE)      │   │
              │  │- id, business_id, rating │   │
              │  │- comment, author_id      │   │
              │  └──────────────────────────┘   │
              │                                  │
              │  ┌──────────────────────────┐   │
              │  │ bookings (PENDIENTE)     │   │
              │  │- id, business_id, user_id   │
              │  │- date, status, guests    │   │
              │  └──────────────────────────┘   │
              └──────────────────────────────────┘
                               │
                    ┌──────────▼───────────┐
                    │  External Services  │
                    ├─────────────────────┤
                    │- Google Maps (URLs) │
                    │- CartoDB (Tiles)    │
                    │- Android/iOS APIs   │
                    │  (geolocation,      │
                    │   image picker)     │
                    └─────────────────────┘
```

---

## 2. FLUJOS DE USUARIO PRINCIPALES

### Flujo 1: Guest → Browse Map → Favorite → Login

```
┌─────────────┐
│   START     │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│  LOGIN SCREEN       │
│ ✓ Email + Password  │
│ ✓ Social Auth       │
│ ✓ "Explorar sin     │
│   crear cuenta"     │
└──────┬──────────────┘
       │
       ├─────────────┬───────────────┐
       │             │               │
   [Email]     [Guest Mode]      [Social]
       │             │               │
       │      GuestSessionService    │
       │      .enterGuestMode()      │
       │             │               │
       ▼             ▼               ▼
┌──────────────────────────────────────┐
│         MAIN LAYOUT                  │
│  ├─ HOME SCREEN                      │
│  ├─ MAP SCREEN   ◄── AQUÍ ESTÁ      │
│  ├─ PROFILE SCREEN                   │
│  └─ SETTINGS                         │
└──────────────────────────────────────┘
       │
       │ [GUEST] Ver negocio + corazón (favorito)
       │
       ▼
┌──────────────────────────────────────┐
│  GUEST GUARD BOTTOM SHEET            │
│  "Crea una cuenta para guardar       │
│   tus favoritos"                     │
│                                      │
│  ┌─────────────┐  ┌──────────────┐  │
│  │ Crear cuenta│  │   Cancelar   │  │
│  └─────────────┘  └──────────────┘  │
└──────┬──────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  REGISTER SCREEN (4 pasos)           │
│  Paso 1: Email + Contraseña          │
│  Paso 2: Perfil (nombre, teléfono)   │
│  Paso 3: OTP (Saltar por ahora)      │
│  Paso 4: Preferencias                │
│                                      │
│  ✓ AuthService.signUp()              │
│  ✓ AuthService.markAsEmprendedor()   │
│  ✓ GuestSessionService.exitGuest()   │
└──────┬──────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  MAIN LAYOUT (LOGUEADO)              │
│  ✓ Favoritos sincronizados           │
│  ✓ Role = turista (o emprendedor)    │
│  ✓ Perfil con datos reales           │
└──────────────────────────────────────┘
       │
       ▼
┌─────────────┐
│   SUCCESS   │
└─────────────┘
```

---

### Flujo 2: Emprendedor → Registra Negocio → Aparece en Mapa

```
┌──────────────────────────────────────┐
│  PROFILE SCREEN (LOGUEADO)           │
│  Role = turista o emprendedor        │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ + Registra tu Negocio          │  │
│  └────────────────────────────────┘  │
└──────┬──────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  REGISTER BUSINESS WIZARD            │
│  (lib/features/business/...)         │
└──────┬──────────────────────────────┘
       │
       ├─ Paso 1: Info Básica
       │  ├─ Nombre
       │  ├─ Categoría (Eco, Tours, etc)
       │  └─ Descripción
       │
       ├─ Paso 2: Ubicación (MAPA PICKER)
       │  ├─ Seleccionar en mapa
       │  ├─ Dirección exacta
       │  └─ Geocodificación reversa
       │     (geocoding package)
       │
       ├─ Paso 3: Contacto & Redes
       │  ├─ Teléfono
       │  ├─ Instagram
       │  ├─ Facebook
       │  └─ TikTok
       │
       ├─ Paso 4: Detalles & Fotos
       │  ├─ Amenities (checkboxes)
       │  ├─ Activities
       │  ├─ Precios
       │  ├─ Reservaciones?
       │  ├─ Sello ECO?
       │  └─ Fotos (image_picker)
       │
       └─ Paso 5: Confirmación & Guardar
          ├─ BusinessStorageService
          │  .addBusiness()
          │ 
          ├─ INSERT → businesses table
          │  {
          │    id, owner_id, name, category,
          │    description, city, address_text,
          │    location (PostGIS), phone,
          │    instagram_handle, photos
          │  }
          │
          └─ AuthService.markAsEmprendedor()
             UPDATE profiles SET role='emprendedor'
       │
       ▼
┌──────────────────────────────────────┐
│  BUSINESS SUCCESS SCREEN             │
│  ✓ "Negocio registrado exitosamente" │
│  ✓ Ver en mapa                       │
│                                      │
│  Notificador: BusinessStorageService │
│               .revision++             │
└──────┬──────────────────────────────┘
       │
       ▼ (30ms después)
┌──────────────────────────────────────┐
│  MAP SCREEN (EN TIEMPO REAL)         │
│  ✓ NUEVO MARKER aparece              │
│  ✓ Categoría visible                 │
│  ✓ Rating (si hay reviews)           │
│                                      │
│  MapScreen escucha:                  │
│  - BusinessStorageService.revision   │
│  - Recarga negocio al cambiar        │
└──────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  PROFILE → MIS NEGOCIOS              │
│  ✓ Negocio aparece en lista          │
│  ✓ Puede editar/eliminar             │
│  ✓ Stats: views, reviews, rating     │
└──────────────────────────────────────┘
       │
       ▼
┌─────────────┐
│   SUCCESS   │
└─────────────┘
```

---

### Flujo 3: Usuario Visita Negocio → Lee Reviews → Booking (Futuro)

```
┌──────────────────────────────────────┐
│  MAP SCREEN                          │
│  [TAP en marker]                     │
└──────┬──────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  BUSINESS PREVIEW SHEET              │
│  (Bottom sheet, animado)             │
│                                      │
│  ├─ Foto                             │
│  ├─ Nombre + Favorito ❤️             │
│  ├─ Distancia (a X km)               │
│  ├─ Tags: Eco, Rating, Actividad     │
│  ├─ [Cómo llegar] [Ver perfil]      │
│  └─ (No price, no reserva en sheet)  │
└──────┬──────────────────────────────┘
       │
       ├─ [Cómo llegar]
       │  └─ url_launcher("https://maps.google.com/...")
       │
       └─ [Ver perfil]
          └─ Navigate → BusinessDetailScreen
                  │
                  ▼
          ┌──────────────────────────┐
          │ BUSINESS DETAIL SCREEN   │
          ├──────────────────────────┤
          │- Galería de fotos        │
          │- Descripción larga       │
          │- Amenities / Activities  │
          │- Precio (si aplica)      │
          │- Reviews (READ-ONLY)     │
          │  ├─ Rating 4.8 ★         │
          │  ├─ "Excelente lugar"    │
          │  └─ por: Usuario X       │
          │- [Hacer reserva]         │
          │  (PENDIENTE)             │
          │- [Dejar review]          │
          │  (PENDIENTE)             │
          │- Contacto (teléfono)     │
          │- Social links            │
          └──────────────────────────┘
```

---

## 3. DIAGRAMA DE DATA FLOW

```
                    ┌──────────────────┐
                    │  USER INTERACTION│
                    │  (Button tap,    │
                    │   form input)    │
                    └─────────┬────────┘
                              │
                    ┌─────────▼────────┐
                    │  SERVICE CALL    │
                    │  (AuthService.   │
                    │   signUp(),      │
                    │   BusinessStorage│
                    │   .addBusiness())│
                    └─────────┬────────┘
                              │
                    ┌─────────▼────────┐
                    │  VALIDATION      │
                    │  (Email regex,   │
                    │   password       │
                    │   strength,      │
                    │   location)      │
                    └─────────┬────────┘
                              │
                    ┌─────────▼────────┐
                    │  SUPABASE RPC    │
                    │  (HTTP Request)  │
                    │  - auth.signUp() │
                    │  - profiles.      │
                    │    insert()       │
                    │  - businesses.    │
                    │    insert()       │
                    └─────────┬────────┘
                              │
                    ┌─────────▼────────┐
                    │  DATABASE        │
                    │  (PostgreSQL +   │
                    │   PostGIS)       │
                    │  WRITE: rows     │
                    └─────────┬────────┘
                              │
                    ┌─────────▼────────┐
                    │  LOCAL SYNC      │
                    │  (SharedPrefs)   │
                    │  WRITE: extras,  │
                    │         favorites│
                    └─────────┬────────┘
                              │
                    ┌─────────▼────────┐
                    │  NOTIFIER UPDATE │
                    │  - AuthService.  │
                    │    authState     │
                    │  - BusinessStorage│
                    │    .revision++   │
                    └─────────┬────────┘
                              │
                    ┌─────────▼────────┐
                    │  REBUILD UI      │
                    │  (Listeners en   │
                    │   ValueNotifier, │
                    │   StreamBuilder) │
                    └─────────┬────────┘
                              │
                    ┌─────────▼────────┐
                    │  USER SEES DATA  │
                    │  (New business   │
                    │   in map,        │
                    │   profile update)│
                    └──────────────────┘
```

---

## 4. DECISIÓN ARQUITECTÓNICA: SERVICIOS SINGLETON

```
Patrón actual (CORRECTO, no cambiar):

class XService {
  factory XService() => instance;
  
  XService._internal();
  
  static final XService instance = XService._internal();
}

VENTAJAS:
✅ Único punto de verdad (instance)
✅ Eficiente en memoria (lazy)
✅ Sincrónico (sin async init)
✅ Simple, sin boilerplate

USADO EN:
- AuthService → authStateChanges stream
- BusinessStorageService → revision notifier
- FavoritesService → idsNotifier
- LocationService → cached position
- GuestSessionService → isGuest flag

NO HACER (hasta confirmación):
❌ Provider / Riverpod
❌ Bloc / Cubit
❌ GetX
❌ Any state management library

RAZÓN: Esta arquitectura es deliberada (ver CLAUDE.md),
       no una falta de madurez. Introduce PM si tienes
       un caso de uso que singletons NO pueden resolver.
```

---

## 5. MATRIZ DE SINCRONIZACIÓN: DÓNDE VIVEN LOS DATOS

```
┌─────────────────────────────────────────────────────────────────────┐
│ CAMPO               │ Supabase │ SharedPrefs │ Memory (Service)    │
├─────────────────────────────────────────────────────────────────────┤
│ auth.users (email)  │ ✅       │ ❌          │ ✅ (AuthService)    │
│ profiles (full_name)│ ✅       │ ❌          │ ✅ (cached)         │
│ profiles (role)     │ ✅       │ ❌          │ ✅ (currentUser)    │
│                     │          │             │                     │
│ businesses (core)   │ ✅       │ ❌          │ ❌ (leído on-demand)│
│ business (local)    │ ❌       │ ✅ JSON     │ ❌ (merged on load) │
│   - amenities       │ ❌       │ ✅          │ ⚠️  local_extras    │
│   - activities      │ ❌       │ ✅          │ ⚠️  local_extras    │
│   - reviews         │ ❌       │ ✅          │ ⚠️  local_extras    │
│   - schedules       │ ❌       │ ✅          │ ⚠️  local_extras    │
│                     │          │             │                     │
│ favorites (ids)     │ ❌       │ ✅ [string] │ ✅ idsNotifier      │
│ guest_mode (flag)   │ ❌       │ ✅ bool     │ ✅ isGuest          │
│ preferences (cats)  │ ❌       │ ✅ JSON     │ ❌ (leído once)     │
└─────────────────────────────────────────────────────────────────────┘

REGLA GENERAL:
- "Backend source of truth" → Supabase (auth, profiles, businesses)
- "Device source of truth" → SharedPreferences (favorites, extras, prefs)
- "Session cache" → Service memory (currentUser, revision notifier)

POST-HACKATHON: Migrar todos los "❌" de Supabase a tablas reales
                (reviews, bookings, local_extras como columnas JSON)
```

---

## 6. STACK TÉCNICO RESUMIDO

```
FRONTEND
├─ Framework: Flutter 3.44.5
├─ Language: Dart ^3.12.2
├─ UI Tokens: AppColors, AppTheme (Figma-linked)
├─ State: Servicios Singleton + ValueNotifier
├─ Navigation: Material Navigator
└─ Localization: Español (strings inline)

BACKEND
├─ Database: PostgreSQL (via Supabase)
├─ Auth: Supabase Auth (email/password, OAuth ready)
├─ Spatial: PostGIS (geography/Point)
├─ API: PostgREST (auto-generated REST)
└─ RLS: DESHABILITADO (por diseño, CLAUDE.md)

DEPENDENCIES CRÍTICAS
├─ supabase_flutter 2.8.0
├─ flutter_map 8.3.1
├─ latlong2 0.10.1
├─ geolocator 14.0.3
├─ shared_preferences 2.5.5
├─ image_picker 1.2.3
├─ url_launcher 6.3.2
├─ google_fonts 8.1.0
└─ flutter_svg 2.2.1

TOOLS
├─ IDE: VS Code / Android Studio
├─ CI/CD: GitHub Actions (WIP)
├─ Analytics: (futuro)
└─ Crash Reporting: (futuro)
```

---

## 7. CHECKLIST VISUAL: QUÉ VER EN CADA PANTALLA

### Login Screen ✅
```
[ ] Email campo con validación regex
[ ] Contraseña con toggle show/hide
[ ] Mensaje de fuerza de contraseña
[ ] Botón "Siguiente" (disabled si form inválido)
[ ] Link "Crear cuenta"
[ ] Botón "Explorar como invitado" prominente
[ ] Aurora gradient background
```

### Register Screen (Paso 1) ✅
```
[ ] Email + Password + Confirm
[ ] Indicador de paso (1/4)
[ ] Validaciones en vivo
[ ] Botón "Siguiente"
[ ] Link "Ya tengo cuenta"
```

### Register Screen (Paso 2) ✅
```
[ ] Avatar picker (image_picker)
[ ] Nombre completo
[ ] Usuario (opcional)
[ ] Teléfono con formato
[ ] Botones "Atrás" / "Siguiente"
```

### Register Screen (Paso 3)
```
[ ] 6 cajas OTP (uno por dígito)
[ ] Botón "Verificar código"
[ ] Link "Saltar por ahora" (implementado)
[ ] Timer de re-enviar (opcional)
```

### Register Screen (Paso 4) ✅
```
[ ] Categorías de interés (checkboxes)
[ ] Botones "Atrás" / "Terminar"
[ ] Navegación a MainLayout al terminar
```

### Map Screen ✅
```
[ ] Mapa full-screen (CartoDB tiles)
[ ] Barra de búsqueda flotante (top-left)
[ ] Botón filtros (top-right)
[ ] Chips de categorías (scroll horizontal)
[ ] Markers de negocios
[ ] Botón "Mi ubicación" (bottom-right)
[ ] Preview sheet al tap marker
```

### Business Detail Screen
```
[ ] Galería de fotos (swiper)
[ ] Nombre + Favorito ❤️
[ ] Rating y número de reviews
[ ] Descripción
[ ] Amenities (íconos)
[ ] Activities (tags)
[ ] Precios
[ ] Horario
[ ] Contacto + teléfono
[ ] Social links
[ ] Botón "Reservar" (futuro)
[ ] Botón "Dejar review" (futuro)
```

### Profile Screen ✅
```
[ ] Avatar del usuario
[ ] Nombre + Role badge
[ ] Pestaña "Favoritos"
[ ] Pestaña "Mis Negocios" (si emprendedor)
[ ] Botón "Registra tu negocio" (si turista)
[ ] Botón "Ajustes"
[ ] Botón "Cerrar sesión"
```

### Register Business Wizard
```
[ ] Paso 1: Nombre, categoría, descripción
[ ] Paso 2: MAP PICKER (ubicación exacta)
[ ] Paso 3: Teléfono, redes sociales
[ ] Paso 4: Amenities, activities, precios, sello eco
[ ] Paso 5: Fotos (multi-select)
[ ] Confirmación final
[ ] Guardar → aparece en mapa
```

---

## 8. DEPLOYMENT CHECKLIST

```
PRE-HACKATHON PRESENTATION:
[ ] App debe correr en: Android, iOS, Web
[ ] No crashes al flow: Guest → Login → Register → Business
[ ] Todos los negocios de Supabase visibles en mapa
[ ] Favoritos se sincronizan
[ ] Mensajes de error en Spanish
[ ] Performance: <2s para abrir mapa

BUILD ARTIFACTS:
[ ] APK de release (Android)
[ ] Build web (Firebase Hosting, etc)
[ ] Instrucciones de instalación

DEMO SCRIPT:
1. Abrir app → "Explorar como invitado"
2. Ir al mapa → mostrar negocios en tiempo real
3. Tap negocio → preview sheet + distancia
4. [Cómo llegar] → abre Google Maps
5. Crear cuenta → 4-step wizard
6. Registrar negocio → rellena wizard
7. Volver al mapa → nuevo negocio apareció ✅
8. Profile → "Mis Negocios" → editar/eliminar
```

