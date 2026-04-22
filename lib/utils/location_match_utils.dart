import 'package:zimdoctors/services/user_location_service.dart';

class LocationMatchUtils {
  static bool matchesUserLocation({
    required String doctorLocationText,
    required UserLocation userLocation,
  }) {
    final haystack = doctorLocationText.toLowerCase();
    for (final token in _userLocationTokens(userLocation)) {
      if (haystack.contains(token)) return true;
    }
    return false;
  }

  static List<String> _userLocationTokens(UserLocation userLocation) {
    final rawCandidates = <String?>[
      userLocation.bestLabel,
      userLocation.subLocality,
      userLocation.locality,
      userLocation.administrativeArea,
      userLocation.country,
    ];

    final seen = <String>{};
    final tokens = <String>[];
    for (final value in rawCandidates) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (seen.add(normalized)) tokens.add(normalized);
    }
    return tokens;
  }
}

