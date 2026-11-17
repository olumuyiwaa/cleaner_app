import 'package:geolocator/geolocator.dart';

typedef LatLng = ({double lat, double lng});

/// Best-effort GPS. Returns null (never throws) when permission is refused,
/// location is off or there is no fix in time, so a weak signal never blocks
/// a job; the server decides whether a missing position is acceptable.
class LocationService {
  const LocationService();

  Future<LatLng?> currentPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );
      return (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return null;
    }
  }
}
