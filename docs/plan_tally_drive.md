# Tally y Google Drive: revisión y envío del APK

Investigación del 8 de octubre de 2026. Alternativa en evaluación solicitada por el usuario; no se crearon formularios, compartieron archivos ni enviaron correos. Supabase Pro y alojamiento del APK en Supabase siguen descartados.

## Resultados

Tally ofrece un panel privado con la pestaña Submissions para consultar respuestas y exportarlas. No se encontró un flujo nativo documentado equivalente a aprobar/rechazar y ejecutar acciones después de la revisión. No presentar la mera consulta de respuestas como un sistema de aprobación ya resuelto.

La integración Tally → Google Sheets es gratuita y crea una fila por respuesta. Las notificaciones al dueño del formulario son gratuitas; las notificaciones automáticas al solicitante desde Tally son una función Pro. Se puede evitar ese coste con automatización de Google.

Drive permite compartir un archivo restringido por correo con permiso de lector. No hace falta compartir una carpeta completa ni publicar el archivo para cualquier persona con el enlace. Compartir un archivo no concede acceso a todo el Drive. Una carpeta compartida concede acceso a su contenido por herencia, incluido material agregado después según los permisos de la carpeta; mantener entregables separados de documentos internos.

## Alternativa sencilla: acceso por correo aprobado

1. Guardar el APK release firmado en una carpeta privada de entregables. Compartir solo el archivo que corresponde a esa versión.
2. Mantener acceso general «Restringido». No agregar destinatarios como editores. Permitir descarga a lectores, porque necesitan instalar el APK.
3. Crear Tally con nombre, correo de acceso, organización opcional, motivo y consentimiento de contacto. La recepción completa deja una solicitud pendiente; no equivale a aprobarla ni a verificar su identidad.
4. Activar alerta al administrador y conectar Google Sheets. Confirmar cómo la integración maneja columnas auxiliares antes de añadirlas; preferir una hoja separada de revisión vinculada al ID de solicitud para no alterar el área sincronizada.
5. Crear bandeja privada de revisión con ID, correo, fecha, motivo, estado (Pendiente/Aprobada/Rechazada), versión, permiso otorgado, aviso solicitado y error. Solo el equipo tiene acceso a la hoja. El solicitante no puede introducir ni modificar su estado de aprobación.
6. El administrador cambia el estado a Aprobada. Un disparador instalable de Apps Script procesa la acción con autorización del propietario.
7. El script crea el permiso de lector en el archivo aprobado mediante Drive API y solicita el correo de notificación de Drive, con un mensaje de aprobación e instrucciones.
8. El destinatario recibe el aviso con acceso al archivo. Probar que puede autenticarse con la identidad autorizada y descargar desde Android. No prometer acceso restringido sin autenticación a quien no dispone de una identidad Google compatible; revisar esa situación en la prueba.

La API admite `sendNotificationEmail` y `emailMessage`. Podemos usar esa notificación para evitar pagar Tally Pro o contratar un proveedor de correo. Si necesitamos un correo propio con diseño específico, Apps Script puede enviar un mensaje separado mediante MailApp; cuentas personales tienen una cuota documentada de 100 destinatarios al día y Workspace 1500. No aplicar automáticamente esa cuota de MailApp al aviso de compartir de Drive, que es otro mecanismo.

Un estado «aviso solicitado» o éxito de API no confirma recepción en bandeja; verificar el correo real. Serializar los cambios de permisos sobre el mismo archivo y registrar la solicitud por ID para reducir duplicados y permitir reintentos.

Los disparadores de edición no se ejecutan por escrituras mediante API. La integración de Tally no debe activar una aprobación automáticamente: el evento esperado aquí es la edición manual del revisor. Si se decide enviar a todos al presentar el formulario, usar un webhook autenticado o una tarea periódica que procese nuevas filas; no confiar en `onFormSubmit` de Google Forms para un formulario Tally.

## Envío inmediato al completar el formulario

Es una decisión distinta de revisión administrativa. Si se elige este modo, las respuestas nuevas pueden conceder permiso y enviar el aviso automáticamente, con validación de correo, control de abuso e idempotencia. En Tally Free el correo al participante necesita la integración; Pro ofrece confirmaciones propias al enviar. También se puede mostrar un enlace en la pantalla final gratuita, pero eso no es un envío por correo ni una aprobación, y un enlace público se puede compartir.

El usuario tiene pendiente aclarar si «completar la solicitud» significa enviarla o terminar su aprobación. Hasta tener respuesta, conservar revisión manual como propuesta y no enviar APK a toda solicitud automáticamente.

## Diferencia con la descarga de un solo uso

Un archivo restringido al destinatario puede descargarse varias veces mientras conserve el permiso. El enlace de Drive no es de un uso y retirar acceso después no recupera las copias descargadas. Esta alternativa simplifica el flujo, pero no satisface por sí sola el requisito anterior de una única transferencia autorizada.

Si ese requisito se mantiene:

- Mantener APK privado en Drive sin dar acceso directo a testers.
- El archivo solo es accesible al equipo y a la identidad del servidor autorizada para leerlo.
- Al aprobar, el script pide al servicio un permiso aleatorio y envía un enlace a nuestra página; no la URL de Drive.
- El botón POST consume atómicamente ese permiso y un gateway, por ejemplo Cloudflare Worker, transmite el APK desde la API privada de Drive. No expone credenciales ni redirige a un enlace reutilizable.
- GET/HEAD no consumen; segundo intento, vencimiento y concurrencia se bloquean. Si la transferencia falla, el administrador puede emitir otro permiso.
- Resolver y probar la identidad OAuth/cuenta de servicio del servidor y el acceso al archivo. Es trabajo adicional, no una opción ya configurada.

Apps Script se usa para administrar permisos y enviar avisos, no para recibir y reenviar de una vez el APK de 138 MB: URL Fetch tiene un límite documentado de 50 MB por respuesta. No adjuntar el APK al correo.

No se interpreta la elección de Drive como cancelación del requisito de un uso. Se consultó al usuario si lo mantiene o acepta acceso restringido repetible; la decisión está pendiente al redactar este documento.

## Alcance de compartir y pruebas

- Probar como visitante no autorizado y como destinatario autorizado, con cuentas separadas.
- Confirmar que lector descarga y no modifica el APK, permisos o carpeta.
- Comprobar permisos heredados: un archivo dentro de una carpeta pública no debe considerarse privado porque su enlace individual no se difundió.
- No incluir en entregables `.env`, keystore, contraseñas, claves de servidor, datos de solicitudes ni documentación privada.
- Google informa que el propietario puede ser visible por nombre y correo al compartir el enlace; elegir conscientemente la cuenta del proyecto.
- El APK descargado puede copiarse. La clave Android de Maps incorporada seguirá necesitando restricciones de paquete y firma; Drive no la vuelve secreta.
- Probar recepción del aviso, versión, descarga desde teléfono, checksum, instalación y Maps/Directions. No certificar seguridad o funcionamiento únicamente por configurar «Restringido».
- La carga inicial se realiza en la consola privada de Drive. Si el entregable requiere un panel web propio que permita cargar versiones, esa interfaz aún debe implementarse; Tally Submissions no la ofrece.

## Fuentes oficiales

- [Tally: panel Submissions y exportación](https://tally.so/help/faq).
- [Tally: integración gratuita con Google Sheets](https://tally.so/help/google-sheets-integration).
- [Tally: avisos gratuitos al administrador](https://tally.so/help/self-email-notifications).
- [Tally: correo al solicitante es Pro](https://tally.so/help/respondent-email-notifications).
- [Tally: pantalla final gratuita](https://tally.so/help/how-to-create-a-thank-you-page).
- [Tally: webhooks gratuitos y evento de envío](https://tally.so/help/webhooks).
- [Drive: permisos, herencia de carpetas y visibilidad del propietario](https://support.google.com/drive/answer/2494822?hl=en).
- [Drive API: compartir y enviar aviso personalizado](https://developers.google.com/workspace/drive/api/reference/rest/v3/permissions/create).
- [Apps Script: disparadores instalables y restricciones](https://developers.google.com/apps-script/guides/triggers/installable).
- [Apps Script: cuotas de correo y URL Fetch](https://developers.google.com/apps-script/guides/services/quotas).
- [Apps Script: servicio avanzado de Drive](https://developers.google.com/apps-script/advanced/drive).
- [Drive: API de descarga privada](https://developers.google.com/workspace/drive/api/guides/manage-downloads).
