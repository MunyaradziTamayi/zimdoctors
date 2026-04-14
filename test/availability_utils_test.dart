import 'package:flutter_test/flutter_test.dart';
import 'package:zimdoctors/utils/availability_utils.dart';

void main() {
  test('earliestUpcomingSlot picks earliest time across dates', () {
    final now = DateTime(2026, 3, 19, 12, 30);
    final slot = AvailabilityUtilsX.earliestUpcomingSlot(
      availableDates: const ['2026-03-19', '2026-03-20'],
      availabilitySlots: const {
        '2026-03-19': ['13:00 - 14:00', '15:00 - 16:00'],
        '2026-03-20': ['08:00 - 09:00'],
      },
      now: now,
    );

    expect(slot, DateTime(2026, 3, 19, 13, 0));
  });

  test('earliestUpcomingSlot falls back to availabilitySlots keys', () {
    final now = DateTime(2026, 3, 19, 12, 30);
    final slot = AvailabilityUtilsX.earliestUpcomingSlot(
      availableDates: const [],
      availabilitySlots: const {
        '2026-03-19': ['13:00 - 14:00'],
      },
      now: now,
    );

    expect(slot, DateTime(2026, 3, 19, 13, 0));
  });
}

