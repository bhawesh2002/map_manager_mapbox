import 'package:geojson_vi/geojson_vi.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

extension GeoJSONLineStringExtensions on GeoJSONLineString {
  /// Returns the coordinates as a list of GeoJSONPoint objects
  List<GeoJSONPoint> get points {
    return coordinates.map((coord) => GeoJSONPoint(coord)).toList();
  }

  /// Creates a GeoJSONLineString from a list of GeoJSONPoint objects
  static GeoJSONLineString fromPoints(List<GeoJSONPoint> points) {
    if (points.isEmpty) {
      throw ArgumentError(
          'Cannot create GeoJSONLineString from empty list of points');
    }
    return GeoJSONLineString(points.map((point) => point.coordinates).toList());
  }
}

extension GeoJSONPointListExtensions on List<GeoJSONPoint> {
  /// Converts a list of GeoJSONPoint to GeoJSONLineString
  /// Returns null if the list is empty to avoid creating invalid GeoJSONLineString
  GeoJSONLineString? toLineString() {
    if (isEmpty) return null;
    return GeoJSONLineString(map((point) => point.coordinates).toList());
  }

  /// Converts a list of GeoJSONPoint to GeoJSONLineString
  /// Throws an exception if the list is empty
  GeoJSONLineString toLineStringOrThrow() {
    if (isEmpty) {
      throw ArgumentError(
          'Cannot create GeoJSONLineString from empty list of points');
    }
    return GeoJSONLineString(map((point) => point.coordinates).toList());
  }
}

extension GeolocatorPosition on geolocator.Position {
  GeoJSONPoint get geojsonPoint => GeoJSONPoint([longitude, latitude]);
}

extension MapboxPoint on geolocator.Position {
  Point get mapboxPoint => Point(coordinates: Position(longitude, latitude));
}
