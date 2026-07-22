import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class BlueSpaceFeature {
  final String name;
  final String type;
  final LatLng navigationPoint;

  const BlueSpaceFeature({
    required this.name,
    required this.type,
    required this.navigationPoint,
  });
}

class BlueSpaceData {
  final List<Polygon<BlueSpaceFeature>> waterPolygons;
  final List<Polyline<BlueSpaceFeature>> waterways;

  const BlueSpaceData({
    required this.waterPolygons,
    required this.waterways,
  });
}

class BlueSpaceService {
  static const String _baseUrl =
      'https://mobilegisserver.mywire.org/geoserver/wfs';

  static const String _karlsruheBbox =
      "BBOX(way,8.25,48.90,8.60,49.15,'EPSG:4326')";

  static Future<BlueSpaceData> fetchBlueSpaces() async {
    final waterPolygons = await _fetchWaterPolygons();
    final waterways = await _fetchWaterways();

    return BlueSpaceData(
      waterPolygons: waterPolygons,
      waterways: waterways,
    );
  }

  static Future<List<Polygon<BlueSpaceFeature>>>
      _fetchWaterPolygons() async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'service': 'WFS',
        'version': '2.0.0',
        'request': 'GetFeature',
        'typeNames': 'mobilegis:planet_osm_polygon',
        'CQL_FILTER':
            "natural='water' AND $_karlsruheBbox",
        'outputFormat': 'application/json',
        'srsName': 'EPSG:4326',
        'count': '5000',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Could not load water areas. '
        'Server returned ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid water-area response.');
    }

    final features =
        decoded['features'] as List<dynamic>? ?? [];

    final polygons =
        <Polygon<BlueSpaceFeature>>[];

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

      final type = _waterAreaType(properties);
      final name = _readName(
        properties,
        fallback: type,
      );

      if (geometryType == 'Polygon' &&
          coordinates is List<dynamic>) {
        polygons.addAll(
          _createWaterPolygons(
            coordinates: coordinates,
            name: name,
            type: type,
          ),
        );
      }

      if (geometryType == 'MultiPolygon' &&
          coordinates is List<dynamic>) {
        for (final polygonCoordinates
            in coordinates) {
          if (polygonCoordinates
              is List<dynamic>) {
            polygons.addAll(
              _createWaterPolygons(
                coordinates:
                    polygonCoordinates,
                name: name,
                type: type,
              ),
            );
          }
        }
      }
    }

    return polygons;
  }

  static List<Polygon<BlueSpaceFeature>>
      _createWaterPolygons({
    required List<dynamic> coordinates,
    required String name,
    required String type,
  }) {
    if (coordinates.isEmpty) {
      return [];
    }

    final outerRing = coordinates.first;

    if (outerRing is! List<dynamic>) {
      return [];
    }

    final points =
        _coordinatesToLatLngList(outerRing);

    if (points.length < 3) {
      return [];
    }

    final feature = BlueSpaceFeature(
      name: name,
      type: type,
      navigationPoint:
          _representativePoint(points),
    );

    return [
      Polygon<BlueSpaceFeature>(
        points: points,
        color: const Color(0x6600A8E8),
        borderColor:
            const Color(0xFF005F99),
        borderStrokeWidth: 2.5,
        hitValue: feature,
      ),
    ];
  }

  static Future<List<Polyline<BlueSpaceFeature>>>
      _fetchWaterways() async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'service': 'WFS',
        'version': '2.0.0',
        'request': 'GetFeature',
        'typeNames': 'mobilegis:planet_osm_line',
        'CQL_FILTER':
            "(waterway='river' OR "
            "waterway='stream' OR "
            "waterway='canal') AND "
            "$_karlsruheBbox",
        'outputFormat': 'application/json',
        'srsName': 'EPSG:4326',
        'count': '5000',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Could not load waterways. '
        'Server returned ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid waterway response.');
    }

    final features =
        decoded['features'] as List<dynamic>? ?? [];

    final waterways =
        <Polyline<BlueSpaceFeature>>[];

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

      final type = _waterwayType(
        properties['waterway'],
      );

      final name = _readName(
        properties,
        fallback: type,
      );

      if (geometryType == 'LineString' &&
          coordinates is List<dynamic>) {
        final polyline = _createWaterway(
          coordinates: coordinates,
          name: name,
          type: type,
        );

        if (polyline != null) {
          waterways.add(polyline);
        }
      }

      if (geometryType == 'MultiLineString' &&
          coordinates is List<dynamic>) {
        for (final lineCoordinates
            in coordinates) {
          if (lineCoordinates
              is! List<dynamic>) {
            continue;
          }

          final polyline = _createWaterway(
            coordinates: lineCoordinates,
            name: name,
            type: type,
          );

          if (polyline != null) {
            waterways.add(polyline);
          }
        }
      }
    }

    return waterways;
  }

  static Polyline<BlueSpaceFeature>?
      _createWaterway({
    required List<dynamic> coordinates,
    required String name,
    required String type,
  }) {
    final points =
        _coordinatesToLatLngList(coordinates);

    if (points.length < 2) {
      return null;
    }

    final feature = BlueSpaceFeature(
      name: name,
      type: type,
      navigationPoint:
          _representativePoint(points),
    );

    return Polyline<BlueSpaceFeature>(
      points: points,
      strokeWidth: 5,
      color: const Color(0xFF0077B6),
      hitValue: feature,
    );
  }

  static String _readName(
    Map<String, dynamic> properties, {
    required String fallback,
  }) {
    final value = properties['name'];

    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  static String _waterAreaType(
    Map<String, dynamic> properties,
  ) {
    final landuse = properties['landuse'];

    if (landuse is String) {
      switch (landuse.toLowerCase()) {
        case 'reservoir':
          return 'Reservoir';
        case 'basin':
          return 'Water basin';
      }
    }

    return 'Water area';
  }

  static String _waterwayType(
    dynamic value,
  ) {
    if (value is! String) {
      return 'Waterway';
    }

    switch (value.toLowerCase()) {
      case 'river':
        return 'River';
      case 'stream':
        return 'Stream';
      case 'canal':
        return 'Canal';
      default:
        return 'Waterway';
    }
  }

  static LatLng _representativePoint(
    List<LatLng> points,
  ) {
    double latitudeSum = 0;
    double longitudeSum = 0;

    for (final point in points) {
      latitudeSum += point.latitude;
      longitudeSum += point.longitude;
    }

    return LatLng(
      latitudeSum / points.length,
      longitudeSum / points.length,
    );
  }

  static List<LatLng>
      _coordinatesToLatLngList(
    List<dynamic> coordinates,
  ) {
    final points = <LatLng>[];

    for (final coordinate in coordinates) {
      if (coordinate is! List<dynamic> ||
          coordinate.length < 2) {
        continue;
      }

      final longitude = coordinate[0];
      final latitude = coordinate[1];

      if (longitude is num &&
          latitude is num) {
        points.add(
          LatLng(
            latitude.toDouble(),
            longitude.toDouble(),
          ),
        );
      }
    }

    return points;
  }
}