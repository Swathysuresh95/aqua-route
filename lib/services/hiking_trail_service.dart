import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class HikingTrailFeature {
  final String id;
  final String name;
  final String type;
  final String? operatorName;
  final String? reference;
  final LatLng navigationPoint;
  final List<LatLng> routePoints;

  const HikingTrailFeature({
    required this.id,
    required this.name,
    required this.type,
    required this.operatorName,
    required this.reference,
    required this.navigationPoint,
    required this.routePoints,
  });
}

class HikingTrailService {
  static const String _baseUrl =
      'https://mobilegisserver.mywire.org/geoserver/wfs';

  static const String _karlsruheBbox =
      "BBOX(way,8.25,48.90,8.60,49.15,'EPSG:4326')";

  static Future<List<HikingTrailFeature>> fetchHikingTrails() async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'service': 'WFS',
        'version': '2.0.0',
        'request': 'GetFeature',
        'typeNames': 'mobilegis:planet_osm_line',
        'CQL_FILTER': "route='hiking' AND $_karlsruheBbox",
        'outputFormat': 'application/json',
        'srsName': 'EPSG:4326',
        'count': '5000',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Could not load hiking trails. '
        'Server returned ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid hiking-trail response.');
    }

    final features = decoded['features'] as List<dynamic>? ?? [];
    final trails = <HikingTrailFeature>[];

    for (final item in features) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final geometry = item['geometry'];
      if (geometry is! Map<String, dynamic>) {
        continue;
      }

      final properties = item['properties'] is Map<String, dynamic>
          ? item['properties'] as Map<String, dynamic>
          : <String, dynamic>{};

      final geometryType = geometry['type'];
      final coordinates = geometry['coordinates'];
      final osmId = properties['osm_id']?.toString() ?? item['id'].toString();
      final type = 'Official hiking route';
      final name = _readName(properties, type);
      final operatorName = _optionalText(properties['operator']);
      final reference = _optionalText(properties['ref']);

      if (geometryType == 'LineString' &&
          coordinates is List<dynamic>) {
        final trail = _createTrail(
          coordinates: coordinates,
          id: osmId,
          name: name,
          type: type,
          operatorName: operatorName,
          reference: reference,
        );

        if (trail != null) {
          trails.add(trail);
        }
      }

      if (geometryType == 'MultiLineString' &&
          coordinates is List<dynamic>) {
        for (final line in coordinates) {
          if (line is! List<dynamic>) {
            continue;
          }

          final trail = _createTrail(
            coordinates: line,
            id: '$osmId-${trails.length}',
            name: name,
            type: type,
            operatorName: operatorName,
            reference: reference,
          );

          if (trail != null) {
            trails.add(trail);
          }
        }
      }
    }

    return trails;
  }

  static HikingTrailFeature? _createTrail({
    required List<dynamic> coordinates,
    required String id,
    required String name,
    required String type,
    required String? operatorName,
    required String? reference,
  }) {
    final points = <LatLng>[];

    for (final coordinate in coordinates) {
      if (coordinate is! List<dynamic> || coordinate.length < 2) {
        continue;
      }

      final longitude = coordinate[0];
      final latitude = coordinate[1];

      if (longitude is num && latitude is num) {
        points.add(
          LatLng(
            latitude.toDouble(),
            longitude.toDouble(),
          ),
        );
      }
    }

    if (points.length < 2) {
      return null;
    }

    return HikingTrailFeature(
      id: id,
      name: name,
      type: type,
      operatorName: operatorName,
      reference: reference,
      navigationPoint: points[points.length ~/ 2],
      routePoints: List<LatLng>.unmodifiable(points),
    );
  }

  static String _readName(
    Map<String, dynamic> properties,
    String fallback,
  ) {
    final names = [
      properties['name'],
      properties['name:de'],
      properties['official_name'],
      properties['ref'],
    ];

    for (final value in names) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return fallback;
  }

  static String? _optionalText(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
