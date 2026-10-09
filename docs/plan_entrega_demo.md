# Plan de entrega: landing, solicitudes, panel privado y APK

Fecha: 8 de octubre de 2026. Presupuesto: 5 horas y 30 minutos de ejecución más hasta 30 minutos de contingencia, ajustados al tiempo realmente disponible. Este documento es un plan; no certifica despliegue, compilación release ni funcionamiento en teléfonos nuevos.

Actualización de alcance: el usuario propone Jotform para solicitudes y revisión, correo tras aprobación y descarga de un uso. El [plan de esta alternativa](plan_jotform_descarga_unica.md) es la referencia actual para ese flujo; la propuesta inicial de bandeja propia que sigue abajo queda como alternativa.

Restricción posterior: el APK no se alojará en Supabase y no se pagará Pro. Consultar la [investigación de alojamiento sin Pro](investigacion_alojamiento_apk_sin_pro.md). Las referencias a Storage de Supabase en la propuesta histórica de abajo no representan la selección actual para el APK.

## Decisión propuesta

Conservar el HTML de presentación entregado en Downloads y trabajar sobre una copia dentro del proyecto. Agregar un formulario integrado, una página de acceso/descarga y un panel web mínimo. Usar el proyecto de Supabase existente para cuentas, solicitudes, permisos y metadatos de versiones. Alojar el APK en un bucket privado si el tamaño y el plan contratado lo permiten.

Google Forms queda como contingencia para capturar interesados. Por sí solo no cubre el requisito de gestionar solicitudes y cargar versiones desde un panel propio.

La pregunta pendiente es si la descarga debe requerir aprobación o ser pública. El diseño propuesto contempla aprobación manual de descarga; esta es una propuesta, no una preferencia confirmada. Si la descarga es pública, se elimina la autorización de descarga y el formulario pasa a solicitar una demostración guiada.

## Evidencia local revisada

- La aplicación es Flutter y usa Supabase para autenticación y datos. Firebase participa en notificaciones push.
- El identificador Android es `com.nikara.app`.
- `android/app/build.gradle.kts` toma `MAPS_API_KEY` de `android/local.properties`, que existe localmente. No se imprimieron sus valores en la revisión de configuración.
- El manifiesto principal ya incluye Internet y ubicación, también necesarios en release.
- La configuración release todavía firma con la clave de depuración. Hace falta una firma propia para la distribución prevista.
- Existe `build/app/outputs/flutter-apk/app-debug.apk`, de 137 800 235 bytes. Es evidencia de compilación debug, no de un release instalado y probado.
- El código de rutas invoca `get-directions` en Supabase y existe código local para leer la clave del servidor. El usuario confirma que la función nunca se terminó de implementar: se considera un pendiente operativo, no una integración funcional. Hay que completar y comprobar despliegue, secreto, permisos y cálculo de ruta antes de ofrecerlo en la demo.
- Ya existe un panel de moderación dentro de la app y una definición SQL de `public.is_admin()`. Podemos reutilizar el criterio de rol, comprobando que esté aplicado y que un usuario común no pueda elevar su rol. El panel de solicitudes y versiones sigue siendo trabajo nuevo.
- `docs/auditoria_sprint2/README.md` registra persistencia parcial o local en varias funciones y falta de validación con dos teléfonos. No debe asumirse que toda la app está sincronizada por generar un APK.

## Flujo mínimo recomendado

1. Visitante abre la landing y selecciona «Solicitar demo».
2. Completa nombre, correo, organización opcional, motivo y consentimiento de contacto. El servidor valida campos, limita solicitudes y crea exclusivamente un registro pendiente.
3. Un administrador inicia sesión en `/admin`, revisa la solicitud y la aprueba o rechaza. El permiso se verifica en el servidor, además de en la interfaz.
4. El administrador carga un APK y registra versión, número de compilación, arquitectura, tamaño, notas y checksum. Solo una versión publicada se ofrece como vigente. La carga debe terminar correctamente antes de publicarla.
5. La persona aprobada verifica su correo e inicia sesión en la página de descarga. El servidor comprueba la aprobación y emite un enlace temporal al APK privado.
6. Instala la app, concede permisos cuando corresponda y utiliza su cuenta personal; no necesita archivos de configuración ni claves de API.

Para reducir dependencias de correo, evaluar al principio el inicio con contraseña y confirmación de correo existente. No activar un flujo de enlaces mágicos para todos sin comprobar SMTP, límites de envío y URL de retorno. La entrega no requiere correo automático de aprobación: el panel puede permitir copiar el enlace de acceso y coordinar la comunicación manualmente. No enviar mensajes a terceros sin autorización.

Un enlace firmado permite descargar a quien lo posea hasta que venza. Una persona también puede compartir un APK ya descargado. Este alcance controla la distribución inicial; no impide por sí solo el uso de una copia. Si se exige acceso privado dentro de la app, hace falta un control de autorización en backend para los recursos protegidos y revisar el modo invitado. Ese alcance debe decidirse antes de implementarlo.

## Datos y permisos

Tablas nuevas propuestas:

- `demo_requests`: datos de contacto, motivo, estado, fechas y administrador que revisó. La aprobación vincula el correo verificado con el usuario; nunca se acepta un rol o estado aprobado suministrado por el formulario.
- `app_releases`: versión, compilación, arquitectura, ruta del archivo, tamaño, checksum, notas, estado publicado y autor.
- `demo_access`: usuario autorizado, solicitud asociada, estado y vencimiento opcional. Usarla si necesitamos separar aprobación, expiración y revocación del contacto inicial.

El visitante solo puede enviar una solicitud mediante un endpoint con validación y control de abuso; no puede listar solicitudes. Solo administradores pueden revisar solicitudes y cargar/publicar versiones. Solo usuarios aprobados pueden obtener enlaces de descarga, salvo que se elija descarga pública. Los permisos se prueban con visitante, usuario normal y administrador. La `service_role` y las claves de servidor nunca van en el HTML ni en el APK.

## Maps y firma del APK

La clave del SDK Android se incorpora durante la compilación; los usuarios no la introducen. Estar fuera de Git protege el repositorio, pero no vuelve secreta una clave empaquetada. Su protección debe ser la restricción a `com.nikara.app`, la huella SHA-1 del certificado que firma el APK entregado y Maps SDK for Android. Mantener separada la clave de Directions usada en el servidor.

Crear y respaldar un keystore propio, protegerlo junto con sus contraseñas y configurar Gradle. Registrar la nueva huella también para Google Sign-In cuando corresponda. Conservar esa firma para las actualizaciones e incrementar el número de compilación. Si un teléfono ya tiene la app con firma debug, instalar una versión con otra firma puede exigir desinstalar la anterior, perdiendo su almacenamiento local.

Después de configurar firma y credenciales:

```powershell
flutter build apk --release
```

El resultado esperado es `build/app/outputs/flutter-apk/app-release.apk`. Medir su tamaño. Si necesitamos variantes más pequeñas:

```powershell
flutter build apk --release --split-per-abi
```

Las variantes deben ofrecerse con su arquitectura correspondiente; no asumir que arm64 sirve para todos los teléfonos. Un APK universal simplifica la descarga si el alojamiento admite su tamaño.

## Cronograma con resultados verificables

| Tiempo desde el inicio | Trabajo | Resultado de salida |
| --- | --- | --- |
| 00:00–00:40 | Confirmar modalidad de descarga, hosting, administrador y límite de archivos. Configurar firma y huellas. Iniciar primer release. | Compilación encaminada y decisiones que pueden bloquear tomadas. |
| 00:40–01:30 | Tablas, permisos, endpoint de solicitudes y autorización de descarga. | Solicitud guardada; visitante sin acceso a datos privados. |
| 01:30–02:10 | Copia de landing, botones y formulario con validación, confirmación y errores. | Solicitud real realizada desde navegador móvil. |
| 02:10–03:15 | Panel privado: bandeja, filtros, aprobar/rechazar, cargar APK y publicar versión. | Administrador gestiona solicitudes y archivos desde la web. |
| 03:15–03:50 | Página de acceso y descarga, enlaces temporales, versión y guía de instalación. | Usuario autorizado descarga; usuario no autorizado recibe denegación. |
| 03:50–04:30 | Instalación del release en teléfono nuevo y correcciones del recorrido central. | App abre sin ordenador, carga datos, muestra mapas y calcula ruta. |
| 04:30–05:00 | Publicación HTTPS, URL/QR, prueba del recorrido desde la URL publicada. | Landing, solicitud, administración y descarga funcionan publicados. |
| 05:00–05:30 | Segunda instalación, actualización de versión, permisos negativos, evidencias y respaldo. | Entrega reproducible y evidencia del flujo completo. |
| 05:30–06:00 | Contingencia según tiempo disponible. | Resolver fallas; congelar cambios y conservar última versión validada. |

La compilación debe comenzar temprano: dependencias, Gradle, SDK y firma pueden consumir tiempo. No esperar a terminar la web para descubrir un bloqueo Android. Acotar cada bloque y ajustar el cronograma si el tiempo restante es menor a seis horas.

## Alojamiento y contingencias

El hosting de la web debe elegirse en los primeros 40 minutos, comprobando herramientas, cuenta y URL HTTPS disponibles. El archivo local y la configuración Firebase de notificaciones no demuestran que ya exista un hosting web listo. No dedicar el plazo a un dominio personalizado.

Supabase Free limita cada archivo a 50 MB. El tamaño del debug actual excede ese límite; el release puede ser menor, pero todavía no lo hemos medido. Primero medir el release y las variantes por arquitectura. Si ninguna cabe, elegir almacenamiento privado que soporte el tamaño y conservar la autorización del servidor; cualquier contratación requiere una decisión explícita sobre coste. Un enlace externo o Google Drive puede servir para una emergencia de descarga, pero no certifica el requisito de carga y control privado desde el panel propio.

Si el correo es el bloqueo, mantener captura de solicitudes y administración, y usar el mecanismo de cuentas ya configurado y validado. No prometer automatización de correo sin pruebas.

Si falla un servicio adicional de la app, priorizar corregir o retirar del recorrido la acción que no funciona. La auditoría tiene pendientes amplios: no comprometer a resolver toda la sincronización dentro de este cronograma.

## Criterio de entrega

- Landing accesible por HTTPS y usable en móvil.
- Solicitud enviada, persistida y visible en el panel después de recargar.
- Panel con acceso privado: usuario común no lista solicitudes, aprueba ni publica APK.
- Versión instalable cargada y publicada desde el panel; versión vigente visible y archivo correcto.
- Si se exige aprobación, una cuenta no aprobada no obtiene enlace de descarga.
- APK firmado instalado desde el navegador en un teléfono nuevo; instrucciones para permitir instalación desde esa fuente.
- Login, datos compartidos, mapa, ubicación y ruta comprobados en el release. Probar Google Sign-In y push si son parte del recorrido prometido.
- Una acción del recorrido confirmado se guarda en servidor y se lee desde el segundo teléfono después de reiniciar.
- URL/QR, APK, versión, checksum, evidencia del recorrido y respaldo de firma disponibles para entregar.
- Limitaciones restantes identificadas con precisión. Ninguna afirmación de «todo funciona perfectamente» sin pruebas.

## Fuentes oficiales consultadas

- [Google Maps: restricciones por aplicación, API y firma Android](https://developers.google.com/maps/api-security-best-practices).
- [Flutter: firma, APK release y variantes por arquitectura](https://docs.flutter.dev/deployment/android).
- [Supabase: buckets privados y enlaces firmados temporales](https://supabase.com/docs/guides/storage/buckets/fundamentals).
- [Supabase: límites de tamaño por archivo](https://supabase.com/docs/guides/storage/uploads/file-limits).
