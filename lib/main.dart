import 'package:flutter/material.dart';

import 'screens/land_area_calculator_screen.dart';

void main() {
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
