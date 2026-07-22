import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/blue_space_service.dart';
import '../services/green_space_service.dart';
import '../services/location_service.dart';
import '../services/water_services.dart';

class WellnessRouteScreen extends StatefulWidget {
  const WellnessRouteScreen({super.key});

  @override
  State<WellnessRouteScreen> createState() =>
      _WellnessRouteScreenState();
}

class _WellnessRouteScreenState
    extends State<WellnessRouteScreen> {
  int _selectedDuration = 30;
  String _routeType = 'Circular';
  bool _drinkingWaterRequired = true;
  bool _preferGreenAreas = true;
  String _blueSpacePreference = 'Water Area';

  bool _isCreatingRoute = false;
  String? _statusMessage;

  double get _maximumDestinationDistanceMetres {
    if (_routeType == 'Circular') {
      switch (_selectedDuration) {
        case 15:
          return 550;
        case 30:
          return 1100;
        case 45:
          return 1700;
      }
    }

    switch (_selectedDuration) {
      case 15:
        return 1000;
      case 30:
        return 2000;
      case 45:
        return 3000;
      default:
        return 2000;
    }
  }

  double get _preferredDestinationDistanceMetres {
    if (_routeType == 'Circular') {
      switch (_selectedDuration) {
        case 15:
          return 300;
        case 30:
          return 650;
        case 45:
          return 1000;
      }
    }

    switch (_selectedDuration) {
      case 15:
        return 700;
      case 30:
        return 1400;
      case 45:
        return 2200;
      default:
        return 1400;
    }
  }

  double _distanceBetween(
    LatLng first,
    LatLng second,
  ) {
    return Geolocator.distanceBetween(
      first.latitude,
      first.longitude,
      second.latitude,
      second.longitude,
    );
  }

  int _nearestPointIndex({
    required LatLng origin,
    required List<LatLng> points,
  }) {
    if (points.isEmpty) {
      return -1;
    }

    int nearestIndex = 0;
    double shortestDistance = double.infinity;

    for (int index = 0;
        index < points.length;
        index++) {
      final distance = _distanceBetween(
        origin,
        points[index],
      );

      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearestIndex = index;
      }
    }

    return nearestIndex;
  }

  LatLng _nearestPointOnFeature({
    required LatLng origin,
    required BlueSpaceFeature feature,
  }) {
    if (feature.routePoints.isEmpty) {
      return feature.navigationPoint;
    }

    final index = _nearestPointIndex(
      origin: origin,
      points: feature.routePoints,
    );

    if (index < 0) {
      return feature.navigationPoint;
    }

    return feature.routePoints[index];
  }

  BlueSpaceFeature? _findBestBlueSpace({
    required LatLng currentLocation,
    required BlueSpaceData blueSpaceData,
    required List<GreenSpaceFeature> greenSpaces,
  }) {
    final candidates = <BlueSpaceFeature>[];

    if (_blueSpacePreference == 'Water Area' ||
        _blueSpacePreference == 'Any blue space') {
      for (final polygon
          in blueSpaceData.waterPolygons) {
        final feature = polygon.hitValue;

        if (feature != null) {
          candidates.add(feature);
        }
      }
    }

    if (_blueSpacePreference == 'River / Canal' ||
        _blueSpacePreference == 'Any blue space') {
      for (final polyline
          in blueSpaceData.waterways) {
        final feature = polyline.hitValue;

        if (feature != null) {
          candidates.add(feature);
        }
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    BlueSpaceFeature? bestFeature;
    double bestScore = double.infinity;

    for (final originalFeature in candidates) {
      final nearestPoint =
          _nearestPointOnFeature(
        origin: currentLocation,
        feature: originalFeature,
      );

      final feature = originalFeature.copyWith(
        navigationPoint: nearestPoint,
      );

      final distanceFromUser = _distanceBetween(
        currentLocation,
        nearestPoint,
      );

      if (distanceFromUser >
          _maximumDestinationDistanceMetres) {
        continue;
      }

      double score =
          (distanceFromUser -
                  _preferredDestinationDistanceMetres)
              .abs();

      if (_preferGreenAreas &&
          greenSpaces.isNotEmpty) {
        final greenDistance =
            _nearestGreenSpaceDistance(
          point: nearestPoint,
          greenSpaces: greenSpaces,
        );

        score += greenDistance * 0.20;
      }

      if (score < bestScore) {
        bestScore = score;
        bestFeature = feature;
      }
    }

    if (bestFeature != null) {
      return bestFeature;
    }

    // Fallback: select the nearest matching feature,
    // even if no feature is within the preferred distance.
    double nearestDistance = double.infinity;

    for (final originalFeature in candidates) {
      final nearestPoint =
          _nearestPointOnFeature(
        origin: currentLocation,
        feature: originalFeature,
      );

      final distance = _distanceBetween(
        currentLocation,
        nearestPoint,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        bestFeature = originalFeature.copyWith(
          navigationPoint: nearestPoint,
        );
      }
    }

    return bestFeature;
  }

  double _nearestGreenSpaceDistance({
    required LatLng point,
    required List<GreenSpaceFeature> greenSpaces,
  }) {
    double nearestDistance = double.infinity;

    for (final greenSpace in greenSpaces) {
      final distance = _distanceBetween(
        point,
        greenSpace.navigationPoint,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
      }
    }

    return nearestDistance;
  }

  GreenSpaceFeature? _findNearestGreenSpace({
    required LatLng point,
    required List<GreenSpaceFeature> greenSpaces,
  }) {
    GreenSpaceFeature? nearestGreenSpace;
    double shortestDistance = double.infinity;

    for (final greenSpace in greenSpaces) {
      final distance = _distanceBetween(
        point,
        greenSpace.navigationPoint,
      );

      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearestGreenSpace = greenSpace;
      }
    }

    return nearestGreenSpace;
  }

  WaterPoint? _findBestWaterPoint({
    required LatLng currentLocation,
    required List<WaterPoint> waterPoints,
    required BlueSpaceFeature selectedBlueSpace,
  }) {
    WaterPoint? bestPoint;
    double bestScore = double.infinity;

    for (final point in waterPoints) {
      final distanceFromUser = _distanceBetween(
        currentLocation,
        point.location,
      );

      final distanceFromBlueSpace =
          _distanceBetween(
        point.location,
        selectedBlueSpace.navigationPoint,
      );

      if (distanceFromUser >
          _maximumDestinationDistanceMetres * 1.3) {
        continue;
      }

      final score =
          (distanceFromUser * 0.35) +
          (distanceFromBlueSpace * 0.65);

      if (score < bestScore) {
        bestScore = score;
        bestPoint = point;
      }
    }

    return bestPoint;
  }

  bool _shouldIncludeOptionalWaterPoint({
    required WaterPoint waterPoint,
    required BlueSpaceFeature blueSpace,
    required LatLng currentLocation,
  }) {
    final distanceToBlueSpace = _distanceBetween(
      waterPoint.location,
      blueSpace.navigationPoint,
    );

    final distanceFromUser = _distanceBetween(
      currentLocation,
      waterPoint.location,
    );

    switch (_selectedDuration) {
      case 15:
        return distanceToBlueSpace <= 180 &&
            distanceFromUser <= 650;

      case 30:
        return distanceToBlueSpace <= 350 &&
            distanceFromUser <= 1400;

      case 45:
        return distanceToBlueSpace <= 600 &&
            distanceFromUser <= 2300;

      default:
        return false;
    }
  }

  List<LatLng> _createWaterwayRoutePoints({
    required LatLng origin,
    required BlueSpaceFeature blueSpace,
  }) {
    final geometry = blueSpace.routePoints;

    if (!blueSpace.isWaterway ||
        geometry.length < 3) {
      return [blueSpace.navigationPoint];
    }

    final nearestIndex = _nearestPointIndex(
      origin: origin,
      points: geometry,
    );

    if (nearestIndex < 0) {
      return [blueSpace.navigationPoint];
    }

    final remainingForward =
        geometry.length - 1 - nearestIndex;
    final remainingBackward = nearestIndex;

    final direction =
        remainingForward >= remainingBackward
            ? 1
            : -1;

    final availablePointCount = direction == 1
        ? remainingForward
        : remainingBackward;

    if (availablePointCount <= 1) {
      return [geometry[nearestIndex]];
    }

    int numberOfWaterwayStops;

    switch (_selectedDuration) {
      case 15:
        numberOfWaterwayStops = 2;
        break;
      case 30:
      case 45:
        numberOfWaterwayStops = 3;
        break;
      default:
        numberOfWaterwayStops = 2;
    }

    numberOfWaterwayStops =
        numberOfWaterwayStops.clamp(
      1,
      availablePointCount,
    );

    final sampledPoints = <LatLng>[];

    for (int stop = 0;
        stop < numberOfWaterwayStops;
        stop++) {
      final fraction =
          (stop + 1) / numberOfWaterwayStops;

      final offset =
          (availablePointCount * fraction)
              .round()
              .clamp(1, availablePointCount);

      final index =
          nearestIndex + (direction * offset);

      final point = geometry[index];

      if (sampledPoints.isEmpty ||
          _distanceBetween(
                sampledPoints.last,
                point,
              ) >
              20) {
        sampledPoints.add(point);
      }
    }

    if (sampledPoints.isEmpty) {
      sampledPoints.add(
        blueSpace.navigationPoint,
      );
    }

    return sampledPoints;
  }

  String _coordinateText(LatLng point) {
    return '${point.latitude},${point.longitude}';
  }

  Future<void> _openGoogleMapsRoute({
    required LatLng origin,
    required BlueSpaceFeature blueSpace,
    WaterPoint? waterPoint,
  }) async {
    final routeWaypoints = <LatLng>[];

    if (waterPoint != null) {
      routeWaypoints.add(waterPoint.location);
    }

    if (blueSpace.isWaterway) {
      routeWaypoints.addAll(
        _createWaterwayRoutePoints(
          origin: origin,
          blueSpace: blueSpace,
        ),
      );
    } else {
      routeWaypoints.add(
        blueSpace.navigationPoint,
      );
    }

    // Prevent accidental duplicate points.
    final uniqueWaypoints = <LatLng>[];

    for (final point in routeWaypoints) {
      final alreadyIncluded =
          uniqueWaypoints.any(
        (existing) =>
            _distanceBetween(existing, point) < 15,
      );

      if (!alreadyIncluded) {
        uniqueWaypoints.add(point);
      }
    }

    final queryParameters = <String, String>{
      'api': '1',
      'origin': _coordinateText(origin),
      'travelmode': 'walking',
    };

    if (_routeType == 'Circular') {
      queryParameters['destination'] =
          _coordinateText(origin);

      if (uniqueWaypoints.isNotEmpty) {
        queryParameters['waypoints'] =
            uniqueWaypoints
                .map(_coordinateText)
                .join('|');
      }
    } else {
      if (uniqueWaypoints.isEmpty) {
        queryParameters['destination'] =
            _coordinateText(
          blueSpace.navigationPoint,
        );
      } else {
        queryParameters['destination'] =
            _coordinateText(
          uniqueWaypoints.last,
        );

        if (uniqueWaypoints.length > 1) {
          queryParameters['waypoints'] =
              uniqueWaypoints
                  .take(
                    uniqueWaypoints.length - 1,
                  )
                  .map(_coordinateText)
                  .join('|');
        }
      }
    }

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      queryParameters,
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw Exception(
        'Google Maps could not be opened.',
      );
    }
  }

  Future<void> _createRoute() async {
    if (_isCreatingRoute) {
      return;
    }

    setState(() {
      _isCreatingRoute = true;
      _statusMessage =
          'Getting your current location...';
    });

    try {
      final position =
          await LocationService.getCurrentPosition();

      final currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _statusMessage =
            'Loading mapped water and green spaces...';
      });

      final results = await Future.wait<dynamic>([
        WaterService.fetchDrinkingWaterPoints(),
        BlueSpaceService.fetchBlueSpaces(),
        GreenSpaceService.fetchGreenSpaces(),
      ]);

      final waterPoints =
          results[0] as List<WaterPoint>;

      final blueSpaceData =
          results[1] as BlueSpaceData;

      final greenSpaces =
          results[2] as List<GreenSpaceFeature>;

      if (!mounted) return;

      setState(() {
        _statusMessage =
            'Selecting a suitable route...';
      });

      final selectedBlueSpace =
          _findBestBlueSpace(
        currentLocation: currentLocation,
        blueSpaceData: blueSpaceData,
        greenSpaces: greenSpaces,
      );

      if (selectedBlueSpace == null) {
        throw Exception(
          'No matching blue space was found.',
        );
      }

      final candidateWaterPoint =
          _findBestWaterPoint(
        currentLocation: currentLocation,
        waterPoints: waterPoints,
        selectedBlueSpace: selectedBlueSpace,
      );

      WaterPoint? selectedWaterPoint;

      if (_drinkingWaterRequired) {
        if (candidateWaterPoint == null) {
          throw Exception(
            'No suitable drinking-water point '
            'was found near this route.',
          );
        }

        selectedWaterPoint = candidateWaterPoint;
      } else if (candidateWaterPoint != null) {
        if (_shouldIncludeOptionalWaterPoint(
          waterPoint: candidateWaterPoint,
          blueSpace: selectedBlueSpace,
          currentLocation: currentLocation,
        )) {
          selectedWaterPoint = candidateWaterPoint;
        }
      }

      GreenSpaceFeature? nearbyGreenSpace;

      if (_preferGreenAreas &&
          greenSpaces.isNotEmpty) {
        nearbyGreenSpace =
            _findNearestGreenSpace(
          point:
              selectedBlueSpace.navigationPoint,
          greenSpaces: greenSpaces,
        );
      }

      final waterwayRoutePoints =
          selectedBlueSpace.isWaterway
              ? _createWaterwayRoutePoints(
                  origin: currentLocation,
                  blueSpace: selectedBlueSpace,
                )
              : <LatLng>[];

      if (!mounted) return;

      final blueSpaceDistance =
          _distanceBetween(
        currentLocation,
        selectedBlueSpace.navigationPoint,
      );

      final waterDescription =
          selectedWaterPoint == null
              ? 'No drinking-water stop included'
              : 'Drinking-water stop:\n'
                  '${selectedWaterPoint.name}';

      final greenDescription =
          nearbyGreenSpace == null
              ? 'No nearby mapped green space found'
              : 'Nearby greenery:\n'
                  '${nearbyGreenSpace.name} '
                  '(${nearbyGreenSpace.type})';

      final routeExplanation =
          selectedBlueSpace.isWaterway
              ? 'AquaRoute selected the nearest section '
                  'of this ${selectedBlueSpace.type.toLowerCase()} '
                  'and will send '
                  '${waterwayRoutePoints.length} waterway '
                  'points to Google Maps. This encourages '
                  'the route to follow the mapped waterway.'
              : 'AquaRoute selected the nearest suitable '
                  'point associated with this water area.';

      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Wellness route ready',
            ),
            content: SingleChildScrollView(
              child: Text(
                'Preferred duration: '
                '$_selectedDuration minutes\n'
                'Route type: $_routeType\n\n'
                'Selected blue space:\n'
                '${selectedBlueSpace.name}\n'
                '${selectedBlueSpace.type}\n'
                'Distance to nearest section: '
                '${_formatDistance(blueSpaceDistance)}\n\n'
                '$waterDescription\n\n'
                '$greenDescription\n\n'
                '$routeExplanation\n\n'
                'Google Maps calculates the final '
                'pedestrian route using recognised '
                'walkable paths. It may adjust the route '
                'when a waterway does not have a continuous '
                'walking path beside it.\n\n'
                'Google Maps may display coordinate-based '
                'locations as “Dropped pin”, but the actual '
                'OSM feature names are shown here.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                icon: const Icon(
                  Icons.directions_walk,
                ),
                label: const Text(
                  'Open route',
                ),
              ),
            ],
          );
        },
      );

      if (shouldOpen != true) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _statusMessage =
            'Opening Google Maps...';
      });

      await _openGoogleMapsRoute(
        origin: currentLocation,
        blueSpace: selectedBlueSpace,
        waterPoint: selectedWaterPoint,
      );
    } catch (error) {
      if (!mounted) return;

      final message = error
          .toString()
          .replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingRoute = false;
          _statusMessage = null;
        });
      }
    }
  }

  String _formatDistance(double metres) {
    if (metres < 1000) {
      return '${metres.round()} m';
    }

    return '${(metres / 1000).toStringAsFixed(2)} km';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 20,
        bottom: 10,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF023E8A),
        ),
      ),
    );
  }

  Widget _durationButton(int minutes) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
        ),
        child: ChoiceChip(
          label: SizedBox(
            width: double.infinity,
            child: Text(
              '$minutes min',
              textAlign: TextAlign.center,
            ),
          ),
          selected:
              _selectedDuration == minutes,
          onSelected: _isCreatingRoute
              ? null
              : (_) {
                  setState(() {
                    _selectedDuration = minutes;
                  });
                },
        ),
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
          'Plan a Wellness Walk',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.directions_walk,
                size: 75,
                color: Color(0xFF00B4D8),
              ),
              const SizedBox(height: 12),
              const Text(
                'Personalised Hydration and '
                'Blue-Space Wellness Walk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF023E8A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose your walking preferences. '
                'For rivers and canals, AquaRoute uses '
                'several points from the mapped waterway '
                'to encourage a route beside the water.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              _sectionTitle(
                'Preferred walking duration',
              ),
              Row(
                children: [
                  _durationButton(15),
                  _durationButton(30),
                  _durationButton(45),
                ],
              ),
              _sectionTitle('Route type'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'Circular',
                    label: Text('Circular'),
                    icon: Icon(Icons.loop),
                  ),
                  ButtonSegment<String>(
                    value: 'One-way',
                    label: Text('One-way'),
                    icon: Icon(
                      Icons.trending_flat,
                    ),
                  ),
                ],
                selected: {_routeType},
                onSelectionChanged:
                    _isCreatingRoute
                        ? null
                        : (selection) {
                            setState(() {
                              _routeType =
                                  selection.first;
                            });
                          },
              ),
              _sectionTitle(
                'Drinking-water stop',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Include drinking water',
                ),
                subtitle: Text(
                  _drinkingWaterRequired
                      ? 'A drinking-water stop is required.'
                      : 'A drinking-water stop is optional.',
                ),
                value: _drinkingWaterRequired,
                onChanged: _isCreatingRoute
                    ? null
                    : (value) {
                        setState(() {
                          _drinkingWaterRequired =
                              value;
                        });
                      },
              ),
              _sectionTitle(
                'Preferred blue-space type',
              ),
              DropdownButtonFormField<String>(
                initialValue:
                    _blueSpacePreference,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.water_outlined,
                  ),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'Water Area',
                    child: Text(
                      'Lake / Pond / Water Area',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'River / Canal',
                    child: Text(
                      'River / Stream / Canal',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Any blue space',
                    child: Text(
                      'Any blue space',
                    ),
                  ),
                ],
                onChanged: _isCreatingRoute
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _blueSpacePreference =
                              value;
                        });
                      },
              ),
              _sectionTitle(
                'Green-space preference',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Prefer blue spaces near greenery',
                ),
                subtitle: const Text(
                  'Green-space proximity helps select '
                  'the destination. A park is not added '
                  'as a separate route stop.',
                ),
                value: _preferGreenAreas,
                onChanged: _isCreatingRoute
                    ? null
                    : (value) {
                        setState(() {
                          _preferGreenAreas = value;
                        });
                      },
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _isCreatingRoute
                    ? null
                    : _createRoute,
                icon: _isCreatingRoute
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.route,
                        color: Colors.white,
                      ),
                label: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  child: Text(
                    _isCreatingRoute
                        ? 'Creating route...'
                        : 'Create Wellness Route',
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF0077B6),
                  disabledBackgroundColor:
                      const Color(0xFF7CB7D4),
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0077B6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 15),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFF0077B6),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The selected duration is a preference. '
                          'AquaRoute selects mapped locations using '
                          'straight-line distances. Google Maps then '
                          'calculates the final route using available '
                          'pedestrian paths.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}