# Catálogo turístico de la demo

Investigación: **7 de octubre de 2026**. Se seleccionaron ocho establecimientos
de El Tránsito, Miramar, Matagalpa y Jinotega. No se inventaron teléfonos,
horarios, reseñas, precios ni verificaciones de identidad. Los campos sin respaldo
se dejan vacíos. La publicación administrativa no activa `is_verified`.

| Negocio | Zona | Oferta | Fuentes principales |
|---|---|---|---|
| Alive Beach House | El Tránsito, León | Hotel, surf, yoga y restaurante | [Web oficial](https://alivebeachhouse.com/) |
| The Free Spirit Hostel | El Tránsito, León | Hostal, piscina, surf y yoga | [Página oficial de Nicaragua](https://thefreespirithostel.com/hostel-nicaragua) |
| Miramar SurfCamp | Miramar, León | Alojamiento y experiencias de surf | [Web oficial](https://www.miramarsurfcamp.com/) |
| Sirena Surf Lodge | Miramar, León | Surf guiado y clases | [Web oficial](https://sirenasurflodge.com/) |
| Reserva Natural Finca Kilimanjaro | San Rafael del Norte, Jinotega | Café, cabalgatas y vida rural | [Web oficial](https://reservakilimanjaro.com/), [INTUR / Visita Nicaragua](https://www.visitanicaragua.com/espacios-naturales/reserva-privada-kilimanjaro/) |
| Selva Negra Ecolodge | Matagalpa | Bosque, cabañas, café y gastronomía | [Web oficial](https://www.selvanegra.com/en/home/), [Registro INTUR](https://www.visitanicaragua.com/establecimientos/selva-negra-6987/) |
| Matagalpa Tours | Matagalpa | Naturaleza, café y turismo comunitario | [Excursiones oficiales](https://matagalpatours.com/day_tours/), [Contacto y horarios](https://matagalpatours.com/contact/) |
| Hotel y Restaurante Adams | Jinotega | Hotel, piscina y restaurante | [Web oficial](https://hotelrestauranteadams.com/) |

La ubicación de cada ficha tiene su propia fuente en `location_source` del
manifiesto: mapa del establecimiento, registro INTUR, Waze o cartografía pública.
La referencia de Alive procede del mapa enlazado en su web; representa el punto
que publica el establecimiento. El pin de Matagalpa Tours corresponde a su oficina,
no a los destinos de sus excursiones. No hubo visita física ni confirmación
telefónica: la comprobación corresponde a fuentes web.

## Archivos

- `scripts/seed_tourism_businesses.py`: importador administrativo reutilizable.
- `scripts/requirements-demo.txt`: dependencias Python.
- `supabase/demo/tourism_catalog.json`: datos, fuentes y selección visual.
- `supabase/demo/prepared/prepared.json`: dimensiones, peso, procedencia y SHA-256 de las imágenes.
- `supabase/demo/prepared/images/`: JPEG optimizados.
- `supabase/demo/prepared/catalog-covers.jpg`: revisión visual de portadas.
- `supabase/demo/prepared/import.sql`: inserción SQL generada para la cuenta elegida.
- `supabase/demo/prepared/import_result.json`: resultado verificado de la carga.
- `supabase/demo/prepared/storage_inventory.json`: inventario de objetos públicos.
- `supabase/demo/prepared/verification.json`: comprobación final de acceso público, CORS e idempotencia.

`supabase/` permanece ignorado por Git según la decisión existente del proyecto.
Respaldá esa carpeta por el mismo mecanismo privado utilizado para el esquema.
El script y esta guía sí pueden versionarse. Las claves administrativas nunca
se guardan en el manifiesto ni en los reportes.

## Registro masivo y vínculo con usuarios

La relación ya existente es **`profiles.id → businesses.owner_id`**: un usuario
puede administrar muchos negocios. No se necesita modificar la app ni crear
una identidad legal ficticia. Al insertar registros con el UUID de una cuenta,
aparecen en **Mi negocio** de esa cuenta; con `status='aprobado'` aparecen también
en el catálogo público. El importador exige una cuenta existente con rol
`emprendedor` o `admin` y usa acceso administrativo desde la CLI local.

La cuenta utilizada para el catálogo de la demo es **José Alfredo Baca Moreno**,
UUID `30a57d65-a20c-407e-bd7f-d07d8c3c54da`, que ya administraba el lote anterior.
`show_host=false` evita presentar al administrador de la demo como anfitrión real
del establecimiento. La carga no cambia el rol, identidad legal o datos de perfil.

```powershell
python -m pip install -r scripts/requirements-demo.txt

# Validar el catálogo sin conectar con Supabase.
python scripts/seed_tourism_businesses.py

# Descargar, optimizar y generar el manifiesto local.
python scripts/seed_tourism_businesses.py --prepare

# Generar una carga pendiente de revisión; no escribe en Supabase.
python scripts/seed_tourism_businesses.py --owner-id UUID_DEL_USUARIO

# Cargar pendiente de revisión.
python scripts/seed_tourism_businesses.py --owner-id UUID_DEL_USUARIO --apply

# Cargar y publicar administrativamente el lote de la demo.
python scripts/seed_tourism_businesses.py --owner-id 30a57d65-a20c-407e-bd7f-d07d8c3c54da --publish --apply
```

Requiere Python, Node/npm y una sesión `supabase login` con acceso al proyecto
configurado en `SupabaseConfig`. La CLI se ejecuta mediante `npx`. Como alternativa
para Storage, el script puede leer `SUPABASE_SERVICE_ROLE_KEY` del entorno; nunca
debe incluirse esa clave en Flutter. `SUPABASE_URL` permite seleccionar otro
proyecto. La consulta SQL se dirige al mismo project ref que esa URL.

Para ampliar el catálogo, agregá objetos al arreglo `businesses` del JSON y volvé
a preparar. Cada objeto necesita un `slug` estable, información comercial,
coordenadas respaldadas, `sources`, `location_source` y entre dos y nueve imágenes
HTTPS con `source_page`, `alt` y `reviewed=true`. Dejá `ready=false` cuando falte
confirmación. `cache_path` es opcional: si ya no existe, se descarga desde `url`.

Los IDs se derivan del slug. Repetir la carga conserva las filas existentes,
incluidas las ediciones hechas posteriormente en la app. No cambia el dueño ni
publica automáticamente una ficha pendiente que ya existía. Las coincidencias
de nombre y ciudad fuera del lote detienen la operación para evitar duplicados.
Para cambiar contenido existente, usá el flujo normal de edición; este comando
está diseñado para insertar registros nuevos.

La inserción de todos los negocios se realiza en una transacción. Si falla,
ninguna ficha nueva se conserva. Storage y PostgreSQL no comparten transacción:
si la inserción falla después de subir las imágenes, pueden quedar objetos sin
referencias; el inventario permite identificarlos. Sus nombres contienen el hash
del contenido, así que repetir la carga reutiliza las mismas imágenes.

## Imágenes y presentación

Se prepararon **30 fotos originales y 8 portadas derivadas** (38 archivos). La
primera URL de `photos` es la portada; las siguientes forman la galería.
Las portadas tienen proporción 4:3 y llegan hasta 1200×900. Las galerías conservan
la proporción original con un lado máximo de 1600 píxeles. No se amplían imágenes
pequeñas. Se normaliza la orientación EXIF, se retiran metadatos y se usa JPEG
progresivo para la compatibilidad de `Image.network` en Flutter.

La interfaz actual usa `BoxFit.cover` en tarjetas y detalles: el dispositivo puede
recortar nuevamente la imagen según el tamaño de la caja. Las portadas se revisan
por separado y el manifiesto admite `focal_point` para ajustar el centro del recorte.
El script comprueba formato, dimensiones, peso y hash; después de subir, descarga
cada URL pública y compara sus bytes. Todos los objetos van al bucket `businesses`,
con prefijo del usuario, dentro del límite existente de 5 MB por archivo.

La carga se ejecutó y verificó contra el proyecto configurado: **14 negocios
públicos en total**, incluidos los ocho nuevos. Las 38 imágenes son accesibles
sin sesión, con CORS para web, y suman aproximadamente 8.61 MiB; el archivo más
grande pesa 593 KiB. Repetir el SQL mantuvo exactamente iguales todas las fichas
públicas, incluidos sus IDs, fechas y contenido. También pasaron seis pruebas
del importador para validar candidatos, slugs, coordenadas, procedencia visual,
integridad de archivos y orientación EXIF. Las portadas se inspeccionaron como
montaje; no se ejecutó una prueba visual completa de la app en un dispositivo.

Se excluyeron logotipos, retratos de plantilla, imágenes identificadas como stock
y fotos pequeñas. La procedencia oficial está documentada; no equivale a una
licencia de reutilización. El manifiesto registra que los derechos no fueron
confirmados para cada foto, para gestionar esa autorización antes de un uso
comercial público del catálogo.

## Candidatos para ampliar

- **Finca Esperanza Verde, San Ramón:** la [portada oficial](https://www.fincaesperanzaverde.net/) anuncia un nuevo restaurante y ecolodge e invita a esperar noticias de apertura. No se cargó como disponible.
- **SOLID Surf Camp, El Tránsito:** [oferta oficial](https://solidsurfnica.com/) encontrada; descarga de fotos respondió HTTP 403. Falta completar galería y ubicación precisa.
- **Mandla Oceanfront Resort, El Tránsito:** [web oficial](https://mandlaresort.com/); se obtuvieron tres fotos, pero queda pendiente contrastar pin y contacto vigente.
- **Reserva El Jaguar:** [web del establecimiento](https://www.jaguarreserve.org/ubicacion.html) y [Alcaldía de Jinotega](https://alcaldiajinotega.gob.ni/jinotega/). Se requiere una galería de mejor resolución y contacto operativo reciente.
- **Finca Las Carmelitas:** integra el [Circuito Turístico del Café presentado por INTUR](https://www.intur.gob.ni/2026/10/02/jinotega-presenta-nuevo-circuito-turistico-del-cafe/). Falta recopilar fotos específicas, contacto y coordenadas de acceso.
