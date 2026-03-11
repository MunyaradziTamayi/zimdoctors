import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum UserLocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class UserLocationFailure implements Exception {
  final UserLocationFailureReason reason;

  const UserLocationFailure(this.reason);
}

class UserLocation {
  final double latitude;
  final double longitude;
  final String? locality;
  final String? subLocality;
  final String? administrativeArea;
  final String? country;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.locality,
    required this.subLocality,
    required this.administrativeArea,
    required this.country,
  });

  String? get bestLabel {
    List<String> buildLabel(List<String?> rawParts) {
      final seen = <String>{};
      final parts = <String>[];
      for (final value in rawParts) {
        final trimmed = value?.trim();
        if (trimmed == null || trimmed.isEmpty) continue;
        final key = trimmed.toLowerCase();
        if (seen.add(key)) parts.add(trimmed);
      }
      return parts;
    }

    final primary = buildLabel([locality, subLocality]);
    if (primary.isNotEmpty) return primary.join(', ');

    final fallback = buildLabel([administrativeArea, country]);
    if (fallback.isNotEmpty) return fallback.join(', ');

    return null;
  }
}

class UserLocationService {
  Future<UserLocation> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const UserLocationFailure(UserLocationFailureReason.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const UserLocationFailure(UserLocationFailureReason.permissionDenied);
    }

    if (permission == LocationPermission.deniedForever) {
      throw const UserLocationFailure(
        UserLocationFailureReason.permissionDeniedForever,
      );
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    String? locality;
    String? subLocality;
    String? administrativeArea;
    String? country;

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      locality = place?.locality ?? place?.subAdministrativeArea;
      subLocality = place?.subLocality ??
          place?.thoroughfare ??
          place?.subThoroughfare ??
          place?.name;
      administrativeArea = place?.administrativeArea;
      country = place?.country;
    } catch (_) {
      // Reverse geocoding can fail on some devices; still return coordinates.
    }

    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      locality: locality,
      subLocality: subLocality,
      administrativeArea: administrativeArea,
      country: country,
    );
  }
}
