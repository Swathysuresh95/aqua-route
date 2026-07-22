import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GreenSpaceFeature {
  final String name;
  final String type;
  final LatLng navigationPoint;

  const GreenSpaceFeature({
    required this.name,
    required this.type,
    required this.navigationPoint,
  });
}

class GreenSpaceService {
  static const String _baseUrl =
      'https://mobilegisserver.mywire.org/geoserver/wfs';

  static const String _karlsruheBbox =
      "BBOX(way,8.25,48.90,8.60,49.15,'EPSG:4326')";

  static Future<List<GreenSpaceFeature>>
      fetchGreenSpaces() async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'service': 'WFS',
        'version': '2.0.0',
        'request': 'GetFeature',
        'typeNames': 'mobilegis:planet_osm_polygon',
        'CQL_FILTER':
            "(leisure='park' "
            "OR leisure='garden' "
            "OR natural='wood' "
            "OR landuse='forest' "
            "OR landuse='grass') "
            "AND $_karlsruheBbox",
        'outputFormat': 'application/json',
        'srsName': 'EPSG:4326',
        'count': '5000',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Could not load green spaces. '
        'Server returned ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Invalid green-space response.',
      );
    }

    final features =
        decoded['features'] as List<dynamic>? ?? [];

    final greenSpaces = <GreenSpaceFeature>[];

    for (final item in features) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final geometry = item['geometry'];

      if (geometry is! Map<String, dynamic>) {
        continue;
      }

      final properties =
          item['properties'] is Map<String, dynamic>
              ? item['properties'] as Map<String, dynamic>
              : <String, dynamic>{};

      final geometryType = geometry['type'];
      final coordinates = geometry['coordinates'];

      final name = _readName(properties);
      final type = _readType(properties);

      if (geometryType == 'Polygon' &&
          coordinates is List<dynamic>) {
        final point =
            _representativePointFromPolygon(
          coordinates,
        );

        if (point != null) {
          greenSpaces.add(
            GreenSpaceFeature(
              name: name,
              type: type,
              navigationPoint: point,
            ),
          );
        }
      }

      if (geometryType == 'MultiPolygon' &&
          coordinates is List<dynamic>) {
        for (final polygon in coordinates) {
          if (polygon is! List<dynamic>) {
            continue;
          }

          final point =
              _representativePointFromPolygon(
            polygon,
          );

          if (point != null) {
            greenSpaces.add(
              GreenSpaceFeature(
                name: name,
                type: type,
                navigationPoint: point,
              ),
            );
          }
        }
      }
    }

    return greenSpaces;
  }

  static LatLng? _representativePointFromPolygon(
    List<dynamic> polygonCoordinates,
  ) {
    if (polygonCoordinates.isEmpty) {
      return null;
    }

    final outerRing = polygonCoordinates.first;

    if (outerRing is! List<dynamic>) {
      return null;
    }

    double latitudeSum = 0;
    double longitudeSum = 0;
    int validPointCount = 0;

    for (final coordinate in outerRing) {
      if (coordinate is! List<dynamic> ||
          coordinate.length < 2) {
        continue;
      }

      final longitude = coordinate[0];
      final latitude = coordinate[1];

      if (longitude is num && latitude is num) {
        longitudeSum += longitude.toDouble();
        latitudeSum += latitude.toDouble();
        validPointCount++;
      }
    }

    if (validPointCount == 0) {
      return null;
    }

    return LatLng(
      latitudeSum / validPointCount,
      longitudeSum / validPointCount,
    );
  }

  static String _readName(
    Map<String, dynamic> properties,
  ) {
    final name = properties['name'];

    if (name is String &&
        name.trim().isNotEmpty) {
      return name.trim();
    }

    return _readType(properties);
  }

  static String _readType(
    Map<String, dynamic> properties,
  ) {
    final leisure = properties['leisure'];
    final natural = properties['natural'];
    final landuse = properties['landuse'];

    if (leisure == 'park') {
      return 'Park';
    }

    if (leisure == 'garden') {
      return 'Garden';
    }

    if (natural == 'wood') {
      return 'Woodland';
    }

    if (landuse == 'forest') {
      return 'Forest';
    }

    if (landuse == 'grass') {
      return 'Grass area';
    }

    return 'Green space';
  }
}