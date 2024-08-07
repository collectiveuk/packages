import 'package:collection/collection.dart';
import 'package:duck_router/src/configuration.dart';
import 'package:duck_router/src/duck_router.dart';
import 'package:duck_router/src/exception.dart';
import 'package:duck_router/src/location.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'navigator.dart';

/// {@template duck_router_delegate}
/// The [RouterDelegate] for [DuckRouter].
/// {@endtemplate}
class DuckRouterDelegate extends RouterDelegate<LocationStack>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<LocationStack> {
  /// {@macro duck_router_delegate}
  DuckRouterDelegate({
    required DuckRouterConfiguration configuration,
    required DuckRouterShellBuilder shellBuilder,
  })  : _configuration = configuration,
        _shellBuilder = shellBuilder,
        currentConfiguration =
            LocationStack(locations: [configuration.initialLocation]);

  final DuckRouterConfiguration _configuration;
  final DuckRouterShellBuilder _shellBuilder;

  @override
  Widget build(BuildContext context) {
    return _shellBuilder(
      context,
      DuckNavigator(
        navigatorKey: navigatorKey,
        stack: currentConfiguration,
        onDidRemovePage: onDidRemovePage,
      ),
    );
  }

  /// See RouterDelegate.onDidRemovePage.
  void onDidRemovePage(Page<Object?> page) {
    final currentLocation = currentConfiguration.locations.last;
    _configuration.removeLocation(currentLocation);
    currentConfiguration.locations.removeLast();
  }

  @override
  LocationStack currentConfiguration = LocationStack.empty;

  @override
  GlobalKey<NavigatorState> get navigatorKey => _configuration.rootNavigatorKey;

  @override
  Future<void> setNewRoutePath(LocationStack configuration) {
    if (currentConfiguration == configuration) {
      return SynchronousFuture<void>(null);
    }

    currentConfiguration = configuration;
    return SynchronousFuture(null);
  }

  @override
  Future<bool> popRoute() async {
    var state = navigatorKey.currentState;
    if (state == null) {
      return false;
    }
    if (!state.canPop()) {
      state = null;
    }

    if (state != null) {
      return state.maybePop();
    }

    return false;
  }

  /// Pops the top location on the routing stack
  void pop<T extends Object?>([T? result]) {
    final currentLocation = currentConfiguration.locations.last;

    if (currentLocation is StatefulLocation) {
      /// Pop inside the stateful child location as long as that's possible.
      /// Else we will pop the whole route.
      if (currentLocation.state.currentRouterDelegate.currentConfiguration
              .locations.length >
          1) {
        return currentLocation.state.pop(result);
      }
    }

    NavigatorState? state;
    if (navigatorKey.currentState?.canPop() ?? false) {
      state = navigatorKey.currentState;
    }
    if (currentConfiguration.locations.length == 1) {
      throw const DuckRouterException('There is nothing to pop!');
    }
    state?.pop(result);
  }

  void popUntil(LocationPredicate predicate) {
    final currentLocation = currentConfiguration.locations.last;

    if (currentLocation is StatefulLocation) {
      /// Pop inside the stateful child location as long as that's possible.
      /// Else we will pop the whole route.
      if (currentLocation.state.currentRouterDelegate.currentConfiguration
              .locations.length >
          1) {
        final result = currentLocation.state.popUntil(predicate);
        if (result) {
          return;
        }
      }
    }

    final destination = currentConfiguration.locations
        .firstWhereOrNull((location) => predicate(location));
    if (destination == null) {
      throw const DuckRouterException(
          'Provided Location predicate does not match any Locations in current stack!');
    }

    NavigatorState? state;
    if (navigatorKey.currentState?.canPop() ?? false) {
      state = navigatorKey.currentState;
    }
    state?.popUntil((route) {
      return route.settings.name == destination.path;
    });
  }

  /// Reset the router to the root
  void root() {
    final currentLocation = currentConfiguration.locations.last;

    if (currentLocation is StatefulLocation) {
      /// Pop inside the stateful child location as long as that's possible.
      /// Else we will pop the whole route.
      if (currentLocation.state.currentRouterDelegate.currentConfiguration
              .locations.length >
          1) {
        return currentLocation.state.reset();
      } else {
        return;
      }
    }

    currentConfiguration = LocationStack(locations: [
      currentConfiguration.locations.firstOrNull ??
          _configuration.initialLocation
    ]);
    notifyListeners();
  }
}
