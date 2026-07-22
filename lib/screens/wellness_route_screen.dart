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

class _WellnessRouteScreenState extends State<WellnessRouteScreen> {
  int _selectedDuration = 30;
  String _routeType = 'Circular';
  bool _drinkingWaterRequired = true;
  bool _preferGreenAreas = true;
  String _blueSpacePreference = 'Water Area';

  bool _isCreatingRoute = false;
  String? _statusMessage;

  double get _maximumRouteDistanceMetres {
    switch (_selectedDuration) {
      case 15:
        return 1250;
      case 30:
        return 2500;
      case 45:
        return 3750;
      default:
        return 2500;
    }
  }

  double get _preferredDestinationDistanceMetres {
    if (_routeType == 'Circular') {
      switch (_selectedDuration) {
        case 15:
          return 350;
        case 30:
          return 700;
        case 45:
          return 1100;
        default:
          return 700;
      }
    }

    switch (_selectedDuration) {
      case 15:
        return 750;
      case 30:
        return 1500;
      case 45:
        return 2300;
      default:
        return 1500;
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

  WaterPoint? _findBestWaterPoint({
    required LatLng currentLocation,
    required List<WaterPoint> waterPoints,
    required BlueSpaceFeature selectedBlueSpace,
  }) {
    if (waterPoints.isEmpty) {
      return null;
    }

    WaterPoint? bestPoint;
    double? bestScore;

    for (final point in waterPoints) {
      final distanceFromUser = _distanceBetween(
        currentLocation,
        point.location,
      );

      final distanceFromBlueSpace = _distanceBetween(
        selectedBlueSpace.navigationPoint,
        point.location,
      );

      if (distanceFromUser >
          _maximumRouteDistanceMetres * 1.1) {
        continue;
      }

      double score;

      if (_routeType == 'Circular') {
        score =
            (distanceFromUser * 0.4) +
            (distanceFromBlueSpace * 0.6);
      } else {
        score =
            (distanceFromUser * 0.45) +
            (distanceFromBlueSpace * 0.55);
      }

      if (bestScore == null || score < bestScore) {
        bestScore = score;
        bestPoint = point;
      }
    }

    return bestPoint;
  }

  double _nearestGreenSpaceDistance({
    required BlueSpaceFeature blueSpace,
    required List<GreenSpaceFeature> greenSpaces,
  }) {
    if (greenSpaces.isEmpty) {
      return double.infinity;
    }

    double nearestDistance = double.infinity;

    for (final greenSpace in greenSpaces) {
      final distance = _distanceBetween(
        blueSpace.navigationPoint,
        greenSpace.navigationPoint,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
      }
    }

    return nearestDistance;
  }

  GreenSpaceFeature? _findNearestGreenSpace({
    required BlueSpaceFeature blueSpace,
    required List<GreenSpaceFeature> greenSpaces,
  }) {
    if (greenSpaces.isEmpty) {
      return null;
    }

    GreenSpaceFeature? nearestGreenSpace;
    double? shortestDistance;

    for (final greenSpace in greenSpaces) {
      final distance = _distanceBetween(
        blueSpace.navigationPoint,
        greenSpace.navigationPoint,
      );

      if (shortestDistance == null ||
          distance < shortestDistance) {
        shortestDistance = distance;
        nearestGreenSpace = greenSpace;
      }
    }

    return nearestGreenSpace;
  }

  BlueSpaceFeature? _findBestBlueSpace({
    required LatLng currentLocation,
    required BlueSpaceData blueSpaceData,
    required List<GreenSpaceFeature> greenSpaces,
  }) {
    final candidates = <BlueSpaceFeature>[];

    if (_blueSpacePreference == 'Water Area' ||
        _blueSpacePreference == 'Any blue space') {
      for (final polygon in blueSpaceData.waterPolygons) {
        final feature = polygon.hitValue;

        if (feature != null) {
          candidates.add(feature);
        }
      }
    }

    if (_blueSpacePreference == 'River / Canal' ||
        _blueSpacePreference == 'Any blue space') {
      for (final polyline in blueSpaceData.waterways) {
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
    double? bestScore;

    for (final feature in candidates) {
      final distanceFromUser = _distanceBetween(
        currentLocation,
        feature.navigationPoint,
      );

      if (distanceFromUser >
          _maximumRouteDistanceMetres * 1.2) {
        continue;
      }

      double score =
          (distanceFromUser -
                  _preferredDestinationDistanceMetres)
              .abs();

      if (_preferGreenAreas && greenSpaces.isNotEmpty) {
        final greenDistance =
            _nearestGreenSpaceDistance(
          blueSpace: feature,
          greenSpaces: greenSpaces,
        );

        score += greenDistance * 0.25;
      }

      if (bestScore == null || score < bestScore) {
        bestScore = score;
        bestFeature = feature;
      }
    }

    if (bestFeature != null) {
      return bestFeature;
    }

    for (final feature in candidates) {
      final distanceFromUser = _distanceBetween(
        currentLocation,
        feature.navigationPoint,
      );

      final score =
          (distanceFromUser -
                  _preferredDestinationDistanceMetres)
              .abs();

      if (bestScore == null || score < bestScore) {
        bestScore = score;
        bestFeature = feature;
      }
    }

    return bestFeature;
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
        return distanceToBlueSpace <= 200 &&
            distanceFromUser <= 700;

      case 30:
        return distanceToBlueSpace <= 450 &&
            distanceFromUser <= 1500;

      case 45:
        return distanceToBlueSpace <= 700 &&
            distanceFromUser <= 2500;

      default:
        return false;
    }
  }

  Future<void> _openGoogleMapsRoute({
    required LatLng origin,
    required BlueSpaceFeature blueSpace,
    WaterPoint? waterPoint,
  }) async {
    final originText =
        '${origin.latitude},${origin.longitude}';

    final blueSpaceText =
        '${blueSpace.navigationPoint.latitude},'
        '${blueSpace.navigationPoint.longitude}';

    final queryParameters = <String, String>{
      'api': '1',
      'origin': originText,
      'travelmode': 'walking',
    };

    if (_routeType == 'Circular') {
      queryParameters['destination'] = originText;

      final waypoints = <String>[];

      if (waterPoint != null) {
        waypoints.add(
          '${waterPoint.location.latitude},'
          '${waterPoint.location.longitude}',
        );
      }

      waypoints.add(blueSpaceText);

      queryParameters['waypoints'] =
          waypoints.join('|');
    } else {
      queryParameters['destination'] = blueSpaceText;

      if (waterPoint != null) {
        queryParameters['waypoints'] =
            '${waterPoint.location.latitude},'
            '${waterPoint.location.longitude}';
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

    if (!opened && mounted) {
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
            'Loading water and green-space data...';
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
            'Selecting a suitable wellness route...';
      });

      final selectedBlueSpace =
          _findBestBlueSpace(
        currentLocation: currentLocation,
        blueSpaceData: blueSpaceData,
        greenSpaces: greenSpaces,
      );

      if (selectedBlueSpace == null) {
        throw Exception(
          'No suitable blue-space feature was found.',
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
            'No suitable drinking-water point was found near this route.',
          );
        }

        selectedWaterPoint = candidateWaterPoint;
      } else if (candidateWaterPoint != null) {
        final shouldInclude =
            _shouldIncludeOptionalWaterPoint(
          waterPoint: candidateWaterPoint,
          blueSpace: selectedBlueSpace,
          currentLocation: currentLocation,
        );

        if (shouldInclude) {
          selectedWaterPoint = candidateWaterPoint;
        }
      }

      GreenSpaceFeature? nearbyGreenSpace;

      if (_preferGreenAreas && greenSpaces.isNotEmpty) {
        nearbyGreenSpace =
            _findNearestGreenSpace(
          blueSpace: selectedBlueSpace,
          greenSpaces: greenSpaces,
        );
      }

      if (!mounted) return;

      final blueSpaceDistance =
          _distanceBetween(
        currentLocation,
        selectedBlueSpace.navigationPoint,
      );

      final waterDescription =
          selectedWaterPoint == null
              ? 'No drinking-water stop included'
              : 'Drinking-water stop: '
                  '${selectedWaterPoint.name}';

      final greenDescription =
          nearbyGreenSpace == null
              ? 'No nearby mapped green space found'
              : 'Nearby greenery: '
                  '${nearbyGreenSpace.name} '
                  '(${nearbyGreenSpace.type})';

      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Wellness route ready',
            ),
            content: Text(
              'Preferred duration: '
              '$_selectedDuration minutes\n'
              'Route type: $_routeType\n\n'
              'Blue-space destination:\n'
              '${selectedBlueSpace.name}\n'
              '${selectedBlueSpace.type}\n'
              'Straight-line distance: '
              '${_formatDistance(blueSpaceDistance)}\n\n'
              '$waterDescription\n\n'
              '$greenDescription\n\n'
              'Greenery is used to select the blue-space '
              'destination and is not added as a separate '
              'route stop.\n\n'
              'Google Maps calculates the actual walking '
              'route and travel time. The result may differ '
              'from the preferred duration.',
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
            'Opening the walking route...';
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
                'Choose your preferences. AquaRoute '
                'selects a suitable blue-space destination '
                'and includes drinking water when requested.',
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
                      'River / Canal',
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
                  'This helps choose the destination. '
                  'A park is not added as a separate route stop.',
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
                          'AquaRoute uses straight-line distances '
                          'to select nearby locations. Google Maps '
                          'calculates the actual walking route and time.',
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