# Solicitud en Jotform, aprobación y descarga de un solo uso

Propuesta del 8 de octubre de 2026, pendiente de implementación y validación. Esta es la alternativa elegida por el usuario para planificar; reemplaza la recomendación inicial de desarrollar una bandeja propia de solicitudes. No implica que cuentas, correo, alojamiento, APK release o integraciones estén preparados.

Restricción confirmada posteriormente: no alojar el APK en Supabase ni pagar Pro. La [investigación de alternativas](investigacion_alojamiento_apk_sin_pro.md) prioriza GitHub Releases privado y Backblaze B2 con un gateway gratuito. Supabase puede continuar solo para registros pequeños y datos de la app.

Alternativa investigada posteriormente por preferencia del usuario: [Tally + Google Drive](plan_tally_drive.md). La aprobación manual y la necesidad de conservar descarga de un uso están consultadas; un enlace directo restringido de Drive no equivale a un permiso de descarga de un uso.

## Recorrido

Landing → formulario Jotform → revisión privada en Jotform → aprobación → webhook autenticado → permiso individual en Supabase → correo con enlace → página de descarga → botón que inicia una única transferencia.

Jotform se encarga de capturar solicitudes y permitir revisión. Nuestro servicio se encarga de crear el permiso de descarga y enviar el correo con su token. No depender de que Jotform pueda incorporar automáticamente una respuesta de webhook en un correo posterior sin comprobar esa capacidad.

## Qué significa un solo uso

El enlace del correo abre una página informativa y puede abrirse varias veces mientras siga vigente. GET y HEAD nunca consumen el permiso. Esto reduce el riesgo de consumo por previsualizaciones y análisis automáticos del correo.

Solo al pulsar «Descargar APK» se envía un POST y se autoriza una transferencia. El servidor cambia el estado de disponible a usado mediante una operación atómica: dos clics simultáneos no pueden iniciar dos transferencias. El servidor entrega el archivo desde almacenamiento privado sin redirigir a una URL pública o firmada reutilizable. Las respuestas no deben almacenarse en caché.

El compromiso es **un único inicio autorizado de transferencia**, no verificar que el usuario guardó o instaló el APK. Si cancela o pierde conexión después de consumirlo, el permiso permanece usado y un administrador puede emitir uno nuevo revocando el anterior. No implementar reanudación automática por rangos en esta primera versión; probar el comportamiento del navegador Android real. Para admitir reanudación más adelante habrá que autorizar una sesión de descarga limitada, que es un alcance diferente.

Un enlace firmado que vence no es, por sí solo, de un uso. No devolverlo al navegador como sustituto de este control. Una vez descargado, el APK se puede copiar; este mecanismo no limita instalaciones ni tiempo de uso de la app. El enlace es una credencial al portador: si se comparte antes de usarlo, la primera persona que lo canjee podría consumirlo. Restringirlo a una identidad exige verificación adicional de correo o sesión.

## Configuración Jotform

1. Crear formulario con nombre, correo, organización opcional, motivo y consentimiento de contacto.
2. Incrustarlo en la landing entregada.
3. Configurar workflow con aprobación manual y exigir login del aprobador.
4. En la rama aprobada, colocar un Webhook POST hacia el servicio propio.
5. Configurar encabezado secreto estático desde el workflow, nunca un campo que controle el solicitante. Enviar identificador de formulario, identificador de solicitud y correo/nombre de sus campos.
6. En la rama rechazada, enviar un aviso sin permiso de descarga si se desea. Aprobar es una decisión administrativa; no equivale a validar documentos o identidad automáticamente.

Validar el secreto en servidor, limitar el formulario permitido y registrar la aprobación. Los eventos duplicados deben devolver el mismo resultado sin crear permisos ni correos duplicados. Los tests del constructor de webhook no deben enviar mensajes a destinatarios reales accidentalmente: usar evento y correo de prueba explícitos.

## Servicio y datos

Supabase puede conservar los registros pequeños aunque el APK se almacene en otro proveedor. Crear:

- `app_releases`: versión inmutable, ruta privada, arquitectura, tamaño, checksum y estado publicado.
- `download_grants`: solicitud de Jotform, destinatario, release fijado, hash de token aleatorio fuerte, vencimiento, uso y revocación.
- Registro de entrega de correo con idempotencia y reintentos. Guardar de forma protegida el material necesario para reenviar el mismo correo; un hash por sí solo no permite reconstruir un token.

Fijar cada permiso a una versión concreta. Propuesta de vencimiento del enlace: 24 horas desde emisión, con posibilidad de reemisión administrativa. La vigencia del permiso no es la vigencia de la app.

Endpoints propuestos:

- `POST /integrations/jotform/approved`: valida evento, crea permiso y encola envío.
- `GET /demo`: página de descarga; no consume ni revela datos personales a visitantes sin token.
- `POST /demo/download`: verifica token y vencimiento, prepara el acceso al objeto privado, consume atómicamente y entrega el cuerpo en streaming.
- Operación administrativa privada para publicar release y reemitir un permiso; nunca abierta por conocer la URL.

Consultar solo el hash del token en la base. No incluir tokens ni claves en logs. En la página evitar recursos de terceros que puedan recibir el enlace; usar política de referrer y sin caché. Las credenciales de Jotform, correo, Storage y Supabase privilegiado viven exclusivamente en el servidor.

## Correo

Usar un SMTP ya disponible y probado o un proveedor transaccional como Resend con dominio remitente verificado. Resolver esta disponibilidad en el primer bloque; no asumir que el correo de autenticación de Supabase cubre notificaciones arbitrarias.

El servicio propio envía «Tu demo de Níkara fue aprobada» con nombre, versión, vencimiento y enlace individual. Desactivar seguimiento de clics si transforma el enlace o dificulta las pruebas. Reintentar fallos de envío sin aprobar otra vez ni generar permisos adicionales. Un aceptado por el proveedor no demuestra llegada a la bandeja: probar recepción real y spam con direcciones controladas por el equipo.

No se enviarán mensajes a terceros durante implementación sin autorización específica. La presente solicitud autoriza planificar el comportamiento, no efectuar envíos externos.

## APK y almacenamiento

Generar y medir un release firmado. El archivo existente de 137.8 MB es debug. Completar Maps, huellas de firma y `get-directions`, que el usuario confirma como pendiente operativo.

Supabase no se usará como alojamiento del APK. Generar y medir el release sigue siendo útil para reducir la descarga, pero la propuesta actual es probar GitHub Releases privado o Backblaze B2 privado. R2 queda como alternativa sujeta a comprobar activación y facturación, no como promesa de uso sin tarjeta.

Para servir un archivo grande con control de un uso, usar un backend que pueda transmitirlo sin cargarlo entero en memoria y sostener transferencias lentas. Cloudflare Workers Free puede consumir el permiso atómicamente mediante el backend de Supabase y devolver el stream privado de GitHub/B2. No copiar ejemplos de acceso por cualquier ruta sin agregar autenticación y permisos. Hay que probar esta combinación antes de prometerla como funcional.

Si se usa R2, comprobar cuenta, activación, costes y límites al principio. Para cargar un archivo de 138 MB desde un panel, prever carga directa multipart al almacenamiento con permisos temporales: no asumir que cabe en el límite de una petición HTTP del Worker. La carga y publicación administrativa es un bloque separado; Jotform no resuelve automáticamente el requisito original de cargar versiones desde un panel privado.

## Orden y estimación

| Bloque | Tiempo orientativo | Salida |
| --- | --- | --- |
| Decisiones, cuentas y primer build | 30 min | Cuenta Jotform, remitente, hosting y almacenamiento confirmados; build iniciado. |
| Jotform y landing | 40 min | Formulario y aprobación manual funcionando. |
| Permisos, webhook y correo | 70 min | Aprobar genera un permiso y llega un correo de prueba. |
| Página y gateway de descarga | 60 min | Una transferencia autorizada; reutilización y concurrencia bloqueadas. |
| Carga/publicación privada y reemisión | 40 min | Administrador publica APK y reemplaza permisos fallidos. |
| Prueba completa, publicación y evidencias | 60 min | Solicitud → aprobación → correo → APK → instalación, desde URL real. |

Total orientativo: 5 horas; reservar lo restante para correcciones de compilación, Directions, correo y descarga. La estimación depende de cuentas accesibles y remitente funcional. Si eso no existe, no prometer el plazo antes de comprobarlo. Este plan no reserva tiempo para corregir todos los pendientes de sincronización de la app.

## Pruebas necesarias

- Solicitud pendiente o rechazada no recibe un permiso de descarga.
- Webhook sin secreto o de otro formulario no crea permisos.
- Aprobación repetida no genera dos permisos ni envíos independientes.
- Correo recibido por destinatario de prueba con versión y enlace correctos.
- GET/HEAD y recarga de la página no consumen.
- Primer POST descarga APK; segundo POST y dos POST simultáneos no autorizan dos streams.
- Token inventado, vencido o revocado no descarga.
- Archivo no tiene ruta pública ni URL reutilizable expuesta.
- Descargar APK real desde Android, validar checksum e instalar; comprobar mapa y Directions del release.
- Fallo/cancelación muestra el comportamiento acordado y administrador puede reemitir.
- Registrar por separado aceptación de correo, inicio de transferencia e instalación probada; ninguno implica automáticamente los otros.

## Fuentes oficiales

- [Jotform: webhook en workflow, eventos de aprobación y encabezados](https://www.jotform.com/help/how-to-create-a-webhook-in-jotform-workflows/).
- [Jotform: login del aprobador](https://www.jotform.com/help/how-to-enable-or-disable-require-login-in-jotform-workflows/).
- [Supabase: enlaces firmados temporales](https://supabase.com/docs/guides/storage/serving/downloads).
- [Supabase: límite por archivo](https://supabase.com/docs/guides/storage/uploads/file-limits).
- [Supabase: límites de Edge Functions](https://supabase.com/docs/guides/functions/limits).
- [Cloudflare: servir objetos R2 desde Workers](https://developers.cloudflare.com/r2/api/workers/workers-api-usage/).
- [Cloudflare: límites de Workers](https://developers.cloudflare.com/workers/platform/limits/).
- [Resend: dominio remitente verificado](https://resend.com/docs/dashboard/domains/introduction).
