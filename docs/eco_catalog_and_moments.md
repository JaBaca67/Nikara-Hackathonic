# Catálogo ECO y controles de Momentos

Investigación y carga: 7 de octubre de 2026. Se leyeron las entrevistas del museo de La Trinidad y de Nicaragua Ecoturismo proporcionadas en Downloads. Las recomendaciones sobre viveros, suelos, agua, mantenimiento de espacios públicos, brigadas pequeñas y supervisión fundamentan el catálogo.

La organización existente **Níkara** (`@nikara_hackthon`) recibió **10 actividades de demo**, una por categoría. Conserva su propietario actual y su verificación legal original. No se creó otra fundación ni se declaró un convenio con las instituciones citadas.

La jornada `PRUEBA push 2026-10-01 - borrar` de la misma organización se pasó de aprobado a pendiente para que no encabece el catálogo público. Conserva sus datos y participantes; puede volver a aprobarse si se necesita para pruebas. La cabecera ahora dice “actividades para explorar” y no atribuye verificación institucional a todas las propuestas.

Los títulos muestran el nombre de la actividad sin el prefijo “Demo”; las descripciones conservan la nota de demostración e indican que fechas y puntos de encuentro son ilustrativos. Las referencias documentan actuaciones reales; las convocatorias futuras de Níkara requieren confirmación. Las fechas del lote van del 17 de octubre al 13 de noviembre de 2026. No se inventaron participantes, asistencia, valoraciones ni coordenadas de encuentro. El municipio sí está asociado al catálogo geográfico oficial que utiliza la app.

| Categoría | Propuesta en la demo | Municipio / departamento | Actividad real de referencia |
|---|---|---|---|
| Reforestación | Reforestar el bosque de pino de Tomabú | Estelí / Estelí | [INATEC, 26/06/2019: jornada de siembra en la reserva](https://www.tecnacional.edu.ni/noticias/jornada-reforestacion-reserva-natural-tomabu/) |
| Fauna | Tortugas marinas de Quelantaro | Villa El Carmen / Managua | [INTUR, 23/01/2017: festival de protección de tortugas](https://www.intur.gob.ni/2017/01/23/realizan-festival-proteger-tortugas-marinas/) |
| Limpieza | Jornada costera en El Tránsito | Nagarote / León | [Viva Nicaragua, 03/03/2024: jornada de brigadas comunitarias](https://www.vivanicaragua.com.ni/2024/03/03/sociales/nagarote-playa-limpia-bonita/) |
| Reciclaje | Artesanía circular en San Juan de Limay | San Juan de Limay / Estelí | [MARENA, 17/09/2026: aprovechamiento de residuos de madera en Don Chico](https://www.marena.gob.ni/2026/09/17/reciclamos-en-armonia-con-la-madre-tierra/) |
| Agua y cuencas | Caminata por la cuenca del río Dipilto | Dipilto / Nueva Segovia | [MARENA, 16/08/2022: intercambio sobre gobernanza hídrica y experiencia comunitaria de Dipilto](https://www.marena.gob.ni/2022/08/16/gobierno-de-nicaragua-intercambia-experiencias-sobre-gobernanza-hidrica-local/), [cierre del taller, 18/08/2022](https://www.marena.gob.ni/2022/08/18/concluye-taller-regional-sobre-experiencias-en-el-manejo-de-cuencas-hidrograficas/) |
| Suelos y agroecología | Suelos vivos en la Serranía de Amerrisque | San Pedro de Lóvago / Chontales | [MARENA, 01/07/2022: taller agroforestal y conservación de suelos en El Juste](https://www.marena.gob.ni/2022/07/01/marena-desarrolla-taller-sobre-la-conservacion-de-los-suelos-en-chontales/) |
| Jardinería y viveros | Viveros forestales de Jinotega | Jinotega / Jinotega | [MARENA, 16/05/2023: seguimiento de viveros forestales y frutales](https://www.marena.gob.ni/2023/05/16/delegacion-marena-jinotega-brinda-acompanamiento-a-viveros-forestales-y-frutales/) |
| Educación ambiental | Clasificación de residuos en Muy Muy | Muy Muy / Matagalpa | [MARENA, 01/02/2022: capacitación sobre residuos en el Instituto Padre José Bartocci](https://www.marena.gob.ni/2022/02/01/marena-imparte-taller-para-el-manejo-de-los-raee-a-estudiantes-de-matagalpa/) |
| Monitoreo de biodiversidad | Observación de biodiversidad en Peñas Blancas | El Cuá / Jinotega | [MARENA, 30/08/2024: monitoreo de especies en el macizo](https://www.marena.gob.ni/2024/08/30/reserva-natural-macizo-de-penas-blancas-un-ecosistema-lleno-de-vida-animal/); [plan de manejo: macizo compartido con El Tuma-La Dalia y Rancho Grande](https://www.marena.gob.ni/wp-content/uploads/2023/08/37-Plan-de-Manejo-Reserva-Natural-Macizo-Penas-Blancas.pdf) |
| Saneamiento ambiental | Saneamiento ambiental en La Trinidad | La Trinidad / Estelí | [ENACAL, 12/09/2022: conexiones de alcantarillado en barrios de La Trinidad](https://www.enacal.com.ni/noticias/nuevas-np/NP12-09-2022.html) y entrevista municipal sobre inundaciones |

El renombre se guarda en `scripts/rename_eco_demo_activity_titles.sql`. El SQL apunta a las diez filas por sus UUID deterministas y a la organización Níkara; verifica que cada título conserve su valor esperado antes de actualizarlo. Una fila ajena o un título editado hace que la transacción se detenga.

Tomabú y Peñas Blancas requieren acordar el sector concreto antes de convocar visitantes. La ubicación del taller regional de cuencas fue Managua; Dipilto es la experiencia comunitaria y cuenca usada como referencia para la propuesta, no una atribución de ese taller a Níkara. Saneamiento se propone como aprendizaje y observación segura, sin operar infraestructura. Las fotografías son archivos de las fuentes citadas y no documentan jornadas ejecutadas por Níkara. No se ha comprobado una licencia de redistribución comercial de esas fotografías.

## Categorías en la app

Los nombres completos están disponibles al crear o editar actividades y en el filtro. Se preservaron Reforestación, Fauna y Limpieza para mantener compatibles los registros anteriores. La fila móvil usa etiquetas breves y conserva el nombre completo en su tooltip. Cada categoría tiene un icono propio.

En las tarjetas de **Descubre más**, la imagen lateral mide 160 px de alto (antes 118 px) para reducir el hueco visual debajo.

Fauna comprende acciones de conservación; Monitoreo se centra en observar y registrar especies. Limpieza cubre recolección de residuos; Saneamiento, prácticas e infraestructura que protegen la salud ambiental. Educación es formación, mientras Reciclaje se orienta a recuperación y transformación de materiales.

## Carga masiva

El catálogo editable está en `docs/data/eco_activity_catalog.json`. `scripts/seed_eco_activities.py` reutiliza el proyecto enlazado y obtiene sus credenciales administrativas en memoria mediante Supabase CLI. No imprime ni guarda claves. Requiere Python, las dependencias de `scripts/requirements-demo.txt` y una sesión administrativa de Supabase CLI.

```powershell
python -m pip install -r scripts/requirements-demo.txt
python scripts/seed_eco_activities.py --prepare

# Genera un plan y SQL revisable; no modifica Supabase.
python scripts/seed_eco_activities.py --organization-id 7a4feee5-cfa2-41ce-a683-fd090aac95ed --owner-id 30a57d65-a20c-407e-bd7f-d07d8c3c54da

# Ejecuta el lote preparado.
python scripts/seed_eco_activities.py --organization-id 7a4feee5-cfa2-41ce-a683-fd090aac95ed --owner-id 30a57d65-a20c-407e-bd7f-d07d8c3c54da --apply
```

`--base-date YYYY-MM-DD` cambia las fechas de registros nuevos. UUID deterministas por organización y propuesta evitan duplicados; repetir el lote preserva ediciones, fechas, políticas, participantes y propietarios existentes. Los conflictos de identidad o propietario abortan la transacción. El script exige una organización aprobada del propietario indicado; no convierte ninguna cuenta en administrador. El lote de demo se inserta aprobado para que resulte visible.

Las diez portadas se descargaron con validación TLS del sistema, se revisaron visualmente y se optimizaron a JPEG progresivo de proporción 3:2, sin ampliar imágenes pequeñas. Resoluciones: 702–1599 px de ancho; tamaños inferiores a 400 KB por portada. Storage conserva rutas con hash y el importador comprueba los bytes públicos antes de registrar actividades. `supabase/demo/eco/` contiene imágenes, inventario de Storage, plan SQL y resultado de carga; esta carpeta está excluida de Git según la política del repositorio. Si falla el SQL después de subir imágenes, el inventario permite identificar objetos sin referencia.

## Administrar Momentos

En **Detalle ECO → Momentos → Administrar Momentos**, el organizador, el propietario de la organización o un administrador de plataforma puede:

- Permitir o cerrar publicaciones de participantes.
- Limitar el total de mensajes de participantes.
- Limitar el número de cuentas distintas que publican.
- Limitar mensajes por cuenta.

Campos vacíos significan sin límite; cero y negativos se rechazan. Cerrar permite seguir leyendo, pero impide nuevos mensajes y ediciones de participantes. No borra publicaciones previas. Los administradores pueden publicar anuncios incluso con el foro cerrado y sus mensajes no consumen cupos de participantes. La actividad debe estar publicada para recibir mensajes nuevos; los demás usuarios también deben estar inscritos. Una cuenta que ya escribió puede seguir publicando al alcanzar el límite de cuentas, si conserva cupo individual y total. Borrar mensajes libera sus cupos; una cuenta deja de contar si ya no conserva mensajes.

Los cambios y publicaciones se serializan con un bloqueo de la fila de actividad. El trigger valida inserciones, incluidas solicitudes directas por API, y prohíbe cambiar autor o destino de mensajes existentes. Los conteos se leen con una función VOLATILE después del bloqueo para renovar la instantánea al competir varias publicaciones. La interfaz actualiza permisos por Realtime y los verifica otra vez antes de abrir el editor y subir fotos. El trigger sigue siendo la autoridad final si se cambia la política durante la composición.

La migración local `supabase/sql/043_eco_moment_controls.sql` ya fue aplicada al proyecto enlazado. Las funciones internas no tienen ejecución para PUBLIC, anon ni authenticated. Solo authenticated puede ejecutar las RPC públicas y su autorización se valida con `auth.uid()`. Leer el foro sigue disponible al público. Las reseñas de negocios conservan su funcionamiento; sus autores y destinos también quedan inmutables al editar.

## Verificación

- Validación de Postgres con PGlite: cierre, límites, cuentas existentes, administradores, inscripción, edición, destinos, grants y repetición de la migración.
- Prueba en Supabase con rol authenticated y RLS real: cierre y los tres límites rechazaron inserciones, cuentas ajenas no configuraron políticas, el organizador pudo publicar, una reseña de negocio no pudo trasladarse al foro. Todos los datos y cambios de prueba se revirtieron mediante ROLLBACK.
- Lectura anónima: diez actividades aprobadas, diez categorías, organización y propietario correctos, municipios y portadas públicos, integridad SHA-256, proporción y CORS.
- Importación repetida: conserva los registros existentes.
- Pruebas Flutter: validación de límites, persistencia de configuración, error de conexión y cabecera ECO en tamaños móviles. `flutter analyze --no-pub lib test` sin incidencias. El análisis global también recorre proyectos temporales preexistentes en `build/`, cuyos imports no resuelven.
- Android físico no conectado durante esta sesión. La revisión visual utiliza Chrome a 390 × 844 px; el catálogo consulta Supabase real y la hoja de configuración usa datos simulados sin guardar cambios.

```powershell
node scripts/validate_eco_moment_controls.mjs
python -m unittest discover -s scripts -p test_seed_eco_activities.py -v
C:\flutter\bin\flutter.bat test test/eco_moment_policy_test.dart test/eco_header_test.dart
```
