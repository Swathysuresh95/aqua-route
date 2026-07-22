import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/blue_space_service.dart';
import '../services/location_service.dart';
import '../services/water_services.dart';

enum MapLayerOption {
  drinkingWater,
  waterAreas,
  waterways,
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<List<WaterPoint>> _waterPointsFuture;
  late Future<BlueSpaceData> _blueSpaceFuture;

  final MapController _mapController = MapController();

  final LayerHitNotifier<BlueSpaceFeature> _waterAreaHitNotifier =
      ValueNotifier(null);

  final LayerHitNotifier<BlueSpaceFeature> _waterwayHitNotifier =
      ValueNotifier(null);

  Position? _currentPosition;
  WaterPoint? _nearestWaterPoint;
  double? _nearestDistanceMetres;

  bool _showDrinkingWater = true;
  bool _showWaterAreas = false;
  bool _showWaterways = false;
  bool _isLoadingLocation = false;

  String? _locationError;

  @override
  void initState() {
    super.initState();

    _waterPointsFuture =
        WaterService.fetchDrinkingWaterPoints();

    _blueSpaceFuture =
        BlueSpaceService.fetchBlueSpaces();
  }

  @override
  void dispose() {
    _waterAreaHitNotifier.dispose();
    _waterwayHitNotifier.dispose();
    _mapController.dispose();

    super.dispose();
  }

  void _reloadData() {
    setState(() {
      _waterPointsFuture =
          WaterService.fetchDrinkingWaterPoints();

      _blueSpaceFuture =
          BlueSpaceService.fetchBlueSpaces();

      _nearestWaterPoint = null;
      _nearestDistanceMetres = null;
    });
  }

  void _toggleLayer(MapLayerOption option) {
    setState(() {
      switch (option) {
        case MapLayerOption.drinkingWater:
          _showDrinkingWater = !_showDrinkingWater;
          break;

        case MapLayerOption.waterAreas:
          _showWaterAreas = !_showWaterAreas;
          break;

        case MapLayerOption.waterways:
          _showWaterways = !_showWaterways;
          break;
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final position =
          await LocationService.getCurrentPosition();

      final waterPoints =
          await _waterPointsFuture;

      WaterPoint? nearestPoint;
      double? shortestDistance;

      for (final point in waterPoints) {
        final distance =
            Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          point.location.latitude,
          point.location.longitude,
        );

        if (shortestDistance == null ||
            distance < shortestDistance) {
          shortestDistance = distance;
          nearestPoint = point;
        }
      }

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _nearestWaterPoint = nearestPoint;
        _nearestDistanceMetres = shortestDistance;
        _isLoadingLocation = false;
        _showDrinkingWater = true;
      });

      _mapController.move(
        LatLng(
          position.latitude,
          position.longitude,
        ),
        16,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _locationError = error.toString();
        _isLoadingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationError!),
        ),
      );
    }
  }

  void _moveToNearestWaterPoint() {
    final point = _nearestWaterPoint;

    if (point == null) return;

    _mapController.move(
      point.location,
      17,
    );
  }

  Future<void> _navigateToLocation({
    required LatLng destination,
  }) async {
    final latitude = destination.latitude;
    final longitude = destination.longitude;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude'
      '&travelmode=walking',
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open Google Maps.',
          ),
        ),
      );
    }
  }

  Future<void> _navigateToWaterPoint(
    WaterPoint point,
  ) {
    return _navigateToLocation(
      destination: point.location,
    );
  }

  String _formatDistance(
    double distanceMetres,
  ) {
    if (distanceMetres < 1000) {
      return '${distanceMetres.round()} m';
    }

    return '${(distanceMetres / 1000).toStringAsFixed(2)} km';
  }

  double? _distanceTo(
    LatLng destination,
  ) {
    final currentPosition =
        _currentPosition;

    if (currentPosition == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      destination.latitude,
      destination.longitude,
    );
  }

  void _showWaterPointDetails(
    WaterPoint point,
  ) {
    final distance =
        _distanceTo(point.location);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(point.name),
          content: Text(
            'Drinking-water point\n\n'
            '${distance != null ? 'Distance: ${_formatDistance(distance)}\n\n' : ''}'
            'Latitude: ${point.location.latitude.toStringAsFixed(6)}\n'
            'Longitude: ${point.location.longitude.toStringAsFixed(6)}',
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);

                _navigateToWaterPoint(
                  point,
                );
              },
              icon: const Icon(
                Icons.directions_walk,
              ),
              label: const Text(
                'Navigate',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Close',
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBlueSpaceDetails(
    BlueSpaceFeature feature,
  ) {
    final distance =
        _distanceTo(
      feature.navigationPoint,
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      child: Icon(
                        Icons.water,
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            feature.type,
                            style: const TextStyle(
                              color:
                                  Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 16,
                ),
                if (distance != null)
                  Text(
                    'Straight-line distance: '
                    '${_formatDistance(distance)}',
                  ),
                if (distance != null)
                  const SizedBox(
                    height: 8,
                  ),
                Text(
                  'Latitude: '
                  '${feature.navigationPoint.latitude.toStringAsFixed(6)}',
                ),
                Text(
                  'Longitude: '
                  '${feature.navigationPoint.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(
                  height: 20,
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );

                      _navigateToLocation(
                        destination:
                            feature.navigationPoint,
                      );
                    },
                    icon: const Icon(
                      Icons.directions_walk,
                    ),
                    label: const Text(
                      'Navigate with Google Maps',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleMapTap(
    TapPosition tapPosition,
    LatLng tappedPoint,
  ) {
    final waterAreaResult =
        _waterAreaHitNotifier.value;

    if (_showWaterAreas &&
        waterAreaResult != null &&
        waterAreaResult.hitValues.isNotEmpty) {
      _showBlueSpaceDetails(
        waterAreaResult.hitValues.first,
      );
      return;
    }

    final waterwayResult =
        _waterwayHitNotifier.value;

    if (_showWaterways &&
        waterwayResult != null &&
        waterwayResult.hitValues.isNotEmpty) {
      _showBlueSpaceDetails(
        waterwayResult.hitValues.first,
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Water Access Map',
        ),
        actions: [
          PopupMenuButton<MapLayerOption>(
            tooltip: 'Map layers',
            icon: const Icon(
              Icons.layers,
            ),
            onSelected: _toggleLayer,
            itemBuilder: (context) {
              return [
                CheckedPopupMenuItem<
                    MapLayerOption>(
                  value:
                      MapLayerOption.drinkingWater,
                  checked:
                      _showDrinkingWater,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: Color(
                          0xFF0077B6,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Drinking-water points',
                      ),
                    ],
                  ),
                ),
                CheckedPopupMenuItem<
                    MapLayerOption>(
                  value:
                      MapLayerOption.waterAreas,
                  checked:
                      _showWaterAreas,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.water,
                        color: Color(
                          0xFF00A8E8,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Water areas',
                      ),
                    ],
                  ),
                ),
                CheckedPopupMenuItem<
                    MapLayerOption>(
                  value:
                      MapLayerOption.waterways,
                  checked:
                      _showWaterways,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.waves,
                        color: Color(
                          0xFF0096C7,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Rivers and waterways',
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
          IconButton(
            onPressed: _reloadData,
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip:
                'Reload map data',
          ),
        ],
      ),
      body:
          FutureBuilder<List<WaterPoint>>(
        future: _waterPointsFuture,
        builder: (
          context,
          waterSnapshot,
        ) {
          if (waterSnapshot
                  .connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(
                    height: 14,
                  ),
                  Text(
                    'Loading drinking-water locations...',
                  ),
                ],
              ),
            );
          }

          if (waterSnapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  24,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 55,
                      color: Colors.red,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'Could not load water locations.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      '${waterSnapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    ElevatedButton.icon(
                      onPressed: _reloadData,
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label: const Text(
                        'Try again',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final waterPoints =
              waterSnapshot.data ?? [];

          return FutureBuilder<
              BlueSpaceData>(
            future: _blueSpaceFuture,
            builder: (
              context,
              blueSnapshot,
            ) {
              final blueSpaceData =
                  blueSnapshot.data;

              return Stack(
                children: [
                  FlutterMap(
                    mapController:
                        _mapController,
                    options: MapOptions(
                      initialCenter:
                          const LatLng(
                        49.0069,
                        8.4037,
                      ),
                      initialZoom: 13,
                      onTap: _handleMapTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.example.aqua_route',
                      ),

                      if (_showWaterAreas &&
                          blueSpaceData !=
                              null)
                        PolygonLayer<
                            BlueSpaceFeature>(
                          hitNotifier:
                              _waterAreaHitNotifier,
                          polygons:
                              blueSpaceData
                                  .waterPolygons,
                        ),

                      if (_showWaterways &&
                          blueSpaceData !=
                              null)
                        PolylineLayer<
                            BlueSpaceFeature>(
                          hitNotifier:
                              _waterwayHitNotifier,
                          minimumHitbox: 20,
                          polylines:
                              blueSpaceData
                                  .waterways,
                        ),

                      if (_showDrinkingWater)
                        MarkerLayer(
                          markers: [
                            ...waterPoints.map(
                              (point) {
                                final isNearest =
                                    point ==
                                        _nearestWaterPoint;

                                return Marker(
                                  point:
                                      point.location,
                                  width:
                                      isNearest
                                          ? 52
                                          : 42,
                                  height:
                                      isNearest
                                          ? 52
                                          : 42,
                                  child:
                                      GestureDetector(
                                    onTap: () {
                                      _showWaterPointDetails(
                                        point,
                                      );
                                    },
                                    child: Icon(
                                      Icons
                                          .water_drop,
                                      size:
                                          isNearest
                                              ? 46
                                              : 36,
                                      color: isNearest
                                          ? Colors
                                              .orange
                                          : const Color(
                                              0xFF0077B6,
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                      if (_currentPosition !=
                          null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                _currentPosition!
                                    .latitude,
                                _currentPosition!
                                    .longitude,
                              ),
                              width: 48,
                              height: 48,
                              child: Container(
                                decoration:
                                    BoxDecoration(
                                  color:
                                      Colors.blue
                                          .withValues(
                                    alpha: 0.25,
                                  ),
                                  shape:
                                      BoxShape
                                          .circle,
                                ),
                                child:
                                    const Center(
                                  child: Icon(
                                    Icons
                                        .my_location,
                                    color:
                                        Colors.blue,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                          ),
                        ],
                      ),
                    ],
                  ),

                  Positioned(
                    top: 12,
                    left: 12,
                    child: Card(
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            if (_showDrinkingWater)
                              Text(
                                '${waterPoints.length} drinking-water locations',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            if (_showWaterAreas &&
                                blueSpaceData !=
                                    null)
                              Text(
                                '${blueSpaceData.waterPolygons.length} water areas',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            if (_showWaterways &&
                                blueSpaceData !=
                                    null)
                              Text(
                                '${blueSpaceData.waterways.length} waterways',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            if (!_showDrinkingWater &&
                                !_showWaterAreas &&
                                !_showWaterways)
                              const Text(
                                'No thematic layers selected',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if ((_showWaterAreas ||
                          _showWaterways) &&
                      blueSnapshot
                              .connectionState ==
                          ConnectionState
                              .waiting)
                    const Positioned(
                      top: 85,
                      left: 12,
                      child: Card(
                        child: Padding(
                          padding:
                              EdgeInsets
                                  .symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              ),
                              SizedBox(
                                width: 8,
                              ),
                              Text(
                                'Loading blue spaces...',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if ((_showWaterAreas ||
                          _showWaterways) &&
                      blueSnapshot.hasError)
                    const Positioned(
                      top: 85,
                      left: 12,
                      child: Card(
                        child: Padding(
                          padding:
                              EdgeInsets.all(
                            10,
                          ),
                          child: Text(
                            'Could not load blue spaces',
                          ),
                        ),
                      ),
                    ),

                  if (_nearestWaterPoint !=
                          null &&
                      _nearestDistanceMetres !=
                          null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 92,
                      child: Card(
                        elevation: 5,
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .all(14),
                          child: Row(
                            children: [
                              const Icon(
                                Icons
                                    .water_drop,
                                size: 34,
                                color:
                                    Colors.orange,
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    const Text(
                                      'Nearest drinking-water point',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            13,
                                        color:
                                            Colors
                                                .black54,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 3,
                                    ),
                                    Text(
                                      _nearestWaterPoint!
                                          .name,
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                        fontSize:
                                            16,
                                      ),
                                    ),
                                    Text(
                                      _formatDistance(
                                        _nearestDistanceMetres!,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize:
                                    MainAxisSize
                                        .min,
                                children: [
                                  IconButton(
                                    onPressed:
                                        _moveToNearestWaterPoint,
                                    icon:
                                        const Icon(
                                      Icons
                                          .center_focus_strong,
                                    ),
                                    tooltip:
                                        'Show nearest fountain',
                                  ),
                                  IconButton(
                                    onPressed:
                                        () {
                                      _navigateToWaterPoint(
                                        _nearestWaterPoint!,
                                      );
                                    },
                                    icon:
                                        const Icon(
                                      Icons
                                          .directions_walk,
                                      color:
                                          Color(
                                        0xFF0077B6,
                                      ),
                                    ),
                                    tooltip:
                                        'Walking directions',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    right: 16,
                    bottom: 30,
                    child:
                        FloatingActionButton(
                      onPressed:
                          _isLoadingLocation
                              ? null
                              : _getCurrentLocation,
                      tooltip:
                          'Find nearest water point',
                      child:
                          _isLoadingLocation
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .my_location,
                                ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}