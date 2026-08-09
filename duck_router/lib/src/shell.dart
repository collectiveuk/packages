import 'dart:async';

import 'package:collection/collection.dart';
import 'package:duck_router/duck_router.dart';
import 'package:duck_router/src/parser.dart';
import 'package:duck_router/src/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'navigator.dart';

/// {@template duck_shell}
/// The [DuckShell] is a Widget that manages state for a
/// [StatefulLocation]. It allows switching between the children of that
/// location.
///
/// {@endtemplate}
///
/// {@category Stateful navigation}
class DuckShell extends StatefulWidget {
  /// {@macro duck_shell}
  const DuckShell({
    required this.children,
    required GlobalKey<DuckShellState> key,
    required this.configuration,
  }) : super(key: key);

  /// The children of this [StatefulLocation]. Each child will have
  /// its own [DuckNavigator].
  final List<Location> children;

  final DuckRouterConfiguration configuration;

  @override
  State<StatefulWidget> createState() => DuckShellState();

  /// Gets the state for the nearest [DuckShell] in the Widget tree.
  static DuckShellState of(BuildContext context) {
    final shellState = maybeOf(context);
    assert(shellState != null, 'Could not find a DuckShell!');
    return shellState!;
  }

  /// Gets the state for the nearest [DuckShell] in the Widget tree.
  ///
  /// Returns null if no [DuckShell] is found.
  static DuckShellState? maybeOf(BuildContext context) {
    final shellState = context.findAncestorStateOfType<DuckShellState>();
    return shellState;
  }

  /// Navigates to the child at the given index.
  void switchChild(int index) {
    final navigatorKey = key! as GlobalKey<DuckShellState>;

    final shellState = navigatorKey.currentState;
    shellState?.switchChild(index);
  }
}

/// The state for the [DuckShell].
class DuckShellState extends State<DuckShell> {
  int _currentIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [];
  final List<LocationStack> _stacks = [];
  final List<_NestedRouterDelegate> _routerDelegates = [];
  final List<DuckInformationParser> _informationParsers = [];
  final List<DuckInformationProvider> _informationProviders = [];
  final List<ChildBackButtonDispatcher> _backButtonDispatchers = [];

  @override
  void initState() {
    for (final c in widget.children) {
      final index = widget.children.indexOf(c);
      _navigatorKeys.add(
        GlobalKey<NavigatorState>(
          debugLabel: 'StatefulChildLocation key: ${c.path}',
        ),
      );
      final stack = LocationStack(locations: [c]);
      _stacks.add(stack);
      _routerDelegates.add(_NestedRouterDelegate(
        stack: _stacks[index],
        navigatorKey: _navigatorKeys[index],
        onNewPath: (config) => _stacks[index] = config,
        configuration: widget.configuration,
      ));

      _informationParsers
          .add(DuckInformationParser(configuration: widget.configuration));
      final provider = DuckInformationProvider(
        stack: stack,
        configuration: widget.configuration,
      );
      _informationProviders.add(provider);
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_backButtonDispatchers.isEmpty) {
      _backButtonDispatchers.add(
        DuckRouter.of(context)
            .backButtonDispatcher
            .createChildBackButtonDispatcher(),
      );
      _backButtonDispatchers[0].takePriority();
    }

    return IndexedStack(
      index: _currentIndex,
      children: widget.children.mapIndexed(
        (i, e) {
          return Router(
            routerDelegate: _routerDelegates[i],
            routeInformationParser: _informationParsers[i],
            routeInformationProvider: _informationProviders[i],
            backButtonDispatcher:
                i == _currentIndex ? _backButtonDispatchers[0] : null,
          );
        },
      ).toList(),
    );
  }

  @override
  void dispose() {
    for (var i = 0; i < _routerDelegates.length; i++) {
      _routerDelegates[i].dispose();
      _informationProviders[i].dispose();
    }
    super.dispose();
  }

  /// Navigates to the child at the given index.
  void switchChild(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Pushes a new location to the current child's stack.
  Future<T?> navigate<T extends Object?>(
    Location to, {
    bool? replace,
    bool? clearStack,
  }) async {
    Location? replaced;
    final currentStack = _currentRouterDelegate.currentConfiguration;

    // As in [DuckRouter.navigate], we leave the delegate's stack alone and
    // hand the parse a copy. The stack only changes once the new one has been
    // parsed.
    var baseLocationStack = currentStack;

    if (clearStack ?? false) {
      for (final l in currentStack.locations) {
        widget.configuration.clearLocation(l);
      }
      baseLocationStack = LocationStack(locations: []);
    } else if (replace ?? false) {
      replaced = currentStack.locations.lastOrNull;
      baseLocationStack = LocationStack(
        locations: currentStack.locations.isEmpty
            ? []
            : currentStack.locations
                .sublist(0, currentStack.locations.length - 1),
      );
    }

    return _informationProviders[_currentIndex].navigate<T>(
      to,
      baseLocationStack: baseLocationStack,
      replaced: replaced,
    );
  }

  /// Pops the top location on the routing stack.
  void pop<T extends Object?>([T? result]) {
    final navigatorKey = _navigatorKeys[_currentIndex];
    if (navigatorKey.currentState == null) {
      return;
    }

    navigatorKey.currentState?.pop(result);
  }

  bool popUntil<T extends Object?>(LocationPredicate predicate, [T? result]) {
    final navigatorKey = _navigatorKeys[_currentIndex];
    if (navigatorKey.currentState == null) {
      return false;
    }

    final routerDelegate = _routerDelegates[_currentIndex];
    final destination = routerDelegate.currentConfiguration.locations
        .firstWhereOrNull((location) => predicate(location));
    if (destination == null) {
      return false;
    }

    navigatorKey.currentState?.popUntilWithResult((route) {
      return route.settings.name == destination.path;
    }, result);

    return true;
  }

  /// Resets the stack
  void reset() {
    final navigatorKey = _navigatorKeys[_currentIndex];
    if (navigatorKey.currentState == null) {
      return;
    }

    navigatorKey.currentState?.popUntil((route) {
      return route.settings.name == _stacks[_currentIndex].locations.first.path;
    });
  }

  void takePriority() {
    if (_backButtonDispatchers.isEmpty) {
      return;
    }

    // There is only ever one back button dispatcher; it is attached to
    // whichever child is currently active, see [build].
    _backButtonDispatchers[0].takePriority();
  }

  RouterDelegate get currentRouterDelegate => _currentRouterDelegate;

  _NestedRouterDelegate get _currentRouterDelegate =>
      _routerDelegates[_currentIndex];
}

typedef _NewPathCallback = void Function(LocationStack configuration);

class _NestedRouterDelegate extends RouterDelegate<LocationStack>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<LocationStack> {
  _NestedRouterDelegate({
    required GlobalKey<NavigatorState> navigatorKey,
    required LocationStack stack,
    required _NewPathCallback onNewPath,
    required DuckRouterConfiguration configuration,
  })  : _navigatorKey = navigatorKey,
        currentConfiguration = stack,
        _onNewPath = onNewPath,
        _routerConfiguration = configuration;

  final _NewPathCallback _onNewPath;
  final GlobalKey<NavigatorState> _navigatorKey;
  final DuckRouterConfiguration _routerConfiguration;

  /// See [DuckRouterDelegate._isHandlingBackButton].
  bool _isHandlingBackButton = false;

  @override
  Widget build(BuildContext context) {
    return DuckNavigator(
      navigatorKey: navigatorKey,
      stack: currentConfiguration,
      onPopPage: onPopPage,
      onDidRemovePage: _onDidRemovePage,
      observers: _routerConfiguration.navigatorObserverBuilder != null
          ? _routerConfiguration.navigatorObserverBuilder!(navigatorKey)
          : null,
    );
  }

  /// See RouterDelegate.onDidRemovePage.
  void _onDidRemovePage(Page<Object?> page) {
    /// Please refer to DuckRouterDelegate._onDidRemovePage
  }

  /// See RouterDelegate.onPopPage.
  void onPopPage(bool didPop, Object? result) {
    if (!didPop) return;

    // The last location can never be popped, see
    // [DuckRouterDelegate._onPopPage].
    if (currentConfiguration.locations.length <= 1) return;

    final currentLocation = currentConfiguration.locations.last;
    _routerConfiguration.removeLocation(currentLocation, result);

    currentConfiguration.locations
        .removeWhere((l) => l.path == currentLocation.path);

    // Notify so the nested [Router] rebuilds and reports the new
    // configuration back to its [DuckInformationProvider] via
    // [routerReportsNewRouteInformation]. See [DuckRouterDelegate._onPopPage].
    if (!_isHandlingBackButton) notifyListeners();
  }

  @override
  Future<bool> popRoute() async {
    final state = navigatorKey.currentState;
    if (state == null) return false;
    _isHandlingBackButton = true;
    try {
      return await state.maybePop();
    } finally {
      _isHandlingBackButton = false;
    }
  }

  @override
  LocationStack currentConfiguration;

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
  Future<void> setNewRoutePath(LocationStack configuration) {
    if (currentConfiguration == configuration) {
      return SynchronousFuture<void>(null);
    }

    currentConfiguration = configuration;
    _onNewPath(configuration);
    return SynchronousFuture(null);
  }
}
