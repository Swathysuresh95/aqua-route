import 'package:flutter/material.dart';

import 'map_screen.dart';
import 'wellness_route_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color navy = Color(0xFF023E8A);
  static const Color blue = Color(0xFF0077B6);
  static const Color cyan = Color(0xFF00B4D8);
  static const Color green = Color(0xFF2A9D58);
  static const Color orange = Color(0xFFF97316);
  static const Color purple = Color(0xFF7C3AED);

  void _openWellnessRoute(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WellnessRouteScreen(),
      ),
    );
  }

  void _openMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MapScreen(),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        18,
        22,
        32,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF023E8A),
            Color(0xFF0077B6),
            Color(0xFF00B4D8),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AquaRoute',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Karlsruhe',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Mobile GIS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.directions_walk_rounded,
                color: Colors.white,
                size: 59,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hydrate. Explore. Move.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Discover drinking-water points, blue spaces '
              'and personalised scenic workout routes '
              'across Karlsruhe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            _buildMainActionButton(
              icon: Icons.route_rounded,
              title: 'Plan a Scenic Workout',
              subtitle:
                  'Walk, run or cycle through blue and green spaces',
              filled: true,
              onTap: () => _openWellnessRoute(context),
            ),
            const SizedBox(height: 11),
            _buildMainActionButton(
              icon: Icons.map_rounded,
              title: 'Open Complete Water Map',
              subtitle:
                  'Explore mapped water features across Karlsruhe',
              filled: false,
              onTap: () => _openMap(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: filled ? 0 : 0.70,
              ),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: filled
                      ? cyan.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: filled ? blue : Colors.white,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: filled ? navy : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: filled
                            ? Colors.black54
                            : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: filled ? blue : Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore AquaRoute',
            style: TextStyle(
              color: navy,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Choose a feature to begin your journey.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color colour,
    required String title,
    required String description,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colour.withValues(alpha: 0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colour,
                        colour.withValues(alpha: 0.65),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: [
                      BoxShadow(
                        color: colour.withValues(alpha: 0.25),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: navy,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colour.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: colour,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colour,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInformationCard() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE8FFF1),
            Color(0xFFEAF8FC),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: green.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: green,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Healthy urban exploration',
                  style: TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: _HomeStatusItem(
                  icon: Icons.gps_fixed_rounded,
                  title: 'GPS',
                  subtitle: 'Current location',
                  colour: blue,
                ),
              ),
              Expanded(
                child: _HomeStatusItem(
                  icon: Icons.water_rounded,
                  title: 'Water',
                  subtitle: 'Blue spaces',
                  colour: cyan,
                ),
              ),
              Expanded(
                child: _HomeStatusItem(
                  icon: Icons.park_rounded,
                  title: 'Green',
                  subtitle: 'Nature context',
                  colour: green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard() {
    return Container(
      margin: const EdgeInsets.only(top: 17),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: purple.withValues(alpha: 0.17),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.cloud_download_rounded,
            color: purple,
            size: 32,
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live GIS data',
                  style: TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'OpenStreetMap geographic data is accessed '
                  'through GeoServer WFS services.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFC),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeroHeader(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              18,
              26,
              18,
              38,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildSectionTitle(),
                  _buildFeatureCard(
                    icon: Icons.directions_run_rounded,
                    colour: orange,
                    title: 'Scenic Workout',
                    description:
                        'Choose walking, running or cycling, '
                        'set your preferred duration and select '
                        'the water feature you want to visit.',
                    label: 'PERSONALISED',
                    onTap: () => _openWellnessRoute(context),
                  ),
                  _buildFeatureCard(
                    icon: Icons.waves_rounded,
                    colour: blue,
                    title: 'Explore Blue Spaces',
                    description:
                        'Discover mapped lakes, ponds, rivers, '
                        'streams, canals and other water areas.',
                    label: 'BLUE SPACE',
                    onTap: () => _openMap(context),
                  ),
                  _buildFeatureCard(
                    icon: Icons.local_drink_rounded,
                    colour: cyan,
                    title: 'Find Drinking Water',
                    description:
                        'Locate nearby mapped public '
                        'drinking-water points.',
                    label: 'HYDRATION',
                    onTap: () => _openMap(context),
                  ),
                  _buildFeatureCard(
                    icon: Icons.my_location_rounded,
                    colour: green,
                    title: 'Nearby Water Facilities',
                    description:
                        'Open the map and use your current GPS '
                        'position to explore nearby water features.',
                    label: 'NEAR ME',
                    onTap: () => _openMap(context),
                  ),
                  _buildFeatureCard(
                    icon: Icons.recycling_rounded,
                    colour: purple,
                    title: 'Bottle Refill Support',
                    description:
                        'Explore public drinking-water points '
                        'where bottle refilling may be possible.',
                    label: 'REFILL',
                    onTap: () => _openMap(context),
                  ),
                  _buildInformationCard(),
                  _buildDataCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeStatusItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color colour;

  const _HomeStatusItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: colour,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: const TextStyle(
            color: HomeScreen.navy,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}