# Rutas: planificación y recorrido

El propósito es convertir los lugares guardados en un viaje que se pueda organizar, revisar y recorrer por etapas. El turista debe saber qué visitará cada día, cómo llegará a la siguiente parada y qué le falta por visitar.

## Cambios implementados

1. **Crear y editar.** El borrador conserva lugares y orden al retroceder. Cada selección pertenece a un día; el mismo lugar puede visitarse en días distintos. El buscador ignora tildes y mayúsculas. La organización permite asignar directamente otro día y sugerir un orden por cercanía, conservando la primera parada y sin atravesar lugares de ubicación desconocida.
2. **Ubicaciones.** Solo coordenadas finitas y válidas habilitan la navegación. Las paradas sin ubicación se señalan en el catálogo y el resumen. En Organizar, «Ubicar en mapa» permite elegir su entrada; el punto queda en esa ruta, sin modificar el catálogo compartido.
3. **Mapa.** El detalle muestra un día a la vez. Los números conservan las posiciones del itinerario, incluso si alguna parada no tiene coordenadas. «Ampliar mapa» abre una vista que admite arrastrar y hacer zoom; «Ver todas las paradas» recupera el encuadre. Los pines se anclan por su centro y quedan sobre el trazado.
4. **Trayectos.** «Calcular trayectos» usa DirectionsService y la función existente `get-directions` para auto o a pie. Solo conecta paradas consecutivas del mismo día con ubicación. Nunca sustituye un error por una línea recta. Las respuestas exitosas se reutilizan durante esa vista; se informa cuando el resultado es parcial. Los tiempos corresponden a traslados y excluyen visitas y descansos.
5. **Modo ruta.** Desde el detalle se abre el checklist personal, con próxima parada, visitas, omisiones y opción de deshacer. «Viajar a esta parada» abre el mapa existente, revisa el trayecto y exige pulsar «Iniciar viaje» para activar GPS. La llegada detectada registra la visita y ofrece continuar a otra parada del mismo día o volver al itinerario. El turista decide cuándo continuar; no se inicia el siguiente tramo automáticamente.
6. **Progreso.** SharedPreferences guarda el avance por cuenta, ruta, día y origen del lugar. Reordenar o recrear filas no pierde visitas; el mismo lugar en otro día tiene progreso independiente. Marcar una visita manualmente no genera una postal del pasaporte. El mapa ofrece acceso para retomar el itinerario mientras haya paradas pendientes.

El botón «Desactivar modo ruta» del itinerario y la X del aviso del mapa ocultan el recorrido activo sin borrar visitas. Se puede activar de nuevo desde el detalle de la ruta.
7. **Diseño.** Títulos y nombre de ruta usan el color principal explícito. El detalle deja más espacio al título, quita la acción duplicada de compartir/menú y explica cómo activar el recorrido.

## Límites actuales y siguientes prioridades

| Prioridad | Trabajo | Motivo / implementación propuesta |
|---|---|---|
| Alta | Catálogo de destinos con entradas verificadas | `mockDestinations` no contiene coordenadas. Sustituirlo por lugares persistidos con identificador, ubicación de acceso y fuente de verificación. Una isla, lago o reserva necesita un acceso real, no su centro geográfico. |
| Alta | Guardado transaccional del itinerario | La edición existente actualiza cabecera y reemplaza paradas con llamadas separadas. Llevar ambas operaciones a una función SQL/RPC con validación de propietario y transacción evita estados parciales por cortes de conexión. Requiere una migración y despliegue del backend. |
| Alta | Fecha del viaje y horarios de visita | Añadir fecha de inicio, estancia prevista y horarios de apertura. Cruzar la fecha del día con las actividades ECO antes de recomendar una jornada. Hoy se muestran las próximas actividades, sin validar su compatibilidad con la fecha de viaje. |
| Media | Progreso entre dispositivos | Llevar el checklist personal a una tabla por usuario y ocurrencia de parada, conservando caché local y conciliación. Hoy persiste únicamente en este dispositivo. |
| Media | Accesos y transporte especial | Distinguir carretera, sendero, ferry o recorrido acuático y exigir conexión real. Directions puede no devolver trayectos a reservas, isletas o playas. |

## Verificación

Las pruebas cubren conservación del borrador, selección independiente por día, búsqueda normalizada, geometría sin saltos entre días o lugares desconocidos, coordenadas inválidas, persistencia por cuenta, concurrencia de escrituras, omitir/deshacer y la interfaz de modo ruta sin ubicación. Se mantienen las comprobaciones existentes de Directions, progreso GPS, llegada y navegación de pantallas.

Para validar en un dispositivo: crear dos días, ubicar una parada, revisar y ampliar el mapa, calcular trayectos, iniciar el primer viaje, desplazar manualmente el mapa y recentrar, comprobar la llegada, continuar la siguiente parada y volver a abrir el itinerario tras reiniciar la app. Los trayectos reales requieren la función y las credenciales de mapas ya utilizadas por la app.
