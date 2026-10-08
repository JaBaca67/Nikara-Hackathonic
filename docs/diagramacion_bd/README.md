# Diagramación de la base de datos de Níkara

## Archivos preparados

| Archivo | Uso |
| --- | --- |
| [nikara_modelo_2fn.drawdb.json](nikara_modelo_2fn.drawdb.json) | Importar en drawDB, mover tablas y editar campos. |
| [nikara_modelo_2fn.drawio](nikara_modelo_2fn.drawio) | Abrir en diagrams.net: diagrama general y seis páginas por módulo; incluye relaciones lógicas y claves compuestas. |
| [nikara_modelo_2fn.dbml](nikara_modelo_2fn.dbml) | Importar o pegar en dbdiagram.io; representa claves compuestas nativamente. Las referencias polimórficas se explican en notas. |
| [nikara_esquema_actual.drawdb.json](nikara_esquema_actual.drawdb.json) | Esquema físico antes de normalizar. |
| [nikara_esquema_actual.drawio](nikara_esquema_actual.drawio) | Diagrama editable del esquema físico. |
| [nikara_esquema_actual.dbml](nikara_esquema_actual.dbml) | Esquema físico para dbdiagram.io. |
| [consultar_esquema_real_supabase.sql](consultar_esquema_real_supabase.sql) | Consulta de solo lectura para exportar el catálogo real de Supabase en JSON. |
| [supabase_api_verificacion.json](supabase_api_verificacion.json) | Resultado de la comprobación del proyecto Supabase vinculado. |
| [guion_presentacion_2fn.md](guion_presentacion_2fn.md) | Explicación general, significado de cardinalidades y recorrido recomendado para exponer el modelo. |

El modelo académico contiene **27 entidades de la aplicación + `auth.users`
como entidad externa = 28 entidades**. Tiene **42 relaciones basadas en claves
foráneas** (incluidas las propuestas para las nuevas tablas) y **8 referencias
lógicas polimórficas**, para un total de **50 relaciones**. `auth.users` solo
muestra `id`, no pretende describir todo el esquema interno de Supabase Auth.

## Herramientas recomendadas

1. **drawDB** — https://www.drawdb.app/editor. Recomendado para acomodar tablas
   y editar sus atributos con una interfaz dedicada a bases de datos. Su editor
   abierto funciona sin cuenta y guarda el trabajo en el navegador; exportar
   JSON permite conservar posiciones y continuar en otro dispositivo.
2. **dbdiagram.io** — https://dbdiagram.io/d. Recomendado si se prefiere mantener
   la estructura como texto DBML y generar el diagrama automáticamente. Permite
   mover tablas y exportar imágenes. El plan gratuito ofrece diagramas públicos;
   la privacidad pertenece a planes de pago.
3. **diagrams.net (draw.io)** — https://app.diagrams.net/. Recomendado para la
   presentación académica: control del diseño, varias páginas y relaciones
   compuestas representadas con un único conector. Se entrega ya dibujado, así
   que no hay que crear cajas ni flechas desde cero.

Fuentes oficiales consultadas el 8 de octubre de 2026:
[drawDB](https://drawdb-io.github.io/docs/),
[dbdiagram](https://dbdiagram.dev/pricing),
[privacidad de dbdiagram](https://docs.dbdiagram.io/access-control/),
[diagrams.net](https://app.diagrams.net/).

## Importar y acomodar en drawDB

1. Abrir https://www.drawdb.app/editor.
2. Crear un diagrama vacío y seleccionar **PostgreSQL**. Es importante que el
   motor coincida con el del archivo.
3. En **File / Archivo → Import / Importar**, elegir **JSON** y seleccionar
   `nikara_modelo_2fn.drawdb.json`; confirmar la importación.
4. Para quitar las frases largas de las líneas sin editar una relación a la vez,
   abrir **View → Show relationship labels** y desmarcar esa opción. Conserva
   los conectores y sus cardinalidades. Si también quieres ocultar los círculos
   `1`/`n`, desmarca **View → Show cardinality**. Usa **View → Fit window** para
   encuadrar el diagrama.
5. Las tablas ya tienen posiciones y agrupación por dependencias. Solo si quieres
   personalizar el diseño, arrástralas por su cabecera;
   los conectores siguen a sus campos. Los colores identifican los módulos.
6. Guardar el trabajo y exportar un **JSON** después de acomodarlo. Para entregar
   una imagen, usar las opciones de exportación del editor.

Las etiquetas del JSON ahora son cortas: cardinalidad y columna FK, por ejemplo
`1:N · owner_id`; las referencias sin FK SQL llevan `Lógica` y las compuestas
se identifican como `FK compuesta`. drawDB las ubica en el centro del conector,
así que pueden cruzarse en una vista general densa. La opción **Show
relationship labels** oculta todos esos textos con un clic; las FK siguen
conectadas y los nombres de campo conservan la columna correspondiente. Esta
opción de `View` cambia únicamente la visualización. [Ayuda oficial de drawDB](https://drawdb-io.github.io/docs/customizing-editor).

Para una presentación con zonas de color y recorrido por áreas, recomendamos
abrir el `.drawio`: incluye una vista general y páginas separadas por módulo.
El guion [guion_presentacion_2fn.md](guion_presentacion_2fn.md) resume cómo
explicar las entidades, las relaciones y la normalización.

Los conectores cuyo nombre comienza con `LOGICA__` representan referencias
polimórficas; **no son claves foráneas SQL**. Los dos conectores
`COMPUESTA_1_DE_2__` y `COMPUESTA_2_DE_2__` representan **juntos una sola FK**:
`profiles(origin_city, origin_municipality)` referencia
`origin_places(city, municipality)`. No son dos restricciones independientes.
El formato visual de drawDB utiliza conectores por campo, por eso se entrega
también el `.drawio` con esa relación como un único conector.

No usar el SQL exportado desde estos JSON como migración: los conectores lógicos
y la representación por campos de la FK compuesta tienen fines visuales.
Los DBML omiten las relaciones lógicas y conservan la FK compuesta real, pero
tampoco son copias completas de DDL: no incluyen todas las políticas, triggers,
valores predeterminados, reglas CHECK ni acciones de borrado del servidor.

## Abrir en diagrams.net

1. Abrir https://app.diagrams.net/ y elegir dónde guardar el archivo.
2. Usar **Archivo → Abrir desde → Dispositivo** y seleccionar
   `nikara_modelo_2fn.drawio`.
3. Usar las pestañas inferiores: vista general, Identidad y cuentas, Negocios,
   Módulo ECO, Rutas y viajes, Interacción social, Avisos y automatización.
4. Mover cada tabla como una unidad y editar su contenido con doble clic.
5. Exportar las páginas necesarias a PDF o imágenes para la entrega.

Cada página de módulo conserva también las entidades relacionadas de otros
módulos para que sus relaciones no queden cortadas. Las referencias polimórficas
son líneas naranjas punteadas; las demás relaciones muestran cardinalidad.

## Importar en dbdiagram.io

Abrir https://dbdiagram.io/d, crear un diagrama e importar
`nikara_modelo_2fn.dbml` o pegar su contenido en el editor. Las tablas y sus
relaciones se generan automáticamente. Las claves primarias compuestas aparecen
en `indexes`; la relación compuesta del catálogo de origen utiliza una sola
declaración `Ref`. Las referencias lógicas aparecen en las notas de la tabla.

## Fuente y alcance del esquema

Se reconstruyeron **49 archivos SQL locales**, desde `001` hasta `048` (hay dos
archivos con el prefijo `039`). La aplicación utiliza **PostgreSQL en Supabase**,
por lo que corresponde un **modelo entidad–relación de BD relacional**.

El catálogo compartido enumera **20 tablas en `public`**: 18 tablas operativas,
la copia auxiliar `reviews_backup` y `spatial_ref_sys`, instalada por PostGIS.
La API confirmó sus nombres y columnas mediante consultas de cero filas. Las
definiciones base de
`profiles` y `businesses` proceden de la documentación del proyecto, porque esas
tablas fueron creadas desde el dashboard y sus migraciones locales solo las
amplían.

### Contrastar con el catálogo desplegado

Para verificar el proyecto Supabase activo, abre su **SQL Editor**, ejecuta
[`consultar_esquema_real_supabase.sql`](consultar_esquema_real_supabase.sql) y
copia el JSON de la columna `supabase_schema_snapshot` en un archivo UTF-8. La
consulta inspecciona `pg_catalog` y devuelve tablas, vistas, columnas, tipos,
valores predeterminados, PK, claves UNIQUE, FK compuestas, destino y acción de
borrado de cada FK, estado de validación y enums públicos. No lee datos de las
tablas; de `auth.users` expone solo el nombre y tipo de `id` para permitir
verificar las FK sin divulgar datos de cuentas. Verifica que el resultado no
sea vacío y que contenga la propiedad `relations`; el archivo no necesita
incluir credenciales.

Un snapshot auténtico de la instancia requiere acceso a la conexión o que alguien
con acceso al Dashboard ejecute y comparta este resultado. En este entorno no
hay una clave de administración ni contraseña de base configuradas y la URL local
del pooler no contiene contraseña; por eso la API pública no puede entregar el
catálogo PostgreSQL completo.

También se verificó la instancia real `taxtvsqfpmrrkvezwwpb` con la clave pública
de la aplicación. `SELECT ... LIMIT 0` confirmó **las 18 tablas operativas, la
tabla `reviews_backup`, `spatial_ref_sys` y `profiles.created_at`**; todas las
consultas regresaron cero filas. La API pública no permite enumerar posibles columnas adicionales ni
obtener los tipos y las restricciones directamente. En consecuencia, el
snapshot del SQL Editor sigue siendo la verificación final del catálogo.

La API de PostgREST pudo resolver **29 de las 30 relaciones con tablas públicas**
en el catálogo consultado. No resolvió `routes.cloned_from_route_id → routes.id`,
pese a que la migración `011_routes.sql` declara la FK. Esa relación se resalta
en rojo punteado: el API por sí sola no permite distinguir entre una FK que falte
en la base y una caché PostgREST desactualizada. Confírmala con la consulta
`pg_catalog` de arriba.

Se incorporaron detalles ausentes en el modelo anterior:

- La migración `048`: `routes.catalog_name` y `routes.owner_id` nullable.
- La relación recursiva `routes.cloned_from_route_id → routes.id`.
- La FK compuesta de procedencia, declarada **NOT VALID** en `041`: los registros
  históricos pueden incumplirla aunque exista la restricción.
- `profiles.created_at`, que aparece en el inventario compartido y se confirmó
  directamente mediante la API.
- `reviews_backup`, copia histórica sin PK ni UNIQUE, está en el esquema físico.
  Se excluye del modelo operativo 2FN: sin una clave declarada, no se puede
  identificar cada fila como entidad sin inventar una.
- `spatial_ref_sys`, instalado por PostGIS, es de infraestructura y no forma
  parte del modelo ER de la aplicación; se documenta aquí, aunque no se dibuja
  entre las entidades del negocio.
- `profiles.id`, `legal_identities.user_id` y `business_posts.owner_id` referencian
  directamente `auth.users.id`; no se sustituyen por FKs a `profiles`.
- Las tres claves primarias compuestas existentes y las restricciones UNIQUE.

## Justificación de 1FN y 2FN

Para la interpretación académica de 1FN, cada lista multivaluada se descompone
en filas individuales:

| Atributo del esquema físico | Tabla propuesta | Clave primaria |
| --- | --- | --- |
| `businesses.photos` | `business_photos` | `(business_id, position)` |
| `businesses.amenities` | `business_amenities` | `(business_id, amenity)` |
| `businesses.activities` | `business_activities` | `(business_id, activity)` |
| `businesses.eco_practices` | `business_eco_practices` | `(business_id, practice)` |
| `businesses.day_pass_includes` | `day_pass_items` | `(business_id, item)` |
| `eco_activities.requirements` | `eco_activity_requirements` | `(activity_id, requirement)` |
| `reviews.media_urls` | `review_media` | `(review_id, position)` |
| `routes.image_urls` | `route_images` | `(route_id, position)` |
| `origin_places.aliases` | `origin_place_aliases` | `(municipality_code, alias)` |

En las listas ordenadas, `position` pertenece a la PK: una posición solo
identifica una foto dentro de su entidad. La URL depende de **ambas columnas**.
Las listas sin orden se interpretan como conjuntos sin elementos duplicados;
todos sus atributos pertenecen a la PK y no hay atributos no clave.

La **2FN** exige 1FN y que cada atributo no primo dependa de la totalidad de
cada clave candidata, sin dependencias parciales. Para las claves compuestas
heredadas, el modelo asume estas reglas de negocio:

- `eco_participants(activity_id, user_id)`: `joined_at` describe la inscripción
  de una persona a una jornada, no a cualquiera de ellas por separado.
- `notification_event_receipts(user_id, event_key)`: `created_at` corresponde al
  registro del evento para ese usuario.
- `notification_completed_trips(user_id, trip_id)`: negocio y fechas describen
  el viaje identificado dentro de la cuenta. Se asume que `trip_id` se identifica
  en el ámbito del usuario; si por regla de negocio fuese globalmente único,
  habría que declararlo y revisar esa dependencia.

Las claves alternativas no se ignoran: `origin_places(city, municipality)` y
`user_favorites(user_id, item_type, item_id)` son UNIQUE sobre columnas NOT NULL.
Bajo la semántica del catálogo y de favoritos, sus atributos no primos dependen
de la pareja del lugar y de la identificación completa del favorito. Las
restricciones UNIQUE que contienen NULL, como la de `route_stops`, no garantizan
por sí mismas una clave candidata relacional.

La ausencia de dependencias parciales se fundamenta en estas reglas de negocio;
no puede demostrarse únicamente por observar las PK de un script SQL.

Las copias de datos de las paradas y de organizadores se conservan: si funcionan
como duplicados sincronizados pueden introducir dependencias transitivas de
3FN; si son snapshots históricos su semántica es diferente. La entrega solicita
hasta 2FN. No se aplicaron cambios a la base desplegada.

## Regenerar los archivos

```powershell
python scripts/er_diagram/extract_schema.py
python scripts/er_diagram/model_2nf.py
python scripts/er_diagram/export_mermaid.py
python scripts/er_diagram/export_web.py
```

Estos comandos solo escriben archivos locales de documentación.
