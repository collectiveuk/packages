import 'package:collection/collection.dart';
import 'package:duck_router/duck_router.dart';
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

  /// Set while [popRoute] is delegating to [NavigatorState.maybePop]. The
  /// [Router] will rebuild and re-report on its own when [popRoute]'s future
  /// resolves (see [_RouterState._handleRoutePopped]), so [_onPopPage] skips
  /// the otherwise-required [notifyListeners] on that path.
  bool _isHandlingBackButton = false;

  @override
  Widget build(BuildContext context) {
    return _shellBuilder(
      context,
      DuckNavigator(
        navigatorKey: navigatorKey,
        stack: currentConfiguration,
        onPopPage: _onPopPage,
        onDidRemovePage: _onDidRemovePage,
        observers: _configuration.navigatorObserverBuilder != null
            ? _configuration.navigatorObserverBuilder!(navigatorKey)
            : null,
      ),
    );
  }

  /// See RouterDelegate.onDidRemovePage.
  void _onDidRemovePage(Page<Object?> page) {
    // Stack removal is handled eagerly in [_onPopPage] (for pops) and in
    // the navigate/pop/reset methods (for declarative changes). Removing
    // here would incorrectly remove a newly pushed page that shares the
    // same path as the page that was just popped.
    // We still need this callback, as this is required by the [Navigator].
  }

  /// See RouterDelegate.onPopPage.
  void _onPopPage(bool didPop, Object? result) {
    if (!didPop) return;

    // The last location can never be popped: it is the page this [Navigator]
    // always shows. Removing it would leave the router without a current
    // location, and every navigation after it would throw.
    //
    // We do check here for it, because [NavigatorState.pop] does not check
    // [NavigatorState.canPop] first. Popping an already closed sheet, for
    // example, pops the page underneath it instead.
    if (currentConfiguration.locations.length <= 1) return;

    final currentLocation = currentConfiguration.locations.last;
    _configuration.removeLocation(currentLocation, result);

    currentConfiguration.locations
        .removeWhere((l) => l.path == currentLocation.path);

    final newLocation = currentConfiguration.locations.lastOrNull;
    if (newLocation is StatefulLocation) {
      newLocation.state.takePriority();
    }

    // Notify so [Router] rebuilds and reports the new configuration back to
    // [DuckInformationProvider] via [routerReportsNewRouteInformation].
    // Without this, the provider's cached value keeps pointing at the popped
    // location and [Router] re-pushes it on rebuild/hot reload.
    //
    // Skipped on the back-button path: [Router] already rebuilds + reports
    // after [popRoute] resolves, so notifying here would just double up.
    if (!_isHandlingBackButton) notifyListeners();
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
      _isHandlingBackButton = true;
      try {
        return await state.maybePop();
      } finally {
        _isHandlingBackButton = false;
      }
    }

    return false;
  }

  /// Pops the top location on the routing stack
  void pop<T extends Object?>([T? result, bool root = false]) {
    final currentLocation = currentConfiguration.locations.lastOrNull;
    if (currentLocation == null) {
      throw const EmptyStackException();
    }

    if (currentLocation is StatefulLocation && !root) {
      /// Pop inside the stateful child location as long as that's possible.
      /// Else we will pop the whole route.
      if (currentLocation.state.currentRouterDelegate.currentConfiguration
              .locations.length >
          1) {
        return currentLocation.state.pop(result);
      }
    }

    // This check comes before the cleanup below: a pop we cannot honour
    // should leave both stacks as they were.
    if (currentConfiguration.locations.length == 1) {
      throw const EmptyStackException();
    }

    if (currentLocation is StatefulLocation && root) {
      // When popping a stateful location, we can consider the nested stack to be cleared from the stack.
      // So we will follow the same cleanup logic as if navigating to a new page, with the clearStack flag set to true.
      for (final l in currentLocation
          .state.currentRouterDelegate.currentConfiguration.locations) {
        _configuration.clearLocation(l);
      }
      currentLocation.state.currentRouterDelegate.currentConfiguration.locations
          .clear();
    }

    NavigatorState? state;
    if (navigatorKey.currentState?.canPop() ?? false) {
      state = navigatorKey.currentState;
    }
    state?.pop(result);
  }

  void popUntil<T extends Object?>(LocationPredicate predicate, [T? result]) {
    final currentLocation = currentConfiguration.locations.lastOrNull;

    if (currentLocation is StatefulLocation) {
      /// Pop inside the stateful child location as long as that's possible.
      /// Else we will pop the whole route.
      if (currentLocation.state.currentRouterDelegate.currentConfiguration
              .locations.length >
          1) {
        final found = currentLocation.state.popUntil(predicate, result);
        if (found) {
          return;
        }
      }
    }

    final destination = currentConfiguration.locations
        .firstWhereOrNull((location) => predicate(location));
    if (destination == null) {
      throw const NoLocationMatchFoundException();
    }

    NavigatorState? state;
    if (navigatorKey.currentState?.canPop() ?? false) {
      state = navigatorKey.currentState;
    }
    state?.popUntilWithResult((route) {
      return route.settings.name == destination.path;
    }, result);
  }

  /// Reset the router to the root
  void root() {
    final currentLocation = currentConfiguration.locations.lastOrNull;

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
