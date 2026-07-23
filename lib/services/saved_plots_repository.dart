import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_plot.dart';

/// Reads and writes the user's saved land plots. Backed by
/// shared_preferences (a free, standard package) — each plot is stored as
/// its own JSON string in a string list, which makes adding/removing a
/// single plot cheap without re-writing everything else.
class SavedPlotsRepository {
  static const String _storageKey = 'saved_plots_v1';

  Future<List<SavedPlot>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_storageKey) ?? [];
    final List<SavedPlot> plots = raw
        .map((s) => SavedPlot.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    plots.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
    return plots;
  }

  Future<void> save(SavedPlot plot) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_storageKey) ?? [];
    raw.add(jsonEncode(plot.toJson()));
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_storageKey) ?? [];
    raw.removeWhere((s) {
      final Map<String, dynamic> map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == id;
    });
    await prefs.setStringList(_storageKey, raw);
  }
}
