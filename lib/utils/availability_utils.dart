import 'package:zimdoctors/utils/date_utils.dart';

class AvailabilityUtilsX {
  static DateTime? earliestUpcomingSlot({
    required Iterable<String> availableDates,
    required Map<String, List<String>> availabilitySlots,
    DateTime? now,
  }) {
    final nowLocal = now ?? DateTime.now();

    final dateSource =
        availableDates.isNotEmpty ? availableDates : availabilitySlots.keys;
    final upcomingDates = DateUtilsX.upcomingIsoDates(dateSource, now: nowLocal);

    DateTime? earliest;
    for (final isoDate in upcomingDates) {
      final date = DateUtilsX.tryParseIsoDate(isoDate);
      if (date == null) continue;

      final slots = availabilitySlots[isoDate] ?? const <String>[];
      for (final slot in slots) {
        final start = _tryParseSlotStart(slot);
        if (start == null) continue;

        final slotStart = date.add(start);
        if (slotStart.isBefore(nowLocal)) continue;

        if (earliest == null || slotStart.isBefore(earliest)) earliest = slotStart;
      }
    }
    return earliest;
  }

  static Duration? _tryParseSlotStart(String slot) {
    final startPart = slot.split('-').first.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(startPart);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;
    return Duration(hours: hour, minutes: minute);
  }
}

