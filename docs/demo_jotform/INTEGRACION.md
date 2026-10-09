# Formulario Nikara: importar y conectar

Preparado el 8 de octubre de 2026. Los archivos están listos localmente; todavía no están importados en una cuenta de Jotform ni conectados a Drive. La APK sigue fuera de Supabase.

## 1. Crear el formulario

**Opción PDF**

En Jotform: Workspace → Create → Form → Import Form → Import PDF Form. Selecciona `Nikara_Solicitud_Demo.pdf`. Es un PDF de una página con nueve campos rellenables; el importador puede requerir revisar tipos, obligatoriedad y casillas. PDF importado y workflow son configuraciones separadas.

**Opción con IA**

En Workspace: Create → Jotform AI. Copia el contenido de `crear_formulario_ia.txt`, genera el formulario y revisa sus campos. Si prefieres un formulario web clásico en lugar de Smart PDF, esta opción describe exactamente los mismos datos.

En ambos casos verifica antes de publicar:

- Nombre, correo, perfil, motivo y las tres casillas: obligatorios.
- Correo: campo Email con validación; no un simple texto corto.
- Organización y dispositivo: opcionales.
- Perfil: sin una respuesta real elegida por defecto.
- Tres casillas separadas, inicialmente desmarcadas, que deban marcarse para enviar.
- No incluir el enlace de Drive en el formulario, agradecimiento ni confirmación de recepción.

Texto de agradecimiento:

> ¡Recibimos tu solicitud! El equipo de Nikara revisará tus datos. Si tu solicitud es aprobada, recibirás por correo las instrucciones para descargar e instalar la demo en Android.

## 2. Conectar a la landing

La vía más rápida: Publish → copia el enlace público y úsalo en el botón «Solicitar demo» de la landing.

```html
<!-- Sustituye ID_REAL por el identificador publicado por Jotform. -->
<a href="https://form.jotform.com/ID_REAL" target="_blank" rel="noopener noreferrer">
  Solicitar demo
</a>
```

Para mostrarlo dentro de la página: Publish → Embed → iFrame → copia el código que entrega Jotform. Pega ese bloque en la sección de solicitud de la landing. Usa su código generado para que el tamaño se adapte; no reemplaces automáticamente partes de una landing React compilada con una búsqueda de texto.

El HTML de presentación original no se ha modificado en esta entrega.

## 3. Activar revisión privada en Jotform

Abre o crea un workflow asociado a este formulario. Añade un elemento Approval y asigna como aprobador un correo real del equipo. Activa Require Login for Approver. Nunca asignes al solicitante como aprobador.

Conecta:

```text
Solicitud → Approval
              ├─ Approve → entrega de acceso → End
              └─ Deny → Email sin descarga → End
```

Si hay un correo automático al recibir la solicitud, debe confirmar recepción únicamente. Edita la rama Approve para que el correo de acceso salga después de aprobar, nunca directamente desde el evento de envío.

## 4. Entregar el APK privado: configuración inmediata

Esta alternativa permite volver a descargar mientras exista el permiso. No cumple el requisito de enlace de un solo uso.

1. Sube una APK release probada a Drive, dentro de una carpeta privada. Acceso general del archivo: Restringido. Comprueba que no herede permisos públicos de la carpeta.
2. Copia el enlace de compartir del archivo individual; no el de la carpeta.
3. En la rama Approve de Jotform añade Email. En Recipient Email selecciona el campo de correo del formulario.
4. Inserta nombre y otros datos con el menú Form Fields de Jotform. Los marcadores del siguiente texto son instrucciones; no son etiquetas técnicas universales de Jotform.

Asunto: Tu acceso a la demo de Nikara fue aprobado

```text
Hola [insertar campo Nombre completo],

Tu solicitud para probar Nikara fue aprobada.

Descarga la APK aquí: [pegar enlace del archivo de Drive]

Abre el enlace con la cuenta de Google vinculada al correo de tu solicitud.
Descarga el archivo en tu teléfono Android, ábrelo y sigue las instrucciones
del sistema para permitir la instalación desde el navegador o gestor de
archivos que utilizaste. Puedes desactivar ese permiso después de instalar.

Esta es una versión de prototipo y puede contener errores.
Si necesitas ayuda o quieres compartir tus comentarios, responde a este correo.

Equipo Nikara
```

Configura Reply-to con un correo real atendido por el equipo.

**Orden para cada solicitud con este método manual:** primero revisa; si corresponde aprobar, comparte la APK en Drive con el correo del solicitante como Lector, manteniendo habilitada su descarga; después pulsa Approve en Jotform. Así el correo automático llegará cuando el permiso ya existe. Puedes desmarcar la notificación de Drive al compartir para evitar dos avisos. Si rechazas, no compartas el archivo.

No adjuntes la APK al correo. Jotform documenta un límite de 5 MB para adjuntos enviados con su remitente predeterminado.

## 5. Automatizar Drive después de aprobar

Arquitectura propuesta; requiere implementar y probar el receptor antes de activarla:

```text
Solicitud → Approval: Approve → Webhook POST → Google Apps Script
                                               └─ permiso de lector + correo de Drive
```

En la rama Approve, el elemento Webhook envía el identificador del formulario, el de la solicitud, el correo y el nombre a un Web App de Apps Script ejecutado como la cuenta propietaria del APK.

El receptor valida un secreto estático configurado por el equipo, limita el formulario permitido y evita procesar dos veces una solicitud. En Apps Script, coloca ese secreto en el cuerpo POST y guárdalo en Script Properties; `doPost(e)` no permite leer cualquier encabezado HTTP personalizado como lo haría un servidor convencional. No pongas secretos en campos del formulario público.

Una vez autorizado, el receptor utiliza el servicio avanzado de Drive para crear un permiso `type: user`, `role: reader`, `emailAddress: correo aprobado` sobre un FILE_ID fijo configurado por el equipo. Usa `sendNotificationEmail: true` y un `emailMessage` con la aprobación y las instrucciones. Drive envía la invitación con acceso al archivo; no se necesita SMTP para ese aviso. No permitas que el solicitante elija el FILE_ID ni asignes permiso de edición.

En este modo, elimina el correo Jotform con enlace de esa rama para evitar duplicados o enviar un enlace antes de conceder el permiso. La implementación deberá confirmar manejo de errores, redirecciones HTTP de Apps Script, reintentos e idempotencia: no está validada solo por configurar el webhook. Si falla, registra el error para revisión del equipo.

## 6. Si se conserva descarga de un solo uso

No compartas directamente el archivo con los solicitantes ni envíes su enlace de Drive. El APK queda accesible solo para el servicio. La aprobación llama al servidor que crea un token por solicitud y envía el enlace individual.

El enlace abre una página sin consumir el token. Al pulsar Descargar, una operación atómica permite un único inicio de transferencia y el servidor entrega la APK privada. GET/HEAD no deben consumirlo, y el servidor no debe redirigir al enlace reutilizable de Drive. Si falla la transferencia después de consumir el permiso, el equipo puede reemitir acceso. Una vez descargada, la APK se puede copiar.

Este gateway no está implementado en estos archivos. Consultar `../plan_jotform_descarga_unica.md` para el diseño detallado. No confundir el método inmediato del apartado 4 con el requisito original de un uso.

## 7. Comprobación antes de abrir la demo

Usa primero un correo del equipo: envía una solicitud, comprueba que todavía no puede descargar, revisa y aprueba, verifica la recepción del correo y descarga la APK en Android. Prueba también rechazo sin enlace y acceso desde otra cuenta no autorizada. En el modo automatizado, repetir el mismo evento no debe crear envíos duplicados. Verifica Maps, autenticación y Directions en la APK release antes de entregarla a testers.

## Fuentes oficiales

- PDF: https://form.jotform.com/products/smart-pdf-forms/
- IA: https://www.jotform.com/help/how-to-use-jotform-ai/
- Embed: https://www.jotform.com/help/148-getting-the-form-iframe-code/
- Approval: https://www.jotform.com/help/1414-how-to-set-up-an-approval-element-in-jotform-workflows/
- Email: https://www.jotform.com/help/1418-how-to-set-up-a-send-email-element-in-jotform-workflows/
- Webhook: https://www.jotform.com/help/how-to-create-a-webhook-in-jotform-workflows/
- Permisos y notificación: https://developers.google.com/workspace/drive/api/reference/rest/v3/permissions/create
- Compartir: https://support.google.com/drive/answer/2494822?hl=es
- Apps Script: https://developers.google.com/apps-script/guides/web
