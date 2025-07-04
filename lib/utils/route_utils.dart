import 'dart:math' as math;
import 'package:geojson_vi/geojson_vi.dart';
import 'geojson_extensions.dart';

/// Represents the result of a route update operation (shrink or grow).
///
/// Contains information about what changed in the route, specifically which segment
/// was modified, to support animated route transitions.
class RouteUpdateResult {
  /// The updated route after shrinking or growing
  final GeoJSONLineString updatedRoute;

  /// Whether the route has changed significantly
  final bool hasChanged;

  /// The index of the segment that changed (-1 if no change)
  final int changedSegmentIndex;

  /// The segment before the change (typically 2 points defining a line)
  final List<GeoJSONPoint> originalSegment;

  /// The segment after the change
  final List<GeoJSONPoint> newSegment;

  /// Whether the route is growing (true) or shrinking (false)
  final bool isGrowing;

  /// True when the route is nearly complete (close to destination)
  final bool isNearlyComplete;

  RouteUpdateResult({
    required this.updatedRoute,
    required this.hasChanged,
    required this.changedSegmentIndex,
    required this.originalSegment,
    required this.newSegment,
    required this.isGrowing,
    this.isNearlyComplete = false,
  });
}

/// Represents the result of projecting a point onto a route segment.
class ProjectionResult {
  /// The projected point on the segment
  final GeoJSONPoint projectedPoint;

  /// Whether the projected point falls on the segment (t between 0 and 1)
  final bool onSegment;

  /// The ratio along the segment (0 = start, 1 = end)
  final double ratio;

  ProjectionResult({
    required this.projectedPoint,
    required this.onSegment,
    required this.ratio,
  });
}

/// Represents the result of checking if a user's location is on a route.
class RouteCheckResult {
  /// Whether the user is on the route (within threshold distance)
  final bool isOnRoute;

  /// The distance from the user to the nearest point on the route (in meters)
  final double distance;

  /// The projected point on the route
  final GeoJSONPoint projectedPoint;

  /// The index of the segment in the route where the projection was found
  final int segmentIndex;

  /// The ratio along the segment (0 = start, 1 = end)
  final double projectionRatio;

  RouteCheckResult({
    required this.isOnRoute,
    required this.distance,
    required this.projectedPoint,
    required this.segmentIndex,
    this.projectionRatio = 0.0,
  });
}

class RouteCalculationData {
  // Required fields
  final bool routeChanged;
  final bool isOnRoute;
  final double distanceFromRoute;

  // Fields for when route has changed
  final int? changedSegmentIndex;
  final List<GeoJSONPoint>? originalSegment;
  final List<GeoJSONPoint>? newSegment;
  final bool isGrowing;
  final bool isNearlyComplete;
  final GeoJSONLineString? updatedRoute;

  // Private constructor for field initialization
  const RouteCalculationData._({
    required this.routeChanged,
    required this.isOnRoute,
    required this.distanceFromRoute,
    this.changedSegmentIndex,
    this.originalSegment,
    this.newSegment,
    this.isGrowing = false,
    this.isNearlyComplete = false,
    this.updatedRoute,
  });

  // Named constructor for route changes
  factory RouteCalculationData.routeChanged({
    required bool isOnRoute,
    required double distanceFromRoute,
    required int changedSegmentIndex,
    required List<GeoJSONPoint> originalSegment,
    required List<GeoJSONPoint> newSegment,
    required bool isGrowing,
    required bool isNearlyComplete,
    required GeoJSONLineString updatedRoute,
  }) {
    return RouteCalculationData._(
      routeChanged: true,
      isOnRoute: isOnRoute,
      distanceFromRoute: distanceFromRoute,
      changedSegmentIndex: changedSegmentIndex,
      originalSegment: originalSegment,
      newSegment: newSegment,
      isGrowing: isGrowing,
      isNearlyComplete: isNearlyComplete,
      updatedRoute: updatedRoute,
    );
  }

  // Named constructor for when the route hasn't changed
  factory RouteCalculationData.unchanged({
    required bool isOnRoute,
    required double distanceFromRoute,
  }) {
    return RouteCalculationData._(
      routeChanged: false,
      isOnRoute: isOnRoute,
      distanceFromRoute: distanceFromRoute,
    );
  }

  // Named constructor for errors or invalid states
  factory RouteCalculationData.error() {
    return const RouteCalculationData._(
      routeChanged: false,
      isOnRoute: false,
      distanceFromRoute: double.infinity,
    );
  }
}

/// Converts a GeoJSONLineString to a List of GeoJSONPoints.
///
/// Useful for converting a GeoJSON LineString to a list of points for projection.
///
/// Parameters:
/// - [lineString]: The GeoJSONLineString to convert
///
/// Returns a list of GeoJSONPoint objects.
List<GeoJSONPoint> lineStringToPoints(GeoJSONLineString lineString) {
  List<GeoJSONPoint> points = [];
  for (var coord in lineString.coordinates) {
    // Create GeoJSONPoint objects from LineString coordinates
    points.add(GeoJSONPoint(coord));
  }
  return points;
}

/// Converts a List of GeoJSONPoints to a GeoJSONLineString.
///
/// Useful for converting a modified list of points back to a GeoJSON LineString.
///
/// Parameters:
/// - [points]: The list of points to convert
///
/// Returns a GeoJSONLineString object.
GeoJSONLineString pointsToLineString(List<GeoJSONPoint> points) {
  List<List<double>> coordinates = [];
  for (GeoJSONPoint point in points) {
    coordinates.add(point.coordinates);
  }
  return GeoJSONLineString(coordinates);
}

/// Projects a point onto a line segment defined by two points.
///
/// Uses vector math to calculate the projection.
///
/// Parameters:
/// - [point]: The point to project
/// - [segmentStart]: The start point of the line segment
/// - [segmentEnd]: The end point of the line segment
///
/// Returns a [ProjectionResult] containing the projected point and metadata.
ProjectionResult projectPointOnSegment(
    GeoJSONPoint point, GeoJSONPoint segmentStart, GeoJSONPoint segmentEnd) {
  // Create segment vector
  double segmentX = segmentEnd.coordinates[0] - segmentStart.coordinates[0];
  double segmentY = segmentEnd.coordinates[1] - segmentStart.coordinates[1];

  // Create vector from segment start to point
  double pointX = point.coordinates[0] - segmentStart.coordinates[0];
  double pointY = point.coordinates[1] - segmentStart.coordinates[1];

  // Calculate dot product
  double dotProduct = pointX * segmentX + pointY * segmentY;

  // Calculate segment length squared
  double segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;

  // If segment is too short, return the start point
  if (segmentLengthSquared < 1e-10) {
    return ProjectionResult(
        projectedPoint: segmentStart, onSegment: true, ratio: 0.0);
  }

  // Calculate projection ratio (t)
  double t = dotProduct / segmentLengthSquared;

  // Constrain t to segment bounds [0,1]
  double clampedT = (t < 0) ? 0 : ((t > 1) ? 1 : t);

  // Determine if projection falls on segment
  bool onSegment = (t >= 0 && t <= 1);

  // Calculate projected point
  GeoJSONPoint projectedPoint = GeoJSONPoint([
    segmentStart.coordinates[0] + clampedT * segmentX,
    segmentStart.coordinates[1] + clampedT * segmentY
  ]);

  return ProjectionResult(
      projectedPoint: projectedPoint, onSegment: onSegment, ratio: clampedT);
}

/// Calculates the distance between two points using the Haversine formula.
///
/// This accounts for the Earth's curvature to give accurate distances in meters.
///
/// Parameters:
/// - [point1]: First point
/// - [point2]: Second point
///
/// Returns the distance in meters.
double haversineDistance(GeoJSONPoint point1, GeoJSONPoint point2) {
  const double kEarthRadius = 6371000; // meters

  // Convert degrees to radians
  double lat1Rad = point1.coordinates[1] * (math.pi / 180);
  double lng1Rad = point1.coordinates[0] * (math.pi / 180);
  double lat2Rad = point2.coordinates[1] * (math.pi / 180);
  double lng2Rad = point2.coordinates[0] * (math.pi / 180);

  // Haversine formula
  double dLat = lat2Rad - lat1Rad;
  double dLng = lng2Rad - lng1Rad;

  double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1Rad) *
          math.cos(lat2Rad) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return kEarthRadius * c;
}

/// Checks if a user's location is on a route within a threshold distance.
///
/// Parameters:
/// - [userLocation]: The user's current location
/// - [route]: GeoJSONLineString defining the route
/// - [thresholdMeters]: Distance threshold in meters (default: 15.0)
///
/// Returns a [RouteCheckResult] with the outcome and detailed information.
RouteCheckResult isUserOnRoute(
    GeoJSONPoint userLocation, GeoJSONLineString route,
    {double thresholdMeters = 15.0}) {
  // Convert route to points for processing
  List<GeoJSONPoint> routePoints = route.points;

  // Handle edge cases
  if (routePoints.length < 2) {
    return RouteCheckResult(
        isOnRoute: false,
        distance: double.infinity,
        projectedPoint: userLocation,
        segmentIndex: -1);
  }

  // Check each segment
  for (int i = 0; i < routePoints.length - 1; i++) {
    // Get projection of user location onto this segment
    ProjectionResult projection =
        projectPointOnSegment(userLocation, routePoints[i], routePoints[i + 1]);

    // Calculate distance using Haversine formula
    double distance =
        haversineDistance(userLocation, projection.projectedPoint);

    // Early return if user is on route
    if (distance <= thresholdMeters) {
      return RouteCheckResult(
          isOnRoute: true,
          projectedPoint: projection.projectedPoint,
          segmentIndex: i,
          distance: distance,
          projectionRatio: projection.ratio);
    }
  }

  // If we get here, user is not on any segment within threshold
  // Find nearest point for reference (useful for growing the route later)
  double minDistance = double.infinity;
  GeoJSONPoint closestPoint = userLocation;
  int closestSegmentIndex = -1;
  double closestRatio = 0.0;

  for (int i = 0; i < routePoints.length - 1; i++) {
    ProjectionResult projection =
        projectPointOnSegment(userLocation, routePoints[i], routePoints[i + 1]);

    double distance =
        haversineDistance(userLocation, projection.projectedPoint);

    if (distance < minDistance) {
      minDistance = distance;
      closestPoint = projection.projectedPoint;
      closestSegmentIndex = i;
      closestRatio = projection.ratio;
    }
  }

  return RouteCheckResult(
      isOnRoute: false,
      projectedPoint: closestPoint,
      segmentIndex: closestSegmentIndex,
      distance: minDistance,
      projectionRatio: closestRatio);
}

List<GeoJSONPoint> trimRouteFromProjection(
  GeoJSONLineString route,
  RouteCheckResult result,
) {
  final all = route.points;
  final i = result.segmentIndex;
  final p = result.projectedPoint;

  if (i < 0 || i >= all.length - 1) return [p];

  // Keep only the projected point and points ahead
  return [p, ...all.sublist(i + 1)];
}

/// Modifies a route by shrinking it based on the user's projected position.
///
/// Creates a new route starting from the projected point and including all
/// subsequent points in the original route. Takes into account the projection
/// ratio to handle the current segment properly.
///
/// Parameters:
/// - [projectedPoint]: The user's projected point on the route
/// - [segmentIndex]: The index of the segment where the projection was found
/// - [projectionRatio]: How far along the segment the projection is (0.0 to 1.0)
/// - [route]: The original route as a GeoJSONLineString
///
/// Returns a [RouteUpdateResult] containing the updated route and information about
/// which segment changed, to support animated transitions.
RouteUpdateResult shrinkRoute(GeoJSONPoint projectedPoint, int segmentIndex,
    double projectionRatio, GeoJSONLineString route) {
  if (route.coordinates.length < 2 ||
      segmentIndex < 0 ||
      segmentIndex >= route.coordinates.length - 1) {
    return RouteUpdateResult(
      updatedRoute: route,
      hasChanged: false,
      changedSegmentIndex: -1,
      originalSegment: [],
      newSegment: [],
      isGrowing: false,
    );
  }

  // Convert route to points list for easier manipulation
  List<GeoJSONPoint> routePoints = route.points;

  // Use List<GeoJSONPoint> for internal route construction
  List<GeoJSONPoint> newRoutePoints = [];
  bool hasChanged = true;
  List<GeoJSONPoint> originalSegment = [];
  List<GeoJSONPoint> newSegment = [];
  bool isNearlyComplete = false;

  // Handle the first segment specially
  if (segmentIndex == 0) {
    // If we're at the very start of the first segment, return the whole route
    if (projectionRatio <= 0.01) {
      return RouteUpdateResult(
        updatedRoute: route,
        hasChanged: false,
        changedSegmentIndex: -1,
        originalSegment: [],
        newSegment: [],
        isGrowing: false,
      );
    }

    originalSegment = [routePoints[0], routePoints[1]];
  }

  // Case 1: Projection at start of segment (within small threshold)
  if (projectionRatio <= 0.01 && segmentIndex > 0) {
    // Include the start point of the segment
    newRoutePoints.add(routePoints[segmentIndex]);
    newRoutePoints.addAll(routePoints.sublist(segmentIndex + 1));

    // Capture the original and new segments
    originalSegment = [
      routePoints[segmentIndex - 1],
      routePoints[segmentIndex]
    ];
    newSegment = [routePoints[segmentIndex], routePoints[segmentIndex + 1]];
  }
  // Case 2: Projection at end of segment (within small threshold)
  else if (projectionRatio >= 0.99) {
    // Skip this segment entirely, start from the next point

    // Handle the last segment specially
    if (segmentIndex == routePoints.length - 2) {
      // If we're at the end of the last segment, return the destination point
      // duplicated to ensure at least 2 points for a valid LineString
      newRoutePoints.add(routePoints.last);
      newRoutePoints.add(routePoints.last); // Duplicate the last point

      // Mark as nearly complete
      isNearlyComplete = true;

      // Capture original and new segments
      originalSegment = [routePoints[segmentIndex], routePoints.last];
      newSegment = [routePoints.last, routePoints.last];
    } else {
      // Normal case - start from the end point of the current segment
      newRoutePoints.addAll(routePoints.sublist(segmentIndex + 1));

      // Capture original and new segments
      originalSegment = [
        routePoints[segmentIndex],
        routePoints[segmentIndex + 1]
      ];
      newSegment = [
        routePoints[segmentIndex + 1],
        routePoints[segmentIndex + 2]
      ];
    }
  }
  // Case 3: Projection in middle of segment
  else {
    // Create new segment from projected point to end of current segment
    newRoutePoints.add(projectedPoint);
    newRoutePoints.addAll(routePoints.sublist(segmentIndex + 1));

    // Capture original and new segments
    originalSegment = [
      routePoints[segmentIndex],
      routePoints[segmentIndex + 1]
    ];
    newSegment = [projectedPoint, routePoints[segmentIndex + 1]];
  }

  // Ensure we always have at least 2 points for a valid GeoJSON LineString
  if (newRoutePoints.length < 2 && newRoutePoints.isNotEmpty) {
    // If we have only one point, duplicate it to create a valid LineString
    newRoutePoints.add(newRoutePoints.first);
    isNearlyComplete = true;
  } else if (newRoutePoints.isEmpty && routePoints.isNotEmpty) {
    // If somehow we ended up with an empty route, use the last point of the original route
    newRoutePoints.add(routePoints.last);
    newRoutePoints.add(routePoints.last); // Duplicate it to ensure 2 points
    isNearlyComplete = true;
  }

  // Check if duplicate endpoints (a sign we're nearly complete)
  if (newRoutePoints.length == 2 &&
      newRoutePoints[0].coordinates[0] == newRoutePoints[1].coordinates[0] &&
      newRoutePoints[0].coordinates[1] == newRoutePoints[1].coordinates[1]) {
    isNearlyComplete = true;
  }

  // Convert points back to GeoJSONLineString for return
  GeoJSONLineString newRoute = newRoutePoints.toLineStringOrThrow();

  return RouteUpdateResult(
    updatedRoute: newRoute,
    hasChanged: hasChanged,
    changedSegmentIndex: segmentIndex,
    originalSegment: originalSegment,
    newSegment: newSegment,
    isGrowing: false,
    isNearlyComplete: isNearlyComplete,
  );
}

/// Modifies a route by growing it to include the user's current off-route position.
///
/// Adds the user's location to the start of the route, creating a new segment
/// from the user's position to the first point of the original route.
///
/// Parameters:
/// - [userLocation]: The user's current location
/// - [route]: The original route as a GeoJSONLineString
///
/// Returns a [RouteUpdateResult] containing the updated route and information about
/// the new segment added, to support animated transitions.
RouteUpdateResult growRoute(
    GeoJSONPoint userLocation, GeoJSONLineString route) {
  // Use List<GeoJSONPoint> for internal route construction
  List<GeoJSONPoint> newRoutePoints = [userLocation];

  // Convert route to points and add them
  List<GeoJSONPoint> routePoints = route.points;
  newRoutePoints.addAll(routePoints);

  // There's no original segment when growing (we're adding a new one)
  List<GeoJSONPoint> originalSegment = [];

  // The new segment is from user location to first route point
  List<GeoJSONPoint> newSegment = [];
  if (routePoints.isNotEmpty) {
    newSegment = [userLocation, routePoints.first];
  } else {
    // If the route was empty, duplicate the user location
    newRoutePoints.add(userLocation);
    newSegment = [userLocation, userLocation];
  }

  // Convert points back to GeoJSONLineString for return
  GeoJSONLineString newRoute = newRoutePoints.toLineStringOrThrow();

  return RouteUpdateResult(
    updatedRoute: newRoute,
    hasChanged: true, // Growing always changes the route
    changedSegmentIndex: 0, // New segment is always at the beginning
    originalSegment: originalSegment,
    newSegment: newSegment,
    isGrowing: true,
  );
}

/// Calculates an updated route based on the user's current location
/// Returns a map with update information or null if no update is needed
RouteCalculationData? calculateUpdatedRoute(
    GeoJSONPoint point, GeoJSONLineString route) {
  try {
    final userLocation = point;
    final checkResult =
        isUserOnRoute(userLocation, route, thresholdMeters: 50.0);

    RouteUpdateResult routeUpdateResult;

    if (checkResult.isOnRoute) {
      routeUpdateResult = shrinkRoute(checkResult.projectedPoint,
          checkResult.segmentIndex, checkResult.projectionRatio, route);
    } else {
      routeUpdateResult = growRoute(userLocation, route);
    }

    // Only return data if there's actually a change
    if (routeUpdateResult.hasChanged) {
      return RouteCalculationData.routeChanged(
        isOnRoute: checkResult.isOnRoute,
        distanceFromRoute: checkResult.distance,
        changedSegmentIndex: routeUpdateResult.changedSegmentIndex,
        originalSegment: routeUpdateResult.originalSegment,
        newSegment: routeUpdateResult.newSegment,
        isGrowing: routeUpdateResult.isGrowing,
        isNearlyComplete: routeUpdateResult.isNearlyComplete,
        updatedRoute: routeUpdateResult.updatedRoute,
      );
    } else {
      return RouteCalculationData.unchanged(
          isOnRoute: checkResult.isOnRoute,
          distanceFromRoute: checkResult.distance);
    }
  } catch (e) {
    rethrow;
  }
}

/// Calculates updated route coordinates by finding the current point's position and removing traversed segments
///
/// This function efficiently calculates new route coordinates by:
/// 1. Finding where the current point projects onto the route
/// 2. If point is close to route: Determining the projected point's position and returning coordinates from there onwards
/// 3. If point is far from route: Adding the point to the beginning of the route to show a detour
///
/// This approach is much faster than recalculating the entire route structure
/// and provides smoother animation performance.
///
/// Parameters:
/// - [currentPoint]: The current location point
/// - [routeCoordinates]: The original route coordinates
///
/// Returns:
/// - [List<List<double>>?]: New route coordinates starting from the current position,
///   or with the current point added to the beginning if it's far from the route.
///   Returns null only if the original route is invalid (less than 2 points).
List<List<double>>? updateRouteGeojson(
    GeoJSONPoint currentPoint, List<List<double>> routeCoordinates) {
  if (routeCoordinates.length < 2) return null;

  // Find the best insertion point and projection
  double minDistance = double.infinity;
  int bestSegmentIndex = 0;
  double bestRatio = 0.0;
  List<double>? projectedCoords;

  // Check each segment to find where the point should be projected
  for (int i = 0; i < routeCoordinates.length - 1; i++) {
    final segmentStart = GeoJSONPoint(routeCoordinates[i]);
    final segmentEnd = GeoJSONPoint(routeCoordinates[i + 1]);

    final projection =
        projectPointOnSegment(currentPoint, segmentStart, segmentEnd);
    final distance = haversineDistance(currentPoint, projection.projectedPoint);

    if (distance < minDistance) {
      minDistance = distance;
      bestSegmentIndex = i;
      bestRatio = projection.ratio;
      projectedCoords = projection.projectedPoint.coordinates;
    }
  }

  // If point is too far from route, add it to the beginning without removing others
  if (minDistance > 50.0 || projectedCoords == null) {
    // Point is too far from route, add current point to the start of the route
    List<List<double>> newCoordinates = [currentPoint.coordinates];
    newCoordinates.addAll(routeCoordinates);
    return newCoordinates;
  }

  // Create new coordinate list
  List<List<double>> newCoordinates = [];

  // If we're at the beginning of a segment (ratio close to 0), start from that segment
  if (bestRatio <= 0.01) {
    // Add coordinates from the segment start onwards
    newCoordinates.addAll(routeCoordinates.sublist(bestSegmentIndex));
  }
  // If we're at the end of a segment (ratio close to 1), start from next segment
  else if (bestRatio >= 0.99) {
    // Add coordinates from the next segment onwards
    if (bestSegmentIndex + 1 < routeCoordinates.length) {
      newCoordinates.addAll(routeCoordinates.sublist(bestSegmentIndex + 1));
    } else {
      // We're at the very end - create a minimal route with just the destination
      newCoordinates.add(routeCoordinates.last);
      newCoordinates.add(
          routeCoordinates.last); // Duplicate to maintain LineString validity
    }
  }
  // We're in the middle of a segment
  else {
    // Add the projected point as the first coordinate
    newCoordinates.add(projectedCoords);
    // Add remaining coordinates from the next point onwards
    if (bestSegmentIndex + 1 < routeCoordinates.length) {
      newCoordinates.addAll(routeCoordinates.sublist(bestSegmentIndex + 1));
    }
  }

  // Ensure we have at least 2 coordinates for a valid LineString
  if (newCoordinates.length < 2) {
    if (newCoordinates.isNotEmpty) {
      newCoordinates.add(newCoordinates.last); // Duplicate the last point
    } else {
      // Fallback: return null if we can't create valid coordinates
      return null;
    }
  }

  return newCoordinates;
}
