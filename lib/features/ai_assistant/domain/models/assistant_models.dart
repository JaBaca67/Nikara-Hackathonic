/// Modelos del asistente de IA. Serialización a mano con `fromJson`, igual
/// que el resto del proyecto (no hay codegen).
///
/// Lo que llega de la Edge Function `travel-assistant` son **ids**, no datos
/// de lugares: el modelo elige del catálogo y Flutter hidrata con
/// `BusinessStorageService`/`EcoService`. Por eso acá no hay nombres ni fotos
/// — ver el comentario de cabecera de la función para el por qué.
library;

/// Qué tabla de origen tiene una recomendación. Lo decide el servidor a
/// partir del catálogo, nunca el modelo de lenguaje: si se equivocara de
/// tipo, la app abriría la pantalla de detalle incorrecta.
enum AssistantItemKind {
  business,
  ecoActivity;

  static AssistantItemKind fromWire(String? raw) => raw == 'eco_activity'
      ? AssistantItemKind.ecoActivity
      : AssistantItemKind.business;
}

/// Un lugar que el asistente recomienda, más la razón que dio.
class AssistantRecommendation {
  const AssistantRecommendation({
    required this.id,
    required this.kind,
    required this.reason,
  });

  factory AssistantRecommendation.fromJson(Map<String, dynamic> json) {
    return AssistantRecommendation(
      id: json['id'] as String? ?? '',
      kind: AssistantItemKind.fromWire(json['kind'] as String?),
      reason: json['reason'] as String? ?? '',
    );
  }

  final String id;
  final AssistantItemKind kind;

  /// Por qué encaja con lo que pidió el usuario, en una oración.
  final String reason;
}

/// Una parada dentro de un día del itinerario propuesto.
class AssistantStop {
  const AssistantStop({
    required this.id,
    required this.kind,
    required this.note,
  });

  factory AssistantStop.fromJson(Map<String, dynamic> json) {
    return AssistantStop(
      id: json['id'] as String? ?? '',
      kind: AssistantItemKind.fromWire(json['kind'] as String?),
      note: json['note'] as String? ?? '',
    );
  }

  final String id;
  final AssistantItemKind kind;
  final String note;
}

class AssistantItineraryDay {
  const AssistantItineraryDay({required this.day, required this.stops});

  factory AssistantItineraryDay.fromJson(Map<String, dynamic> json) {
    return AssistantItineraryDay(
      day: (json['day'] as num?)?.toInt() ?? 1,
      stops: ((json['stops'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AssistantStop.fromJson)
          .toList(growable: false),
    );
  }

  final int day;
  final List<AssistantStop> stops;
}

/// Itinerario propuesto, listo para convertirse en una ruta real.
class AssistantItinerary {
  const AssistantItinerary({required this.title, required this.days});

  factory AssistantItinerary.fromJson(Map<String, dynamic> json) {
    return AssistantItinerary(
      title: json['title'] as String? ?? 'Tu plan',
      days: ((json['days'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AssistantItineraryDay.fromJson)
          .toList(growable: false),
    );
  }

  final String title;
  final List<AssistantItineraryDay> days;

  int get totalStops => days.fold(0, (sum, day) => sum + day.stops.length);
}

/// La respuesta completa de un turno del asistente.
class AssistantReply {
  const AssistantReply({
    required this.text,
    this.recommendations = const [],
    this.itinerary,
  });

  factory AssistantReply.fromJson(Map<String, dynamic> json) {
    final rawItinerary = json['itinerary'];
    return AssistantReply(
      text: json['reply'] as String? ?? '',
      recommendations: ((json['recommendations'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AssistantRecommendation.fromJson)
          .toList(growable: false),
      itinerary: rawItinerary is Map<String, dynamic>
          ? AssistantItinerary.fromJson(rawItinerary)
          : null,
    );
  }

  final String text;
  final List<AssistantRecommendation> recommendations;
  final AssistantItinerary? itinerary;
}

/// Quién escribió un mensaje del hilo.
enum AssistantAuthor { user, assistant }

/// Un mensaje del chat tal como se pinta en pantalla.
///
/// Es el modelo de la UI, no del transporte: por eso incluye [isError] (un
/// aviso que se muestra como burbuja del asistente pero no se reenvía a la
/// API como parte del historial, para no enseñarle a disculparse).
class AssistantMessage {
  const AssistantMessage({
    required this.author,
    required this.text,
    this.recommendations = const [],
    this.itinerary,
    this.isError = false,
  });

  AssistantMessage.user(this.text)
    : author = AssistantAuthor.user,
      recommendations = const [],
      itinerary = null,
      isError = false;

  AssistantMessage.fromReply(AssistantReply reply)
    : author = AssistantAuthor.assistant,
      text = reply.text,
      recommendations = reply.recommendations,
      itinerary = reply.itinerary,
      isError = false;

  AssistantMessage.error(String message)
    : author = AssistantAuthor.assistant,
      text = message,
      recommendations = const [],
      itinerary = null,
      isError = true;

  final AssistantAuthor author;
  final String text;
  final List<AssistantRecommendation> recommendations;
  final AssistantItinerary? itinerary;
  final bool isError;

  bool get isUser => author == AssistantAuthor.user;
}
