import 'package:duck_router/src/configuration.dart';
import 'package:duck_router/src/delegate.dart';
import 'package:duck_router/src/exception.dart';
import 'package:duck_router/src/interceptor.dart';
import 'package:duck_router/src/location.dart';
import 'package:duck_router/src/parser.dart';
import 'package:duck_router/src/provider.dart';
import 'package:flutter/material.dart';

/// A builder for a shell around the [DuckRouter].
typedef DuckRouterShellBuilder = Widget Function(
  BuildContext context,
  Widget child,
);

/// Signature for the [DuckRouter.popUntil] predicate argument.
typedef LocationPredicate = bool Function(Location location);

/// {@template duck_router}
/// Creates a [DuckRouter].
///
/// The [initialLocation] will be the first location opened by the app.
///
/// Interceptors can be used to redirect the user to a different location based
/// on specific conditions.
///
/// Specify a [DuckRouterDeepLinkHandler] to handle deep links. Be aware that
/// deep links still go through interceptors.
/// {@endtemplate}
class DuckRouter implements RouterConfig<LocationStack> {
  /// {@macro duck_router}
  factory DuckRouter({
    required Location initialLocation,
    List<LocationInterceptor>? interceptors,
    DuckRouterDeepLinkHandler? onDeepLink,
    DuckRouterNavigatorListener? onNavigate,
  }) {
    return DuckRouter.withConfig(
      configuration: DuckRouterConfiguration(
        initialLocation: initialLocation,
        interceptors: interceptors,
        onDeepLink: onDeepLink,
        onNavigate: onNavigate,
      ),
    );
  }

  /// {@macro duck_router}
  DuckRouter.withConfig({
    required this.configuration,
  }) {
    WidgetsFlutterBinding.ensureInitialized();

    backButtonDispatcher = RootBackButtonDispatcher();
    routerDelegate = DuckRouterDelegate(
      configuration: configuration,
      shellBuilder: (context, child) => InheritedDuckRouter(
        goRouter: this,
        child: child,
      ),
    );
    routeInformationParser =
        DuckInformationParser(configuration: configuration);
    routeInformationProvider = DuckInformationProvider(
      stack: _initialLocation(configuration.initialLocation),
      configuration: configuration,
    );
  }

  /// Find the current DuckRouter in the widget tree.
  ///
  /// This method throws when it is called during redirects.
  static DuckRouter of(BuildContext context) {
    final inherited = maybeOf(context);
    assert(inherited != null, 'No DuckRouter found in context');
    return inherited!;
  }

  /// The current DuckRouter in the widget tree, if any.
  ///
  /// This method returns null when it is called during redirects.
  static DuckRouter? maybeOf(BuildContext context) {
    final inherited = context
        .getElementForInheritedWidgetOfExactType<InheritedDuckRouter>()
        ?.widget as InheritedDuckRouter?;
    return inherited?.goRouter;
  }

  /// The route configuration used by [DuckRouter].
  final DuckRouterConfiguration configuration;

  @override
  late final BackButtonDispatcher backButtonDispatcher;

  /// The router delegate. Provide this to the MaterialApp or CupertinoApp's
  /// `.router()` constructor
  @override
  late final DuckRouterDelegate routerDelegate;

  /// The route information provider used by [DuckRouter].
  @override
  late final DuckInformationProvider routeInformationProvider;

  /// The route information parser used by [DuckRouter].
  @override
  late final DuckInformationParser routeInformationParser;

  /// Navigate to a new location.
  ///
  /// Use [root] to navigate from the root navigator.
  ///
  /// If [replace] is set, the current location will be replaced with [to].
  ///
  /// If [clearStack] is set, the current stack will be cleared before navigating.
  /// [clearStack] will take precedence over [replace].
  Future<T?> navigate<T extends Object?>({
    required Location to,
    bool root = false,
    bool? replace,
    bool? clearStack,
  }) {
    final currentStack = routerDelegate.currentConfiguration;
    final currentRootLocation = currentStack.locations.last;

    if (clearStack ?? false) {
      if (currentRootLocation is StatefulLocation && !root) {
        return currentRootLocation.state.navigate(
          to,
          replace: replace,
          clearStack: clearStack,
        );
      }

      currentStack.locations.clear();
      return routeInformationProvider.navigate<T>(
        to,
        baseLocationStack: currentStack,
      );
    }

    if (!(replace ?? false) &&
        currentStack.locations.any((loc) => loc.path == to.path)) {
      throw DuckRouterException('Cannot push duplicate route: ${to.path}');
    }

    if (currentRootLocation is StatefulLocation && !root) {
      return currentRootLocation.state.navigate(to, replace: replace);
    }

    if ((replace ?? false)) {
      currentStack.locations.removeLast();
    }

    return routeInformationProvider.navigate<T>(
      to,
      baseLocationStack: currentStack,
    );
  }

  /// Pop the top-most route off the current screen.
  ///
  /// If the top-most route is a pop up or dialog, this method pops it instead
  /// of any route under it.
  void pop<T extends Object?>([T? result]) {
    routerDelegate.pop<T>(result);
  }

  void popUntil(LocationPredicate predicate) {
    routerDelegate.popUntil(predicate);
  }

  /// Reset the router to the root location.
  void root() {
    routerDelegate.root();
  }

  void onPopInvoked(Location location, bool didPop, Object? result) {
    final locationMatch = configuration.findLocation(location.path);
    locationMatch?.completer?.complete(result);
  }

  LocationStack _initialLocation(Location userSpecifiedInitialLocation) {
    Uri platformInitialLocation = Uri.parse(
      WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    );
    if (platformInitialLocation.hasEmptyPath) {
      platformInitialLocation = Uri(
        path: '/',
        queryParameters: platformInitialLocation.queryParameters,
      );
    }

    if (platformInitialLocation.path == '/') {
      return LocationStack(
        locations: [userSpecifiedInitialLocation],
      );
    }

    if (configuration.onDeepLink != null) {
      return LocationStack(
        locations: configuration.onDeepLink!(
            platformInitialLocation, userSpecifiedInitialLocation),
      );
    }

    return LocationStack(
      locations: [userSpecifiedInitialLocation],
    );
  }
}

/// DuckRouter implementation of InheritedWidget.
///
/// Used for to find the current DuckRouter in the widget tree. This is useful
/// when routing from anywhere in your app.
class InheritedDuckRouter extends InheritedWidget {
  /// Default constructor for the inherited duck router.
  const InheritedDuckRouter({
    required super.child,
    required this.goRouter,
    super.key,
  });

  /// The [DuckRouter] that is made available to the widget tree.
  final DuckRouter goRouter;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
