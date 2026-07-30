import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/blue_space_service.dart';
import '../services/green_space_service.dart';
import '../services/hiking_trail_service.dart';
import '../services/location_service.dart';
import '../services/water_services.dart';

enum RouteActivity {
  walk,
  hike,
  run,
  cycle,
}

enum HikingTimeMode {
  allTrails,
  maximumTime,
}

class HikingRouteOption {
  final HikingTrailFeature trail;
  final LatLng entryPoint;
  final double approachDistanceMetres;
  final double trailDistanceMetres;
  final int estimatedMinutes;
  final List<LatLng> mapPoints;

  const HikingRouteOption({
    required this.trail,
    required this.entryPoint,
    required this.approachDistanceMetres,
    required this.trailDistanceMetres,
    required this.estimatedMinutes,
    required this.mapPoints,
  });
}

class WellnessRouteScreen extends StatefulWidget {
  const WellnessRouteScreen({super.key});

  @override
  State<WellnessRouteScreen> createState() => _WellnessRouteScreenState();
}

class _WellnessRouteScreenState extends State<WellnessRouteScreen> {
  final TextEditingController _customDurationController =
      TextEditingController(text: '60');

  int _selectedDuration = 30;
  bool _useCustomDuration = false;
  RouteActivity _activity = RouteActivity.walk;
  String _routeType = 'Circular';
  String _waterFeaturePreference = 'Any water feature';
  bool _drinkingWaterRequired = false;
  bool _preferGreenAreas = true;
  HikingTimeMode _hikingTimeMode = HikingTimeMode.allTrails;
  int _maximumHikingMinutes = 300;
  bool _isCreatingRoute = false;
  String? _statusMessage;

  static const Color _navy = Color(0xFF023E8A);
  static const Color _blue = Color(0xFF0077B6);
  static const Color _cyan = Color(0xFF00B4D8);
  static const Color _hikeGreen = Color(0xFF16856B);
  static const Color _orange = Color(0xFFF97316);
  static const Color _purple = Color(0xFF7C3AED);

  @override
  void dispose() {
    _customDurationController.dispose();
    super.dispose();
  }

  int get _durationMinutes => _selectedDuration;
  bool get _isHiking => _activity == RouteActivity.hike;

  String get _activityName {
    switch (_activity) {
      case RouteActivity.walk:
        return 'Walking';
      case RouteActivity.hike:
        return 'Hiking';
      case RouteActivity.run:
        return 'Running';
      case RouteActivity.cycle:
        return 'Cycling';
    }
  }

  String get _activityButtonName => 'Create $_activityName Route';

  IconData get _activityIcon {
    switch (_activity) {
      case RouteActivity.walk:
        return Icons.directions_walk_rounded;
      case RouteActivity.hike:
        return Icons.hiking_rounded;
      case RouteActivity.run:
        return Icons.directions_run_rounded;
      case RouteActivity.cycle:
        return Icons.directions_bike_rounded;
    }
  }

  Color get _activityColor {
    switch (_activity) {
      case RouteActivity.walk:
        return _cyan;
      case RouteActivity.hike:
        return _hikeGreen;
      case RouteActivity.run:
        return _orange;
      case RouteActivity.cycle:
        return _purple;
    }
  }

  List<Color> get _activityGradient {
    switch (_activity) {
      case RouteActivity.walk:
        return const [Color(0xFF0077B6), Color(0xFF00B4D8)];
      case RouteActivity.hike:
        return const [Color(0xFF0B5D46), Color(0xFF2A9D58)];
      case RouteActivity.run:
        return const [Color(0xFFF97316), Color(0xFFF59E0B)];
      case RouteActivity.cycle:
        return const [Color(0xFF5B21B6), Color(0xFF8B5CF6)];
    }
  }

  String get _googleMapsTravelMode {
    return _activity == RouteActivity.cycle ? 'bicycling' : 'walking';
  }

  double get _estimatedSpeedMetresPerMinute {
    switch (_activity) {
      case RouteActivity.walk:
        return 80;
      case RouteActivity.hike:
        return 75;
      case RouteActivity.run:
        return 135;
      case RouteActivity.cycle:
        return 250;
    }
  }

  double get _estimatedTotalDistanceMetres =>
      _durationMinutes * _estimatedSpeedMetresPerMinute;

  double get _preferredDestinationDistanceMetres {
    if (_isHiking) {
      return _routeType == 'Circular'
          ? _estimatedTotalDistanceMetres * 0.25
          : _estimatedTotalDistanceMetres * 0.60;
    }

    return _routeType == 'Circular'
        ? _estimatedTotalDistanceMetres * 0.22
        : _estimatedTotalDistanceMetres * 0.70;
  }

  double get _maximumDestinationDistanceMetres =>
      _preferredDestinationDistanceMetres * (_isHiking ? 1.8 : 1.5);

  bool get _selectedFeatureIsFountain =>
      _waterFeaturePreference == 'Drinking-water fountain';

  double _distanceBetween(LatLng first, LatLng second) {
    return Geolocator.distanceBetween(
      first.latitude,
      first.longitude,
      second.latitude,
      second.longitude,
    );
  }

  int _nearestPointIndex(LatLng origin, List<LatLng> points) {
    if (points.isEmpty) return -1;

    int nearestIndex = 0;
    double shortestDistance = double.infinity;

    for (int index = 0; index < points.length; index++) {
      final distance = _distanceBetween(origin, points[index]);
      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearestIndex = index;
      }
    }

    return nearestIndex;
  }

  LatLng _nearestPointOnBlueFeature(
    LatLng origin,
    BlueSpaceFeature feature,
  ) {
    final index = _nearestPointIndex(origin, feature.routePoints);
    return index < 0 ? feature.navigationPoint : feature.routePoints[index];
  }

  bool _matchesWaterPreference(BlueSpaceFeature feature) {
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

  List<BlueSpaceFeature> _blueCandidates(BlueSpaceData data) {
    final candidates = <BlueSpaceFeature>[];

    for (final polygon in data.waterPolygons) {
      final feature = polygon.hitValue;
      if (feature != null && _matchesWaterPreference(feature)) {
        candidates.add(feature);
      }
    }

    for (final line in data.waterways) {
      final feature = line.hitValue;
      if (feature != null && _matchesWaterPreference(feature)) {
        candidates.add(feature);
      }
    }

    return candidates;
  }

  double _nearestGreenDistance(
    LatLng point,
    List<GreenSpaceFeature> greenSpaces,
  ) {
    double nearest = double.infinity;

    for (final greenSpace in greenSpaces) {
      final distance = _distanceBetween(
        point,
        greenSpace.navigationPoint,
      );
      if (distance < nearest) nearest = distance;
    }

    return nearest;
  }

  GreenSpaceFeature? _nearestGreenSpace(
    LatLng point,
    List<GreenSpaceFeature> greenSpaces,
  ) {
    GreenSpaceFeature? result;
    double nearest = double.infinity;

    for (final greenSpace in greenSpaces) {
      final distance = _distanceBetween(
        point,
        greenSpace.navigationPoint,
      );
      if (distance < nearest) {
        nearest = distance;
        result = greenSpace;
      }
    }

    return result;
  }

  BlueSpaceFeature? _findBestBlueSpace(
    LatLng currentLocation,
    BlueSpaceData data,
    List<GreenSpaceFeature> greenSpaces,
  ) {
    final candidates = _blueCandidates(data);
    BlueSpaceFeature? best;
    double bestScore = double.infinity;

    for (final original in candidates) {
      final point = _nearestPointOnBlueFeature(currentLocation, original);
      final distance = _distanceBetween(currentLocation, point);
      if (distance > _maximumDestinationDistanceMetres) continue;

      double score =
          (distance - _preferredDestinationDistanceMetres).abs();

      if (_preferGreenAreas && greenSpaces.isNotEmpty) {
        score += _nearestGreenDistance(point, greenSpaces) * 0.20;
      }

      if (score < bestScore) {
        bestScore = score;
        best = original.copyWith(navigationPoint: point);
      }
    }

    return best;
  }

  WaterPoint? _findBestFountain(
    LatLng origin,
    List<WaterPoint> waterPoints,
  ) {
    WaterPoint? best;
    double bestScore = double.infinity;

    for (final point in waterPoints) {
      final score = (_distanceBetween(origin, point.location) -
              _preferredDestinationDistanceMetres)
          .abs();
      if (score < bestScore) {
        bestScore = score;
        best = point;
      }
    }

    return best;
  }

  WaterPoint? _findWaterStop(
    LatLng origin,
    LatLng destination,
    List<WaterPoint> waterPoints,
  ) {
    WaterPoint? best;
    double bestScore = double.infinity;

    for (final point in waterPoints) {
      final fromUser = _distanceBetween(origin, point.location);
      if (fromUser > _maximumDestinationDistanceMetres * 1.4) continue;

      final score = fromUser * 0.35 +
          _distanceBetween(point.location, destination) * 0.65;

      if (score < bestScore) {
        bestScore = score;
        best = point;
      }
    }

    return best;
  }

  double _lineLength(List<LatLng> points) {
    double total = 0;
    for (int index = 1; index < points.length; index++) {
      total += _distanceBetween(points[index - 1], points[index]);
    }
    return total;
  }

  List<LatLng> _sampleEntireTrail(
    List<LatLng> geometry,
    LatLng origin,
  ) {
    if (geometry.length < 2) return geometry;

    var ordered = List<LatLng>.from(geometry);
    if (_distanceBetween(origin, ordered.last) <
        _distanceBetween(origin, ordered.first)) {
      ordered = ordered.reversed.toList();
    }

    final trailLength = _lineLength(ordered);
    final maximumMapPoints = trailLength < 2000
        ? 2
        : trailLength < 5000
            ? 4
            : 6;

    if (ordered.length <= maximumMapPoints) return ordered;

    final sampled = <LatLng>[];
    for (int index = 0; index < maximumMapPoints; index++) {
      final sourceIndex =
          ((ordered.length - 1) * index / (maximumMapPoints - 1)).round();
      sampled.add(ordered[sourceIndex]);
    }
    return sampled;
  }

  List<HikingRouteOption> _buildHikingOptions(
    LatLng origin,
    List<HikingTrailFeature> trails,
  ) {
    final options = <HikingRouteOption>[];

    for (final trail in trails) {
      if (trail.routePoints.length < 2) continue;

      var mapPoints = _sampleEntireTrail(trail.routePoints, origin);
      if (mapPoints.length < 2) continue;

      final entryPoint = mapPoints.first;
      final approachDistance = _distanceBetween(origin, entryPoint);
      final trailDistance = _lineLength(trail.routePoints);

      // Approximation used only for ordering the choices. Google Maps
      // calculates the final navigable duration after a route is opened.
      final approachMinutes = approachDistance / 80;
      final trailMinutes = trailDistance / 75;
      final returnMinutes =
          _routeType == 'Circular' ? approachDistance / 80 : 0;
      final estimatedMinutes =
          (approachMinutes + trailMinutes + returnMinutes).ceil();

      options.add(
        HikingRouteOption(
          trail: trail,
          entryPoint: entryPoint,
          approachDistanceMetres: approachDistance,
          trailDistanceMetres: trailDistance,
          estimatedMinutes: estimatedMinutes,
          mapPoints: mapPoints,
        ),
      );
    }

    options.sort(
      (first, second) =>
          first.estimatedMinutes.compareTo(second.estimatedMinutes),
    );

    if (_hikingTimeMode == HikingTimeMode.maximumTime) {
      return options
          .where(
            (option) => option.estimatedMinutes <= _maximumHikingMinutes,
          )
          .toList();
    }

    return options;
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours h' : '$hours h $remaining min';
  }

  Future<HikingRouteOption?> _showHikingOptions(
    List<HikingRouteOption> options,
  ) {
    return showModalBottomSheet<HikingRouteOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Color(0xFFF5FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2E9),
                      child: Icon(Icons.hiking_rounded, color: _hikeGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hiking routes in Karlsruhe',
                            style: TextStyle(
                              color: _navy,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${options.length} routes · shortest time first',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: options.length,
                 separatorBuilder: (_, _) => const SizedBox(height: 11),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final operatorName = option.trail.operatorName;

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.pop(sheetContext, option),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _hikeGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: _hikeGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.trail.name,
                                      style: const TextStyle(
                                        color: _navy,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (operatorName != null)
                                      Text(
                                        operatorName,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 7),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 5,
                                      children: [
                                        _routeChip(
                                          Icons.schedule_rounded,
                                          _formatTime(option.estimatedMinutes),
                                        ),
                                        _routeChip(
                                          Icons.hiking_rounded,
                                          _formatDistance(
                                            option.trailDistanceMetres,
                                          ),
                                        ),
                                        _routeChip(
                                          Icons.near_me_rounded,
                                          '${_formatDistance(option.approachDistanceMetres)} away',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: _hikeGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _routeChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: _hikeGreen),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  List<LatLng> _sampleLine(
    List<LatLng> geometry, {
    required LatLng origin,
    int maximumPoints = 6,
  }) {
    if (geometry.isEmpty) return [];

    final nearestIndex = _nearestPointIndex(origin, geometry);
    if (nearestIndex < 0) return [];

    final forward = geometry.length - 1 - nearestIndex;
    final backward = nearestIndex;
    final direction = forward >= backward ? 1 : -1;
    final available = direction == 1 ? forward : backward;

    if (available == 0) return [geometry[nearestIndex]];

    final count = available < maximumPoints ? available : maximumPoints;
    final sampled = <LatLng>[];

    for (int stop = 1; stop <= count; stop++) {
      int offset = (available * stop / count).round();
      if (offset < 1) offset = 1;
      final index = nearestIndex + direction * offset;
      final point = geometry[index];

      if (sampled.isEmpty ||
          _distanceBetween(sampled.last, point) > 30) {
        sampled.add(point);
      }
    }

    return sampled;
  }

  List<LatLng> _uniquePoints(List<LatLng> points) {
    final result = <LatLng>[];
    final minimumSeparation = _isHiking ? 150.0 : 15.0;

    for (final point in points) {
      if (!result.any(
        (existing) =>
            _distanceBetween(existing, point) < minimumSeparation,
      )) {
        result.add(point);
      }
    }
    return result;
  }

  String _coordinate(LatLng point) =>
      '${point.latitude},${point.longitude}';

  Future<void> _openGoogleMaps({
    required LatLng origin,
    required List<LatLng> routePoints,
  }) async {
    final points = _uniquePoints(routePoints);
    if (points.isEmpty) {
      throw Exception('No route points were available.');
    }

    final query = <String, String>{
      'api': '1',
      'origin': _coordinate(origin),
      'travelmode': _googleMapsTravelMode,
    };

    if (_routeType == 'Circular') {
      query['destination'] = _coordinate(origin);
      query['waypoints'] = points.map(_coordinate).join('|');
    } else {
      query['destination'] = _coordinate(points.last);
      if (points.length > 1) {
        query['waypoints'] =
            points.take(points.length - 1).map(_coordinate).join('|');
      }
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', query);
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw Exception('Google Maps could not be opened.');
    }
  }

  Future<void> _createRoute() async {
    if (_isCreatingRoute) return;
    FocusScope.of(context).unfocus();

    if (_durationMinutes < 5 || _durationMinutes > 300) {
      _showMessage('Choose a duration between 5 and 300 minutes.');
      return;
    }

    setState(() {
      _isCreatingRoute = true;
      _statusMessage = 'Finding your current location...';
    });

    try {
      final position = await LocationService.getCurrentPosition();
      final origin = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _statusMessage = _isHiking
            ? 'Loading mapped hiking trails and natural areas...'
            : 'Loading water and green-space data...';
      });

      final results = await Future.wait<dynamic>([
        WaterService.fetchDrinkingWaterPoints(),
        BlueSpaceService.fetchBlueSpaces(),
        GreenSpaceService.fetchGreenSpaces(),
        if (_isHiking) HikingTrailService.fetchHikingTrails(),
      ]);

      final waterPoints = results[0] as List<WaterPoint>;
      final blueData = results[1] as BlueSpaceData;
      final greenSpaces = results[2] as List<GreenSpaceFeature>;
      final trails = _isHiking
          ? results[3] as List<HikingTrailFeature>
          : <HikingTrailFeature>[];
      if (!mounted) return;
      setState(() {
        _statusMessage = _isHiking
            ? 'Ordering official hiking routes by total time...'
            : 'Designing your scenic route...';
      });

      final routePoints = <LatLng>[];
      String destinationName;
      String destinationType;
      LatLng destinationPoint;
      String natureText;
      String hydrationText;

      if (_isHiking) {
        final hikingOptions = _buildHikingOptions(origin, trails);

        if (hikingOptions.isEmpty) {
          throw Exception(
            _hikingTimeMode == HikingTimeMode.maximumTime
                ? 'No official hiking route fits within '
                    '${_formatTime(_maximumHikingMinutes)}. '
                    'Increase the time or select All available trails.'
                : 'No official mapped hiking routes were found in Karlsruhe.',
          );
        }

        if (!mounted) return;
        setState(() => _statusMessage = null);

        final selectedOption = await _showHikingOptions(hikingOptions);
        if (selectedOption == null || !mounted) return;

        routePoints.addAll(selectedOption.mapPoints);
        destinationName = selectedOption.trail.name;
        destinationType =
            '${selectedOption.trail.type} · '
            '${_formatTime(selectedOption.estimatedMinutes)} estimated';
        destinationPoint = selectedOption.entryPoint;
        natureText = selectedOption.trail.operatorName ??
            'Official mapped OSM hiking route';
        hydrationText = 'No drinking-water stop requested.';

        if (_drinkingWaterRequired) {
          final waterStop = _findWaterStop(
            origin,
            destinationPoint,
            waterPoints,
          );
          if (waterStop == null) {
            throw Exception(
              'No suitable drinking-water stop was found near this hike.',
            );
          }
          routePoints.insert(0, waterStop.location);
          hydrationText =
              'Included drinking-water stop: ${waterStop.name}';
        }
      } else if (_selectedFeatureIsFountain) {
        final fountain = _findBestFountain(origin, waterPoints);
        if (fountain == null) {
          throw Exception('No drinking-water fountain was found.');
        }

        routePoints.add(fountain.location);
        destinationName = fountain.name;
        destinationType = 'Drinking-water fountain';
        destinationPoint = fountain.location;
        final green = _nearestGreenSpace(destinationPoint, greenSpaces);
        natureText = green == null
            ? 'No nearby mapped green space'
            : '${green.name} (${green.type})';
        hydrationText =
            'The destination itself is a drinking-water point.';
      } else {
        final blueSpace = _findBestBlueSpace(
          origin,
          blueData,
          greenSpaces,
        );

        if (blueSpace == null) {
          throw Exception(
            'No suitable $_waterFeaturePreference was found. '
            'Try another category or a longer duration.',
          );
        }

        if (_drinkingWaterRequired) {
          final stop = _findWaterStop(
            origin,
            blueSpace.navigationPoint,
            waterPoints,
          );
          if (stop == null) {
            throw Exception(
              'No suitable drinking-water stop was found near the route.',
            );
          }
          routePoints.add(stop.location);
          hydrationText = 'Included drinking-water stop: ${stop.name}';
        } else {
          hydrationText = 'No drinking-water stop requested.';
        }

        if (blueSpace.isWaterway) {
          routePoints.addAll(
            _sampleLine(
              blueSpace.routePoints,
              origin: origin,
              maximumPoints: 4,
            ),
          );
        } else {
          routePoints.add(blueSpace.navigationPoint);
        }

        destinationName = blueSpace.name;
        destinationType = blueSpace.type;
        destinationPoint = blueSpace.navigationPoint;
        final green = _nearestGreenSpace(destinationPoint, greenSpaces);
        natureText = green == null
            ? 'No nearby mapped green space'
            : '${green.name} (${green.type})';
      }

      final shouldOpen = await _showRouteDialog(
        destinationName: destinationName,
        destinationType: destinationType,
        distance: _distanceBetween(origin, destinationPoint),
        natureText: natureText,
        hydrationText: hydrationText,
      );

      if (shouldOpen != true || !mounted) return;

      setState(() => _statusMessage = 'Opening Google Maps...');
      await _openGoogleMaps(origin: origin, routePoints: routePoints);
    } catch (error) {
      if (mounted) {
        _showMessage(
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingRoute = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<bool?> _showRouteDialog({
    required String destinationName,
    required String destinationType,
    required double distance,
    required String natureText,
    required String hydrationText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: _activityColor.withValues(alpha: 0.15),
                child: Icon(_activityIcon, color: _activityColor),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Your route is ready')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogLine(
                Icons.route_rounded,
                '$_activityName · $_durationMinutes min · $_routeType',
              ),
              _dialogLine(
                _isHiking ? Icons.hiking_rounded : Icons.water_rounded,
                '$destinationName\n$destinationType · '
                    '${_formatDistance(distance)} away',
              ),
              _dialogLine(Icons.park_rounded, natureText),
              _dialogLine(Icons.local_drink_rounded, hydrationText),
              if (_isHiking)
                _dialogLine(
                  Icons.terrain_rounded,
                  'This route uses mapped paths, tracks or foot trails.',
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _activityColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Open Route'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _activityColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(message),
        ),
      );
  }

  String _formatDistance(double metres) {
    return metres < 1000
        ? '${metres.round()} m'
        : '${(metres / 1000).toStringAsFixed(1)} km';
  }

  void _selectActivity(RouteActivity activity) {
    HapticFeedback.selectionClick();
    setState(() {
      _activity = activity;

      if (activity == RouteActivity.hike &&
          !_useCustomDuration &&
          _selectedDuration < 45) {
        _selectedDuration = 45;
      }
    });
  }

  Widget _activityCard(
    RouteActivity activity,
    String label,
    String subtitle,
    IconData icon,
    Color colour,
  ) {
    final selected = _activity == activity;

    return Expanded(
      child: GestureDetector(
        onTap: _isCreatingRoute ? null : () => _selectActivity(activity),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? colour : Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: colour, width: selected ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: colour.withValues(alpha: selected ? 0.28 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 31,
                color: selected ? Colors.white : colour,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white70 : Colors.black45,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activitySelector() {
    return Column(
      children: [
        Row(
          children: [
            _activityCard(
              RouteActivity.walk,
              'Walk',
              'Scenic city walk',
              Icons.directions_walk_rounded,
              _cyan,
            ),
            _activityCard(
              RouteActivity.hike,
              'Hike',
              'Paths and forest tracks',
              Icons.hiking_rounded,
              _hikeGreen,
            ),
          ],
        ),
        Row(
          children: [
            _activityCard(
              RouteActivity.run,
              'Run',
              'Fitness route',
              Icons.directions_run_rounded,
              _orange,
            ),
            _activityCard(
              RouteActivity.cycle,
              'Cycle',
              'Explore farther',
              Icons.directions_bike_rounded,
              _purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _durationButton(int minutes) {
    final selected =
        !_useCustomDuration && _selectedDuration == minutes;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? _activityColor : Colors.white,
            foregroundColor: selected ? Colors.white : _navy,
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: BorderSide(color: _activityColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          onPressed: _isCreatingRoute
              ? null
              : () {
                  setState(() {
                    _selectedDuration = minutes;
                    _useCustomDuration = false;
                  });
                },
          child: Text(
            '$minutes min',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _durationArea() {
    if (_isHiking) {
      return Column(
        children: [
          _hikingTimeModeCard(
            mode: HikingTimeMode.allTrails,
            icon: Icons.format_list_numbered_rounded,
            title: 'All available trails',
            subtitle:
                'Show every official hiking route, shortest time first.',
          ),
          const SizedBox(height: 11),
          _hikingTimeModeCard(
            mode: HikingTimeMode.maximumTime,
            icon: Icons.timer_rounded,
            title: 'Choose maximum time',
            subtitle: 'Only show routes that fit within your available time.',
          ),
          if (_hikingTimeMode == HikingTimeMode.maximumTime) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFD7E3EA)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: _hikeGreen),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Maximum total time',
                          style: TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(_maximumHikingMinutes),
                        style: const TextStyle(
                          color: _hikeGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _maximumHikingMinutes.toDouble(),
                    min: 30,
                    max: 300,
                    divisions: 18,
                    activeColor: _hikeGreen,
                    label: _formatTime(_maximumHikingMinutes),
                    onChanged: _isCreatingRoute
                        ? null
                        : (value) {
                            setState(() {
                              _maximumHikingMinutes =
                                  (value / 15).round() * 15;
                              _selectedDuration = _maximumHikingMinutes;
                            });
                          },
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('30 min', style: TextStyle(fontSize: 11)),
                      Text('5 hours', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    final quickDurations = [15, 30, 45];

    return Column(
      children: [
        Row(
          children: quickDurations
              .map((minutes) => _durationButton(minutes))
              .toList(),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _useCustomDuration,
          activeThumbColor: _activityColor,
          activeTrackColor: _activityColor.withValues(alpha: 0.45),
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFD7E3EA)),
          ),
          title: const Text(
            'Custom duration',
            style: TextStyle(fontWeight: FontWeight.bold, color: _navy),
          ),
          subtitle: const Text('Choose between 5 and 300 minutes'),
          onChanged: _isCreatingRoute
              ? null
              : (value) {
                  setState(() {
                    _useCustomDuration = value;
                    if (value) {
                      _selectedDuration =
                          int.tryParse(_customDurationController.text) ?? 60;
                    }
                  });
                },
        ),
        if (_useCustomDuration) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customDurationController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Duration',
              suffixText: 'minutes',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onChanged: (value) {
              final duration = int.tryParse(value);
              if (duration != null) {
                setState(() => _selectedDuration = duration);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _hikingTimeModeCard({
    required HikingTimeMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _hikingTimeMode == mode;

    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: _isCreatingRoute
          ? null
          : () {
              setState(() {
                _hikingTimeMode = mode;
                if (mode == HikingTimeMode.maximumTime) {
                  _selectedDuration = _maximumHikingMinutes;
                }
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? _hikeGreen.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? _hikeGreen : const Color(0xFFD7E3EA),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: _hikeGreen, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: _hikeGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeTypeButton(String value, IconData icon) {
    final selected = _routeType == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: selected
                ? _activityColor.withValues(alpha: 0.12)
                : Colors.white,
            foregroundColor: _activityColor,
            padding: const EdgeInsets.symmetric(vertical: 17),
            side: BorderSide(
              color: selected ? _activityColor : const Color(0xFFD7E3EA),
              width: selected ? 2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          onPressed: () => setState(() => _routeType = value),
          icon: Icon(icon),
          label: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _section(String number, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 11),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: _activityColor,
            child: Text(number, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _waterSelector() {
    const items = [
      'Any water feature',
      'Lake',
      'Pond',
      'Reservoir',
      'Water basin',
      'Other water area',
      'River',
      'Stream',
      'Canal',
      'Drinking-water fountain',
    ];

    return DropdownButtonFormField<String>(
      initialValue: _waterFeaturePreference,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.water_rounded, color: _blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: _isCreatingRoute
          ? null
          : (value) {
              if (value == null) return;
              setState(() {
                _waterFeaturePreference = value;
                if (_selectedFeatureIsFountain) {
                  _drinkingWaterRequired = false;
                }
              });
            },
    );
  }

  Widget _optionSwitch(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 13),
      decoration: BoxDecoration(
        color: value
            ? _activityColor.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD7E3EA)),
      ),
      child: SwitchListTile(
        value: value,
        activeThumbColor: _activityColor,
        activeTrackColor: _activityColor.withValues(alpha: 0.45),
        secondary: Icon(icon, color: _activityColor),
        title: Text(
          title,
          style: const TextStyle(color: _navy, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        onChanged: _isCreatingRoute ? null : onChanged,
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _activityGradient),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                ),
                const Expanded(
                  child: Text(
                    'Plan a Scenic Workout',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 14),
            Icon(_activityIcon, size: 64, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              _isHiking ? 'Find a Real Trail' : 'Move. Explore. Recharge.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isHiking
                  ? 'Hiking searches mapped nature paths, forest tracks '
                      'and foot trails near water and greenery.'
                  : 'Create a personalised $_activityName route through '
                      'water features and green surroundings.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    return Container(
      margin: const EdgeInsets.only(top: 23),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 13,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryValue(_activityIcon, _activityName, 'Activity'),
          _summaryValue(
            Icons.timer_rounded,
            _isHiking && _hikingTimeMode == HikingTimeMode.allTrails
                ? 'All times'
                : _isHiking
                    ? 'Up to ${_formatTime(_maximumHikingMinutes)}'
                    : '$_durationMinutes min',
            _isHiking ? 'Time filter' : 'Duration',
          ),
          _summaryValue(
            Icons.route_rounded,
            _formatDistance(_estimatedTotalDistanceMetres),
            'Estimate',
          ),
        ],
      ),
    );
  }

  Widget _summaryValue(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _activityColor),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.black45, fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFC),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section(
                    '1',
                    'Choose your activity',
                    'Hiking uses mapped trails and is separate from walking.',
                  ),
                  _activitySelector(),
                  _section(
                    '2',
                    _isHiking
                        ? 'Choose how to find hiking routes'
                        : 'Set your activity time',
                    _isHiking
                        ? 'See every route or apply a maximum of up to 5 hours.'
                        : 'Use a quick option or a custom duration.',
                  ),
                  _durationArea(),
                  _section(
                    '3',
                    'Choose the route style',
                    'Return to the start or finish at the destination.',
                  ),
                  Row(
                    children: [
                      _routeTypeButton('Circular', Icons.loop_rounded),
                      _routeTypeButton(
                        'One-way',
                        Icons.trending_flat_rounded,
                      ),
                    ],
                  ),
                  _section(
                    '4',
                    _isHiking
                        ? 'Choose nearby water scenery'
                        : 'Select a water feature',
                    _isHiking
                        ? 'The trail receives preference when it is near '
                            'your selected water feature.'
                        : 'Choose the scenery you would like to visit.',
                  ),
                  _waterSelector(),
                  if (!_selectedFeatureIsFountain)
                    _optionSwitch(
                      Icons.local_drink_rounded,
                      'Include drinking water',
                      'Add a mapped drinking-water point as a route stop.',
                      _drinkingWaterRequired,
                      (value) =>
                          setState(() => _drinkingWaterRequired = value),
                    ),
                  _optionSwitch(
                    Icons.park_rounded,
                    _isHiking
                        ? 'Prioritise forests and natural areas'
                        : 'Prefer green surroundings',
                    _isHiking
                        ? 'Nature paths and forest tracks receive priority.'
                        : 'Water features near greenery receive preference.',
                    _preferGreenAreas,
                    (value) => setState(() => _preferGreenAreas = value),
                  ),
                  _summary(),
                  if (_statusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          CircularProgressIndicator(
                            color: _activityColor,
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: TextStyle(
                                color: _activityColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.only(top: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _activityGradient),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _isCreatingRoute ? null : _createRoute,
                      icon: _isCreatingRoute
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(_activityIcon),
                      label: Text(
                        _isCreatingRoute
                            ? 'Creating your route...'
                            : _activityButtonName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      _isHiking
                          ? 'Hiking searches actual mapped OSM paths and '
                              'tracks. Google Maps receives points along the '
                              'selected trail, but may adjust them according '
                              'to paths available in Google Maps.'
                          : 'The selected time is a preference. AquaRoute '
                              'selects suitable mapped features and Google '
                              'Maps calculates the final navigable route.',
                      style: const TextStyle(
                        color: Color(0xFF78350F),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
