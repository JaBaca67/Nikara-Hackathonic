# Alojamiento del APK sin Supabase Pro

Investigación de fuentes oficiales: 8 de octubre de 2026, hora local Guatemala. Alcance: alternativas relevantes para un APK de aproximadamente 138 MB, aprobación en Jotform, correo y un único inicio autorizado de descarga. Se revisaron documentación y precios públicos; no se crearon cuentas, subieron archivos ni validaron transferencias en una cuenta del equipo.

## Restricciones y recomendación

Supabase queda descartado como alojamiento del APK y no se propone pagar Pro. Puede continuar como base de datos gratuita para registros pequeños y como backend de la app. El APK debe permanecer privado, y los testers deben poder descargar sin configurar claves ni tener una cuenta GitHub o Backblaze.

Primera opción para una prueba rápida sin suscripción: **GitHub Releases en repositorio privado + Cloudflare Workers Free + registros de permisos en Supabase Free**. La viabilidad se infiere de las capacidades documentadas; hay que probar el camino real de descarga privada antes de elegirlo definitivamente.

Alternativa de almacenamiento orientada a este uso: **Backblaze B2 privado + Cloudflare Workers Free**. B2 admite empezar sin tarjeta y tiene almacenamiento gratuito; la integración con Cloudflare evita el coste de transferencia de B2 por la ruta asociada. Hay que comprobar límites de cuenta y contabilización real de esa ruta.

R2 es una opción técnicamente cómoda, pero activa una suscripción de facturación por uso. La documentación exige checkout; no se presenta como una alternativa garantizada sin método de pago. AWS/Oracle/Firebase Storage tampoco deben confundirse con servicios sin activación de facturación.

La disponibilidad de tarjeta y el número de testers se consultaron al usuario; al redactar este documento no hay respuesta. Se prioriza no pagar suscripciones y no depender de una tarjeta. El correo remitente aún debe confirmarse.

## Comparación

| Servicio | ¿Cabe 138 MB? | Uso gratuito documentado | Compatibilidad con un uso | Decisión para hoy |
| --- | --- | --- | --- | --- |
| GitHub Releases privado | Sí: cada asset debe ser menor de 2 GiB | Repositorios privados en Free; Releases no fija un límite total de tamaño o ancho de banda | Sí, con API privada y gateway propio que entrega el stream | Primera prueba, especialmente si ya hay cuenta GitHub |
| Backblaze B2 privado | Sí: consola admite hasta 5 GiB por archivo | Primeros 10 GB; alta sin tarjeta; salida gratuita mediante Cloudflare según integración | Sí, con autorización privada y gateway propio | Alternativa principal |
| Cloudflare R2 Standard | Sí: admite objetos mucho mayores | 10 GB-mes, 1 millón de operaciones A y 10 millones B; salida sin coste | Sí, con bucket privado y Worker | Buena si se puede activar checkout; verificar medio de pago |
| Firebase App Distribution | Sí: máximo 2048 MiB por binario | Producto sin coste, disponible en Spark | Invitación de un uso, pero no una única transferencia del APK | Respaldo si se acepta cambiar el requisito |
| Google Drive | Sí | Hasta 15 GB compartidos con Gmail y Photos | Link compartido no; API privada + gateway es técnicamente posible | Respaldo; OAuth añade configuración |
| Dropbox Basic | Sí | 2 GB; enlaces compartidos con 20 GB/día de ancho de banda | Link compartido no; API privada + gateway requiere integración | Posible, con límites de tráfico y OAuth |
| file.io Free | Sí: hasta 2 GB | 4 GB de subidas por hora; archivo eliminado después de una descarga | Sí, por borrado del archivo; cada persona requiere otra copia | Contingencia para pocas solicitudes; probar antes |
| Oracle Object Storage Always Free | Sí | 20 GB de Object Storage | Sí, con objeto privado y gateway | Alternativa técnica; alta exige tarjeta y más configuración |
| AWS S3 | Sí | Free plan para nuevos clientes hasta seis meses/créditos, sujeto a elegibilidad | Sí, con objeto privado y gateway | No es una solución gratuita permanente para este plazo |
| Firebase Cloud Storage | Sí | Cuotas gratuitas dentro de Blaze | Sí, con objeto privado y gateway | Descartado si no se activa facturación: exige Blaze desde febrero de 2026 |
| Appwrite Cloud Free | No con límite publicado de 50 MB por archivo | Free con límites | No resuelve el archivo actual | No migrar por este problema; tabla dinámica de precios debe reconfirmarse en consola |

Ninguno de los servicios de objetos hace un enlace de un uso únicamente por crear una URL temporal. Esta propiedad la implementa el gateway, salvo la eliminación por descarga de file.io o la aceptación única de invitación de App Distribution, que tienen alcances distintos.

## GitHub Releases privado: plan concreto

1. Crear un repositorio privado separado, destinado a releases de Níkara. No cambiar la visibilidad del repositorio actual ni subir archivos de configuración secretos.
2. Crear una release de prototipo y adjuntar el APK firmado como asset. No añadir el APK como archivo Git: el límite de Releases es diferente del límite de archivos del repositorio. No hace falta Git LFS, Packages ni Actions para esta distribución.
3. Crear una credencial de servidor limitada al repositorio y lectura de Contents. El tester nunca recibe esta credencial ni acceso al repositorio.
4. Guardar el identificador del asset y su versión inmutable. Al crear un permiso, fijar ese asset; no cambiarlo automáticamente a «latest».
5. El Worker valida y consume el permiso mediante una operación atómica en Supabase. Después entrega el archivo solicitado a la API de GitHub como stream.
6. GitHub puede responder con el cuerpo o con una redirección. El Worker debe seguir la redirección internamente, sin transmitir su ubicación al navegador y sin reenviar la credencial GitHub a un host de almacenamiento distinto.
7. Probar archivo completo, checksum, concurrencia, expiración y segundo intento. Publicar la integración solo después de esta prueba.

La subida inicial puede hacerse desde el panel privado de GitHub. Para cumplir literalmente «cargar versiones desde un panel propio», debe añadirse la integración de carga: no se da ese requisito por cumplido con una pantalla que solo guarda URLs. Un archivo de 138 MB no cabe como una sola petición entrante de Worker Free (100 MB); la arquitectura de carga debe usar otro canal apto para ese tamaño. La descarga de 138 MB sí puede transmitirse porque no hay límite de tamaño del cuerpo de respuesta del Worker.

## Backblaze B2 privado: plan concreto

1. Alta B2, bucket privado y subida del APK desde la consola, con nombre/versionado fijo.
2. Clave de aplicación limitada al bucket y operaciones necesarias. Mantener la clave y tokens únicamente en servidor.
3. Worker valida el permiso y obtiene el archivo con autorización de B2. La documentación oficial muestra integración de buckets privados y subdominio `workers.dev`, sin comprar dominio.
4. Agregar nuestra autorización por permiso; un ejemplo que autentica al Worker contra B2 no identifica por sí solo al visitante. Nunca publicar una ruta que entregue cualquier objeto por conocer su nombre.
5. Transmitir archivo sin exponer URL/token de B2, sin caché de respuestas protegidas y sin cargarlo completo en memoria.
6. Verificar contabilización de transferencia hacia Cloudflare y Caps & Alerts con una descarga real. El precio de salida directa y el precio hacia el socio son distintos; no calcular capacidad usando solo la cuota de almacenamiento.

La documentación ofrece salida sin coste hacia Cloudflare. La ausencia de suscripción y la cuota de almacenamiento no son una promesa de recursos ilimitados. Mantener pocas versiones y revisar uso real de la cuenta.

## El servidor gratuito que controla el flujo

Cloudflare Workers es apto como gateway: su alta gratuita no requiere tarjeta; Free tiene 100 000 solicitudes al día. Las respuestas HTTP no tienen límite de cuerpo impuesto y los Workers HTTP pueden seguir transmitiendo mientras el cliente está conectado. Debe usarse streaming: la memoria del Worker es 128 MB y el archivo ronda 138 MB. Free limita CPU a 10 ms por solicitud; esperar red no consume ese tiempo, pero hay que medir el código real.

No colocar el APK dentro del código del Worker ni dentro de los assets de la landing. El archivo reside en Releases/B2/R2; el Worker solo autoriza y transmite. No es necesario alquilar una máquina ni mantener encendido un ordenador.

La URL `workers.dev` permite empezar sin un dominio comprado. Un dominio de correo verificado es una dependencia distinta, y no queda resuelto por ese subdominio.

## Jotform, correo y descarga de un uso

1. Jotform guarda la solicitud; administrador autenticado aprueba.
2. Solo la rama aprobada envía un webhook con encabezado secreto al servicio.
3. El servicio crea un permiso aleatorio, almacena su hash/vencimiento/release e inicia el envío de correo. Eventos duplicados no crean permisos independientes.
4. El correo lleva a una página con instrucciones. GET y HEAD no consumen; ningún recurso público del APK queda expuesto.
5. POST del botón «Descargar» consume atómicamente el permiso. Solo una petición concurrente obtiene autorización.
6. El gateway transmite desde el almacenamiento privado. Bloquea reutilización. Si se cancela, un administrador puede emitir un permiso nuevo y revocar el anterior.

El compromiso sigue siendo un inicio autorizado, no demostrar instalación ni impedir compartir el APK. Un token al portador puede usarlo quien lo posea; vincularlo estrictamente al destinatario requiere otro paso de autenticación.

Jotform Starter admite 100 solicitudes mensuales entre los formularios de la cuenta. Aunque el almacenamiento soporte 500 descargas, el formulario gratuito puede ser el límite previo. No se planea subir el APK a Jotform.

Resend ofrece 3 000 correos al mes y 100 al día en Free y permite empezar sin tarjeta, pero para enviar a terceros necesitamos un remitente/dominio verificado. Si no existe, elegir un canal de correo disponible antes de comprometer un flujo automático de coste cero. El hosting gratis no garantiza automáticamente correo gratis sin configuración.

## Capacidad de una demo

Con el tamaño observado de 137.8 MB, sin contar reintentos:

| Descargas | Transferencia aproximada |
| --- | --- |
| 10 | 1.38 GB |
| 50 | 6.89 GB |
| 100 | 13.78 GB |
| 500 | 68.9 GB |

Un APK se almacena una vez en GitHub/B2/R2 y se transmite a cada autorizado. file.io elimina el objeto al descargarlo: para 50 personas se subirían 50 copias a lo largo del flujo, aproximadamente 6.89 GB de subidas, además de descargas. Su cuota de 4 GB/hora también debe considerarse.

## Alternativas de entrega con otra semántica

Firebase App Distribution es gratuito y permite publicar APK, seleccionar testers y enviarles automáticamente invitaciones. La persona acepta con Google; la invitación se acepta una sola vez, pero el acceso posterior al release no equivale a una única descarga. Releases permanecen 150 días. Se puede conectar la aprobación de Jotform al alta/distribución mediante backend y APIs, pero no se debe afirmar que coincide con el requisito original sin que el usuario acepte ese cambio.

Drive/Dropbox sirven para entrega manual rápida. Compartir una URL directamente no controla un uso. Mantener archivos privados y usar APIs por un gateway es posible, pero exige OAuth/permisos y pruebas; no es necesariamente más sencillo que GitHub o B2.

file.io evita construir el mecanismo de borrado, pero la copia debe crearse por cada aprobado. Tiene que probarse el comportamiento con correo, navegadores Android, caducidad, errores y acceso API; no se validó el servicio en una cuenta del equipo.

Render Free puede alojar un backend, pero el filesystem es efímero y no es almacenamiento persistente para APK subidos. Las Vercel Functions documentan un límite de payload de 4.5 MB; no son una elección inicial para servir este binario a través de una respuesta convencional. Algunos productos admiten rutas de streaming o almacenamiento directo distintas, pero requieren validación específica y no solucionan por sí solos el uso único.

## Orden recomendado antes de construir toda la integración

1. En los primeros 20–30 minutos, probar GitHub privado + Worker con el APK actual o un archivo de prueba de tamaño equivalente: archivo privado, stream completo y checksum. No distribuir el debug como release final.
2. Si ese camino falla, hacer la misma prueba con B2 privado + Worker, comprobando cuota/transferencia en consola.
3. En cuanto el almacenamiento quede validado, conectar el permiso atómico, webhook y correo. Probar primer intento, segundo intento, dos intentos simultáneos y fallo de red.
4. Terminar release firmado, Maps y Directions; reemplazar el archivo de prueba por la versión validada con identidad nueva.
5. Reunir evidencia de solicitud, aprobación, correo, descarga, segundo intento rechazado e instalación real. Documentar qué panel carga la versión y cuál gestiona solicitudes.

Es una recomendación basada en documentación, no una garantía de despliegue ni una prueba de cuentas disponibles. No activar facturación, contratar un plan ni enviar correos externos sin autorización.

## Fuentes oficiales

- [GitHub: límites de Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
- [GitHub: repositorios privados en Free](https://docs.github.com/en/get-started/learning-about-github/githubs-plans).
- [GitHub: API de assets y permisos de lectura](https://docs.github.com/en/rest/releases/assets).
- [Backblaze: precio, almacenamiento incluido y transferencia por socios](https://www.backblaze.com/cloud-storage/pricing).
- [Backblaze: registro sin tarjeta](https://www.backblaze.com/sign-up/cloud-storage).
- [Backblaze: tamaño de archivos en consola/API](https://www.backblaze.com/docs/cloud-storage-files).
- [Backblaze: servir buckets privados mediante Cloudflare](https://www.backblaze.com/docs/cloud-storage-deliver-private-backblaze-b2-content-through-cloudflare-cdn).
- [Cloudflare Workers: registro gratuito sin tarjeta](https://www.cloudflare.com/products/workers/).
- [Workers: tamaño de petición/respuesta, CPU, memoria y duración](https://developers.cloudflare.com/workers/platform/limits/).
- [R2: cuota gratuita](https://developers.cloudflare.com/r2/pricing/), [checkout](https://developers.cloudflare.com/r2/get-started/), [límites](https://developers.cloudflare.com/r2/platform/limits/).
- [Firebase: App Distribution sin coste](https://firebase.google.com/pricing), [límite de binario](https://firebase.google.com/docs/app-distribution/troubleshooting?platform=android), [publicación y retención](https://firebase.google.com/docs/app-distribution/android/distribute-console), [aceptación por tester](https://firebase.google.com/docs/app-distribution/get-set-up-as-a-tester?platform=android).
- [Firebase Storage: requisito de Blaze](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).
- [Google: almacenamiento gratuito](https://support.google.com/googleone/answer/9004013?hl=en), [API de descarga](https://developers.google.com/workspace/drive/api/guides/manage-downloads).
- [Dropbox Basic](https://help.dropbox.com/plans/dropbox-basic), [límites de enlaces compartidos](https://help.dropbox.com/share/banned-links).
- [file.io: plan gratuito y borrado por descarga](https://www.file.io/plans).
- [Oracle: recursos Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm), [requisito de tarjeta](https://www.oracle.com/cloud/free/faq/).
- [AWS: duración y elegibilidad de Free Tier](https://aws.amazon.com/free/free-tier-faqs/).
- [Appwrite: planes](https://appwrite.io/pricing).
- [Render: filesystem efímero en Free](https://render.com/docs/free).
- [Vercel: limitaciones de funciones](https://vercel.com/docs/functions/limitations).
- [Jotform: límites de Starter](https://www.jotform.com/help/does-jotform-offer-a-free-trial/), [webhook de workflow](https://www.jotform.com/help/how-to-create-a-webhook-in-jotform-workflows/).
- [Resend: cuotas](https://resend.com/pricing), [alta sin tarjeta](https://resend.com/products/transactional-emails), [dominio verificado](https://resend.com/docs/dashboard/domains/introduction).
