import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AquaRouteApp());
}

class AquaRouteApp extends StatelessWidget {
  const AquaRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AquaRoute Karlsruhe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}