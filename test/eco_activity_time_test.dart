import 'package:flutter_test/flutter_test.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/utils/eco_format.dart';

/// Regresión del bug de zona horaria de las jornadas ECO: Postgres devuelve
/// `start_time` como `timestamptz` en UTC y los formatters de `eco_format.dart`
/// leen `.hour`/`.day` crudos, así que una jornada de las 9:00 a.m. en
/// Nicaragua (UTC-6) se mostraba a las 3:00 p.m.
///
/// Dart no permite cambiar la zona horaria del proceso en runtime (solo con la
/// variable de entorno `TZ` al lanzarlo), así que estas aserciones están
/// escritas para pasar en cualquier zona: se comparan contra la zona local de
/// la máquina en vez de contra una hora fija.
void main() {
  Map<String, dynamic> row({required String startTime}) => {
    'id': 'eco-1',
    'title': 'Limpieza de playa',
    'start_time': startTime,
    'created_at': '2026-01-01T00:00:00Z',
    'status': 'approved',
  };

  group('EcoActivityModel.fromRow — zona horaria', () {
    test('normaliza start_time a la zona local en vez de dejarlo en UTC', () {
      final activity = EcoActivityModel.fromRow(
        row(startTime: '2026-10-05T15:00:00Z'),
      );

      expect(
        activity.startTime.isUtc,
        isFalse,
        reason:
            'si queda en UTC, los formatters pintan la hora del servidor y no '
            'la del usuario',
      );
    });

    test('conserva el instante absoluto al normalizar', () {
      final activity = EcoActivityModel.fromRow(
        row(startTime: '2026-10-05T15:00:00Z'),
      );

      expect(
        activity.startTime.toUtc(),
        DateTime.utc(2026, 10, 5, 15),
        reason: 'toLocal() cambia la representación, nunca el instante',
      );
    });

    test(
      'los componentes que leen los formatters son los de la zona local',
      () {
        const raw = '2026-10-05T15:00:00Z';
        final activity = EcoActivityModel.fromRow(row(startTime: raw));
        final expected = DateTime.parse(raw).toLocal();

        expect(activity.startTime.hour, expected.hour);
        expect(activity.startTime.day, expected.day);
        expect(
          formatEcoDateTimeLong(activity.startTime),
          formatEcoDateTimeLong(expected),
        );
      },
    );

    test('un start_time con offset explícito también queda local', () {
      // Lo que manda `eco_service` es siempre `toUtc()`, pero una fila vieja o
      // escrita a mano desde el dashboard puede traer el offset de Managua.
      final activity = EcoActivityModel.fromRow(
        row(startTime: '2026-10-05T09:00:00-06:00'),
      );

      expect(activity.startTime.isUtc, isFalse);
      expect(activity.startTime.toUtc(), DateTime.utc(2026, 10, 5, 15));
    });

    test(
      'isPast compara contra el instante real, no contra la hora pintada',
      () {
        final pasado = EcoActivityModel.fromRow(
          row(startTime: '2020-01-01T12:00:00Z'),
        );
        final futuro = EcoActivityModel.fromRow(
          row(startTime: '2090-01-01T12:00:00Z'),
        );

        expect(pasado.isPast, isTrue);
        expect(futuro.isPast, isFalse);
      },
    );
  });

  group('EcoParticipant.fromRow — zona horaria', () {
    test('normaliza joined_at: se pinta en la pestaña de participantes', () {
      final participant = EcoParticipant.fromRow({
        'user_id': 'user-1',
        'joined_at': '2026-10-05T15:00:00Z',
        'public_profiles': {'full_name': 'Sofía Ramírez', 'role': 'turista'},
      });

      expect(participant.joinedAt.isUtc, isFalse);
      expect(participant.joinedAt.toUtc(), DateTime.utc(2026, 10, 5, 15));
      expect(
        formatEcoDateTimeShort(participant.joinedAt),
        formatEcoDateTimeShort(
          DateTime.parse('2026-10-05T15:00:00Z').toLocal(),
        ),
      );
    });
  });

  group('eco_format — hora de 12 horas', () {
    test('formatea una hora local fija sin ambigüedad de mediodía', () {
      expect(formatEcoTime(DateTime(2026, 10, 5, 9, 0)), '9:00 a.m.');
      expect(formatEcoTime(DateTime(2026, 10, 5, 15, 0)), '3:00 p.m.');
      expect(formatEcoTime(DateTime(2026, 10, 5, 0, 5)), '12:05 a.m.');
      expect(formatEcoTime(DateTime(2026, 10, 5, 12, 0)), '12:00 p.m.');
    });

    test('formatEcoDateTimeLong arma la cadena completa en español', () {
      expect(
        formatEcoDateTimeLong(DateTime(2026, 10, 5, 9, 0)),
        '5 de octubre, 2026 · 9:00 a.m.',
      );
    });
  });
}
