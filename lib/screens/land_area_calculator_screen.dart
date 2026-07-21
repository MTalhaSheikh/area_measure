import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/geo_area_calculator.dart';
import '../widgets/area_info_panel.dart';

class LandAreaCalculatorScreen extends StatefulWidget {
  const LandAreaCalculatorScreen({super.key});

  @override
  State<LandAreaCalculatorScreen> createState() =>
      _LandAreaCalculatorScreenState();
}

class _LandAreaCalculatorScreenState extends State<LandAreaCalculatorScreen> {
  static const LatLng _fallbackCenter = LatLng(30.1575, 71.5249); // Multan

  GoogleMapController? _mapController;

  /// The ordered list of boundary points the user has placed.
  final List<LatLng> _points = [];

  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _goToCurrentLocation(moveCamera: false);
  }

  // ---------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------

  Future<void> _goToCurrentLocation({bool moveCamera = true}) async {
    setState(() => _locating = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Please turn on location services to center the map.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission denied. Showing default location.');
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (moveCamera && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            18,
          ),
        );
      }
    } catch (_) {
      _showSnack('Could not fetch current location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ---------------------------------------------------------------------
  // Editing boundary points
  // ---------------------------------------------------------------------

  void _addPoint(LatLng point) {
    setState(() => _points.add(point));
  }

  void _movePoint(int index, LatLng newPosition) {
    setState(() => _points[index] = newPosition);
  }

  /// google_maps_flutter's Marker widget doesn't expose a long-press
  /// callback (only onTap), so tapping directly on a placed marker is
  /// the closest equivalent to "long press to remove". We surface it as
  /// a small confirmation sheet so it's still a deliberate, undo-able
  /// action rather than an accidental deletion.
  void _confirmRemovePoint(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Point ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_points[index].latitude.toStringAsFixed(6)}, '
                  '${_points[index].longitude.toStringAsFixed(6)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove this point'),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _points.removeAt(index));
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _undoLastPoint() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _clearAllPoints() {
    if (_points.isEmpty) return;
    setState(() => _points.clear());
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final double areaSqMeters = GeoAreaCalculator.computeAreaInSquareMeters(
      _points,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Land Area Calculator'),
        actions: [
          IconButton(
            tooltip: 'Undo last point',
            onPressed: _points.isEmpty ? null : _undoLastPoint,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Clear all points',
            onPressed: _points.isEmpty ? null : _clearAllPoints,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _fallbackCenter,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _goToCurrentLocation();
            },
            onTap: _addPoint,
            mapType: MapType.hybrid,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _buildMarkers(),
            polygons: _buildPolygons(),
            polylines: _buildPolylines(),
          ),
          if (_locating)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  height: 3,
                  width: 120,
                  child: LinearProgressIndicator(),
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: AreaInfoPanel(
              pointCount: _points.length,
              areaInSquareMeters: areaSqMeters,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'locate_me',
        onPressed: () => _goToCurrentLocation(),
        tooltip: 'Go to my location',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    return {
      for (int i = 0; i < _points.length; i++)
        Marker(
          markerId: MarkerId('point_$i'),
          position: _points[i],
          draggable: true,
          infoWindow: InfoWindow(title: 'Point ${i + 1}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          // Marker has no onLongPress in google_maps_flutter — tapping it
          // opens the remove confirmation instead. See _confirmRemovePoint.
          onTap: () => _confirmRemovePoint(i),
          onDragEnd: (newPosition) => _movePoint(i, newPosition),
        ),
    };
  }

  Set<Polygon> _buildPolygons() {
    if (_points.length < 3) return {};
    return {
      Polygon(
        polygonId: const PolygonId('land_area'),
        points: _points,
        strokeWidth: 3,
        strokeColor: Colors.greenAccent.shade700,
        fillColor: Colors.green.withOpacity(0.25),
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    // While there are fewer than 3 points, a filled polygon can't be
    // drawn yet — show a simple connecting line instead so the user
    // gets immediate visual feedback.
    if (_points.length < 2 || _points.length >= 3) return {};
    return {
      Polyline(
        polylineId: const PolylineId('draft_line'),
        points: _points,
        width: 3,
        color: Colors.greenAccent.shade700,
      ),
    };
  }
}
