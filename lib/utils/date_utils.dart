class DateUtilsX {
  static DateTime startOfDay(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

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
