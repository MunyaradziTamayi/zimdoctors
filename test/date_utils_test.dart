import 'package:flutter_test/flutter_test.dart';
import 'package:zimdoctors/utils/date_utils.dart';

void main() {
  test('DateUtilsX.isPastDate compares against start of today', () {
    final now = DateTime(2026, 3, 19, 15, 30);
    expect(DateUtilsX.isPastDate('2026-03-18', now: now), isTrue);
    expect(DateUtilsX.isPastDate('2026-03-19', now: now), isFalse);
    expect(DateUtilsX.isPastDate('2026-03-20', now: now), isFalse);
  });

  test('DateUtilsX.upcomingIsoDates filters past and sorts', () {
    final now = DateTime(2026, 3, 19, 15, 30);
    final dates = [
      '2026-03-18',
      '2026-03-20',
      '2026-03-19',
      'invalid-date',
    ];
    expect(
      DateUtilsX.upcomingIsoDates(dates, now: now),
      ['2026-03-19', '2026-03-20'],
    );
  });
}
