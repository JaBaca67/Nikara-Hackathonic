# ACCIONES INMEDIATAS: PASOS TÉCNICOS ESPECÍFICOS

## SEMANA 1 — DÍA 1 (Hoy)

### Actividad 1.1: Setup & Verificación (1 hora)

#### Paso 1: Clonar/actualizar repo
```bash
cd ~/Projects/nikara_app  # o tu ruta
git status
git checkout feature/home  # rama actual

# Si no tienes cambios locales, pullear main
git pull origin main
```

#### Paso 2: Instalar dependencias
```bash
flutter clean
flutter pub get
dart format .  # verificar formato
flutter analyze  # chequear linting
```

#### Paso 3: Verificar que todo funciona
```bash
# En Chrome (web)
flutter run -d chrome

# O en dispositivo conectado
flutter devices
flutter run -d <device-id>
```

**Criterio de aceptación:**
- ✅ App levanta sin errores
- ✅ Ves login screen
- ✅ No hay red underlines (análisis)

---

### Actividad 1.2: Testear Login → Register → Main (2 horas)

#### Paso 1: Test Login incompleto (Guest mode)
1. Abre LoginScreen
2. Toca "Explorar como invitado"
3. Verifica que ves MainLayout (Home → Map → Profile)
4. Navega al Map → deberías ver negocios reales de Supabase

**Problema esperado:** Si no ves negocios:
- Verifica que Supabase tiene registros en tabla `businesses`
- Verifica que tienen `latitude` y `longitude` (no null)
- Abre Browser DevTools → verifica respuesta de API

#### Paso 2: Test Register completo
1. LoginScreen → "Crear cuenta"
2. Completa 4-step wizard:
   - Paso 1: Email válido, password 6+ chars
   - Paso 2: Nombre, teléfono, sube foto (opcional)
   - Paso 3: OTP → toca "Saltar por ahora"
   - Paso 4: Selecciona 2-3 categorías
3. Toca "Terminar"
4. Deberías ver MainLayout

**Problema esperado:** 
- AuthException → revisa logs
- "No se pudo guardar tu perfil" → tabla `profiles` no existe o schema incorrecto
- Phone validation → revisa `input_formatters.dart`

#### Paso 3: Verificar datos en Supabase
1. Abre https://app.supabase.com
2. Ve a "SQL Editor"
3. Corre:
```sql
SELECT id, full_name, email, role, created_at FROM profiles ORDER BY created_at DESC LIMIT 5;
```

Deberías ver el nuevo usuario.

**Criterio de aceptación:**
- ✅ Nuevo usuario aparece en `profiles`
- ✅ Role = 'turista'
- ✅ Se puede ver MainLayout post-login

---

### Actividad 1.3: Mapas en vivo (1.5 horas)

#### Paso 1: Verificar que mapa carga negocios
1. En app, ve a Map tab
2. Deberías ver markers de negocios reales
3. Toca un marker → preview sheet con nombre, foto, categoría

#### Paso 2: Test búsqueda y filtros
1. Search bar: escribe nombre de un negocio
2. Debería aparecer/desaparecer según coincida
3. Category chips: toca "Lagunas" (u otra categoría)
4. Debería filtrar por categoría

#### Paso 3: Test "Mi ubicación"
1. Botón bottom-right (brújula)
2. Primera vez → pide permiso (location)
3. Aprueba permiso
4. Mapa centra en tu ubicación actual (o Managua si falla)

**Problema esperado:**
- CartoDB tiles no cargan → revisa internet
- Markers no aparecen → revisa que negocios tengan coords
- Permisos no piden → verifica AndroidManifest.xml (Android) e Info.plist (iOS)

#### Paso 4: Test "Cómo llegar"
1. Marker → preview sheet
2. Botón "Cómo llegar"
3. Debería abrir Google Maps en navegador

**Criterio de aceptación:**
- ✅ Mapa visible con CartoDB tiles
- ✅ Markers aparecen para todos los negocios
- ✅ Búsqueda funciona
- ✅ Filtros funcionan
- ✅ "Mi ubicación" funciona (con permisos)
- ✅ "Cómo llegar" abre Google Maps

---

## SEMANA 1 — DÍA 2 (Registro de Negocios)

### Actividad 2.1: Completar paso de ubicación (3 horas)

**Archivos a tocar:**
- `lib/features/business/presentation/screens/register_business_wizard.dart`
- `lib/features/business/data/business_storage_service.dart`

#### Paso 1: Agregar geocoding
```bash
flutter pub add geocoding
```

#### Paso 2: Implementar map picker en wizard (Paso 2 de ubicación)
En `register_business_wizard.dart`, agregar pantalla interactiva de mapa:

```dart
// En el paso de ubicación
GestureDetector(
  onTap: () {
    // Abrir map picker
    showDialog(
      context: context,
      builder: (_) => _MapPickerDialog(
        initialLat: _businessLat ?? 12.1363,
        initialLng: _businessLng ?? -86.2513,
        onLocationPicked: (lat, lng, address) {
          setState(() {
            _businessLat = lat;
            _businessLng = lng;
            _businessAddress = address;
          });
        },
      ),
    );
  },
  child: Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(_businessAddress ?? 'Selecciona ubicación en mapa'),
  ),
);
```

#### Paso 3: Implementar _MapPickerDialog
```dart
class _MapPickerDialog extends StatefulWidget {
  final double initialLat, initialLng;
  final Function(double, double, String) onLocationPicked;
  
  const _MapPickerDialog({
    required this.initialLat,
    required this.initialLng,
    required this.onLocationPicked,
  });
  
  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late MapController _mapController;
  double? _selectedLat, _selectedLng;
  
  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
    _mapController = MapController();
  }
  
  Future<void> _geocodeReverse(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final address = [
          p.street,
          p.locality,
          p.administrativeArea,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        return address;
      }
    } catch (_) {
      // Fallback: usar coords
    }
    return "$lat, $lng";
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_selectedLat!, _selectedLng!),
                initialZoom: 14,
                onTap: (_, point) {
                  setState(() {
                    _selectedLat = point.latitude;
                    _selectedLng = point.longitude;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                ),
                if (_selectedLat != null && _selectedLng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_selectedLat!, _selectedLng!),
                        child: Icon(Icons.location_on, color: Colors.red),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final address = await _geocodeReverse(_selectedLat!, _selectedLng!);
                      widget.onLocationPicked(_selectedLat!, _selectedLng!, address);
                      Navigator.pop(context);
                    },
                    child: Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### Paso 4: Testear map picker
1. En app: Profile → "Registra tu negocio"
2. Completa Paso 1 (info básica)
3. En Paso 2, toca selector de ubicación
4. Debería abrir diálogo con mapa
5. Toca ubicación en mapa
6. Toca "Confirmar"
7. Dirección debería aparecer

**Criterio de aceptación:**
- ✅ Map picker abre correctamente
- ✅ Tap en mapa actualiza marcador
- ✅ Geocoding reverso genera dirección
- ✅ Coords guardadas en businessLat/businessLng

---

### Actividad 2.2: Conectar wizard al backend (2 horas)

**Archivos a tocar:**
- `lib/features/business/presentation/screens/register_business_wizard.dart`
- `lib/features/business/data/business_storage_service.dart`

#### Paso 1: En RegisterBusinessWizard, en paso final:
```dart
// Cuando usuario toca "Guardar negocio"
Future<void> _submitBusiness() async {
  // Crear modelo
  final business = BusinessModel(
    id: const Uuid().v4(),  // Generar UUID
    name: _nameController.text,
    category: _selectedCategory,
    description: _descriptionController.text,
    city: _cityController.text,
    locationText: _selectedAddress,  // Dirección completa
    latitude: _selectedLat,
    longitude: _selectedLng,
    contactPhone: _phoneController.text,
    instagramLink: _instagramController.text,
    facebookLink: _facebookController.text,
    tiktokLink: _tiktokController.text,
    hostName: _hostNameController.text,
    ownerId: AuthService().currentAuthUser?.id ?? '',  // UUID del dueño
    allowsReservations: _allowsReservations,
    price: _priceController.text.isNotEmpty 
      ? double.parse(_priceController.text) 
      : null,
    amenities: _selectedAmenities.toList(),
    activities: _selectedActivities.toList(),
    ecoSealRequested: _ecoSealRequested,
    ecoPractices: _selectedEcoPractices.toList(),
    localImagePaths: _photosPaths,  // Paths de fotos
  );
  
  // Guardar en Supabase
  try {
    setState(() => _isSubmitting = true);
    await BusinessStorageService().addBusiness(business);
    
    // Promocionar a emprendedor
    await AuthService().markAsEmprendedor();
    
    // Mostrar success screen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessSuccessScreen(business: business),
        ),
      );
    }
  } on BusinessServiceException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  } finally {
    setState(() => _isSubmitting = false);
  }
}
```

#### Paso 2: Validar en BusinessStorageService
Ya está implementado ✅:
```dart
void _requireOwnerId(BusinessModel business) {
  if (business.ownerId.trim().isEmpty) {
    throw const BusinessServiceException(...);
  }
}

void _requireLocation(BusinessModel business) {
  if (business.latitude == null || business.longitude == null) {
    throw const BusinessServiceException(...);
  }
}
```

#### Paso 3: Verificar PostGIS conversion
En `_toRow()`:
```dart
'location': 'SRID=4326;POINT(${b.longitude} ${b.latitude})',
```
✅ Esto convierte (lat, lng) a formato EWKT que PostGIS entiende.

#### Paso 4: Testear E2E
1. Profile → "Registra tu negocio"
2. Completa los 5 pasos
3. Paso final: toca "Guardar negocio"
4. Debería ir a BusinessSuccessScreen
5. Verifica que negocio está en Supabase:
```sql
SELECT id, owner_id, name, category, location FROM businesses 
ORDER BY created_at DESC LIMIT 1;
```

**Criterio de aceptación:**
- ✅ Negocio se guarda en tabla `businesses`
- ✅ owner_id es correcto (UUID del usuario)
- ✅ location es PostGIS Point (SRID=4326;POINT(...))
- ✅ No hay errores de constraints

---

## SEMANA 1 — DÍA 3 (Mapa en vivo & UI Polish)

### Actividad 3.1: Mapa actualiza en tiempo real (1.5 horas)

**Archivos a tocar:**
- `lib/features/map/presentation/screens/map_screen.dart`
- `lib/features/business/data/business_storage_service.dart`

#### Paso 1: MapScreen escucha cambios en BusinessStorageService
```dart
// En _MapScreenState.initState()
@override
void initState() {
  super.initState();
  
  // Escuchar cambios en negocio
  BusinessStorageService.revision.addListener(_loadBusinesses);
  
  // Cargar negocios iniciales
  _loadBusinesses();
}

@override
void dispose() {
  BusinessStorageService.revision.removeListener(_loadBusinesses);
  super.dispose();
}
```

Ya está implementado ✅, pero verifica que funciona.

#### Paso 2: Testear flujo completo
1. Abre app en DOS ventanas de navegador (o dos dispositivos)
2. Ventana 1: Ve al Map
3. Ventana 2: Va a Profile → Registra negocio
4. Ventana 1: Debería ver nuevo marker aparecer sin refresh

**Problema esperado:**
- Mapa no se actualiza → verifica que listener está registrado
- Negocio aparece pero con ubicación incorrecta → revisa coords en Supabase

**Criterio de aceptación:**
- ✅ Mapa se actualiza automáticamente sin refresh
- ✅ Nuevo negocio aparece en tiempo real (30ms aprox)

---

### Actividad 3.2: Profile → Mis Negocios (1 hora)

**Archivos a tocar:**
- `lib/features/profile/presentation/screens/profile_screen.dart`

#### Paso 1: Filtrar negocios por owner
```dart
// En ProfileScreen
Future<void> _loadMyBusinesses() async {
  try {
    final all = await BusinessStorageService().getBusinesses();
    final userId = AuthService().currentAuthUser?.id ?? '';
    
    setState(() {
      _myBusinesses = all.where((b) => b.ownerId == userId).toList();
    });
  } on BusinessServiceException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}
```

#### Paso 2: Mostrar lista + acciones
```dart
// En build(), en pestaña "Mis Negocios"
ListView.builder(
  itemCount: _myBusinesses.length,
  itemBuilder: (context, index) {
    final business = _myBusinesses[index];
    return ListTile(
      title: Text(business.name),
      subtitle: Text(business.category),
      trailing: PopupMenuButton(
        itemBuilder: (_) => [
          PopupMenuItem(
            child: Text('Editar'),
            onTap: () => _editBusiness(business),
          ),
          PopupMenuItem(
            child: Text('Eliminar'),
            onTap: () => _deleteBusiness(business.id),
          ),
        ],
      ),
    );
  },
)
```

#### Paso 3: Testear
1. Login como emprendedor (registró negocio)
2. Profile tab
3. Debería ver "Mis Negocios" con lista
4. Toca menu → Editar
5. Abre EditBusinessHubScreen
6. Haz cambio (ej: nombre)
7. Guarda
8. Verifica que cambio aparece en mapa también

**Criterio de aceptación:**
- ✅ "Mis Negocios" muestra solo negocios del usuario
- ✅ Edit/delete funcionan
- ✅ Cambios sincronizan al mapa

---

### Actividad 3.3: Mensajes de error en Spanish (30 min)

Ya casi todo está en Spanish ✅. Verifica:

```dart
// lib/core/services/auth_service.dart
String _friendlyAuthError(AuthException e) {
  // ✅ Ya está hecho
  if (message.contains('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';  // ✅
  }
  // ... más casos
}

// lib/features/business/data/business_storage_service.dart
throw BusinessServiceException(
  'No se pudo guardar el negocio: ${e.message}',  // ✅ Spanish
);
```

Busca cualquier error en inglés que pasemos por alto:
```bash
grep -r "error\|Error\|ERROR" lib/ --include="*.dart" | grep -i english
```

---

## SEMANA 1 — DÍA 4 (QA & Release)

### Actividad 4.1: Testing E2E (2 horas)

**Flujo completo a testear:**

1. **Guest mode** ✅
   - [x] LoginScreen → "Explorar como invitado"
   - [x] Ver Home, Map, Profile
   - [x] Tap favorito → GuestGuard → "Crea cuenta"

2. **Register** ✅
   - [x] 4-step wizard completable
   - [x] Email/password válidos
   - [x] Foto opcional pero funciona
   - [x] OTP step → "Saltar por ahora"
   - [x] Preferencias guardadas

3. **Map** ✅
   - [x] Carga negocios reales
   - [x] Búsqueda por nombre
   - [x] Filtros por categoría
   - [x] "Mi ubicación" con permisos
   - [x] Tap marker → preview sheet

4. **Business registration** ✅
   - [x] Profile → "Registra tu negocio"
   - [x] Paso 1: info básica
   - [x] Paso 2: map picker para ubicación
   - [x] Paso 3: contacto
   - [x] Paso 4: amenities, eco seal
   - [x] Paso 5: fotos
   - [x] Guardar → BusinessSuccessScreen
   - [x] Negocio aparece en Supabase
   - [x] Negocio aparece en mapa

5. **Mis Negocios** ✅
   - [x] Profile → "Mis Negocios"
   - [x] Ver lista propia
   - [x] Edit → cambio sincroniza
   - [x] Delete → elimina

---

### Actividad 4.2: Widget Tests (1 hora)

Agrega tests para pantallas críticas:

```bash
# Verificar que tests existen
ls test/

# Correr todos los tests
flutter test

# Correr test específico
flutter test test/features/auth/presentation/screens/login_screen_test.dart
```

Ver `CLAUDE.md` para setup de fixtures Supabase.

---

### Actividad 4.3: Build Release (1 hora)

```bash
# Limpiar build anterior
flutter clean

# Build APK (Android)
flutter build apk --release
# Archivo: build/app/outputs/flutter-app.apk

# Build Web
flutter build web --release
# Carpeta: build/web/

# Verificar que no hay warnings
flutter analyze
```

---

### Actividad 4.4: Documentación (30 min)

Actualiza README.md:
```markdown
# Níkara

MVP Flutter app para turismo y negocios locales en Nicaragua.

## Setup
```bash
flutter pub get
flutter run -d chrome  # o tu dispositivo
```

## Features
- Autenticación (Supabase Auth)
- Mapa en vivo (OpenStreetMap via flutter_map)
- Registro de negocios
- Búsqueda y filtros
- Favoritos

## Hackathon Status
✅ MVP Completo
- Mapa funcional
- Auth (Login/Register)
- Negocio registration
- Profile ("Mis Negocios")

## Próximas fases
- Reviews en Supabase
- Bookings/Reservas
- Admin panel
- Push notifications
```

---

## VERIFICACIÓN FINAL (Antes de presentación)

### Checklist:

```
PRE-PRESENTATION (Hace 1 hora):
[ ] App corre sin crashes
[ ] Guest → Map → Ver negocios ✅
[ ] Login → Register 4-step ✅
[ ] Registra negocio → Aparece en mapa ✅
[ ] Profile → "Mis Negocios" ✅
[ ] Todos los mensajes en ESPAÑOL ✅
[ ] Build APK/Web generados ✅
[ ] README actualizado ✅

DEVICE TESTING:
[ ] Testeado en Android (APK o emulador)
[ ] Testeado en iOS (si posible)
[ ] Testeado en Web (Chrome)
[ ] Testeado con poor connectivity (throttle)
[ ] Testeado con permisos denegados (location)

DEMO SCRIPT ENSAYADO:
[ ] Abres app en dispositivo real
[ ] Demostración 5 minutos max
[ ] Puntos clave visibles y fluidos
[ ] Sin bugs obvios
```

---

## DEPLOYMENT FINAL

### Hosts disponibles:
- **Android (APK):** Distribuir vía email, QR, o Drive
- **Web (Flutter Web):** Firebase Hosting, Vercel, o Netlify
- **iOS (si tienes Mac):** TestFlight o build local

### Instrucciones para jueces:
```
1. Descargar APK:
   https://drive.google.com/...

2. Instalar en Android:
   adb install app.apk

3. O acceder a web:
   https://nikara-hackathon.web.app

4. Demo user:
   Email: demo@nikara.com
   Password: DemoPass123
```

---

**FIN DE TAREAS**

Total de horas estimadas: **18-20 horas** distribuidas en 2-3 días
Con equipo de 2-3 devs: **Completable antes del deadline**

