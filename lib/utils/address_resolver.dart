import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Turns a coordinate into a human-readable address, e.g. "Suraj Miani
/// Road, Multan, Punjab". Returns null if it can't be resolved (no
/// internet, no geocoding service on the device, or nothing found) —
/// callers should treat that as "address unavailable", not an error.
class AddressResolver {
  AddressResolver._();

  static Future<String?> resolve(LatLng point) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) return null;
      return _format(placemarks.first);
    } catch (_) {
      return null;
    }
  }

  static String? _format(Placemark p) {
    final List<String> parts = [
      p.street,
      p.subLocality,
      p.locality,
      p.administrativeArea,
    ].where((s) => s != null && s.trim().isNotEmpty).cast<String>().toList();

    // Drop consecutive duplicates (street/subLocality are often the same
    // string in some regions' geocoding responses).
    final List<String> deduped = [];
    for (final part in parts) {
      if (deduped.isEmpty || deduped.last != part) deduped.add(part);
    }

    return deduped.isEmpty ? null : deduped.join(', ');
  }
}
