import 'package:flutter/material.dart';

import '../widgets/feature_card.dart';
import 'map_screen.dart';
import 'wellness_route_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openMap(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const MapScreen(),
      ),
    );
  }

  void _openWellnessRoute(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const WellnessRouteScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0077B6),
        foregroundColor: Colors.white,
        title: const Text(
          'AquaRoute Karlsruhe',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.directions_walk,
                size: 85,
                color: Color(0xFF00B4D8),
              ),
              const SizedBox(height: 12),

              const Text(
                'Personalised Hydration and Blue-Space Walks',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF023E8A),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Create a walking route that combines drinking-water access, '
                'blue spaces and green surroundings across Karlsruhe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 25),

              ElevatedButton.icon(
                onPressed: () => _openWellnessRoute(context),
                icon: const Icon(Icons.route),
                label: const Text(
                  'Plan a Wellness Walk',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0077B6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              OutlinedButton.icon(
                onPressed: () => _openMap(context),
                icon: const Icon(Icons.map),
                label: const Text(
                  'Open Complete Water Map',
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Explore AquaRoute',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              FeatureCard(
                icon: Icons.directions_walk,
                title: 'Wellness Walk',
                description:
                    'Choose your walking duration, route type and preferred blue space.',
                onTap: () => _openWellnessRoute(context),
              ),

              FeatureCard(
                icon: Icons.water,
                title: 'Explore Blue Spaces',
                description:
                    'Discover lakes, ponds, rivers, streams and canals.',
                onTap: () => _openMap(context),
              ),

              FeatureCard(
                icon: Icons.local_drink,
                title: 'Find Drinking Water',
                description:
                    'Locate nearby mapped public drinking-water points.',
                onTap: () => _openMap(context),
              ),

              FeatureCard(
                icon: Icons.my_location,
                title: 'Nearby Water Facilities',
                description:
                    'Use your current location to explore nearby water features.',
                onTap: () => _openMap(context),
              ),

              FeatureCard(
                icon: Icons.water_drop_outlined,
                title: 'Bottle Refill Support',
                description:
                    'Find drinking-water points where bottle refilling may be possible.',
                onTap: () => _openMap(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}