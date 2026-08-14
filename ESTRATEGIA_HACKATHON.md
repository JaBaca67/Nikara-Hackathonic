# PROPUESTA TÉCNICA ESTRATÉGICA — NÍKARA HACKATHON

## RESUMEN EJECUTIVO

El proyecto Níkara está en **estado muy sólido** para el hackathon. La arquitectura es limpia, la autenticación está implementada correctamente con Supabase, y los mapas funcionan con OpenStreetMap (CartoDB).

**Entregables prioritarios para el MVP:**
1. ✅ **Mapas**: Ya funciona con flutter_map + CartoDB (OpenStreetMap)
2. ⚠️ **Autenticación**: 85% completa — necesita pulido y flujo de Guest Mode optimizado
3. ⚠️ **Base de datos**: Estructura básica en lugar — necesita schema completo y relaciones FK

**Decisión estratégica**: Para el hackathon, usar **solo la app móvil** + formulario Google Forms externo para onboarding de emprendedores. Evitar dashboard web por ahora.

---

## 1. ANÁLISIS: API DE MAPAS (RECOMENDACIÓN FINAL)

### Estado actual:
```dart
// lib/features/map/presentation/screens/map_screen.dart
TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
  subdomains: const ['a', 'b', 'c', 'd'],
  userAgentPackageName: 'com.example.nikara_app',
  minZoom: 6,
  maxZoom: 19,
),
```

**Librerías instaladas:**
- `flutter_map` 8.3.1 ✅
- `latlong2` 0.10.1 ✅
- `geolocator` 14.0.3 ✅

### Comparativa: OpenStreetMap (CartoDB) vs Google Maps API

| Criterio | OpenStreetMap (CartoDB) | Google Maps API |
|----------|----------------------|-----------------|
| **Costo** | ❌ Gratis | ⚠️ ~$7/1000 requests (Mobile) |
| **Implementación** | ✅ 5 min (ya hecho) | ⚠️ 2-3 horas (API key, auth) |
| **Performance** | ✅ Excelente en Flutter | ✅ Excelente |
| **Customización visual** | ✅ 10+ temas disponibles | ⚠️ Limitada a estilos predefinidos |
| **Localización Nicaragua** | ✅ Tiles disponibles | ✅ Disponibles |
| **Routing/Directions** | ❌ Usa Google Maps URL (actual) | ✅ Integrado |
| **Hackathon ready** | ✅ YA FUNCIONA | ❌ Requiere setup |

### **RECOMENDACIÓN: Mantener OpenStreetMap (CartoDB)**

**Justificación:**
- Ya está implementado y testeado
- Cero costos (crítico para prototipo)
- Tiles CartoDB Voyager son visualmente limpios
- Para "Cómo llegar", seguimos usando Google Maps URL (ya funciona via `url_launcher`)
- Geolocator está integrado para "Mi ubicación" ✅

**Pasos para 100% de integración:**
1. ✅ MapScreen: ya muestra negocios en tiempo real desde Supabase
2. ✅ Markers personalizados: pins con círculos de oro/crema
3. ✅ Geolocalización: botón "Mi ubicación" funciona
4. ✅ Búsqueda + filtros: funcionan en vivo
5. ⚠️ **PENDIENTE**: Geocodificación inversa (dirección → coords) para registro de negocios
   - Usar `geocoding` package (Flutter) o PostGIS directo en Supabase

**Acción inmediata:**
```bash
flutter pub add geocoding
```
Luego implementar en `RegisterBusinessWizard` el paso de ubicación.

---

## 2. PLAN DE IMPLEMENTACIÓN: FLUJO DE AUTENTICACIÓN

### Estado actual (85% completo):

**Componentes que ya funcionan:**
- ✅ `AuthService`: completo con Supabase Auth
- ✅ `LoginScreen`: formulario + social auth (UI, sin backend)
- ✅ `RegisterScreen`: 4-step wizard
  - Paso 1: Email + contraseña
  - Paso 2: Perfil (nombre, teléfono, foto)
  - Paso 3: OTP (stub, sin SMS provider)
  - Paso 4: Preferencias de interés (local)
- ✅ `GuestSessionService`: modo invitado completo
- ✅ Diferenciación de roles: turista → emprendedor (al registrar negocio)

**Gaps identificados:**

### Gap 1: Flujo de Guest → Autenticado incompleto
**Problema:** Un usuario invitado que decide registrarse debe poder preservar favoritos.
**Solución (1 hora):**
```dart
// lib/core/services/auth_service.dart
Future<AuthResult> signUp({...}) async {
  // ... código actual ...
  
  // Al finalizar, migrar favoritos locales
  final favoritesBefore = await FavoritesService().getFavoriteIds();
  // Los favoritos ya están sincronizados via SharedPreferences,
  // así que no hace falta hacer nada especial.
}
```

### Gap 2: Verificación OTP (stub actual)
**Problema:** Paso 3 dice "Verificar código" pero no tiene SMS provider.
**Decisión para hackathon:** Mantener como stub + botón "Saltar por ahora" (ya implementado).
**Para post-hackathon:** Integrar Twilio/AWS SNS.

### Gap 3: Social auth (UI sin backend)
**Problema:** `SocialAuthRow` existe pero no llama a Supabase.
**Decisión para hackathon:** Desactivar temporalmente o mostrar "Próximamente".
**Esfuerzo:** 2-3 horas si se activa (Supabase OAuth config).

### Arquitectura final recomendada:

```
Auth Flow Diagram
================

LoginScreen
  ├─ Email + Contraseña (signIn)
  ├─ Social Auth (desactivado/próximamente)
  └─ "Explorar como invitado" → GuestSessionService.enterGuestMode()

RegisterScreen (4 pasos)
  ├─ Paso 1: Email + Contraseña + Fuerza en vivo
  ├─ Paso 2: Perfil (nombre, teléfono, avatar)
  │   └─ [AQUÍ] signUp() → AuthService
  │   └─ Crea auth.users + profiles row
  ├─ Paso 3: OTP (stub, "Saltar por ahora")
  └─ Paso 4: Preferencias (local, no Supabase)

MainLayout (protegida)
  ├─ authStateChanges stream → redirige si logout
  ├─ Diferencia roles:
  │  ├─ turista: acceso a Home/Map/Profile/Favoritos
  │  ├─ emprendedor: + acceso a "Mis Negocios" (edit, delete)
  │  ├─ admin: + acceso a auditoría (tarea futura)
  │  └─ auditor: solo lectura con badge

Guest Guest Mode
  └─ Puede ver Home/Map
  └─ Intentar favorito → GuestGuardBottomSheet → "Crea cuenta"
```

**Tareas pendientes (3 días de trabajo):**
1. Confirmar email verification en Supabase (opcional para hackathon)
2. Testear flujo completo: Guest → Register → SignIn
3. Validar que favoritos se sincronizan post-login
4. Pulir mensajes de error (ya en español ✅)

---

## 3. ESTRUCTURA DE BASE DE DATOS (DIAGRAMA E-R)

### Tablas actuales (confirmadas en código):

```mermaid
erDiagram
    PROFILES ||--o{ BUSINESSES : owns
    PROFILES ||--o{ REVIEWS : writes
    BUSINESSES ||--o{ REVIEWS : receives
    BUSINESSES ||--o{ BOOKINGS : has
    PROFILES ||--o{ BOOKINGS : makes

    PROFILES {
        uuid id PK "auth.users.id"
        string full_name
        string email
        string phone
        user_role role "enum: turista|emprendedor|admin|auditor"
        int points "0 inicialmente"
        timestamp created_at
    }

    BUSINESSES {
        uuid id PK "client-generated"
        uuid owner_id FK "profiles.id"
        string name
        string category
        text description
        string city
        string address_text
        geography location "PostGIS Point(4326)"
        string phone
        string instagram_handle
        string[] photos "JSON array de paths"
        boolean is_verified "admin-only"
        timestamp created_at
    }

    REVIEWS {
        uuid id PK
        uuid business_id FK "businesses.id"
        uuid author_id FK "profiles.id"
        decimal rating "1-5"
        text comment
        timestamp created_at
    }

    BOOKINGS {
        uuid id PK
        uuid business_id FK "businesses.id"
        uuid user_id FK "profiles.id"
        date booking_date
        int guests
        text special_requests
        string status "pending|confirmed|cancelled"
        timestamp created_at
    }

    LOCAL_EXTRAS {
        string business_id "no table, SharedPreferences JSON"
        boolean allows_reservations
        decimal price
        string[] amenities
        string[] activities
        boolean eco_seal_requested
        string[] eco_practices
        text schedules
        text access_details
        text other_notes
    }

    FAVORITES {
        set{string} ids "no table, SharedPreferences Set<String>"
    }

    PREFERENCES {
        string[] interest_categories "local, no Supabase"
    }
```

### Análisis del schema actual:

**Lo que funciona bien:**
- ✅ `profiles` con auth linkage (id = auth.users.id)
- ✅ `businesses` con PostGIS location
- ✅ Roles diferenciados para control de acceso
- ✅ Timestamps para auditoría

**Gaps y deuda técnica:**
- ❌ **Reviews**: Cero tabla en Supabase (solo local, no sincroniza)
- ❌ **Bookings**: Tabla creada pero no completamente wired en UI
- ❌ **Foto de perfil**: No hay `avatar_url` en `profiles`
- ❌ **Validación de email**: No hay columna `email_verified`
- ❌ **Soft delete**: No hay `deleted_at` para auditoría suave
- ⚠️ **Local extras**: Campos en SharedPreferences, no Supabase

### SQL para crear tablas (si no existen):

```sql
-- RLS está deshabilitado a propósito en este proyecto (ver CLAUDE.md)

CREATE TYPE user_role AS ENUM ('turista', 'emprendedor', 'admin', 'auditor');

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT DEFAULT '',
  role user_role DEFAULT 'turista',
  avatar_url TEXT,
  points INT DEFAULT 0,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  city TEXT NOT NULL,
  address_text TEXT NOT NULL,
  location GEOGRAPHY(Point, 4326) NOT NULL,
  phone TEXT NOT NULL,
  instagram_handle TEXT DEFAULT '',
  photos TEXT[] DEFAULT ARRAY[]::TEXT[],
  is_verified BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  rating DECIMAL(3,2) NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  booking_date DATE NOT NULL,
  guests INT NOT NULL DEFAULT 1,
  special_requests TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX idx_businesses_owner_id ON businesses(owner_id);
CREATE INDEX idx_businesses_location ON businesses USING GIST(location);
CREATE INDEX idx_reviews_business_id ON reviews(business_id);
CREATE INDEX idx_reviews_author_id ON reviews(author_id);
CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_business_id ON bookings(business_id);
```

**Diagrama SQL (versión texto limpia):**

```
PROFILES
  ├─ id (UUID, PK, FK auth.users)
  ├─ full_name, email, phone
  ├─ role (enum: turista|emprendedor|admin|auditor)
  ├─ avatar_url, points
  └─ created_at, updated_at

BUSINESSES
  ├─ id (UUID, PK)
  ├─ owner_id (FK → profiles.id)
  ├─ name, category, description
  ├─ city, address_text
  ├─ location (PostGIS Point)
  ├─ phone, instagram_handle, photos[]
  ├─ is_verified
  └─ timestamps + soft delete

REVIEWS
  ├─ id (UUID, PK)
  ├─ business_id (FK)
  ├─ author_id (FK)
  ├─ rating (1-5), comment
  └─ created_at

BOOKINGS
  ├─ id (UUID, PK)
  ├─ business_id, user_id (FK)
  ├─ booking_date, guests
  ├─ special_requests
  ├─ status (pending|confirmed|cancelled)
  └─ timestamps
```

---

## 4. DECISIÓN ESTRATÉGICA: SITIO WEB vs FORMULARIO GOOGLE FORMS

### Contexto:
El equipo debe decidir cómo los emprendedores se registran y crean sus perfiles de negocio.

**Opción A: Dashboard Web (4-6 semanas)**
- Pros:
  - Control total de UX/datos
  - Integración Supabase nativa
  - Validación server-side completa
  - Escalable a futuro
  - Admin puede gestionar negocios
- Cons:
  - 3-4 días de desarrollo (tiempo de hackathon)
  - Recursos limitados
  - Desvío de foco de la app móvil
  - Mantenimiento extra

**Opción B: Google Forms + App Móvil (esta semana) ✅ RECOMENDADO**
- Pros:
  - ✅ Cero desarrollo backend
  - ✅ Los emprendedores ya saben usar Forms
  - ✅ Respuestas automáticamente en Google Sheets
  - ✅ Reduce presión operativa para hackathon
  - ✅ La app móvil es el prototipo principal
  - ✅ Puedes migrar datos a Supabase post-hackathon con scripts
- Cons:
  - Requiere un job manual: Sheets → Supabase
  - UX divergente (Forms en web, app en móvil)
  - No es escalable al largo plazo

**Opción C: Formulario en la App Móvil (1-2 días)** ✅ MEJOR OPCIÓN
- La app ya tiene `RegisterBusinessWizard` casi completo
- Simplemente conectar directamente a Supabase
- Usuarios emprendedores pueden registrar negocios **dentro de la app**
- Pros:
  - UX consistente
  - Datos directo a Supabase
  - Hackathon-ready (MVP completo)
- Cons:
  - Requiere 8-10 horas de pulido

### **VEREDICTO: Opción C (Registro de negocios EN la app móvil)**

**Justificación:**
- Ya tienen 80% del wizard implementado
- Supabase está configurado
- Los datos van directo a la tabla `businesses`
- Es una feature completable en 1-2 días
- El hackathon requiere un MVP **integrado**, no desconectado

**Acción:**
1. Pulir `RegisterBusinessWizard` (ubicación, validaciones)
2. Conectar paso final al `BusinessStorageService.addBusiness()`
3. Testear E2E: Guest → Login → Register Negocio → Aparece en Map
4. LISTO: MVP completo, sin dashboard web

---

## 5. ROADMAP PRIORIZADO PARA HACKATHON (5 ENTREGAS)

### Fase 1: Autenticación & Guest Mode (Día 1 — 6 horas)
**Objetivo:** Login/Register flujo 100% funcional.

**Tareas:**
- [ ] T1.1: Testear flujo completo: Guest → Favorito → Login → Preservar favoritos
  - Archivo: `lib/core/services/auth_service.dart` + `favorites_service.dart`
  - Esfuerzo: 2h
  - Criterio de aceptación: Usuario invitado marca favorito, luego registra, favorito persiste

- [ ] T1.2: Desactivar social auth o implementar OAuth (decisión)
  - Si desactiva: 15 min
  - Si implementa: 2-3h (Supabase OAuth setup)
  - Recomendación: Desactivar para hackathon, mostrar "Próximamente"

- [ ] T1.3: Pulir mensajes de error en Spanish
  - Ya está ✅ (ver `_friendlyAuthError`)
  - Validar con QA: 30 min

- [ ] T1.4: Testear RegisterScreen (4 pasos)
  - Pantalla completable end-to-end
  - Esfuerzo: 2h (test manual + widget tests)

**Criterio de aceptación:**
- Nuevo usuario puede registrarse completo
- Guest puede favoritar sin cuenta
- Los datos se sincronizan con Supabase `profiles`
- Mensajes de error son claros en español

---

### Fase 2: Registro de Negocios (Día 1-2 — 8 horas)
**Objetivo:** Emprendedores pueden registrar negocios dentro de la app.

**Tareas:**
- [ ] T2.1: Completar paso de ubicación (mapa picker)
  - Archivo: `lib/features/business/presentation/screens/register_business_wizard.dart`
  - Agregar geocodificación: `flutter pub add geocoding`
  - Esfuerzo: 3h
  - Criterio: Usuario marca ubicación en mapa, coords se guardan

- [ ] T2.2: Conectar paso final al `BusinessStorageService.addBusiness()`
  - Archivo: `business_storage_service.dart`
  - Validar que la ubicación se convierte a PostGIS Point
  - Esfuerzo: 2h
  - Criterio: Negocio aparece en base de datos

- [ ] T2.3: Actualizar `AuthService.markAsEmprendedor()`
  - Al finalizar registro, promocionar user a role='emprendedor'
  - Esfuerzo: 1h

- [ ] T2.4: Testear E2E
  - Registrar negocio completo
  - Verificar que aparece en mapa
  - Esfuerzo: 2h

**Criterio de aceptación:**
- Nuevo emprendedor completa wizard
- Negocio aparece en tabla `businesses` de Supabase
- Role cambia a `emprendedor`
- Negocio aparece en mapa en tiempo real

---

### Fase 3: Mapas & Exploración (Día 1 — 4 horas)
**Objetivo:** Mapa funcional, búsqueda, filtros.

**Tareas:**
- [ ] T3.1: Validar mapa funciona con datos reales
  - Archivo: `lib/features/map/presentation/screens/map_screen.dart`
  - Ya funciona ✅
  - Esfuerzo: 30 min (testing)

- [ ] T3.2: Asegurar pins se actualizan en vivo
  - BusinessStorageService.revision notifier
  - MapScreen escucha cambios
  - Esfuerzo: 1h
  - Criterio: Registrar negocio, mapa se actualiza sin refresh

- [ ] T3.3: Geolocalización ("Mi ubicación")
  - Ya funciona ✅
  - Validar permisos en Android/iOS
  - Esfuerzo: 1h

- [ ] T3.4: Búsqueda + filtros por categoría
  - Ya funciona ✅
  - Testing: 1h

**Criterio de aceptación:**
- Mapa muestra todos los negocios de Supabase
- Búsqueda por nombre funciona en vivo
- Filtros por categoría funcionan
- "Mi ubicación" funciona con permisos

---

### Fase 4: Perfil & Mis Negocios (Día 2 — 6 horas)
**Objetivo:** Usuario puede ver/editar sus negocios.

**Tareas:**
- [ ] T4.1: ProfileScreen muestra "Mis Negocios"
  - Archivo: `lib/features/profile/presentation/screens/profile_screen.dart`
  - Filtrar negocios donde owner_id == currentUser.id
  - Esfuerzo: 2h

- [ ] T4.2: Edit Business button
  - Archivo: `edit_business_hub_screen.dart` (ya existe)
  - Conectar a `BusinessStorageService.updateBusiness()`
  - Esfuerzo: 2h

- [ ] T4.3: Delete business (con confirmación)
  - Esfuerzo: 1h

- [ ] T4.4: Mostrar stats del negocio (reviews, rating)
  - Esfuerzo: 1h

**Criterio de aceptación:**
- Emprendedor ve sus negocios en Profile
- Puede editar nombre, descripción, ubicación
- Cambios se sincronizan a mapa en tiempo real

---

### Fase 5: QA, Pulido & Documentación (Día 2-3 — 8 horas)
**Objetivo:** MVP listo para presentar.

**Tareas:**
- [ ] T5.1: Widget testing de pantallas críticas
  - LoginScreen, RegisterScreen, MapScreen, ProfileScreen
  - Usar fixture Supabase (ya configurado en CLAUDE.md)
  - Esfuerzo: 3h

- [ ] T5.2: Testing E2E manual (flujo completo)
  - Nuevo usuario: Guest → Registra → Ve mapa → Registra negocio → Ve en perfil
  - En dispositivos Android e iOS (o Chrome)
  - Esfuerzo: 3h

- [ ] T5.3: Auditoría de overflow (nombres/descripciones largas)
  - Ver `test/overflow_audit_test.dart`
  - Agregar nuevas pantallas a test
  - Esfuerzo: 1h

- [ ] T5.4: Documentación
  - README actualizado
  - Setup instrucciones
  - Esfuerzo: 1h

**Criterio de aceptación:**
- Zero critical crashes
- MVP completo y fluido
- Documentación clara para continuidad post-hackathon

---

## 6. CHECKLIST DE IMPLEMENTACIÓN INMEDIATA

### Semana 1 (MVP Hackathon):

- [ ] **Día 1 (Mañana):**
  - [ ] Clonar/verificar estado del repo
  - [ ] `flutter pub get` + `flutter analyze`
  - [ ] Levantar app: `flutter run -d chrome` (o dispositivo)
  - [ ] Testear LoginScreen → RegisterScreen → MainLayout
  - Tiempo: 1h

- [ ] **Día 1 (Tarde):**
  - [ ] Completar RegisterBusinessWizard (paso de ubicación)
  - [ ] Conectar al `BusinessStorageService`
  - [ ] Testear: Registrar negocio → Aparece en mapa
  - Tiempo: 4h

- [ ] **Día 2:**
  - [ ] Pulir ProfileScreen ("Mis Negocios")
  - [ ] Edit/Delete business
  - [ ] Testing E2E completo
  - Tiempo: 6h

- [ ] **Día 3:**
  - [ ] QA, overflow audit
  - [ ] Build release: APK + Web
  - [ ] Documentación
  - Tiempo: 4h

### Semana 2+ (Post-Hackathon):

- [ ] Implementar tabla `reviews` en Supabase (es local ahora)
- [ ] Confirmar email verification
- [ ] Social auth (OAuth)
- [ ] Admin dashboard (web)
- [ ] Notificaciones push
- [ ] Analytics

---

## 7. DEPENDENCIAS & SETUP FINAL

### Dependencias a agregar:
```bash
flutter pub add geocoding  # Para geocodificación en wizard
```

### Verificar Supabase:
1. ✅ Project URL en `supabase_config.dart`
2. ✅ Anon key está configurada
3. ⚠️ **Verificar tablas existen:**
   - `profiles` (vinculada a `auth.users`)
   - `businesses` (con PostGIS location)
   - `reviews` (crear si no existe)
   - `bookings` (crear si no existe)

### Permisos Android/iOS:
- ✅ `geolocator`: Configurado en `pubspec.yaml`
- ⚠️ Verificar `AndroidManifest.xml` tiene:
  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  ```
- ⚠️ Verificar `Info.plist` (iOS) tiene privacy strings

### Build final:
```bash
# Para APK (Android)
flutter build apk --release

# Para Web
flutter build web --release

# Para iOS
flutter build ios --release
```

---

## 8. MATRIZ DE RIESGOS & MITIGACIÓN

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|--------|-----------|
| Reviews no sincroniza a Supabase | Alta | Medio | Usar local por ahora, migrar post-hackathon |
| Geocodificación lenta | Media | Bajo | Caché en mapa picker, no hace consulta en cada keystroke |
| Permisos de ubicación (Android) | Alta | Medio | Testear en dispositivo real, fallback a Managua |
| PostGIS Point parsing fallido | Baja | Alto | Test unitario, usar EWKT format |
| Guest mode + login confusa UX | Media | Medio | Simplificar flujo, botones claros |

---

## CONCLUSIÓN

**Estado del proyecto: LISTO PARA HACKATHON**

Con 16 horas de trabajo distribuido en 2-3 días, el MVP será:
- ✅ Autenticación completa (Login, Register 4-paso)
- ✅ Mapas funcionales con negocios reales
- ✅ Registro de negocios dentro de la app
- ✅ Perfil de usuario con "Mis Negocios"
- ✅ Guest mode para exploración
- ✅ Sincronización en tiempo real Supabase

**No incluir en hackathon:**
- ❌ Dashboard web (post-hackathon)
- ❌ Social auth (post-hackathon)
- ❌ SMS OTP (post-hackathon)
- ❌ Admin panel (post-hackathon)

**Arquitectura decisión:** Mantener servicios singleton + SharedPreferences. NO introduce Provider/Riverpod/Bloc sin confirmación explícita.

