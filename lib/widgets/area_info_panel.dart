import 'package:flutter/material.dart';

import '../utils/geo_area_calculator.dart';

/// Card shown at the bottom of the map with the live area readout and
/// point count. Purely presentational — all math happens elsewhere.
class AreaInfoPanel extends StatelessWidget {
  const AreaInfoPanel({
    super.key,
    required this.pointCount,
    required this.pointsUsed,
    required this.pointsAllowed,
    required this.areaInSquareMeters,
    required this.showLocalUnits,
  });

  final int pointCount;

  /// Points spent toward [pointsAllowed]. Shown in the chip instead of
  /// [pointCount] because deleting a point no longer frees up its slot —
  /// this can be higher than the live [pointCount] on the map.
  final int pointsUsed;

  /// The current cap on points (free limit, or the higher limit unlocked
  /// via a rewarded ad). Shown next to the count, e.g. "3/4 pts".
  final int pointsAllowed;
  final double areaInSquareMeters;

  /// Whether to include marla/kanal alongside the universal units. False
  /// when the user is outside Pakistan (see [RegionalUnits]).
  final bool showLocalUnits;

  @override
  Widget build(BuildContext context) {
    final bool hasArea = pointCount >= 3;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.crop_free,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  hasArea
                      ? 'Land area'
                      : 'Tap the map to place ${pointCount == 0 ? 'your first' : 'more'} point${pointCount == 0 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text('$pointsUsed/$pointsAllowed pts'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (hasArea) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 18,
                runSpacing: 4,
                children: [
                  _AreaValue(
                    label: 'm²',
                    value: areaInSquareMeters,
                    big: true,
                  ),
                  _AreaValue(
                    label: 'ft²',
                    value: GeoAreaCalculator.squareMetersToSquareFeet(
                      areaInSquareMeters,
                    ),
                  ),
                  _AreaValue(
                    label: 'acres',
                    value: GeoAreaCalculator.squareMetersToAcres(
                      areaInSquareMeters,
                    ),
                    decimals: 3,
                  ),
                  _AreaValue(
                    label: 'hectares',
                    value: GeoAreaCalculator.squareMetersToHectares(
                      areaInSquareMeters,
                    ),
                    decimals: 3,
                  ),
                  if (showLocalUnits) ...[
                    _AreaValue(
                      label: 'marla',
                      value: GeoAreaCalculator.squareMetersToMarla(
                        areaInSquareMeters,
                      ),
                    ),
                    _AreaValue(
                      label: 'kanal',
                      value: GeoAreaCalculator.squareMetersToKanal(
                        areaInSquareMeters,
                      ),
                      decimals: 3,
                    ),
                  ],
                ],
              ),
            ] else if (pointCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Need at least 3 points to calculate an area.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AreaValue extends StatelessWidget {
  const _AreaValue({
    required this.label,
    required this.value,
    this.decimals = 1,
    this.big = false,
  });

  final String label;
  final double value;
  final int decimals;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: value.toStringAsFixed(decimals),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: big ? 20 : 15,
              color: Colors.black87,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
