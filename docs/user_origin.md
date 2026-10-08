# Procedencia y perfil público

La procedencia se declara explícitamente: no se deduce del teléfono, GPS o IP.
El registro exige **Nicaragüense** (Nicaragua, ciudad y municipio) o
**Extranjero** (país distinto de Nicaragua). El catálogo y las 250 banderas
se incluyen localmente; fuente: [Flagpedia](https://flagpedia.net/download/api).

## Selección con búsqueda

Registro, completar procedencia y edición de perfil permiten escribir en el
mismo campo. Mientras se escribe aparece una lista de sugerencias, sin abrir
otra pantalla ni un buscador separado. Solo **seleccionar** un resultado guarda
el valor del catálogo. Editar o borrar una selección exige volver a elegir una
opción antes de guardar. La búsqueda no distingue mayúsculas ni tildes y funciona
sin conexión.

Para Nicaragua, un único campo **Ciudad / municipio de origen** usa un catálogo
de 153 municipios y sus cabeceras. La selección completa ambos nombres con la
pareja canónica correspondiente: Masaya → Masaya, Malpaisillo → Larreynaga,
Bilwi → Puerto Cabezas. El departamento/región aparece para distinguir lugares
y también permite filtrar la búsqueda. Se prioriza la coincidencia con la
ciudad sobre las coincidencias con el departamento. No es un catálogo de todos
los barrios, comarcas o comunidades; los visitantes eligen su municipio de origen.

Fuentes del catálogo: [códigos municipales de INIDE](https://www.inide.gob.ni/docu/censos2005/CifrasMun/tablas_cifras.htm)
y nombres/cabeceras de la Ley 59 consolidada, [La Gaceta 189 del 13/10/2021](https://cam.gob.ni/wp-content/uploads/2025/04/1.-LEY-1048-LEY-DEL-DIGESTO-JURIDICO-NICARAGUENSE-DE-LA-MATERIA-MUNICIPAL.pdf),
páginas 10022–10027. Las variantes sirven para buscar, mientras los nombres
canónicos son los que se guardan en `origin_city` y `origin_municipality`.
El mismo catálogo se incluye en Dart y PostgreSQL; la verificación SQL compara
las 153 parejas para evitar diferencias entre la app y la base de datos.

Para extranjeros, al escribir el país aparecen sugerencias en el mismo formulario; las
sugerencias muestran su bandera y se guarda su código, por ejemplo **ES**
para España. Nicaragua se elige mediante la condición Nicaragüense.

Negocios, fundaciones y jornadas ECO reutilizan el mismo selector de catálogo
en su formulario de ubicación. Ver [destinos y formularios geográficos](discovery_geography.md)
y la migración adicional 042 para esas tablas.

## Instalación

Ejecutar `supabase/sql/039_user_origin_and_public_profile.sql` en el SQL Editor
de Supabase **antes de distribuir la app actualizada**. La migración es
transaccional y se puede repetir. `supabase/` permanece fuera de Git por la
configuración existente del proyecto; respaldar este SQL junto al resto.

Para el formulario con autocompletado, ejecutar además
`supabase/sql/041_origin_place_catalog.sql` **después de los dos 039 y del 040**.
No se modificaron las migraciones anteriores. Este SQL es transaccional y
repetible; agrega el catálogo de solo lectura `origin_places`, una clave
foránea y validación de las escrituras de procedencia. Mantiene las columnas
existentes de perfiles y no requiere enviar un campo nuevo desde el cliente.

La migración normaliza parejas antiguas solo cuando coinciden inequívocamente
con un lugar del catálogo. Conserva los valores no reconocidos o ambiguos;
la app solicita seleccionarlos de nuevo al entrar. La clave foránea se crea
con `NOT VALID` para conservar estas filas históricas. Nuevos registros y
escrituras explícitas del origen rechazan valores fuera del catálogo, aunque
intenten reenviar una pareja histórica. Cambios ajenos al origen no borran
los datos antiguos.

Las cuentas existentes mantienen valores nulos hasta completar el formulario.
El trigger exige origen válido al crear cuentas con contraseña; los proveedores
sociales pueden crear perfiles incompletos y la app solicita el origen al entrar.
La compuerta está en `MainLayout`, por lo que cubre inicio con contraseña,
Google/Apple/Facebook, sesiones restauradas y cambios de cuenta. No monta las
pestañas ni permite continuar al fallar la carga o el guardado. Los invitados
siguen pudiendo explorar sin declarar procedencia.

## Persistencia y privacidad

`profiles` agrega `residence_type`, `origin_country_code`, `origin_city`,
`origin_municipality`, `public_display_name`, `bio`, `show_origin` y
`show_origin_details`. País se guarda como código del catálogo; ciudad y
municipio como nombres canónicos de la pareja seleccionada. Los campos
locales se limpian al cambiar a extranjero. Las restricciones validan países,
combinaciones y longitudes. RLS mantiene la edición limitada al propietario;
rol y puntos continúan protegidos.

`public_profiles.full_name` resuelve el nombre público, con el nombre de
registro como respaldo. La vista publica foto, presentación y procedencia
según la visibilidad elegida. Ocultar procedencia devuelve NULL en **todos**
los campos de origen; ocultar detalles devuelve NULL en ciudad y municipio,
conservando la bandera de Nicaragua. Los datos declarados permanecen en la
tabla privada. Correo y teléfono no se agregan a la vista pública.

Reseñas y participantes ECO leen esta vista, por lo que nuevas consultas
muestran nombre, foto y procedencia actuales. Las pantallas ya abiertas se
actualizan al recargarlas. El acceso a edición y vista previa está en Perfil y
en el perfil público del propio usuario. Nombre público: máximo 80 caracteres;
presentación: 300; ciudad y municipio: 100 cada uno.

## Verificación

```powershell
flutter analyze lib test
flutter test
npm.cmd install --prefix build/origin_sql_validation @electric-sql/pglite
node scripts/validate_origin_migration.mjs
```

Los tests Flutter cubren datos antiguos, validación por residencia, banderas,
privacidad de la vista del propietario, compuerta, errores de red/guardado e
interfaces estrechas con texto grande. La comprobación de SQL ejecuta las
migraciones 039 y 041 dos veces en PostgreSQL local con PGlite, con roles y RLS: valida
trigger, restricciones, permisos, protección de perfiles ajenos y máscaras de
la vista pública. No sustituye aplicar y comprobar la migración en Supabase.
