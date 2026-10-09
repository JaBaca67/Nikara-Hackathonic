# Evidencia de pruebas seleccionadas

Esta ejecución corresponde a la auditoría inicial, antes de las correcciones. La validación posterior está documentada en [cambios de datos remotos](cambios_datos_remotos.md): suite completa con 570 pruebas y, después de añadir la edición remota del username para cuentas anteriores, 35 pruebas de registro y Ajustes aprobadas. El análisis final de Dart conserva únicamente dos diagnósticos previos.

Ejecución local durante la auditoría del 8 de octubre de 2026 (Guatemala).

```powershell
flutter test --no-pub test/favorites_per_account_test.dart test/favorites_offline_cache_test.dart test/passport_service_test.dart test/route_travel_service_test.dart test/origin_flow_test.dart test/settings_categories_test.dart test/notification_refresh_test.dart test/eco_participation_test.dart test/review_submission_test.dart test/route_description_service_test.dart
```

Resultado del runner: **`00:24 +98: All tests passed!`**, código de salida **0**.

La selección cubre separación de favoritos por cuenta y caché sin conexión,
persistencia local del pasaporte y progreso, payload de procedencia y edición,
pantallas de Ajustes, refresh de avisos, inscripción ECO, envío de reseñas y
descripciones de rutas. No representa la suite completa.

Las pruebas usan preferencias simuladas y, en distintos servicios, HTTP
simulado o credenciales falsas. No prueban las políticas, triggers, funciones
desplegadas ni la sincronización real entre dos dispositivos.

La ejecución emitió advertencias de descarga de fuentes de `google_fonts`
(Nunito y League Spartan); el runner terminó con todas las pruebas aprobadas.
No se corrigió ese problema de infraestructura visual como parte de esta
auditoría de datos.
