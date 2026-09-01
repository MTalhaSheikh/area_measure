import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A boundary the user has named and saved for later, so they don't have
/// to re-walk/re-tap the same plot of land again.
class SavedPlot {
  const SavedPlot({
    required this.id,
    required this.name,
    required this.points,
    required this.areaSquareMeters,
    required this.createdAt,
    this.address,
    this.showLocalUnits = true,
  });

  final String id;
  final String name;
  final List<LatLng> points;
  final double areaSquareMeters;
  final DateTime createdAt;

  /// Human-readable reverse-geocoded address of the plot's centroid.
  /// Nullable because reverse geocoding can fail (no internet, no
  /// permission, or the coordinates don't resolve to a known address).
  final String? address;

  /// Whether this plot's location is somewhere marla/kanal make sense to
  /// show (i.e. Pakistan). Decided once at save time from the plot's own
  /// location, not the app's current location, so a saved list can mix
  /// plots from different countries correctly.
  final bool showLocalUnits;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'points': points.map((p) => [p.latitude, p.longitude]).toList(),
    'areaSquareMeters': areaSquareMeters,
    'createdAt': createdAt.toIso8601String(),
    'address': address,
    'showLocalUnits': showLocalUnits,
  };

  factory SavedPlot.fromJson(Map<String, dynamic> json) {
    return SavedPlot(
      id: json['id'] as String,
      name: json['name'] as String,
      points: (json['points'] as List)
          .map(
            (e) => LatLng(
              (e[0] as num).toDouble(),
              (e[1] as num).toDouble(),
            ),
          )
          .toList(),
      areaSquareMeters: (json['areaSquareMeters'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      // Older saved entries (from before these fields existed) won't have
      // these keys at all, so fall back to sensible defaults rather than
      // throwing.
      address: json['address'] as String?,
      showLocalUnits: json['showLocalUnits'] as bool? ?? true,
    );
  }
}
