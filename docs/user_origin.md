# Procedencia y perfil público

La procedencia se declara explícitamente: no se deduce del teléfono, GPS o IP.
El registro exige **Nicaragüense** (Nicaragua, ciudad y municipio) o
**Extranjero** (país distinto de Nicaragua). El catálogo y las 250 banderas
se incluyen localmente; fuente: [Flagpedia](https://flagpedia.net/download/api).

## Instalación

Ejecutar `supabase/sql/039_user_origin_and_public_profile.sql` en el SQL Editor
de Supabase **antes de distribuir la app actualizada**. La migración es
transaccional y se puede repetir. `supabase/` permanece fuera de Git por la
configuración existente del proyecto; respaldar este SQL junto al resto.

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
`show_origin_details`. País se guarda como código del catálogo; los campos
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
interfaces estrechas con texto grande. La comprobación de SQL ejecuta la
migración dos veces en PostgreSQL local con PGlite, con roles y RLS: valida
trigger, restricciones, permisos, protección de perfiles ajenos y máscaras de
la vista pública. No sustituye aplicar y comprobar la migración en Supabase.
