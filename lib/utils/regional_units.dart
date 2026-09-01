/// Marla and kanal are traditional land units that only make sense to
/// show to users measuring land in Pakistan (and, informally, nearby parts
/// of North India) — everywhere else they're just unfamiliar noise next
/// to m² / ft² / acres / hectares, which are shown to everyone regardless.
class RegionalUnits {
  RegionalUnits._();

  static const Set<String> _localUnitCountryCodes = {'PK'};

  /// Whether to show marla/kanal for a place with the given ISO 3166-1
  /// alpha-2 country code (e.g. "PK", "US"). Defaults to true when the
  /// country can't be determined (no internet, geocoding failed, etc.) —
  /// this app's audience and fallback location are both in Pakistan, so
  /// "unknown" is a safer default than hiding units most users expect.
  static bool showLocalUnits(String? isoCountryCode) {
    if (isoCountryCode == null) return true;
    return _localUnitCountryCodes.contains(isoCountryCode.toUpperCase());
  }
}
