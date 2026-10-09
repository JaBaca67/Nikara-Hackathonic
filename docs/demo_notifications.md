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

## Lectura completa y cobertura de push

Mantener presionada una tarjeta de la bandeja expande el propio widget:
muestra el título y cuerpo sin límite de líneas, la fecha y hora completas,
y el estado de lectura. El botón «Ver menos» o una segunda pulsación larga
contraen la tarjeta. La pulsación larga no abre otro recurso ni marca el aviso
como leído; el toque corto conserva su navegación habitual.

Los mensajes recibidos en primer plano ahora usan `BigTextStyleInformation`
en Android. Cada fila conserva una etiqueta propia, por lo que dos avisos del
mismo tipo aparecen separados. Los mensajes con un tipo desconocido también
se muestran; los mensajes de datos con título/cuerpo pueden mostrarse aunque
no incluyan el bloque `notification`. El registro FCM se reintenta al volver a
la app, para recuperar fallos de conexión durante el arranque.

Se probaron los 17 tipos definidos mediante el canal nativo simulado de Android:
todos invocan la presentación nativa y conservan el cuerpo completo. Pasaron
19 pruebas de notificaciones, presentación push y actualización de la bandeja,
y el análisis de esos archivos no encontró problemas.

El webhook de inserción existente no filtra por tipo de notificación: genera
push para cada fila nueva. FCM incluye el cuerpo completo y usa el formato
expandible del SDK cuando Android presenta un aviso en segundo plano. El gesto
de mantener presionado en el panel del sistema pertenece a Android y suele
mostrar controles de notificaciones; para desplegar el texto se usa su flecha
de expansión. La pulsación larga que expande nuestra tarjeta corresponde a la
bandeja de Níkara.

Esto verifica la configuración y la presentación de todos los tipos; no es una
garantía de entrega del sistema operativo. Se requieren permisos habilitados,
un token registrado y conexión. El APK quedó instalado después de reconectar
el Samsung. El bloqueo seguro y el acceso de sesión vencido impidieron repetir
la prueba física de todos los tipos: hace falta desbloquear y abrir la app para
renovar la sesión. Se revisó el widget contra capturas Flutter a 384 dp con
las fuentes Nunito y League Spartan, sin texto recortado en el estado expandido.
La activación remota
de las automatizaciones de 045/046 sigue pendiente como se documentó en
`action_notifications.md`.
