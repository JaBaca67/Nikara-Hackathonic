# Circuito Creativo Xolotlán en Nikara

Las cinco rutas municipales forman un **catálogo global en Supabase**, visible
en **Rutas → Comunidad** para todas las cuentas e invitados. Los originales
tienen `owner_id=null`, `catalog_name='Circuito Creativo Xolotlán'` e
`is_public=true`; no pertenecen al perfil de ningún promotor. La migración
`supabase/sql/048_global_creative_routes.sql`, ya aplicada, convierte las cinco
rutas existentes conservando sus IDs, descripciones y paradas.

Los nuevos circuitos se publican con `catalog_name` y sin dueño personal. La
base exige que sean públicos y limita su mantenimiento a administradores.
El importador usa este mismo esquema para todas las rutas que agregue al lote.
Las copias son personales, privadas por defecto y editables; el original global
permanece disponible aunque se elimine la cuenta que hizo la carga. El detalle
conserva su enlace a la fuente municipal.

Las fichas de los lugares siguen administradas por la cuenta promotora de José
Alfredo Baca Moreno (`30a57d65-a20c-407e-bd7f-d07d8c3c54da`), como en el catálogo
turístico anterior; su estado aprobado permite consultarlas públicamente.

| Ruta | Paradas | Con coordenadas para navegación |
|---|---:|---:|
| Natural | 9 | 6 |
| Gastronómica | 11 | 11 |
| Histórica patrimonial | 11 | 10 |
| Cultural | 16 | 16 |
| Recreación y esparcimiento | 11 | 11 |
| Total | 58 | 54 |

Se registraron **51 lugares distintos y 96 fotografías**. Las paradas compartidas
usan el mismo negocio/lugar de origen. El número y el orden corresponden al
campo `placesOfInterest.order` del mapa municipal, consultado el **8 de octubre
de 2026**. No se optimizó ni sustituyó el itinerario oficial.

## Fuentes y condiciones de visita

- [Publicación aportada por el usuario](https://www.nicaraguacreativa.com/2026/07/27/lanzamiento-circuito-creativo-xolotlan-de-managua-multicultural/).
- [Circuito y mapa municipal](https://ciudadcreativa.managua.gob.ni/circuitos-creativos).
- [Datos públicos del mapa oficial](https://ciudadcreativa.managua.gob.ni/mc-map/circuits).
- [Directorio municipal de lugares](https://ciudadcreativa.managua.gob.ni/mc-map/directory-items).

Cada ficha conserva su enlace de procedencia en `other_notes`; el catálogo local
también registra la URL original de cada fotografía. Las descripciones de lugares
se redactaron a partir de los datos publicados. Se conservan los teléfonos,
direcciones y horarios proporcionados; los datos ausentes se dejan vacíos.
No se inventaron precios, reseñas, contactos, disponibilidad ni verificaciones.
`is_verified=false` y `show_host=false`: administrar el registro no acredita la
representación comercial ni la identidad del propietario del establecimiento.

La fuente presenta cuatro pines como referencias de lagunas o del mirador, sin
identificar una entrada: **Laguna de Tiscapa, Mirador Loma de Tiscapa, Laguna de
Nejapa y Laguna de Asososca**. Se mantienen sus coordenadas originales en las
fichas y en el manifiesto. En las paradas de las rutas se omiten las coordenadas
para desactivar la navegación automática hacia esos puntos; siguen visibles y
se pueden marcar como visitados u omitidos. Sus indicaciones solicitan confirmar
los accesos autorizados. No representan entradas peatonales verificadas.

**Huellas de Acahualinca** figura en remodelación en la ficha municipal. La
Antigua Catedral y la Casa de los Pueblos se contemplan únicamente desde el
exterior. **Isla del Amor** requiere embarcación desde Puerto Salvador Allende;
una navegación por carretera no sustituye ese transporte. Estas condiciones
aparecen en las fichas y en los subtítulos de las paradas correspondientes.

Los recorridos se presentan como itinerarios de un día para poder demostrar el
modo ruta. Esa organización no garantiza completar todas las actividades en un
día ni coincide necesariamente con los horarios de apertura. El manifiesto
conserva la duración y distancia que publica el mapa, y una copia permite
redistribuir las visitas por días.

## Descripción editable

La descripción es opcional, admite hasta **500 caracteres** y aparece en las
tarjetas y el detalle. Se precarga al editar, puede vaciarse y se conserva al
copiar junto con la fuente. Las rutas anteriores usan una descripción vacía.
La migración `supabase/sql/047_route_descriptions.sql` agrega `description` y
`source_url`; ya está aplicada al proyecto enlazado.

## Carga y verificación

```powershell
# Validar los datos locales sin escribir en Supabase.
python scripts/seed_creative_routes.py

# Preparar fotografías y revisar covers-1.jpg, covers-2.jpg y covers-3.jpg.
python scripts/seed_creative_routes.py --prepare

# Generar SQL sin publicarlo.
python scripts/seed_creative_routes.py --owner-id 30a57d65-a20c-407e-bd7f-d07d8c3c54da

# Registrar lugares faltantes y publicar las cinco rutas.
python scripts/seed_creative_routes.py --owner-id 30a57d65-a20c-407e-bd7f-d07d8c3c54da --apply

# Comprobar acceso público, orden, datos, autor y referencias sin navegación.
python scripts/verify_creative_routes.py

# PostgreSQL local: migración, límites, reutilización, atomicidad e idempotencia.
node scripts/test_creative_routes.mjs
```

Se usan las dependencias de `scripts/requirements-demo.txt` y la sesión de
Supabase CLI existente. La prueba SQL usa PGlite instalado en
`build/notification-sql-tests`. Las credenciales administrativas permanecen en
memoria y no se incluyen en Flutter ni en los reportes.

`scripts/data/xolotlan_catalog.json` contiene el catálogo reproducible. Las
imágenes preparadas, el SQL, las fuentes descargadas, el inventario de Storage y
los resultados están en `supabase/demo/xolotlan/`. Esa carpeta y la migración
están ignoradas por Git según la configuración del proyecto: respaldarlas por el
mecanismo privado habitual.

La importación es transaccional. Reutiliza una ficha existente con el mismo
nombre y ciudad; aborta ante coincidencias ambiguas o lugares sin publicar.
Repetirla conserva las ediciones y las paradas eliminadas de rutas ya importadas;
las rutas originales del catálogo siempre son públicas. Las copias personales
conservan su privacidad. Se verificó la repetición en PostgreSQL local y en el proyecto
enlazado; no alteró las rutas ni sus paradas existentes.

## Revisión visual

Las 96 fotos públicas se descargaron y decodificaron correctamente el 8 de
octubre. En Android se observó un `Failed host lookup` temporal para el dominio
de Supabase durante el arranque; luego el mismo teléfono volvió a resolverlo.
`LocalImage`, compartido por fichas y rutas, ahora realiza dos reintentos,
evicta la petición fallida antes de volver a cargar, ofrece **Reintentar foto**
y recupera imágenes fallidas al volver a la app. Las pruebas cubren errores
transitorios, fallos persistentes, reintento manual, regreso a la app y cierre.

La revisión web con datos reales mostró el nombre del catálogo sin perfil
personal y fotos cargadas en Comunidad, las paradas y la ficha de Puerto
Salvador Allende. Se recibieron 16 respuestas HTTP 200 para fotos, con validación
de certificados activa. Las capturas adicionales son `global-stops-preview.png`
y `business-photo-preview.png`, en `supabase/demo/xolotlan/`.
La revisión visual de Android quedó limitada por el bloqueo del teléfono y una
conexión USB intermitente. La versión final se compiló en modo debug y se instaló
correctamente en el Samsung A56 (`adb install -r`: `Success`).

El campo de descripción se revisó en el Samsung A56 a 384 dp. Comunidad y el
detalle se revisaron además en una previsualización web de 384 × 832 px, con las
fotografías públicas y los datos reales. Las capturas están en
`supabase/demo/xolotlan/description-phone.png`, `community-preview.png` y
`route-detail-preview.png`.

La previsualización web detectó que el proyecto no carga el SDK JavaScript de
Google Maps en `web/index.html`; el mapa queda vacío en ese entorno. Las rutas
y las fichas sí cargan. Esta comprobación no valida el mapa web ni sustituye
una prueba del recorrido completo en Android con GPS. El modo de recorrido,
su progreso y las paradas sin coordenadas se comprobaron mediante las pruebas
del módulo.
