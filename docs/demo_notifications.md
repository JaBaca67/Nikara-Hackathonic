# Notificaciones de demostración

Con una sesión iniciada, abrir **Inicio** carga dos mensajes de bienvenida y
hasta tres recomendaciones de negocios aprobados del catálogo. Tocar una
recomendación abre el perfil del negocio. El lote se guarda una vez por cuenta;
marcarlo como leído o recargar Inicio no vuelve a enviarlo. Los invitados no
reciben avisos. Si aún no hay negocios, las recomendaciones se completan en una
carga posterior.

Al tocar **Unirme** en una jornada ECO y guardar correctamente la inscripción,
se generan dos avisos: confirmación con la fecha y el lugar reales, e
indicaciones con los requisitos de la jornada. Ambos abren su detalle. Una
inscripción fallida o repetida no genera avisos. Si falla la entrega de las
notificaciones, la inscripción continúa confirmada.

Los mensajes preparados están en
`lib/features/notifications/domain/models/notification_message.dart`.
No se inventan promociones, precios ni horarios de los negocios. Las
indicaciones ECO llegan al unirse. Los recordatorios futuros y los avisos por
logros y postales se describen en [action_notifications.md](action_notifications.md).

Las filas se insertan en la tabla existente `notifications`. La campana se
actualiza mediante `NotificationService.revision` y el webhook de push existente
entrega las mismas filas por FCM si el dispositivo tiene un token registrado y
permiso para notificaciones. El lote inicial no requiere migraciones; las
automatizaciones por acciones y por horario requieren los scripts 045 y 046.

Para repetir el lote completo durante otra demostración, iniciar sesión con
otra cuenta. Las notificaciones de inscripción se pueden mostrar al unirse a
otra jornada o después de abandonar y volver a unirse.

Validación:

```powershell
flutter test test/notification_demo_test.dart test/eco_participation_test.dart test/notifications_screen_test.dart
flutter analyze
```

## Verificación de push en Android — 2026-10-08

Se comprobó la entrega real en el Samsung A56 (`R5GYB58K0QH`, Android 16),
insertando un aviso para la cuenta activa en `notifications` en cada escenario:

| Estado de Níkara | Resultado observado en Android |
| --- | --- |
| Abierta | `Prueba push abierta 1791476683`, 10:24:45 |
| En segundo plano | `Prueba push fondo 1791476700`, 10:25:03 |
| Sin proceso activo, después de `am kill` | `Prueba push cerrada 1791476744`, 10:25:58 |

Horarios del teléfono (UTC−06:00). Los tres avisos aparecieron como registros
nativos de `com.nikara.app` en el canal `notifications_default`, con importancia
4. La prueba usó el webhook existente y FCM; no se generaron avisos mediante
comandos locales de Android. Los avisos de prueba se conservaron para revisión.

La revisión detectó que el token FCM del teléfono no estaba registrado para
la cuenta activa. `PushTokenService` ahora registra también la sesión ya
restaurada al iniciar, serializa los registros concurrentes y, si RLS rechaza
un token perteneciente a otra cuenta, lo renueva en Firebase antes de guardar
uno nuevo. Se confirmó que el token local coincide con el registro de la
cuenta activa en Supabase. Las políticas de acceso permanecen vigentes.

La versión corregida quedó compilada e instalada en el teléfono. Pasaron las
40 pruebas de notificaciones y participación; el análisis de
`push_token_service.dart` no encontró problemas.
