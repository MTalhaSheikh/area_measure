import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Renders short text (e.g. "32.4 m") onto a small transparent bitmap so
/// it can be used as a [Marker] icon. google_maps_flutter has no built-in
/// way to draw text directly on the map, so custom marker bitmaps are the
/// standard workaround for on-map labels like side lengths. Text is drawn
/// with a white halo instead of a background box, which keeps the label
/// small and readable over any part of the map.
class LabelMarkerFactory {
  LabelMarkerFactory._();

  static Future<BitmapDescriptor> create(
    String text, {
    Color fillColor = Colors.black,
    Color outlineColor = Colors.white,
    double fontSize = 11,
    double pixelRatio = 4,
  }) async {
    final TextStyle style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );

    // Outline pass: same text, stroked, drawn first (acts as a halo so
    // the label stays readable over both light and dark map tiles
    // without needing a background box — this is what makes it read as
    // noticeably smaller than the earlier pill design).
    final TextPainter outlinePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = outlineColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final TextPainter fillPainter = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(color: fillColor)),
      textDirection: TextDirection.ltr,
    )..layout();

    const double margin = 2;
    final double width = outlinePainter.width + margin * 2;
    final double height = outlinePainter.height + margin * 2;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width * pixelRatio, height * pixelRatio),
    );
    canvas.scale(pixelRatio);

    outlinePainter.paint(canvas, Offset(margin, margin));
    fillPainter.paint(canvas, Offset(margin, margin));

    final ui.Image image = await recorder.endRecording().toImage(
      (width * pixelRatio).round(),
      (height * pixelRatio).round(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    // Note: BitmapDescriptor.bytes() (the newer API) has known bugs around
    // sizing/crashes on some plugin versions. fromBytes() is deprecated but
    // still works reliably, so it's used here deliberately.
    // ignore: deprecated_member_use
    return BitmapDescriptor.fromBytes(
      byteData!.buffer.asUint8List(),
      size: Size(width, height),
    );
  }
}
