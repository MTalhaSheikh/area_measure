import 'package:flutter/material.dart';

import '../models/saved_plot.dart';
import '../services/saved_plots_repository.dart';
import '../utils/geo_area_calculator.dart';

/// Shows every saved plot. Tapping one pops this screen and returns the
/// [SavedPlot] to the caller, which loads its points back onto the map.
class SavedPlotsScreen extends StatefulWidget {
  const SavedPlotsScreen({super.key});

  @override
  State<SavedPlotsScreen> createState() => _SavedPlotsScreenState();
}

class _SavedPlotsScreenState extends State<SavedPlotsScreen> {
  final SavedPlotsRepository _repository = SavedPlotsRepository();
  late Future<List<SavedPlot>> _plotsFuture;

  @override
  void initState() {
    super.initState();
    _plotsFuture = _repository.loadAll();
  }

  void _reload() {
    setState(() => _plotsFuture = _repository.loadAll());
  }

  Future<void> _delete(SavedPlot plot) async {
    await _repository.delete(plot.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved plots')),
      body: FutureBuilder<List<SavedPlot>>(
        future: _plotsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<SavedPlot> plots = snapshot.data ?? [];
          if (plots.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saved plots yet.\nMap a boundary and tap the save '
                  'icon to keep it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: plots.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final SavedPlot plot = plots[index];
              final double acres = GeoAreaCalculator.squareMetersToAcres(
                plot.areaSquareMeters,
              );
              final String areaLine = plot.showLocalUnits
                  ? '${plot.areaSquareMeters.toStringAsFixed(1)} m² · '
                        '${acres.toStringAsFixed(3)} acres · '
                        '${GeoAreaCalculator.squareMetersToMarla(plot.areaSquareMeters).toStringAsFixed(1)} marla'
                  : '${plot.areaSquareMeters.toStringAsFixed(1)} m² · '
                        '${acres.toStringAsFixed(3)} acres';
              return ListTile(
                leading: const Icon(Icons.crop_free),
                title: Text(plot.name),
                subtitle: Text(
                  '${plot.address ?? 'Address unavailable'}\n'
                  '$areaLine\n'
                  '${_formatDate(plot.createdAt)} · ${plot.points.length} points',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(plot),
                ),
                onTap: () => Navigator.pop(context, plot),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(SavedPlot plot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${plot.name}"?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _delete(plot);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }
}
