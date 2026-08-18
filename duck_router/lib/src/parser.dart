import 'dart:async';

import 'package:flutter/material.dart';
import 'package:duck_router/src/configuration.dart';
import 'package:duck_router/src/exception.dart';
import 'package:duck_router/src/interceptor.dart';
import 'package:duck_router/src/location.dart';
import 'state.dart';

/// {@template duck_information_parser}
/// A [RouteInformationParser] for the [DuckRouter].
/// {@endtemplate}
class DuckInformationParser extends RouteInformationParser<LocationStack> {
  /// {@macro duck_information_parser}
  DuckInformationParser({
    required DuckRouterConfiguration configuration,
  })  : _codec = LocationStackCodec(configuration: configuration),
        _configuration = configuration;

  final LocationStackCodec _codec;
  final DuckRouterConfiguration _configuration;

  @override
  Future<LocationStack> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final state = routeInformation.state;

    if (state is! LocationState) {
      /// This would be the result of state restoration, see
      /// [restoreRouteInformation]. We can presume the routeInformation state
      /// is a [LocationStack] in this case.

      if (state is! Map<Object?, Object?>) {
        throw DuckRouterException('Invalid state type: ${state.runtimeType}');
      }

      final stack =
          _codec.decode(routeInformation.state! as Map<Object?, Object?>);

      return _maybeIntercept(
          stack.locations.last,
          // Before rebuild:
          // - /home/page1
          // Then we rebuild, so we need to remove page1, otherwise
          // we will have /home/page1/page1
          stack.locations.sublist(0, stack.locations.length - 1));
    }

    final currentStack = state.baseLocationStack.locations;
    return _maybeIntercept(
      state.location,
      currentStack,
      completer: state.completer,
      replaced: state.replaced,
    );
  }

  @override
  RouteInformation? restoreRouteInformation(LocationStack configuration) {
    return RouteInformation(
      uri: configuration.uri,
      // Note: notice how we are not saving LocationState here!
      // We can use the LocationStack in [parseRouteInformation] to restore the
      // state.
      state: _codec.encode(configuration),
    );
  }

  LocationStack _maybeIntercept(
    Location to,
    List<Location> currentStack, {
    Completer? completer,
    Location? replaced,
  }) {
    for (final i in _configuration.interceptors ?? <LocationInterceptor>[]) {
      final result = i.execute(
        to,
        currentStack.lastOrNull,
      );
      if (result != null) {
        _configuration.addLocation(
          result,
          completer: completer,
          replaced: replaced,
        );
        _configuration.onNavigate?.call(result);
        if (i.pushesOnTop) {
          return _register(LocationStack(
            locations: [...currentStack, to, result],
          ));
        }

        return _register(LocationStack(
          locations: [...currentStack, result],
        ));
      }
    }

    _configuration.addLocation(to, completer: completer, replaced: replaced);
    _configuration.onNavigate?.call(to);
    return _register(LocationStack(locations: [...currentStack, to]));
  }

  /// Adds every location on [stack] to the directory of locations.
  ///
  /// The destination is already added above, together with its completer.
  /// This covers the rest of the stack: the location an interceptor pushed on
  /// top of, and any base stack handed to us by a
  /// [DuckRouterDeepLinkHandler]. Those never went through a navigate of their
  /// own, so without this they sit on the stack while the router does not know
  /// about them, and decoding the stack later on - upon state restoration, or
  /// when the platform reports a new deeplink - throws a
  /// [LocationStackDecoderException].
  ///
  /// Locations that are already in the directory are left alone, so this never
  /// disturbs a completer that is waiting on a pop.
  LocationStack _register(LocationStack stack) {
    for (final l in stack.locations) {
      _configuration.addLocation(l);
    }
    return stack;
  }
}
