import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Computes the area enclosed by a polygon of [LatLng] points on the
/// surface of the earth, and converts it to common land-measurement units.
///
/// This uses the spherical-excess algorithm (the same one used internally
/// by Google's Android Maps Utils `SphericalUtil.computeArea`), so results
/// closely match what you'd see in Google Maps / Google Earth. No extra
/// network calls or paid API are needed for this calculation.
class GeoAreaCalculator {
  GeoAreaCalculator._();

  /// Earth's mean (authalic) radius in meters — same constant Google uses.
  static const double _earthRadiusMeters = 6378137.0;

  /// Returns the enclosed area in square meters.
  /// Needs at least 3 points; returns 0 for fewer.
  static double computeAreaInSquareMeters(List<LatLng> path) {
    if (path.length < 3) return 0;
    return _computeSignedArea(path).abs();
  }

  static double _computeSignedArea(List<LatLng> path) {
    final int size = path.length;
    double total = 0;

    final LatLng prevPoint = path[size - 1];
    double prevTanLat = math.tan(
      (math.pi / 2 - _toRadians(prevPoint.latitude)) / 2,
    );
    double prevLng = _toRadians(prevPoint.longitude);

    for (final LatLng point in path) {
      final double tanLat = math.tan(
        (math.pi / 2 - _toRadians(point.latitude)) / 2,
      );
      final double lng = _toRadians(point.longitude);
      total += _polarTriangleArea(tanLat, lng, prevTanLat, prevLng);
      prevTanLat = tanLat;
      prevLng = lng;
    }

    return total * _earthRadiusMeters * _earthRadiusMeters;
  }

  static double _polarTriangleArea(
    double tan1,
    double lng1,
    double tan2,
    double lng2,
  ) {
    final double deltaLng = lng1 - lng2;
    final double t = tan1 * tan2;
    return 2 * math.atan2(t * math.sin(deltaLng), 1 + t * math.cos(deltaLng));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Straight-line (geodesic) distance between two points, in meters,
  /// using the haversine formula. Used to label each side of the
  /// boundary with its length.
  static double distanceInMeters(LatLng a, LatLng b) {
    final double lat1 = _toRadians(a.latitude);
    final double lat2 = _toRadians(b.latitude);
    final double dLat = _toRadians(b.latitude - a.latitude);
    final double dLng = _toRadians(b.longitude - a.longitude);

    final double h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return _earthRadiusMeters * c;
  }

  // ---------------- Unit conversions ----------------

  static double squareMetersToSquareFeet(double sqMeters) =>
      sqMeters * 10.7639104167;

  static double squareMetersToSquareYards(double sqMeters) =>
      sqMeters * 1.19599005;

  static double squareMetersToAcres(double sqMeters) =>
      sqMeters * 0.000247105381;

  static double squareMetersToHectares(double sqMeters) => sqMeters / 10000;

  static double squareMetersToSquareKilometers(double sqMeters) =>
      sqMeters / 1000000;

  /// Marla and Kanal are traditional land units widely used across
  /// Pakistan and North India.
  static double squareMetersToMarla(double sqMeters) => sqMeters / 25.2929;

  static double squareMetersToKanal(double sqMeters) => sqMeters / 505.857;
}
