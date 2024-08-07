import 'dart:async';

import 'package:flutter/material.dart';
import 'package:duck_router/src/interceptor.dart';
import 'package:duck_router/src/location.dart';

/// Handler for when the app gets a deeplink.
typedef DuckRouterDeepLinkHandler = List<Location> Function(
  Uri uri,
  Location currentLocation,
);

/// A listener for when the router navigates.
typedef DuckRouterNavigatorListener = void Function(Location destination);

/// {@template duck_router_configuration}
/// A configuration object for the [DuckRouter].
/// {@endtemplate}
class DuckRouterConfiguration {
  /// {@macro duck_router_configuration}
  DuckRouterConfiguration({
    required this.initialLocation,
    GlobalKey<NavigatorState>? rootNavigatorKey,
    this.interceptors,
    this.onDeepLink,
    this.onNavigate,
  }) : rootNavigatorKey = rootNavigatorKey ?? GlobalKey<NavigatorState>();

  /// The list of locations that the user can route to
  final Location initialLocation;

  /// The list of interceptors to run before routing.
  ///
  /// See also:
  /// - [LocationInterceptor]
  final List<LocationInterceptor>? interceptors;

  /// The root navigator key.
  final GlobalKey<NavigatorState> rootNavigatorKey;

  /// If set, router will ask consumer to provide a stack of locations
  /// to navigate to.
  final DuckRouterDeepLinkHandler? onDeepLink;

  /// A listener for when the router navigates.
  final DuckRouterNavigatorListener? onNavigate;

  final Map<String, LocationMatch> _routeMapping = {};

  /// Adds a [Location] to the current dynamic directory of locations, so
  /// that we can find it back later, e.g. upon state restoration.
  void addLocation<T>(Location location, {Completer<T>? completer}) {
    if (_routeMapping.containsKey(location.path)) {
      return;
    }
    _routeMapping[location.path] = LocationMatch(
      location: location,
      completer: completer,
    );
  }

  /// Returns the [LocationMatch] for the given path.
  LocationMatch? findLocation(String path) {
    return _routeMapping[path];
  }

  /// Removes a location from the current dynamic directory of locations.
  void removeLocation<T>(Location location) {
    _routeMapping.remove(location.path);
  }
}

/// {@template location_match}
/// A match for a location, containing some extra context around the location.
///
/// Some locations need extra context when performing certain actions, for
/// example, we might need the [Completer] when trying to pop the page.
/// {@endtemplate}
class LocationMatch<T> {
  /// {@macro location_match}
  LocationMatch({
    required this.location,
    this.completer,
  });

  final Location location;
  final Completer<T>? completer;
}
