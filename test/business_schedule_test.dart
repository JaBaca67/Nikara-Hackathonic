import 'package:flutter_test/flutter_test.dart';
import 'package:nikara_app/features/business/utils/business_schedule.dart';

void main() {
  group('formato estructurado del wizard', () {
    test('se traduce a días y horas legibles', () {
      // Crudo, la pantalla de detalle mostraba "1,2,3,4,5: 07:00–18:00".
      expect(
        businessScheduleLines('1,2,3,4,5: 07:00–18:00\n6,7: 06:00–19:00'),
        [
          'Lunes a Viernes · 7:00 AM – 6:00 PM',
          'Sábado a Domingo · 6:00 AM – 7:00 PM',
        ],
      );
      expect(businessScheduleLines('1,2,3,4,5,6,7: 00:00–23:30'), [
        'Todos los días · 12:00 AM – 11:30 PM',
      ]);
      expect(businessScheduleLines('1,3,5: 08:00–12:00'), [
        'L, X, V · 8:00 AM – 12:00 PM',
      ]);
    });

    test('resuelve la franja del día actual', () {
      // 2026-10-05 es lunes; 2026-10-11, domingo.
      final lunes = businessScheduleSummary(
        '1,2,3,4,5: 07:00–18:00',
        now: DateTime(2026, 10, 5),
      );
      expect(lunes.label, 'Hoy');
      expect(lunes.value, '7:00 AM – 6:00 PM');

      final domingo = businessScheduleSummary(
        '1,2,3,4,5: 07:00–18:00',
        now: DateTime(2026, 10, 11),
      );
      expect(domingo.label, 'Hoy');
      expect(domingo.value, 'Cerrado');
    });

    test('acepta las etiquetas de día de antes del 2026-09-05', () {
      expect(businessScheduleLines('Lunes a viernes: 08:00–17:00'), [
        'Lunes a Viernes · 8:00 AM – 5:00 PM',
      ]);
    });
  });

  group('prosa libre', () {
    test('se muestra literal, nunca reescrita', () {
      const raw = 'Lunes a Domingo de 11:30 AM a 10:00 PM';
      expect(businessScheduleLines(raw), [raw]);
    });

    test('la tarjeta se queda con el rango horario, no con la frase', () {
      // Es lo que hacía que la columna "Hoy" dijera "Lunes a Doming…".
      final summary = businessScheduleSummary(
        'Lunes a Domingo de 11:30 AM a 10:00 PM',
      );
      expect(summary.label, 'Horario');
      expect(summary.value, '11:30 AM – 10:00 PM');

      expect(
        businessScheduleSummary(
          'Lunes a viernes: 8:00–18:00. Sábado: 8:00–16:00.',
        ).value,
        '8:00 – 18:00',
      );
    });

    test('"Hoy" solo se afirma cuando se puede resolver el día', () {
      // Con prosa libre no hay forma de saber a qué día corresponde: la
      // etiqueta no puede prometer más de lo que el dato respalda.
      expect(
        businessScheduleSummary('Lunes a Domingo de 6:00 AM a 6:00 PM').label,
        'Horario',
      );
    });

    test('reconoce 24 horas y el horario vacío', () {
      expect(
        businessScheduleSummary(
          'Servicio de hotel: 24 horas, según la web oficial.',
        ).value,
        '24 horas',
      );
      expect(businessScheduleSummary('   ').value, 'No especificado');
      expect(businessScheduleLines(''), isEmpty);
    });

    test('sin rango reconocible cae a la primera línea', () {
      expect(
        businessScheduleSummary('Abrimos cuando hay marea\nConsultar').value,
        'Abrimos cuando hay marea',
      );
    });
  });
}
