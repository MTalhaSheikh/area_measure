import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'screens/land_area_calculator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never let an ads SDK problem (most commonly: missing AdMob
  // APPLICATION_ID meta-data in AndroidManifest.xml) prevent the app from
  // starting at all. Ads should be a nice-to-have on top of a working
  // app, not a single point of failure for launching it.
  try {
    await MobileAds.instance.initialize();
  } catch (_) {
    // Ads simply won't show this session; the rest of the app still works.
  }
  runApp(const LandAreaApp());
}

class LandAreaApp extends StatelessWidget {
  const LandAreaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Measures',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const LandAreaCalculatorScreen(),
    );
  }
}
