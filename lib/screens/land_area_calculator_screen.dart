import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/saved_plot.dart';
import '../services/app_update_service.dart';
import '../services/points_budget_repository.dart';
import '../services/rewarded_ad_service.dart';
import '../services/saved_plots_repository.dart';
import '../utils/address_resolver.dart';
import '../utils/geo_area_calculator.dart';
import '../utils/label_marker_factory.dart';
import '../utils/regional_units.dart';
import '../widgets/area_info_panel.dart';
import 'saved_plots_screen.dart';

class LandAreaCalculatorScreen extends StatefulWidget {
  const LandAreaCalculatorScreen({super.key});

  @override
  State<LandAreaCalculatorScreen> createState() =>
      _LandAreaCalculatorScreenState();
}

class _LandAreaCalculatorScreenState extends State<LandAreaCalculatorScreen> {
  static const LatLng _fallbackCenter = LatLng(30.1575, 71.5249); // Multan

  /// Points allowed before a rewarded ad is required. There's no upper
  /// ceiling — each ad watch adds [_pointsPerAd] more, and the user can
  /// keep watching ads to keep extending the boundary as much as they
  /// want. Both numbers are plain constants — change them here to retune.
  static const int _freePointsLimit = 4;
  static const int _pointsPerAd = 4;

  GoogleMapController? _mapController;

  /// The ordered list of boundary points the user has placed.
  final List<LatLng> _points = [];

  /// Points removed via "undo", most-recently-removed last, so "redo" can
  /// put them back in the right order. Only the undo/redo pair feeds this
  /// stack — deliberately removing a point via the marker sheet does not,
  /// to keep the mental model simple ("redo" only reverses "undo").
  final List<LatLng> _redoStack = [];

  /// Small text-pill markers showing each side's length, regenerated
  /// whenever the boundary changes.
  Set<Marker> _lengthLabelMarkers = {};

  LatLng? _initialCameraTarget;
  bool _resolvingStartLocation = true;

  final SavedPlotsRepository _savedPlotsRepository = SavedPlotsRepository();
  final PointsBudgetRepository _pointsBudgetRepository = PointsBudgetRepository();

  MapType _mapType = MapType.hybrid;

  /// Whether to show marla/kanal alongside the universal units. Defaults
  /// to true (the app's home market is Pakistan) and is corrected to
  /// false once we can confirm the user is somewhere else.
  bool _showLocalUnits = true;

  final RewardedAdService _rewardedAdService = RewardedAdService();

  /// How many rewarded ads the user has watched this session — each one
  /// adds [_pointsPerAd] to the allowed point count. Session-only by
  /// design (resets on app restart); persisting this is possible later
  /// the same way saved plots are, if you want it to survive a restart.
  int _adsWatchedThisSession = 0;

  /// A point the user tapped that couldn't be placed yet because the
  /// current limit was hit — placed automatically once they earn the
  /// reward, so watching the ad doesn't lose their tap.
  LatLng? _pendingPointAfterAd;

  int get _pointsAllowed =>
      _freePointsLimit + (_adsWatchedThisSession * _pointsPerAd);

  /// Points "spent" toward the limit — increases when a point is placed,
  /// but unlike _points.length, does NOT decrease when a point is
  /// deleted via the pin's delete sheet. Without this, someone could
  /// place a point, delete it, place another, delete it, forever,
  /// without ever needing to watch an ad. Undo/redo are the exception:
  /// they mirror the exact last action, so they do adjust this count —
  /// only the explicit "delete this point" action doesn't.
  int _pointsUsed = 0;

  @override
  void initState() {
    super.initState();
    _resolveStartLocation();
    _restorePointsBudget();
    AppUpdateService.checkAndForceUpdateIfNeeded();
  }

  /// Restores how many points have been spent and how many ads have been
  /// watched — but deliberately leaves the map empty. Only the budget
  /// carries across a restart, not the unsaved drawing itself.
  Future<void> _restorePointsBudget() async {
    final budget = await _pointsBudgetRepository.load();
    if (!mounted) return;
    if (budget.pointsUsed == 0 && budget.adsWatched == 0) return;
    setState(() {
      _pointsUsed = budget.pointsUsed;
      _adsWatchedThisSession = budget.adsWatched;
    });
  }

  void _persistPointsBudget() {
    _pointsBudgetRepository.save(
      pointsUsed: _pointsUsed,
      adsWatched: _adsWatchedThisSession,
    );
  }

  @override
  void dispose() {
    _rewardedAdService.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------

  /// Figures out where to first point the camera *before* the map is
  /// built, so it opens already centered on the user instead of opening
  /// on the fallback location and only animating away from it afterwards.
  Future<void> _resolveStartLocation() async {
    final LatLng? here = await _tryGetCurrentLatLng();
    if (!mounted) return;
    final LatLng target = here ?? _fallbackCenter;
    setState(() {
      _initialCameraTarget = target;
      _resolvingStartLocation = false;
    });
    if (here == null) {
      _showSnack('Could not get your location — showing default area.');
    }
    // Non-blocking: don't hold up showing the map just to know which
    // units to display. The panel updates itself once this resolves.
    unawaited(_refreshLocalUnitsFlag(target));
  }

  Future<void> _refreshLocalUnitsFlag(LatLng target) async {
    final ResolvedAddress resolved = await AddressResolver.resolve(target);
    if (!mounted) return;
    final bool shouldShowLocal = RegionalUnits.showLocalUnits(
      resolved.isoCountryCode,
    );
    if (shouldShowLocal != _showLocalUnits) {
      setState(() => _showLocalUnits = shouldShowLocal);
    }
  }

  Future<LatLng?> _tryGetCurrentLatLng() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _goToCurrentLocation() async {
    final LatLng? here = await _tryGetCurrentLatLng();
    if (here == null) {
      _showSnack('Could not fetch current location.');
      return;
    }
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(here, 18),
    );
    // The user may have moved to a different country since the app
    // opened (or this may be a more accurate fix than the startup one).
    unawaited(_refreshLocalUnitsFlag(here));
  }

  // ---------------------------------------------------------------------
  // Editing boundary points
  // ---------------------------------------------------------------------

  void _addPoint(LatLng point) {
    if (_pointsUsed >= _pointsAllowed) {
      _showPointLimitReached(point);
      return;
    }
    setState(() {
      _points.add(point);
      _pointsUsed++;
      _redoStack.clear(); // a fresh action invalidates any pending redo
    });
    _refreshLengthLabels();
  }

  void _showPointLimitReached(LatLng tappedPoint) {
    _pendingPointAfterAd = tappedPoint;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock more points'),
        content: Text(
          "You've used all $_pointsAllowed available points. Watch a "
          'short video to unlock $_pointsPerAd more for this plot.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _pendingPointAfterAd = null;
              Navigator.pop(context);
            },
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _watchAdForMorePoints();
            },
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Watch ad'),
          ),
        ],
      ),
    );
  }

  Future<void> _watchAdForMorePoints() async {
    if (!_rewardedAdService.isReady) {
      _showSnack('Ad not ready yet — try again in a moment.');
      _pendingPointAfterAd = null;
      return;
    }

    final bool shown = await _rewardedAdService.show(
      onUserEarnedReward: () {
        if (!mounted) return;
        setState(() {
          _adsWatchedThisSession++;
          if (_pendingPointAfterAd != null) {
            _points.add(_pendingPointAfterAd!);
            _pointsUsed++;
            _redoStack.clear();
            _pendingPointAfterAd = null;
          }
        });
        _refreshLengthLabels();
        _showSnack('Unlocked $_pointsPerAd more points — $_pointsAllowed total now.');
      },
    );

    if (!shown) {
      _showSnack('Ad not ready yet — try again in a moment.');
      _pendingPointAfterAd = null;
    }
  }

  void _movePoint(int index, LatLng newPosition) {
    setState(() => _points[index] = newPosition);
    _refreshLengthLabels();
  }

  void _undoLastPoint() {
    if (_points.isEmpty) return;
    setState(() {
      _redoStack.add(_points.removeLast());
      _pointsUsed--;
    });
    _refreshLengthLabels();
  }

  void _redoLastPoint() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _points.add(_redoStack.removeLast());
      _pointsUsed++;
    });
    _refreshLengthLabels();
  }

  void _clearAllPoints() {
    if (_points.isEmpty) return;
    setState(() {
      _points.clear();
      _redoStack.clear();
      // Deliberately NOT resetting _pointsUsed here. It must only ever
      // decrease via Undo (which reverses your exact last action) — not
      // via clearing the map, and not via deleting an individual point.
      // Otherwise "clear + redraw" becomes a free way to dodge the ad
      // wall, exactly the loophole this counter exists to prevent.
    });
    _refreshLengthLabels();
  }

  Future<void> _saveCurrentPlot() async {
    if (_points.length < 3) {
      _showSnack('Place at least 3 points before saving.');
      return;
    }

    final String? name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save this plot'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. Field near canal'),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;
    if (!mounted) return;

    // Reverse-geocode the plot's centroid so the saved entry carries a
    // readable address (and knows which units make sense for it), not
    // just raw coordinates. Shown as a quick loading dialog since this
    // depends on network/geocoding availability.
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Saving...'),
            ],
          ),
        ),
      ),
    );

    final LatLng centroid = _centroidOf(_points);
    final ResolvedAddress resolved = await AddressResolver.resolve(centroid);

    if (!mounted) return;
    Navigator.pop(context); // close the loading dialog

    final plot = SavedPlot(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      points: List.of(_points),
      areaSquareMeters: GeoAreaCalculator.computeAreaInSquareMeters(_points),
      createdAt: DateTime.now(),
      address: resolved.formatted,
      showLocalUnits: RegionalUnits.showLocalUnits(resolved.isoCountryCode),
    );
    await _savedPlotsRepository.save(plot);
    _showSnack(
      resolved.formatted == null
          ? 'Saved "$name".'
          : 'Saved "$name" — ${resolved.formatted}',
    );
  }

  LatLng _centroidOf(List<LatLng> points) {
    double lat = 0, lng = 0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  Future<void> _openSavedPlots() async {
    final SavedPlot? selected = await Navigator.push<SavedPlot>(
      context,
      MaterialPageRoute(builder: (context) => const SavedPlotsScreen()),
    );
    if (selected == null) return;

    setState(() {
      _points
        ..clear()
        ..addAll(selected.points);
      _redoStack.clear();
      _showLocalUnits = selected.showLocalUnits;
      final int extraNeeded = selected.points.length - _freePointsLimit;
      if (extraNeeded > 0) {
        final int adsNeeded = (extraNeeded / _pointsPerAd).ceil();
        if (adsNeeded > _adsWatchedThisSession) {
          _adsWatchedThisSession = adsNeeded;
        }
      }
      _pointsUsed = selected.points.length;
    });
    await _refreshLengthLabels();
    _fitCameraToCurrentPoints();
  }

  Future<void> _fitCameraToCurrentPoints() async {
    if (_points.isEmpty || _mapController == null) return;
    if (_points.length == 1) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_points.first, 18),
      );
      return;
    }
    double minLat = _points.first.latitude, maxLat = _points.first.latitude;
    double minLng = _points.first.longitude, maxLng = _points.first.longitude;
    for (final p in _points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  /// google_maps_flutter's Marker widget doesn't expose a long-press
  /// callback (only onTap), so tapping directly on a placed marker is
  /// the closest equivalent to "long press to remove". It's surfaced as
  /// a confirmation sheet so it stays a deliberate, undo-able action
  /// rather than an accidental deletion.
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
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove this point'),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _points.removeAt(index));
                      _refreshLengthLabels();
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ---------------------------------------------------------------------
  // Side-length labels
  // ---------------------------------------------------------------------

  /// Recomputes the length of every side and regenerates the small on-map
  /// label markers for them. Runs after any point add/move/remove — never
  /// continuously during a drag — so it stays cheap.
  Future<void> _refreshLengthLabels() async {
    _persistPointsBudget();
    final List<_Edge> edges = _currentEdges();
    if (edges.isEmpty) {
      if (_lengthLabelMarkers.isNotEmpty && mounted) {
        setState(() => _lengthLabelMarkers = {});
      }
      return;
    }

    final Set<Marker> newMarkers = {};
    for (int i = 0; i < edges.length; i++) {
      final _Edge edge = edges[i];
      final double meters = GeoAreaCalculator.distanceInMeters(
        edge.start,
        edge.end,
      );
      final LatLng midpoint = LatLng(
        (edge.start.latitude + edge.end.latitude) / 2,
        (edge.start.longitude + edge.end.longitude) / 2,
      );
      final BitmapDescriptor icon = await LabelMarkerFactory.create(
        '${meters.toStringAsFixed(1)} m',
      );
      newMarkers.add(
        Marker(
          markerId: MarkerId('edge_label_$i'),
          position: midpoint,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          zIndex: 1,
          consumeTapEvents: false,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _lengthLabelMarkers = newMarkers);
  }

  List<_Edge> _currentEdges() {
    if (_points.length == 2) {
      return [_Edge(_points[0], _points[1])];
    }
    if (_points.length >= 3) {
      return [
        for (int i = 0; i < _points.length; i++)
          _Edge(_points[i], _points[(i + 1) % _points.length]),
      ];
    }
    return const [];
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_resolvingStartLocation) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double areaSqMeters = GeoAreaCalculator.computeAreaInSquareMeters(
      _points,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Measures'),
        actions: [
          IconButton(
            tooltip: 'Undo last point',
            onPressed: _points.isEmpty ? null : _undoLastPoint,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redoStack.isEmpty ? null : _redoLastPoint,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Save this plot',
            onPressed: _points.length < 3 ? null : _saveCurrentPlot,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Saved plots',
            onPressed: _openSavedPlots,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            tooltip: 'Clear all points',
            onPressed: _points.isEmpty ? null : _clearAllPoints,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      // A Column (map on top, info card below) instead of stacking the
      // card over the whole screen — this is what stops the bottom card
      // from covering the FAB / system nav buttons.
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialCameraTarget!,
                    zoom: 17,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: _addPoint,
                  mapType: _mapType,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  markers: {..._buildPointMarkers(), ..._lengthLabelMarkers},
                  polygons: _buildPolygons(),
                  polylines: _buildPolylines(),
                ),
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Tap map to add a point · tap a pin to remove it',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _MapTypeButton(
                    current: _mapType,
                    onChanged: (type) => setState(() => _mapType = type),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton(
                    heroTag: 'locate_me',
                    onPressed: _goToCurrentLocation,
                    tooltip: 'Go to my location',
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: AreaInfoPanel(
                pointCount: _points.length,
                pointsUsed: _pointsUsed,
                pointsAllowed: _pointsAllowed,
                areaInSquareMeters: areaSqMeters,
                showLocalUnits: _showLocalUnits,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildPointMarkers() {
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
    if (_points.length != 2) return {};
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

class _Edge {
  const _Edge(this.start, this.end);
  final LatLng start;
  final LatLng end;
}

/// Small floating control that opens a menu for switching between the
/// map's rendering styles (satellite, hybrid, standard roadmap, terrain).
class _MapTypeButton extends StatelessWidget {
  const _MapTypeButton({required this.current, required this.onChanged});

  final MapType current;
  final ValueChanged<MapType> onChanged;

  static const List<(MapType, String, IconData)> _options = [
    (MapType.hybrid, 'Hybrid', Icons.satellite_alt_outlined),
    (MapType.satellite, 'Satellite', Icons.satellite_outlined),
    (MapType.normal, 'Map', Icons.map_outlined),
    (MapType.terrain, 'Terrain', Icons.terrain_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: PopupMenuButton<MapType>(
        tooltip: 'Change map view',
        initialValue: current,
        onSelected: onChanged,
        icon: const Icon(Icons.layers_outlined),
        itemBuilder: (context) => [
          for (final (type, label, icon) in _options)
            PopupMenuItem<MapType>(
              value: type,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: type == current
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(label),
                  if (type == current) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
