# Notificaciones por acciones y horario

Las automatizaciones están implementadas y probadas localmente. La activación
en el proyecto remoto está pendiente: la credencial administrativa disponible
respondió HTTP 401. La app mantiene las confirmaciones ECO existentes mientras
se aplica la migración.

| Acción | Aviso preparado | Al tocarlo |
| --- | --- | --- |
| Guardar el primer negocio favorito | Observador Alado | Perfil e insignias |
| Guardar tres negocios favoritos | Guardián del Bosque | Perfil e insignias |
| Publicar la primera reseña de un negocio | Viajero Consciente | Perfil e insignias |
| Completar viajes confirmados por la app: 1, 3 y 5 | Protector del Lago, Cultura Viva y Escalador Eco | Perfil e insignias |
| Llegar por primera vez a un negocio y obtener su postal | «¡Ganaste una nueva postal!» | Colección del pasaporte |
| Inscribirse en una jornada ECO | Confirmación con fecha/lugar y preparación con requisitos | Jornada |
| Faltar 24 horas o 2 horas para una jornada inscrita | Recordatorio con fecha y lugar | Jornada |
| Cambiar fecha o lugar de una jornada inscrita | Aviso de cambios | Jornada |
| Dejar de publicar una jornada inscrita | Aviso de que ya no está disponible | Informativo |
| Pasar una o dos horas, elegidas al azar por cuenta | Recomendación de un negocio aprobado | Perfil del negocio |

Ejemplos: «¡Nuevo logro: Protector del Lago!», «Tu visita a \"Café Uno\" ya
tiene su sello en tu pasaporte», «Tu jornada ECO comienza pronto» y
«Descubre \"Taller Dos\" en Masaya. Explora su perfil y guárdalo para tu próxima visita».
Los nombres, fechas y lugares proceden de los datos reales. Los requisitos ECO
se resumen a los primeros tres; el detalle conserva las indicaciones completas.

Cada logro y postal se avisa una sola vez por cuenta, incluso si el usuario
borra la notificación o la app reintenta. Una nueva visita al mismo negocio
cuenta como viaje, pero no entrega otra postal. Las inscripciones ECO usan un
recibo por participación: abandonar y volver a inscribirse permite una nueva
confirmación. No se envían recordatorios de jornadas pasadas, no aprobadas o abandonadas.
Si la inscripción ocurre a menos de dos horas del inicio, solo corresponde el
recordatorio de dos horas. Si se cambia la fecha, los recordatorios se calculan
otra vez para la fecha nueva.

Las recomendaciones comienzan una o dos horas después de abrir Inicio con una
sesión registrada tras la activación del servidor. Cada envío vuelve a elegir
el siguiente intervalo. Se evita recomendar consecutivamente el mismo negocio
cuando existen alternativas aprobadas. El trabajo revisa pendientes cada cinco
minutos; el envío puede demorarse hasta ese intervalo, además de la entrega de
FCM. No se acumulan envíos si el trabajo estuvo detenido. Los invitados no se
inscriben en estas recomendaciones.

Todas las automatizaciones insertan filas en `notifications`; el webhook
existente `on_notification_created` y la función `send-push` las entregan al
teléfono mediante FCM, incluso con la app en segundo plano o sin proceso activo.
El dispositivo debe tener token registrado y permiso nativo para notificaciones.
La entrega nativa de esta cadena se verificó antes de esta ampliación; los nuevos
disparadores aún necesitan una prueba remota después de aplicar los scripts.
Al llegar un push con la app abierta se actualizan la bandeja y la campana.

El pasaporte sigue guardado en el teléfono. La app sincroniza únicamente los
eventos de viajes después de persistirlos y al cargar Inicio, por lo que puede
reintentar un envío fallido sin perder la postal. Los viajes anteriores se
sincronizan al abrir Inicio y pueden generar avisos pendientes. La confirmación
GPS pertenece al flujo de llegada de la app; este RPC de demostración no añade
una verificación GPS independiente en el servidor.

## Activar en Supabase

1. Abrir el SQL Editor del proyecto de Níkara.
2. Ejecutar `supabase/sql/045_action_notification_automations.sql`.
3. Ejecutar `supabase/sql/046_schedule_notification_automations.sql`.
4. Verificar que la última consulta devuelve
   `nikara-notification-automations`, `*/5 * * * *` y `active = true`.
5. Abrir Inicio en el teléfono. La primera recomendación queda programada para
   dentro de una o dos horas; guardar un favorito o completar una llegada permite
   comprobar los avisos por acciones antes.

También se preparó `supabase/activate_action_notifications.sql`, que combina
ambos scripts en el orden correcto para copiarlo una sola vez al SQL Editor.
Se requiere el esquema actual, incluido el webhook de push de 033. Los scripts
se pueden ejecutar de nuevo sin duplicar los disparadores ni el trabajo cron.

Para pausar las recomendaciones de una cuenta desde el SQL Editor:

```sql
update public.notification_automation_settings
set enabled = false where user_id = 'UUID_DE_LA_CUENTA';
```

Volver a abrir Inicio conserva esa pausa. Para detener el trabajo completo:

```sql
select cron.unschedule('nikara-notification-automations');
```

## Verificación local

```powershell
flutter test --no-pub test/notification_demo_test.dart test/eco_participation_test.dart test/notifications_screen_test.dart test/passport_service_test.dart test/notification_refresh_test.dart
npm install --prefix build/notification-sql-tests --no-audit --no-fund @electric-sql/pglite
node scripts/test_notification_automations.mjs
```

Las pruebas SQL ejecutan la migración real en PostgreSQL local y verifican
deduplicación, aislamiento por cuenta, permisos, frecuencia, selección de
negocios y el ciclo de inscripciones/cambios/recordatorios ECO. No envían push.
El cron se verifica en Supabase después de aplicar 046.

El 2026-10-08 pasaron 54 pruebas Flutter y 18 verificaciones SQL. El análisis de
los archivos modificados no encontró problemas. La versión debug final quedó
instalada en el Samsung A56 (`R5GYB58K0QH`), conservando la sesión y su token FCM
registrado. La inspección visual final quedó pendiente porque el teléfono tenía
el bloqueo seguro activo; no se intentó evadirlo.

Los archivos de `supabase/` se mantienen fuera de git por la decisión existente
del proyecto; conservar una copia privada de los scripts junto con el backend.
