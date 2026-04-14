class DateUtilsX {
  static DateTime startOfDay(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  static AppointmentWindow? tryParseAppointmentWindow(
    String isoDate,
    String slot, {
    Duration defaultDuration = const Duration(hours: 1),
  }) {
    final parsedDate = tryParseIsoDate(isoDate);
    if (parsedDate == null) return null;

    final normalized = slot.trim();
    if (normalized.isEmpty) return null;

    final parts = normalized.split('-').map((p) => p.trim()).toList();
    final startTime = _tryParseTimeOfDay(parts.first);
    if (startTime == null) return null;

    final start = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      startTime.hour,
      startTime.minute,
    );

    if (parts.length >= 2) {
      final endTime = _tryParseTimeOfDay(parts[1]);
      if (endTime == null) return AppointmentWindow(start, start.add(defaultDuration));
      final end = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        endTime.hour,
        endTime.minute,
      );
      return AppointmentWindow(start, end.isAfter(start) ? end : start.add(defaultDuration));
    }

    return AppointmentWindow(start, start.add(defaultDuration));
  }

  static _TimeOfDay24? _tryParseTimeOfDay(String input) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(input.trim());
    if (m == null) return null;
    final hour = int.tryParse(m.group(1) ?? '');
    final minute = int.tryParse(m.group(2) ?? '');
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;
    return _TimeOfDay24(hour, minute);
  }

  static DateTime? tryParseIsoDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  static bool isPastDate(String isoDate, {DateTime? now}) {
    final today = startOfDay(now ?? DateTime.now());
    final parsed = tryParseIsoDate(isoDate);
    if (parsed == null) return false;
    return parsed.isBefore(today);
  }

  static List<String> upcomingIsoDates(
    Iterable<String> isoDates, {
    DateTime? now,
  }) {
    final today = startOfDay(now ?? DateTime.now());
    final kept = <String>[];
    for (final d in isoDates) {
      final parsed = tryParseIsoDate(d);
      if (parsed == null) continue;
      if (!parsed.isBefore(today)) kept.add(d);
    }
    kept.sort((a, b) {
      final da = tryParseIsoDate(a);
      final db = tryParseIsoDate(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return kept;
  }
}

class AppointmentWindow {
  final DateTime start;
  final DateTime end;
  const AppointmentWindow(this.start, this.end);
}

class _TimeOfDay24 {
  final int hour;
  final int minute;
  const _TimeOfDay24(this.hour, this.minute);
}
