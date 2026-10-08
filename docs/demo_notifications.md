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
indicaciones ECO llegan al unirse; no se programa un recordatorio futuro.

Las filas se insertan en la tabla existente `notifications`. La campana se
actualiza mediante `NotificationService.revision` y el webhook de push existente
entrega las mismas filas por FCM si el dispositivo tiene un token registrado y
permiso para notificaciones. No requiere migraciones ni dependencias nuevas.

Para repetir el lote completo durante otra demostración, iniciar sesión con
otra cuenta. Las notificaciones de inscripción se pueden mostrar al unirse a
otra jornada o después de abandonar y volver a unirse.

Validación:

```powershell
flutter test test/notification_demo_test.dart test/eco_participation_test.dart test/notifications_screen_test.dart
flutter analyze
```
