import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/blue_space_service.dart';
import '../services/green_space_service.dart';
import '../services/location_service.dart';
import '../services/water_services.dart';

enum RouteActivity {
  walk,
  run,
  cycle,
}

class WellnessRouteScreen extends StatefulWidget {
  const WellnessRouteScreen({super.key});

  @override
  State<WellnessRouteScreen> createState() =>
      _WellnessRouteScreenState();
}

class _WellnessRouteScreenState
    extends State<WellnessRouteScreen> {
  final TextEditingController _customDurationController =
      TextEditingController(text: '60');

  int _selectedDuration = 30;
  bool _useCustomDuration = false;

  RouteActivity _activity = RouteActivity.walk;

  String _routeType = 'Circular';
  String _waterFeaturePreference = 'Any water feature';

  bool _drinkingWaterRequired = false;
  bool _preferGreenAreas = true;

  bool _isCreatingRoute = false;
  String? _statusMessage;

  @override
  void dispose() {
    _customDurationController.dispose();
    super.dispose();
  }

  int get _durationMinutes => _selectedDuration;

  String get _activityName {
    switch (_activity) {
      case RouteActivity.walk:
        return 'Walking';
      case RouteActivity.run:
        return 'Running';
      case RouteActivity.cycle:
        return 'Cycling';
    }
  }

  IconData get _activityIcon {
    switch (_activity) {
      case RouteActivity.walk:
        return Icons.directions_walk;
      case RouteActivity.run:
        return Icons.directions_run;
      case RouteActivity.cycle:
        return Icons.directions_bike;
    }
  }

  String get _googleMapsTravelMode {
    switch (_activity) {
      case RouteActivity.walk:
      case RouteActivity.run:
        return 'walking';

      case RouteActivity.cycle:
        return 'bicycling';
    }
  }

  double get _estimatedSpeedMetresPerMinute {
    switch (_activity) {
      case RouteActivity.walk:
        return 80;

      case RouteActivity.run:
        return 135;

      case RouteActivity.cycle:
        return 250;
    }
  }

  double get _estimatedTotalDistanceMetres {
    return _durationMinutes *
        _estimatedSpeedMetresPerMinute;
  }

  double get _preferredDestinationDistanceMetres {
    if (_routeType == 'Circular') {
      return _estimatedTotalDistanceMetres * 0.22;
    }

    return _estimatedTotalDistanceMetres * 0.70;
  }

  double get _maximumDestinationDistanceMetres {
    return _preferredDestinationDistanceMetres * 1.50;
  }

  bool get _selectedFeatureIsFountain {
    return _waterFeaturePreference ==
        'Drinking-water fountain';
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

    final nearestIndex = _nearestPointIndex(
      origin: origin,
      points: feature.routePoints,
    );

    if (nearestIndex < 0) {
      return feature.navigationPoint;
    }

    return feature.routePoints[nearestIndex];
  }

  bool _matchesWaterPreference(
    BlueSpaceFeature feature,
  ) {
    final type = feature.type.toLowerCase();

    switch (_waterFeaturePreference) {
      case 'Any water feature':
        return true;

      case 'Lake':
        return type == 'lake';

      case 'Pond':
        return type == 'pond';

      case 'Reservoir':
        return type == 'reservoir';

      case 'Water basin':
        return type == 'water basin';

      case 'Other water area':
        return type == 'water area';

      case 'River':
        return type == 'river';

      case 'Stream':
        return type == 'stream';

      case 'Canal':
        return type == 'canal';

      default:
        return false;
    }
  }

  BlueSpaceFeature? _findBestBlueSpace({
    required LatLng currentLocation,
    required BlueSpaceData blueSpaceData,
    required List<GreenSpaceFeature> greenSpaces,
  }) {
    final candidates = <BlueSpaceFeature>[];

    for (final polygon in blueSpaceData.waterPolygons) {
      final feature = polygon.hitValue;

      if (feature != null &&
          _matchesWaterPreference(feature)) {
        candidates.add(feature);
      }
    }

    for (final polyline in blueSpaceData.waterways) {
      final feature = polyline.hitValue;

      if (feature != null &&
          _matchesWaterPreference(feature)) {
        candidates.add(feature);
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    BlueSpaceFeature? bestFeature;
    double bestScore = double.infinity;

    for (final originalFeature in candidates) {
      final nearestPoint = _nearestPointOnFeature(
        origin: currentLocation,
        feature: originalFeature,
      );

      final candidateFeature = originalFeature.copyWith(
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
        bestFeature = candidateFeature;
      }
    }

    if (bestFeature != null) {
      return bestFeature;
    }

    // Fallback: use the nearest matching feature.
    double nearestDistance = double.infinity;

    for (final originalFeature in candidates) {
      final nearestPoint = _nearestPointOnFeature(
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

  WaterPoint? _findBestFountain({
    required LatLng currentLocation,
    required List<WaterPoint> waterPoints,
  }) {
    if (waterPoints.isEmpty) {
      return null;
    }

    WaterPoint? bestPoint;
    double bestScore = double.infinity;

    for (final point in waterPoints) {
      final distance = _distanceBetween(
        currentLocation,
        point.location,
      );

      final score =
          (distance -
                  _preferredDestinationDistanceMetres)
              .abs();

      if (score < bestScore) {
        bestScore = score;
        bestPoint = point;
      }
    }

    return bestPoint;
  }

  WaterPoint? _findWaterStopNearBlueSpace({
    required LatLng currentLocation,
    required List<WaterPoint> waterPoints,
    required BlueSpaceFeature blueSpace,
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
        blueSpace.navigationPoint,
      );

      if (distanceFromUser >
          _maximumDestinationDistanceMetres * 1.30) {
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

    final forwardAvailable =
        geometry.length - 1 - nearestIndex;

    final backwardAvailable = nearestIndex;

    final direction =
        forwardAvailable >= backwardAvailable
            ? 1
            : -1;

    final availableCount = direction == 1
        ? forwardAvailable
        : backwardAvailable;

    if (availableCount < 1) {
      return [geometry[nearestIndex]];
    }

    int requestedStops;

    if (_durationMinutes <= 20) {
      requestedStops = 2;
    } else if (_durationMinutes <= 60) {
      requestedStops = 3;
    } else {
      requestedStops = 4;
    }

    if (requestedStops > availableCount) {
      requestedStops = availableCount;
    }

    if (requestedStops < 1) {
      requestedStops = 1;
    }

    final sampledPoints = <LatLng>[];

    for (int stop = 0;
        stop < requestedStops;
        stop++) {
      final fraction =
          (stop + 1) / requestedStops;

      int offset =
          (availableCount * fraction).round();

      if (offset < 1) {
        offset = 1;
      }

      if (offset > availableCount) {
        offset = availableCount;
      }

      final index =
          nearestIndex + (direction * offset);

      final point = geometry[index];

      final sufficientlySeparated =
          sampledPoints.isEmpty ||
              _distanceBetween(
                    sampledPoints.last,
                    point,
                  ) >
                  20;

      if (sufficientlySeparated) {
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

  List<LatLng> _removeDuplicatePoints(
    List<LatLng> points,
  ) {
    final uniquePoints = <LatLng>[];

    for (final point in points) {
      final alreadyIncluded =
          uniquePoints.any(
        (existingPoint) {
          return _distanceBetween(
                existingPoint,
                point,
              ) <
              15;
        },
      );

      if (!alreadyIncluded) {
        uniquePoints.add(point);
      }
    }

    return uniquePoints;
  }

  String _coordinateText(LatLng point) {
    return '${point.latitude},${point.longitude}';
  }

  Future<void> _openGoogleMapsRoute({
    required LatLng origin,
    BlueSpaceFeature? blueSpace,
    WaterPoint? fountainDestination,
    WaterPoint? drinkingWaterStop,
  }) async {
    final routePoints = <LatLng>[];

    if (drinkingWaterStop != null) {
      routePoints.add(
        drinkingWaterStop.location,
      );
    }

    if (fountainDestination != null) {
      routePoints.add(
        fountainDestination.location,
      );
    } else if (blueSpace != null) {
      if (blueSpace.isWaterway) {
        routePoints.addAll(
          _createWaterwayRoutePoints(
            origin: origin,
            blueSpace: blueSpace,
          ),
        );
      } else {
        routePoints.add(
          blueSpace.navigationPoint,
        );
      }
    }

    final uniquePoints =
        _removeDuplicatePoints(routePoints);

    if (uniquePoints.isEmpty) {
      throw Exception(
        'No route destination was available.',
      );
    }

    final queryParameters = <String, String>{
      'api': '1',
      'origin': _coordinateText(origin),
      'travelmode': _googleMapsTravelMode,
    };

    if (_routeType == 'Circular') {
      queryParameters['destination'] =
          _coordinateText(origin);

      queryParameters['waypoints'] =
          uniquePoints
              .map(_coordinateText)
              .join('|');
    } else {
      queryParameters['destination'] =
          _coordinateText(
        uniquePoints.last,
      );

      if (uniquePoints.length > 1) {
        queryParameters['waypoints'] =
            uniquePoints
                .take(uniquePoints.length - 1)
                .map(_coordinateText)
                .join('|');
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

    if (_durationMinutes < 5 ||
        _durationMinutes > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a duration between 5 and 300 minutes.',
          ),
        ),
      );

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

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Loading mapped water features...';
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

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Selecting a scenic route...';
      });

      BlueSpaceFeature? selectedBlueSpace;
      WaterPoint? fountainDestination;
      WaterPoint? drinkingWaterStop;
      GreenSpaceFeature? nearbyGreenSpace;

      if (_selectedFeatureIsFountain) {
        fountainDestination =
            _findBestFountain(
          currentLocation: currentLocation,
          waterPoints: waterPoints,
        );

        if (fountainDestination == null) {
          throw Exception(
            'No drinking-water fountain was found.',
          );
        }

        if (_preferGreenAreas &&
            greenSpaces.isNotEmpty) {
          nearbyGreenSpace =
              _findNearestGreenSpace(
            point: fountainDestination.location,
            greenSpaces: greenSpaces,
          );
        }
      } else {
        selectedBlueSpace =
            _findBestBlueSpace(
          currentLocation: currentLocation,
          blueSpaceData: blueSpaceData,
          greenSpaces: greenSpaces,
        );

        if (selectedBlueSpace == null) {
          throw Exception(
            'No mapped $_waterFeaturePreference '
            'was found nearby. Try another water '
            'feature or a longer duration.',
          );
        }

        if (_drinkingWaterRequired) {
          drinkingWaterStop =
              _findWaterStopNearBlueSpace(
            currentLocation: currentLocation,
            waterPoints: waterPoints,
            blueSpace: selectedBlueSpace,
          );

          if (drinkingWaterStop == null) {
            throw Exception(
              'No suitable drinking-water stop '
              'was found near this route.',
            );
          }
        }

        if (_preferGreenAreas &&
            greenSpaces.isNotEmpty) {
          nearbyGreenSpace =
              _findNearestGreenSpace(
            point:
                selectedBlueSpace.navigationPoint,
            greenSpaces: greenSpaces,
          );
        }
      }

      final destinationName =
          fountainDestination?.name ??
              selectedBlueSpace?.name ??
              'Selected destination';

      final destinationType =
          fountainDestination != null
              ? 'Drinking-water fountain'
              : selectedBlueSpace?.type ??
                  _waterFeaturePreference;

      final destinationPoint =
          fountainDestination?.location ??
              selectedBlueSpace!.navigationPoint;

      final destinationDistance =
          _distanceBetween(
        currentLocation,
        destinationPoint,
      );

      final hydrationText =
          fountainDestination != null
              ? 'The destination itself is a '
                  'drinking-water point.'
              : drinkingWaterStop == null
                  ? 'No additional drinking-water stop.'
                  : 'Drinking-water stop:\n'
                      '${drinkingWaterStop.name}';

      final greenText =
          nearbyGreenSpace == null
              ? 'No nearby mapped green space found.'
              : '${nearbyGreenSpace.name} '
                  '(${nearbyGreenSpace.type})';

      final waterwayText =
          selectedBlueSpace?.isWaterway == true
              ? '\n\nSeveral coordinates from the mapped '
                  '${selectedBlueSpace!.type.toLowerCase()} '
                  'will be sent to Google Maps to encourage '
                  'the route to remain close to the waterway.'
              : '';

      if (!mounted) {
        return;
      }

      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Scenic route ready',
            ),
            content: SingleChildScrollView(
              child: Text(
                'Activity: $_activityName\n'
                'Preferred duration: '
                '$_durationMinutes minutes\n'
                'Route type: $_routeType\n'
                'Estimated workout distance: '
                '${_formatDistance(_estimatedTotalDistanceMetres)}\n\n'
                'Selected water feature:\n'
                '$destinationName\n'
                '$destinationType\n'
                'Straight-line distance: '
                '${_formatDistance(destinationDistance)}\n\n'
                '$hydrationText\n\n'
                'Nearby greenery:\n'
                '$greenText'
                '$waterwayText\n\n'
                'Google Maps calculates the final '
                'route using available walking or cycling '
                'paths. The actual duration may differ '
                'from the selected workout duration.'
                '${_activity == RouteActivity.run ? '\n\nRunning uses walking navigation because Google Maps does not have a separate running mode.' : ''}',
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
                icon: Icon(_activityIcon),
                label: const Text('Open route'),
              ),
            ],
          );
        },
      );

      if (shouldOpen != true) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Opening Google Maps...';
      });

      await _openGoogleMapsRoute(
        origin: currentLocation,
        blueSpace: selectedBlueSpace,
        fountainDestination:
            fountainDestination,
        drinkingWaterStop:
            drinkingWaterStop,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error
          .toString()
          .replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
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

    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 22,
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

  Widget _activityButton({
    required RouteActivity activity,
    required String label,
    required IconData icon,
  }) {
    final selected = _activity == activity;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isCreatingRoute
              ? null
              : () {
                  setState(() {
                    _activity = activity;
                  });
                },
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 5,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF0077B6)
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0077B6)
                    : Colors.black26,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF0077B6),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickDurationButton(int minutes) {
    final selected =
        !_useCustomDuration &&
        _selectedDuration == minutes;

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
          selected: selected,
          onSelected: _isCreatingRoute
              ? null
              : (_) {
                  setState(() {
                    _selectedDuration = minutes;
                    _useCustomDuration = false;
                  });
                },
        ),
      ),
    );
  }

  Widget _customDurationField() {
    return TextField(
      controller: _customDurationController,
      enabled: !_isCreatingRoute,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Custom duration',
        hintText: 'Example: 75',
        suffixText: 'minutes',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.timer_outlined),
        helperText:
            'Enter any duration from 5 to 300 minutes.',
      ),
      onChanged: (value) {
        final duration = int.tryParse(value);

        if (duration == null) {
          return;
        }

        setState(() {
          _selectedDuration = duration;
        });
      },
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
          'Plan a Scenic Workout',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Icon(
                _activityIcon,
                size: 72,
                color: const Color(0xFF00B4D8),
              ),
              const SizedBox(height: 12),
              const Text(
                'Personalised Hydration and '
                'Blue-Space Scenic Route',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF023E8A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose your activity, preferred workout '
                'time and water feature. AquaRoute selects '
                'a suitable scenic destination using your '
                'GPS location and mapped geographic data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),

              _sectionTitle('Activity'),

              Row(
                children: [
                  _activityButton(
                    activity: RouteActivity.walk,
                    label: 'Walk',
                    icon: Icons.directions_walk,
                  ),
                  _activityButton(
                    activity: RouteActivity.run,
                    label: 'Run',
                    icon: Icons.directions_run,
                  ),
                  _activityButton(
                    activity: RouteActivity.cycle,
                    label: 'Cycle',
                    icon: Icons.directions_bike,
                  ),
                ],
              ),

              _sectionTitle(
                'Preferred workout duration',
              ),

              Row(
                children: [
                  _quickDurationButton(15),
                  _quickDurationButton(30),
                  _quickDurationButton(45),
                ],
              ),

              const SizedBox(height: 12),

              ChoiceChip(
                label: const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Choose a custom duration',
                    textAlign: TextAlign.center,
                  ),
                ),
                selected: _useCustomDuration,
                onSelected: _isCreatingRoute
                    ? null
                    : (selected) {
                        setState(() {
                          _useCustomDuration = selected;

                          if (selected) {
                            final enteredDuration =
                                int.tryParse(
                              _customDurationController
                                  .text,
                            );

                            _selectedDuration =
                                enteredDuration ?? 60;
                          }
                        });
                      },
              ),

              if (_useCustomDuration) ...[
                const SizedBox(height: 14),
                _customDurationField(),
              ],

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _activityIcon,
                        color:
                            const Color(0xFF0077B6),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Selected: $_activityName for '
                          '$_durationMinutes minutes\n'
                          'Estimated distance: '
                          '${_formatDistance(_estimatedTotalDistanceMetres)}',
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                'Preferred water feature',
              ),

              DropdownButtonFormField<String>(
                initialValue: _waterFeaturePreference,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.water_outlined),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'Any water feature',
                    child: Text(
                      'Any water feature',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Lake',
                    child: Text('Lake'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Pond',
                    child: Text('Pond'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Reservoir',
                    child: Text('Reservoir'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Water basin',
                    child: Text('Water basin'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Other water area',
                    child: Text(
                      'Other water area',
                    ),
                  ),
                  DropdownMenuItem<String>(
                    value: 'River',
                    child: Text('River'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Stream',
                    child: Text('Stream'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Canal',
                    child: Text('Canal'),
                  ),
                  DropdownMenuItem<String>(
                    value:
                        'Drinking-water fountain',
                    child: Text(
                      'Drinking-water fountain',
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
                          _waterFeaturePreference =
                              value;

                          if (_selectedFeatureIsFountain) {
                            _drinkingWaterRequired =
                                false;
                          }
                        });
                      },
              ),

              if (!_selectedFeatureIsFountain) ...[
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
                        ? 'A separate drinking-water stop is required.'
                        : 'No separate drinking-water stop is required.',
                  ),
                  value:
                      _drinkingWaterRequired,
                  onChanged: _isCreatingRoute
                      ? null
                      : (value) {
                          setState(() {
                            _drinkingWaterRequired =
                                value;
                          });
                        },
                ),
              ],

              _sectionTitle(
                'Green-space preference',
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Prefer water features near greenery',
                ),
                subtitle: const Text(
                  'Green-space proximity helps select '
                  'the destination. The green space is '
                  'not automatically added as another stop.',
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
                    : Icon(
                        _activityIcon,
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
                        : 'Create Scenic Route',
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
                          'The selected duration is a '
                          'preference. AquaRoute uses estimated '
                          'activity speeds and straight-line '
                          'distances to select a suitable feature. '
                          'Google Maps then calculates the actual '
                          'route using available paths.',
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