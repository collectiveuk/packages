import 'package:flutter/material.dart';

import '../navigator.dart';

typedef TransitionBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
);

/// {@template duck_page}
/// DuckPage is a page that allows defining a custom transition.
///
/// For example:
///
/// ```dart
/// DuckPage(
///   child: MyPage(),
///   transitionsBuilder: (c, a, s, child) {
///     return FadeTransition(
///       opacity: a,
///       child: child,
///     );
///   },
/// )
/// ```
/// {@endtemplate}
class DuckPage<T> extends Page<T> {
  /// {@macro duck_page}
  const DuckPage({
    required this.child,
    required this.transitionsBuilder,
    required OnPopInvokedCallback onPopInvoked,
    this.isModal = false,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration = const Duration(milliseconds: 300),
    this.maintainState = false,
    this.canTapToDismiss = false,
    this.backgroundColor,
    this.semanticLabel,
    super.name,
    super.arguments,
    super.restorationId,
    super.key,
  });

  /// Content of this page.
  final Widget child;

  /// Duration of the transition.
  ///
  /// Defaults to 300ms.
  final Duration transitionDuration;

  /// Duration of the reverse transition.
  ///
  /// Defaults to 300ms.
  final Duration reverseTransitionDuration;

  /// If true, route will stay in memory.
  ///
  /// See also:
  /// - [ModalRoute.maintainState]
  final bool maintainState;

  /// Set to true to make this page route a modal page, which is a fullscreen
  /// page that covers the entire screen and shows an X instead of a back
  /// button.
  final bool isModal;

  /// Set to true to allow dismissing the route by tapping.
  ///
  /// Defaults to false.
  final bool canTapToDismiss;

  /// The color to use as background color for the route.
  ///
  /// If this is null, the barrier will be transparent.
  ///
  /// See also:
  /// - [ModalRoute.barrierColor]
  final Color? backgroundColor;

  /// The semantic label used if this route can be dismissed by tapping.
  ///
  /// See also:
  /// - [ModalRoute.barrierLabel]
  /// - [canTapToDismiss]
  final String? semanticLabel;

  /// Use the [transitionsBuilder] to define custom transitions for this page.
  ///
  /// This transition will wrap the [child] widget.
  ///
  /// See also:
  /// - [ModalRoute.buildTransitions] for more information on how to use this.
  final TransitionBuilder transitionsBuilder;

  @override
  Route<T> createRoute(BuildContext context) => _DuckPageRoute<T>(this);
}

class _DuckPageRoute<T> extends PageRoute<T> {
  _DuckPageRoute(DuckPage<T> page) : super(settings: page);

  DuckPage<T> get _page => settings as DuckPage<T>;

  @override
  bool get barrierDismissible => _page.canTapToDismiss;

  @override
  Color? get barrierColor => _page.backgroundColor;

  @override
  String? get barrierLabel => _page.semanticLabel;

  @override
  Duration get transitionDuration => _page.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _page.reverseTransitionDuration;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.isModal;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: _page.child,
      );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _page.transitionsBuilder(
        context,
        animation,
        secondaryAnimation,
        child,
      );
}
