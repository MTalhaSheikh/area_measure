import 'package:shared_preferences/shared_preferences.dart';

/// Persists just the point *budget* — how many points have been spent
/// and how many rewarded ads have been watched — so relaunching the app
/// can't be used to reset back to 0/4 and get free points again.
///
/// Deliberately does NOT store the actual in-progress boundary
/// (coordinates of unsaved points). That's a separate concern: this is
/// only about the count staying honest, not about restoring a half-drawn
/// shape. Explicitly-saved plots (see SavedPlotsRepository) are a
/// completely separate feature and are untouched by this class.
class PointsBudgetRepository {
  static const String _pointsUsedKey = 'points_used_v1';
  static const String _adsWatchedKey = 'ads_watched_v1';

  Future<void> save({required int pointsUsed, required int adsWatched}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsUsedKey, pointsUsed);
    await prefs.setInt(_adsWatchedKey, adsWatched);
  }

  /// Returns the persisted (pointsUsed, adsWatched), or (0, 0) if nothing
  /// has been saved yet.
  Future<({int pointsUsed, int adsWatched})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      pointsUsed: prefs.getInt(_pointsUsedKey) ?? 0,
      adsWatched: prefs.getInt(_adsWatchedKey) ?? 0,
    );
  }
}
