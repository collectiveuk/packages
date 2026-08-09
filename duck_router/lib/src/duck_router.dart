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
///
/// {@endtemplate}
/// {@category Configuration}
/// {@category Deep linking}
/// {@category Stateful navigation}
/// {@category Custom pages and transitions}
class DuckRouter implements RouterConfig<LocationStack> {
  /// {@macro duck_router}
  factory DuckRouter({
    required Location initialLocation,
    List<LocationInterceptor>? interceptors,
    DuckRouterDeepLinkHandler? onDeepLink,
    DuckRouterNavigatorListener? onNavigate,
    DuckRouterNavigatorObserverBuilder? navigatorObserverBuilder,
    DuckRestorer? duckRestorer,
  }) {
    return DuckRouter.withConfig(
      configuration: DuckRouterConfiguration(
        initialLocation: initialLocation,
        interceptors: interceptors,
        onDeepLink: onDeepLink,
        onNavigate: onNavigate,
        navigatorObserverBuilder: navigatorObserverBuilder,
        duckRestorer: duckRestorer,
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
        router: this,
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

  /// Disposes the router and its associated resources.
  ///
  /// After calling this, the router must not be used anymore.
  ///
  /// Note: this is not wired into any framework-driven teardown. Flutter's
  /// [Router] does not dispose its [RouterConfig], and [InheritedDuckRouter]
  /// is built inside [routerDelegate], so it cannot own this instance's
  /// lifecycle. Most apps hold a single [DuckRouter] for the app's lifetime
  /// and never need to call this; callers who replace the router at runtime
  /// are responsible for invoking [dispose] on the previous instance.
  void dispose() {
    routerDelegate.dispose();
    routeInformationProvider.dispose();
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
    return inherited?.router;
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
  ///
  /// You can await [navigate] to pass back results from the new location.
  /// This can create complicated scenarios when used in combination with
  /// [replace]. The behavior defined as follows:
  ///
  /// - Location A navigates to and awaits Location B
  /// - Location B is replaced by Location C
  /// - Location C pops, with a result.
  ///
  /// This result will still be passed to Location A. Be mindful that this
  /// result should be of the same type as the result of Location B.
  ///
  /// If the awaited location is cleared using [clearStack], an error will be
  /// thrown.
  Future<T?> navigate<T extends Object?>({
    required Location to,
    bool root = false,
    bool? replace,
    bool? clearStack,
  }) {
    final currentStack = routerDelegate.currentConfiguration;
    final currentRootLocation = currentStack.locations.lastOrNull;
    Location? replaced;

    if (clearStack ?? false) {
      if (currentRootLocation is StatefulLocation && !root) {
        return currentRootLocation.state.navigate(
          to,
          replace: replace,
          clearStack: clearStack,
        );
      }

      for (final l in currentStack.locations) {
        configuration.clearLocation(l);
      }

      // We hand over a new, empty stack instead of emptying [currentStack].
      // That object is the delegate's current configuration, which should
      // only change once the new stack has been parsed.
      //
      // The parse does not always happen: [Router] drops it when a back
      // button press starts a new transaction first, and skips it entirely
      // when an interceptor throws. Emptying up front would leave the router
      // without any location at all, breaking every navigation after it.
      return routeInformationProvider.navigate<T>(
        to,
        baseLocationStack: LocationStack(locations: []),
      );
    }

    if (!(replace ?? false) &&
        currentStack.locations.any((loc) => loc.path == to.path)) {
      throw DuplicateRouteException(to);
    }

    if (currentRootLocation is StatefulLocation) {
      if (root) {
        /// We are navigating from the root, so we can just continue, however,
        /// we do need to have the root [BackButtonDispatcher] take priority
        /// again, as opposed to the one in the shell.
        ///
        /// See also:
        /// - [DuckShellState.build]
        backButtonDispatcher.takePriority();
      } else {
        return currentRootLocation.state.navigate(to, replace: replace);
      }
    }

    // Same as in the [clearStack] branch above: we drop the replaced location
    // from a copy, so that the delegate keeps its stack until the new one has
    // been parsed.
    var baseLocationStack = currentStack;
    if (replace ?? false) {
      replaced = currentStack.locations.lastOrNull;
      baseLocationStack = LocationStack(
        locations: currentStack.locations.isEmpty
            ? []
            : currentStack.locations
                .sublist(0, currentStack.locations.length - 1),
      );
    }

    return routeInformationProvider.navigate<T>(
      to,
      baseLocationStack: baseLocationStack,
      replaced: replaced,
    );
  }

  /// Pop the top-most route off the current screen.
  ///
  /// If the top-most route is a pop up or dialog, this method pops it instead
  /// of any route under it.
  void pop<T extends Object?>([T? result]) {
    routerDelegate.pop<T>(result);
  }

  /// Pop the root route off the current screen.
  @Deprecated('Use exit instead')
  void popRoot<T extends Object?>([T? result]) {
    routerDelegate.pop<T>(result, true);
  }

  /// Close the current stack of routes if in a [StatefulLocation] or
  /// [FlowLocation], otherwise, pop.
  ///
  /// This is equivalent to calling [pop] until the root location is reached,
  /// in other words, it will immediately pop the root location.
  ///
  /// See also:
  /// - [StatefulLocation] for creating an inner navigation stack.
  void exit<T extends Object?>([T? result]) {
    routerDelegate.pop<T>(result, true);
  }

  /// Pop until the given predicate is satisfied.
  ///
  /// If [result] is provided, it will be passed back to the destination
  /// location, completing any awaited [navigate] call.
  void popUntil<T extends Object?>(LocationPredicate predicate, [T? result]) {
    routerDelegate.popUntil(predicate, result);
  }

  /// Reset the router to the root location.
  void root() {
    routerDelegate.root();
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
      final locationStack = configuration.onDeepLink!(
        platformInitialLocation,
        userSpecifiedInitialLocation,
      );
      if (locationStack != null) {
        return LocationStack(locations: locationStack);
      }
    }

    return LocationStack(
      locations: [userSpecifiedInitialLocation],
    );
  }
}

/// DuckRouter implementation of InheritedWidget.
///
/// Used to find the current DuckRouter in the widget tree. This is useful
/// when routing from anywhere in your app.
class InheritedDuckRouter extends InheritedWidget {
  /// Default constructor for the inherited duck router.
  const InheritedDuckRouter({
    required super.child,
    required this.router,
    super.key,
  });

  /// The [DuckRouter] that is made available to the widget tree.
  final DuckRouter router;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
