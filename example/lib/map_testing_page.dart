import 'package:example/app_map.dart';
import 'package:flutter/material.dart';
import 'package:map_manager_mapbox/manager/map_manager.dart';
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapTestingPage extends StatefulWidget {
  const MapTestingPage({super.key});

  @override
  State<MapTestingPage> createState() => _MapTestingPageState();
}

class _MapTestingPageState extends State<MapTestingPage> {
  MapManager? _mapManager;
  MapMode _currentMode = MapMode.basic();

  void _onMapCreated(manager) {
    _mapManager = manager;
  }

  void _changeMode(MapMode mode) async {
    if (_mapManager != null) {
      await _mapManager!.changeMode(mode);
    }
  }

  final _mapModesMap = <Map<String, dynamic>>[
    {'name': 'Basic Mode', 'config': BasicMapMode(trackUserLoc: true)},
    {
      'name': "Location Selection",
      'config': LocationSelectionMode(maxSelections: 4)
    },
    {
      'name': "Route Mode",
      'config': RouteMode(
        geojson: {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": [
              [-122.420679, 37.772537],
              [-122.420247, 37.773245],
              [-122.419198, 37.773662],
              [-122.418640, 37.774097],
              [-122.417961, 37.774357],
              [-122.417297, 37.774674],
              [-122.416289, 37.775180],
              [-122.415389, 37.775596],
              [-122.414331, 37.776005],
              [-122.413467, 37.776335]
            ]
          },
          "properties": {}
        },
      )
    },
    {
      'name': "Tracking Mode (LineString)",
      'config': TrackingMode(
          route: LineString(coordinates: [
            Position(-122.420679, 37.772537),
            Position(-122.420247, 37.773245),
            Position(-122.419198, 37.773662),
            Position(-122.418640, 37.774097),
            Position(-122.417961, 37.774357),
            Position(-122.417297, 37.774674),
            Position(-122.416289, 37.775180),
            Position(-122.415389, 37.775596),
          ]),
          waypoints: [
            Point(coordinates: Position(-122.420679, 37.772537)),
            Point(coordinates: Position(-122.415389, 37.775596)),
          ])
    },
    {
      'name': "Tracking Mode (GeoJSON)",
      'config': TrackingMode(geojson: {
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": [
            [-122.425, 37.775],
            [-122.424, 37.776],
            [-122.423, 37.777],
            [-122.422, 37.778],
            [-122.421, 37.779],
            [-122.420, 37.780],
          ]
        },
        "properties": {
          "name": "Test Tracking Route",
          "description": "Example GeoJSON route for tracking"
        }
      }, waypoints: [
        Point(coordinates: Position(-122.425, 37.775)),
        Point(coordinates: Position(-122.420, 37.780)),
      ])
    }
  ];
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppMap(
          initialMode: _mapModesMap.first['config'],
          onMapCreated: _onMapCreated,
        ),
        Positioned.fill(
          top: MediaQuery.viewPaddingOf(context).top + 20,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                    spacing: 12,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Map Manager Testing Suite',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _mapModesMap.map((preset) {
                          final isSelected = preset['config'] == _currentMode;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentMode = preset['config'];
                              });
                              _changeMode(_currentMode);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected ? Colors.blue : Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                preset['name'],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    ])),
          ),
        )
      ],
    );
  }
}
