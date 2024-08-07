import 'package:flutter/material.dart';

import '../duck_router.dart';
import 'pages/cupertino.dart';
import 'pages/material.dart';

typedef OnPopInvokedCallback = void Function(bool didPop, Object? result);

/// {@template duck_navigator}
/// A [Navigator] for a [LocationStack].
/// {@endtemplate}
class DuckNavigator extends StatefulWidget {
  /// {@macro duck_navigator}
  const DuckNavigator({
    required this.stack,
    required this.navigatorKey,
    required this.onDidRemovePage,
    super.key,
  });

  /// The stack of [Location]s for this navigator.
  final LocationStack stack;

  /// The navigator key for this navigator.
  final GlobalKey<NavigatorState> navigatorKey;

  final DidRemovePageCallback onDidRemovePage;

  @override
  State<StatefulWidget> createState() {
    return _DuckNavigatorState();
  }
}

class _DuckNavigatorState extends State<DuckNavigator> {
  HeroController? _controller;
  Page<void> Function({
    required LocalKey key,
    required String? name,
    required Widget child,
    required OnPopInvokedCallback onPopInvoked,
  })? _pageBuilderForAppType;

  /// Rebuilds are common, so we want to cache pages to rebuild only
  /// when we really need to.
  List<Page<Object?>>? _pages;

  @override
  void didUpdateWidget(DuckNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stack != oldWidget.stack) {
      _pages = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Create a HeroController based on the app type.
    if (_controller == null) {
      if (isMaterialApp(context)) {
        _controller = createMaterialHeroController();
      } else if (isCupertinoApp(context)) {
        _controller = createCupertinoHeroController();
      } else {
        _controller = HeroController();
      }
    }
    _pages = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_pages == null) {
      _updatePages(context);
    }

    return HeroControllerScope(
      controller: _controller!,
      child: Navigator(
        key: widget.navigatorKey,
        pages: _pages!,
        onDidRemovePage: widget.onDidRemovePage,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _updatePages(BuildContext context) {
    assert(_pages == null, 'Trying to rebuild _pages while they already exist');
    _pages = _buildPages(context);
  }

  List<Page<Object?>> _buildPages(BuildContext context) {
    final stack = widget.stack;
    final pages = <Page<Object?>>[];

    _cacheAppType(context);

    for (final l in stack.locations) {
      assert(l.pageBuilder != null || l.builder != null,
          'Location must have a builder or a pageBuilder');
      if (l.pageBuilder != null) {
        pages.add(l.pageBuilder!(context));
      } else {
        pages.add(_buildPage(l));
      }
    }
    return pages;
  }

  Page<Object?> _buildPage(Location location) {
    return _pageBuilderForAppType!(
      key: ValueKey(location.path),
      name: location.path,
      child: location.builder!(context),
      onPopInvoked: (didPop, result) =>
          DuckRouter.of(context).onPopInvoked(location, didPop, result),
    );
  }

  void _cacheAppType(BuildContext context) {
    if (_pageBuilderForAppType == null) {
      final elem = context is Element ? context : null;

      if (elem != null && isMaterialApp(elem)) {
        _pageBuilderForAppType = pageBuilderForMaterialApp;
      } else if (elem != null && isCupertinoApp(elem)) {
        _pageBuilderForAppType = pageBuilderForCupertinoApp;
      }
    }

    assert(_pageBuilderForAppType != null, 'App type not found!');
  }
}
