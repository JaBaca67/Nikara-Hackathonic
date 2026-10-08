# Procedencia y destinos de exploración

El origen del perfil, el destino del viaje y la posición del dispositivo son
datos distintos. Elegir un destino no modifica el perfil ni el GPS.

## Formularios del catálogo

- Registro de cuenta, completar procedencia y editar perfil: país de origen
  seleccionable con búsqueda para extranjeros; ciudad/cabecera y municipio
  canónicos para nicaragüenses. Escribir en la búsqueda no crea un valor.
- Negocios, fundaciones y jornadas ECO, al registrar y editar: comparten
  `NicaraguaLocationFormFields`, con país Nicaragua y selectores de departamento
  y ciudad/municipio con autocompletado en el mismo campo: se escribe y se elige
  una sugerencia, sin abrir otra pantalla. La dirección o referencia sigue siendo
  un dato separado.
- La selección guarda un `municipality_code` del catálogo del 041, que identifica
  también el departamento, municipio y cabecera. No hay tres cadenas libres.
- El catálogo cubre los municipios y cabeceras de Nicaragua, no todas sus
  comunidades ni ciudades extranjeras. El país de un visitante extranjero no
  determina la ubicación de su negocio, fundación o actividad.

## Filtros y cercanía

El botón de filtros junto a la búsqueda de Inicio abre el selector de destino y
la ordenación (recientes/cercanos). No hay un botón adicional «Explorar destino»
en Inicio ni en ECO. En ECO, el botón de filtros junto a la búsqueda abre el
selector territorial; ambos comparten el destino
durante la sesión. Estelí departamento incluye La Trinidad; Estelí municipio no.
Los destacados y listados respetan territorio, categoría y búsqueda.

«Cerca de ti» usa el catálogo completo y la ubicación física, independientemente
del destino elegido. Ordena por distancia geográfica, descarta coordenadas
inválidas y muestra hasta seis lugares de menor a mayor distancia, sin selector
de radio. Sin lugares con coordenadas válidas se oculta la sección; sin ubicación
ofrece activarla. La ubicación se renueva al refrescar,
al volver a primer plano y cada dos minutos mientras la aplicación está activa.
Se descartan ubicaciones antiguas, sin permisos o demasiado imprecisas.
Las distancias son en línea recta, no recorridos por carretera.

## Base de datos

Ejecutar `supabase/sql/042_discovery_geography.sql` después del 041. Agrega el
código municipal a negocios, fundaciones y jornadas, con FK e índices. Es
transaccional y repetible. No modifica la IA ni el SQL ya ejecutado del 041.

El backfill reconoce nombres y alias completos sin tildes. En ECO reconoce
segmentos completos separados por comas, puntos medios o saltos de línea.
No asigna municipios a localidades desconocidas ni a resultados ambiguos
(por ejemplo Wiwilí sin departamento). Los registros sin código siguen visibles
sin filtro territorial; deben completar ubicación en el editor para filtrarlos.
Las fundaciones antiguas no tenían ubicación y necesitan esa selección.

Validación local de la migración: `node scripts/validate_discovery_migration.mjs`
(requiere la instalación PGlite utilizada por `validate_origin_migration.mjs`).
