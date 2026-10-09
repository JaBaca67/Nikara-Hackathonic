# Guion de apoyo: modelo ER de Níkara hasta 2FN

## Explicación general

Este diagrama representa la base de datos relacional de Níkara en PostgreSQL y
organiza sus entidades por áreas funcionales. Se presenta hasta la segunda
forma normal (2FN): además de las tablas operativas, muestra tablas propuestas
para separar listas de valores que en el esquema físico están guardadas como
arreglos. Esas tablas nuevas se identifican con **[2FN]**; son una propuesta
académica y todavía no existen en Supabase.

Las líneas se leen desde la tabla padre hacia la tabla relacionada. **1:N**
significa que un registro padre puede relacionarse con varios registros hijos;
**1:1** significa que se relaciona con uno como máximo. El campo junto a la
línea identifica la FK en la tabla hija. **PK** identifica la clave primaria,
**FK** la clave foránea y **UQ** una restricción única.

Las referencias **lógicas** con línea punteada no son FKs declaradas por
PostgreSQL: el tipo o discriminador de la fila indica si el identificador apunta
a un negocio, una actividad u otro recurso. La relación de origen de perfil es
compuesta: `origin_city` y `origin_municipality` se interpretan en conjunto.
`auth.users` es una entidad externa de Supabase y aquí solo se muestra su ID.

## Recorrido sugerido

1. **Identidad y cuentas:** `profiles` representa la información pública y de
   cuenta; desde ella se relacionan propietarios, organizadores, autores y
   usuarios de otras áreas. El catálogo `origin_places` normaliza la ubicación.
2. **Negocios y ECO:** los negocios y actividades tienen sus datos principales;
   sus listas (fotos, servicios, prácticas, requisitos) se separan en entidades
   hijas marcadas `[2FN]`. `eco_participants` conecta usuarios con actividades.
3. **Rutas y viajes:** `routes` contiene una ruta y `route_stops` sus paradas;
   `route_images` separa las imágenes de la ruta.
4. **Interacción social y avisos:** reseñas, favoritos y notificaciones conectan
   usuarios con recursos. Algunas conexiones son polimórficas y por eso se
   distinguen de las FKs físicas.

## Nota sobre la normalización

En 1FN, una celda debe guardar un valor atómico. Por eso cada arreglo repetible
se convierte en una tabla hija. En las nuevas tablas con clave compuesta, cada
valor depende de la clave completa; ese es el criterio de 2FN aplicado aquí.
Las claves compuestas ya existentes también se conservan. El diagrama no afirma
que el esquema desplegado haya cambiado: documenta la propuesta de normalización
hasta 2FN.

## Recomendación de presentación

Usa `nikara_modelo_2fn.drawio` en diagrams.net. La página **Vista general**
explica el mapa completo y las páginas siguientes permiten presentar cada área
con menos conexiones visibles. Los colores corresponden a las áreas indicadas
en la leyenda. Para que las líneas se lean mejor, presenta primero la vista
general y luego cambia a las páginas por módulo; evita reducir la vista general
hasta que quepa toda en una diapositiva.

En drawDB, las etiquetas de relación ahora muestran cardinalidad y campo de FK
(`1:N · owner_id`) en lugar de nombres internos largos. Si aún se superponen,
desactiva **View → Show relationship labels**: las líneas y su cardinalidad
permanecen y el campo FK sigue indicado dentro de las tablas.
