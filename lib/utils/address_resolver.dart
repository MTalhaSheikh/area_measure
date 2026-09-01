import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Result of a reverse-geocoding lookup: a human-readable address plus the
/// ISO 3166-1 alpha-2 country code (e.g. "PK"), when available. Either can
/// be null if the lookup fails or the coordinates don't resolve to a known
/// place — callers should treat that as "unknown", not an error.
class ResolvedAddress {
  const ResolvedAddress({this.formatted, this.isoCountryCode});

  final String? formatted;
  final String? isoCountryCode;
}

/// Turns a coordinate into a human-readable address, e.g. "Suraj Miani
/// Road, Multan, Punjab", and the country it's in.
class AddressResolver {
  AddressResolver._();

  static Future<ResolvedAddress> resolve(LatLng point) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) return const ResolvedAddress();
      final Placemark p = placemarks.first;
      return ResolvedAddress(
        formatted: _format(p),
        isoCountryCode: p.isoCountryCode,
      );
    } catch (_) {
      return const ResolvedAddress();
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
