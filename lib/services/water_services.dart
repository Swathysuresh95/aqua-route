import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class WaterPoint {
  final String name;
  final LatLng location;

  const WaterPoint({
    required this.name,
    required this.location,
  });
}

class WaterService {
  static const String _baseUrl =
      'https://mobilegisserver.mywire.org/geoserver/wfs';

  static Future<List<WaterPoint>> fetchDrinkingWaterPoints() async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'service': 'WFS',
        'version': '2.0.0',
        'request': 'GetFeature',
        'typeNames': 'mobilegis:planet_osm_point',
        'CQL_FILTER': "amenity='drinking_water'",
        'outputFormat': 'application/json',
        'srsName' : 'EPSG:4326',
        'count' : '5000'
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Could not load drinking-water locations. '
        'Server returned ${response.statusCode}.',
      );
    }

    final Map<String, dynamic> geoJson =
        jsonDecode(response.body) as Map<String, dynamic>;

    final List<dynamic> features =
        geoJson['features'] as List<dynamic>? ?? [];

    return features
        .map((feature) {
          final featureMap = feature as Map<String, dynamic>;

          final geometry =
              featureMap['geometry'] as Map<String, dynamic>?;

          final properties =
              featureMap['properties'] as Map<String, dynamic>? ?? {};

          final coordinates =
              geometry?['coordinates'] as List<dynamic>?;

          if (coordinates == null || coordinates.length < 2) {
            return null;
          }

          final longitude = (coordinates[0] as num).toDouble();
          final latitude = (coordinates[1] as num).toDouble();

          final rawName = properties['name'];

          return WaterPoint(
            name: rawName is String && rawName.trim().isNotEmpty
                ? rawName
                : 'Drinking-water point',
            location: LatLng(latitude, longitude),
          );
        })
        .whereType<WaterPoint>()
        .toList();
  }
}