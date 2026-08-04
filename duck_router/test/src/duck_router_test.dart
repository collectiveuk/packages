// ignore_for_file: prefer_const_constructors, unawaited_futures

import 'dart:async';

import 'package:duck_router/src/configuration.dart';
import 'package:duck_router/src/duck_router.dart';
import 'package:duck_router/src/exception.dart';
import 'package:duck_router/src/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('Basic routing', () {
    testWidgets('match home route', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 1);
      expect(locations.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('can replace location', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(to: Page1Location(), replace: true);
      await tester.pumpAndSettle();
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/page1');
    });

    testWidgets('Pops', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: Page1Location(),
      );
      await tester.pumpAndSettle();
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 2);

      router.pop();
      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 1);
      expect(locations2.uri.path, '/home');
    });

    testWidgets('Pops via system back button', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: Page1Location(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 2);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 1);
      expect(locations2.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Sequential system back button pops maintain correct stack',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();
      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 3);

      // First back press: should remove Page2
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      var locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 2);
      expect(locations2.uri.path, '/home/page1');
      expect(find.byType(Page1Screen), findsOneWidget);

      // Second back press: should remove Page1
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 1);
      expect(locations2.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        'System back button does not modify stack when pop is not allowed',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(to: NonPoppableLocation());
      await tester.pumpAndSettle();

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 2);

      // PopScope(canPop: false) prevents the pop from succeeding,
      // so the stack should remain unchanged.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 2);
      expect(locations2.uri.path, '/home/non-poppable');
    });

    testWidgets('Pops until X', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: Page1Location(),
      );
      await tester.pumpAndSettle();
      router.navigate(
        to: Page2Location(),
      );
      await tester.pumpAndSettle();
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 3);

      router.popUntil((location) => location is HomeLocation);
      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 1);
      expect(locations2.uri.path, '/home');
    });

    testWidgets('Pops until X from nested flow', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: NestedChildRootLocation(),
      );
      await tester.pumpAndSettle();
      router.navigate(
        to: Child2Location(),
      );
      await tester.pumpAndSettle();
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 2);
      final nestedLocations = (locations.locations.last as StatefulLocation)
          .state
          .currentRouterDelegate
          .currentConfiguration;
      expect(nestedLocations.locations.length, 2);

      router.popUntil((location) => location is HomeLocation);
      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 1);
      expect(locations2.uri.path, '/home');
    });

    testWidgets('can popUntil just one pop', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: Page1Location(),
      );
      await tester.pumpAndSettle();
      router.navigate(
        to: Page2Location(),
      );
      await tester.pumpAndSettle();
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 3);

      router.popUntil((location) => location is Page1Location);
      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 2);
      expect(locations2.uri.path, '/home/page1');
    });

    testWidgets('Does nothing for popUntil if already in the location',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      await tester.pumpAndSettle();

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 1);
      expect(locations.uri.path, '/home');

      router.popUntil((location) => location is HomeLocation);
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 1);
      expect(locations2.uri.path, '/home');
    });

    /// Screen A --- navigates to and waits for result of ---> Screen B
    /// Screen B --- navigates to ---> Screen C
    /// Screen C --- popUntil Screen A with result ---> Screen A
    testWidgets('popUntil with result returns result to awaiting location',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      // Screen A navigates to Screen B and awaits result
      int result = 0;
      router
          .navigate<int>(
        to: Page1Location(),
      )
          .then((value) {
        return result = value!;
      });
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      // Screen B navigates to Screen C and awaits result
      bool screenBCompleted = false;
      int? screenBResult = -1;
      router
          .navigate<int>(
        to: Page2Location(),
      )
          .then((value) {
        screenBCompleted = true;
        screenBResult = value;
      });
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.locations.length, 3);

      // Screen C pops until Screen A with result
      router.popUntil((location) => location is HomeLocation, 42);
      await tester.pumpAndSettle();

      final locations3 = router.routerDelegate.currentConfiguration;
      expect(locations3.locations.length, 1);
      expect(locations3.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(result, equals(42));
      expect(screenBCompleted, isTrue);
      expect(screenBResult, isNull);
    });

    testWidgets('Resets to root', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: Page1Location(),
      );
      await tester.pumpAndSettle();

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 2);

      router.root();

      final locations2 = router.routerDelegate.currentConfiguration;

      expect(locations2.uri.path, '/home');
    });

    testWidgets('Clears stack', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: Page1Location(),
      );
      await tester.pumpAndSettle();
      router.navigate(
        to: Page2Location(),
      );
      await tester.pumpAndSettle();

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 3);

      router.navigate(to: LoginLocation(), clearStack: true);
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;

      expect(locations2.uri.path, '/login');
    });

    testWidgets('Does not reset when already in root', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: RootLocation(),
        replace: true,
      );
      await tester.pumpAndSettle();
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');
      router.navigate(
        to: HomeLocation(),
        replace: true,
      );
      await tester.pumpAndSettle();

      router.root();
      await tester.pumpAndSettle();
      final locations3 = router.routerDelegate.currentConfiguration;
      expect(locations3.uri.path, '/root');

      router.root();

      await tester.pumpAndSettle();
      final locations4 = router.routerDelegate.currentConfiguration;
      expect(locations4.uri.path, '/root');
    });

    testWidgets('can await navigate', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      int result = 0;
      router
          .navigate<int>(
        to: Page1Location(),
      )
          .then((value) {
        return result = value!;
      });
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      router.pop(1);
      await tester.pumpAndSettle();

      expect(result, equals(1));
    });

    /// Screen A --- navigates to and waits for result of ---> Screen B
    /// Screen B --- navigates to with replace:true ---> Screen C
    /// Screen C --- pops to ---> Screen A
    testWidgets('shows correct screen after replace and pop', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      int result = 0;
      router
          .navigate<int>(
        to: Page1Location(),
      )
          .then((value) {
        return result = value!;
      });
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      router.navigate(to: Page2Location(), replace: true);
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      router.pop(1);
      await tester.pumpAndSettle();

      expect(result, equals(1));
    });

    /// Screen A --- navigates to and waits for result of ---> Screen B
    /// Screen B --- navigates to with replace:true ---> Screen C
    /// Screen C --- pops to ---> Screen A
    testWidgets('can await navigate that gets replaced', (tester) async {
      const timeout = Duration(seconds: 10);

      // Initial screen A
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      /// A -> B: expect result 1 from B
      final navigateFuture1 = expectLater(
        router.navigate<int>(to: Page1Location()).timeout(timeout),
        completion(equals(1)),
      );
      await tester.pumpAndSettle();

      /// A -> B replaces to C: expect result 1 from C
      /// This is expected to produce result on its own and propagate result
      /// back to creator of B (to the screen A)
      final navigateFuture2 = expectLater(
        router.navigate(to: Page2Location(), replace: true).timeout(timeout),
        completion(equals(1)),
      );
      await tester.pumpAndSettle();

      /// C pops with result 1. This result should be delivered to function from
      /// screen B (the original caller) and to screen A (since C took place of B).
      router.pop(1);
      await tester.pumpAndSettle();

      await (
        navigateFuture1,
        navigateFuture2,
        tester.pump(Duration(seconds: 25)),
      ).wait;
    });

    testWidgets(
        'throws error if trying to return different type result in location that replaces another',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      // ignore: unused_local_variable
      int a = 0;
      Exception? exception;
      router
          .navigate<int>(
        to: Page1Location(),
      )
          .then((value) {
        return a = value!;
      }).catchError((e) {
        exception = e;
        return 0;
      });
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      router.navigate(to: Page2Location(), replace: true);
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      router.pop('different type than int');
      await tester.pumpAndSettle();
      expect(exception, isA<InvalidPopTypeException>());
    });

    testWidgets('Can return null when a page replacing a page is being awaited',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      int result = 0;
      router
          .navigate<int>(
        to: Page1Location(),
      )
          .then((value) {
        return result = value ?? 1;
      });
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      router.navigate(to: Page2Location(), replace: true);
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(result, equals(1));
    });

    testWidgets('can await navigate that gets cleared via clearStack',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      int result = 0;
      Exception? error;
      router
          .navigate<int>(
        to: Page1Location(),
      )
          .then((value) {
        return result = 1;
      }).catchError((e) {
        error = e;
        return 2;
      });
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      router.navigate(to: Page2Location(), clearStack: true);
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      expect(result, equals(0));
      expect(error, TypeMatcher<ClearStackException>());
    });

    testWidgets('can navigate to and from locations with arguments',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      final detailLocation = DetailLocation(message: 'Hello!');
      router.navigate(
        to: detailLocation,
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello!'), findsOneWidget);

      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();
      expect(find.text('Hello!'), findsNothing);
    });

    testWidgets('works with iOS', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouterOnIos(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 1);
      expect(locations.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('works with WidgetsApp', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouterOnWidgetsApp(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 1);
      expect(locations.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    group('Custom page', () {
      testWidgets('can specify custom page', (tester) async {
        final config = DuckRouterConfiguration(
          initialLocation: CustomPageLocation(),
        );

        final router = await createRouterOnIos(config, tester);
        final locations = router.routerDelegate.currentConfiguration;
        expect(locations.locations.length, 1);
        expect(locations.uri.path, '/custom-page');
        expect(find.byType(CustomScreen), findsOneWidget);
      });

      testWidgets('can await navigate to custom page', (tester) async {
        final config = DuckRouterConfiguration(
          initialLocation: HomeLocation(),
        );

        final router = await createRouter(config, tester);
        final locations = router.routerDelegate.currentConfiguration;
        expect(locations.uri.path, '/home');

        int result = 0;
        router.navigate<int>(to: CustomPageLocation()).then((value) {
          return result = value!;
        });
        await tester.pumpAndSettle();
        expect(find.byType(CustomScreen), findsOneWidget);

        router.pop(1);
        await tester.pumpAndSettle();

        expect(result, equals(1));
      });

      testWidgets('can specify custom page transition', (tester) async {
        final config = DuckRouterConfiguration(
          initialLocation: CustomPageTransitionLocation(),
        );

        final router = await createRouterOnIos(config, tester);
        final locations = router.routerDelegate.currentConfiguration;
        expect(locations.locations.length, 1);
        expect(locations.uri.path, '/custom-page-transition');
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('Can pop from custom page', (tester) async {
        final config = DuckRouterConfiguration(
          initialLocation: HomeLocation(),
        );

        final router = await createRouter(config, tester);
        router.navigate(to: CustomPageLocation());
        await tester.pumpAndSettle();
        final locations = router.routerDelegate.currentConfiguration;
        expect(locations.locations.length, 2);
        expect(locations.uri.path, '/home/custom-page');
        expect(find.byType(CustomScreen), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();
        final locations2 = router.routerDelegate.currentConfiguration;
        expect(locations2.locations.length, 1);
        expect(locations2.uri.path, '/home');
      });

      testWidgets('Throws error when custom page does not override createRoute',
          (tester) async {
        late BuildContext context;

        await tester.pumpWidget(
          Builder(builder: (c) {
            context = c;
            return Container();
          }),
        );

        final page = FaultyCustomPage();
        try {
          page.createRoute(context, null);
          fail('Should have thrown an error');
        } catch (e) {
          expect(e, isInstanceOf<MissingCreateRouteException>());
        }
      });
    });

    /// See https://github.com/JaspervanRiet/duck_router/issues/78
    ///
    /// This test is to ensure that when navigating to a new page while a pop transition is in progress,
    /// the stack is not corrupted.
    testWidgets(
        'Navigating to a new page while a pop transition is in progress does not corrupt the stack',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);

      // Navigate to Page1 (the underlying screen)
      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      // Navigate to Page2 (e.g. a modal shown on top of Page1)
      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      var locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 3);

      // Pop Page2 but do NOT wait for the transition to finish.
      // This simulates the user closing a modal and immediately
      // tapping a button on the underlying screen.
      router.pop();
      await tester.pump();

      // While the pop animation is still in progress, navigate to Page3.
      router.navigate(to: Page3Location());
      await tester.pumpAndSettle();

      locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/page1/page3');
      expect(find.byType(Page3Screen), findsOneWidget);

      // Now pop Page3 — should return to Page1, not Page2.
      router.pop();
      await tester.pumpAndSettle();

      locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 2);
      expect(locations.uri.path, '/home/page1');
      expect(find.byType(Page1Screen), findsOneWidget);
      expect(find.byType(Page2Screen), findsNothing);
    });

    /// When rapidly popping a page and then pushing the
    /// same page back, the _onDidRemovePage callback (which fires after
    /// the transition animation completes) must not remove the newly
    /// pushed page from the stack. Because pages are matched by path,
    /// the callback could incorrectly match the new page and remove it.
    testWidgets(
        'Rapidly popping and re-pushing the same page does not corrupt the stack',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);

      // Build up a stack: Home -> Page1 -> Page2
      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();
      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();

      var locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 3);
      expect(locations.uri.path, '/home/page1/page2');

      // Pop Page2 but do NOT wait for the transition to finish.
      router.pop();
      await tester.pump();

      // While the pop animation is still in progress, push the same
      // page (Page2) back onto the stack.
      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();

      // The new Page2 should be on the stack.
      locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 3);
      expect(locations.uri.path, '/home/page1/page2');
      expect(find.byType(Page2Screen), findsOneWidget);

      // Popping should go back to Page1.
      router.pop();
      await tester.pumpAndSettle();

      locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 2);
      expect(locations.uri.path, '/home/page1');
      expect(find.byType(Page1Screen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    /// See https://github.com/JaspervanRiet/duck_router/issues/40
    ///
    /// This test is to ensure that the router does not error when
    /// it has to restore itself.
    testWidgets('Does not error when refreshing app', (tester) async {
      StreamController<int> streamController =
          StreamController<int>.broadcast();

      addTearDown(() {
        streamController.close();
      });

      await tester.pumpWidget(
        RefreshableApp(stream: streamController.stream),
      );

      // This will navigate to a new page. We do this
      // to ensure that we're not just fixing a duplication issue
      // for the initial location, but in general instead.
      streamController.add(1);
      await tester.pumpAndSettle();

      // This will trigger a rebuild of the app,
      // including the router. That will trigger
      // a restoration of the router.
      streamController.add(2);
      await tester.pumpAndSettle();
    });
  });

  group('Interceptors', () {
    testWidgets('can intercept a location', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        interceptors: [
          AuthInterceptor(isLoggedIn: () => false),
        ],
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: SensitiveLocation(),
      );
      await tester.pumpAndSettle();

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/login');
    });

    testWidgets('Preserves routing functionality when intercepting',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        interceptors: [
          AuthInterceptor(isLoggedIn: () => false),
        ],
      );

      final router = await createRouter(config, tester);
      router.navigate(
        to: SensitiveLocation(),
      );
      await tester.pumpAndSettle();

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/login');
    });

    testWidgets('Goes through as expected when not intercepting',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        interceptors: [
          AuthInterceptor(isLoggedIn: () => true),
        ],
      );

      final router = await createRouter(config, tester);

      router.navigate(to: Page1Location());

      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);
      var locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/page1');

      router.navigate(
        to: SensitiveLocation(),
      );
      await tester.pumpAndSettle();

      locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/page1/sensitive');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);
      locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/page1');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');
    });

    testWidgets('Pushes on top if specified', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        interceptors: [
          PushesOnTopInterceptor(),
        ],
      );

      final router = await createRouter(config, tester);
      await tester.pumpAndSettle();

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/page1');
    });

    testWidgets('Preserves whole routing path when pushing on top',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        interceptors: [
          ConditionallyPushesOnTopInterceptor(),
        ],
      );

      final router = await createRouter(config, tester);
      await tester.pumpAndSettle();

      router.navigate(to: Page1Location());

      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);
      var locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/page1');

      // this will be intercepted
      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();
      expect(find.byType(Page3Screen), findsOneWidget);
      locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/page1/page2/page3');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(Page2Screen), findsOneWidget);
      locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/page1/page2');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(Page1Screen), findsOneWidget);
      locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/page1');
    });

    testWidgets('Errors when pushing a route with a duplicate path',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      await tester.pumpAndSettle();

      // Second navigation to the same path
      expect(
        () => router.navigate(to: HomeLocation()),
        throwsA(isA<DuplicateRouteException>()),
      );

      await tester.pumpAndSettle();
    });
  });

  group('Nested navigation', () {
    testWidgets('can host a stateful location', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 1);
      expect(locations.uri.path, '/root');
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Page1Screen), findsOneWidget);
      expect(find.byType(Page2Screen), findsNothing);
    });

    testWidgets('can switch between tabs', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 1);
      expect(locations.uri.path, '/root');
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Page1Screen), findsOneWidget);
      expect(find.byType(Page2Screen), findsNothing);

      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsNothing);
      expect(find.byType(Page2Screen), findsOneWidget);
    });

    testWidgets('can push and pop inside stateful locations', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');

      router.navigate(to: HomeLocation());
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');
      final statefulLocation = locations2.locations.last as StatefulLocation;
      final child =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(child.uri.path, '/child1/home');
      expect(find.byType(HomeScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(
          statefulLocation
              .state.currentRouterDelegate.currentConfiguration.uri.path,
          '/child1');

      // Now we should start seeing an error because we're trying to pop
      // the root.
      expect(router.pop, throwsException);
    });

    testWidgets('can pop the root', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      var locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      router.navigate(to: RootLocation());
      await tester.pumpAndSettle();

      locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home/root');

      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;
      final statefulLocation = locations2.locations.last as StatefulLocation;
      final child =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(child.uri.path, '/child1/page1');
      expect(find.byType(Page1Screen), findsOneWidget);

      router.exit();
      locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');
    });

    testWidgets('can clear stack in nested locations', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');

      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();

      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.uri.path, '/root');
      final statefulLocation = locations2.locations.last as StatefulLocation;
      final child =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(child.uri.path, '/child1/page1/page2');
      expect(find.byType(Page2Screen), findsOneWidget);

      router.navigate(to: HomeLocation(), clearStack: true);
      await tester.pumpAndSettle();
      expect(
          statefulLocation
              .state.currentRouterDelegate.currentConfiguration.uri.path,
          '/home');
    });

    testWidgets('can clear root stack from nested location', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');

      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();

      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations2.uri.path, '/root');
      final statefulLocation = locations2.locations.last as StatefulLocation;
      final child =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(child.uri.path, '/child1/page1/page2');
      expect(find.byType(Page2Screen), findsOneWidget);

      router.navigate(to: HomeLocation(), clearStack: true, root: true);
      await tester.pumpAndSettle();
      final locations3 = router.routerDelegate.currentConfiguration;
      expect(locations3.uri.path, '/home');
    });

    testWidgets('Can popUntil in nested locations', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');

      router.navigate(to: HomeLocation());
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      router.popUntil((location) => location is HomeLocation);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('can replace location', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');

      router.navigate(to: HomeLocation(), replace: true);
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');
      final statefulLocation = locations2.locations.last as StatefulLocation;
      final child =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(child.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('can still push to root navigator', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);

      router.navigate(to: HomeLocation(), root: true);
      await tester.pumpAndSettle();

      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root/home');
    });

    testWidgets('can mix pushing to root and pushing to nested',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');

      router.navigate(to: HomeLocation());
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      router.navigate(to: HomeLocation(), root: true);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);
    });

    testWidgets(
        'can pop a root push back to the shell while on a non-first child',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);

      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      router.navigate(to: HomeLocation(), root: true);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Page2Screen), findsOneWidget);
    });

    testWidgets('can await navigate', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');

      int result = 0;
      router.navigate<int>(to: HomeLocation()).then((value) {
        return result = value!;
      });
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      router.pop(1);
      await tester.pumpAndSettle();

      expect(result, equals(1));
    });

    testWidgets('Child back button dispatcher handles back button press',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);

      // Navigate to a child route
      router.navigate(to: HomeLocation());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Simulate a back button press
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(Page1Screen), findsOneWidget);
    });

    testWidgets('Nested back button handling works correctly', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);

      // Navigate to a child route
      router.navigate(to: HomeLocation());
      await tester.pumpAndSettle();

      // Navigate to another child route
      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();

      expect(find.byType(Page1Screen), findsOneWidget);

      // Simulate a back button press
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Check if we've returned to the HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(Page1Screen), findsNothing);

      // Simulate another back button press
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Should now be at first page of RootLocation
      // Which is the Page1Screen
      expect(find.byType(Page1Screen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Try to go back again (should stay at RootLocation)
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Should still be at RootLocation
      expect(find.byType(Page1Screen), findsOneWidget);
    });

    // Regression test for issue #74:
    // https://github.com/JaspervanRiet/duck_router/issues/74
    // Back button should not traverse inactive tab's navigation stack
    testWidgets(
        'Back button does not traverse inactive tab stack after switching tabs',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      await tester.pumpAndSettle();

      // Verify we're on tab 1 (Child1) at root
      expect(find.byType(Page1Screen), findsOneWidget);
      expect(find.byType(Page2Screen), findsNothing);

      final rootLocation = router
          .routerDelegate.currentConfiguration.locations.first as RootLocation;
      final shellState = rootLocation.state;

      // Step 1: Navigate deep in Child1 (Tab A)
      // Child1 -> Home -> Page1 (2 levels deep)
      router.navigate(to: HomeLocation());
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      // Verify we're 3 levels deep in child1's stack
      final child1Stack = shellState.currentRouterDelegate.currentConfiguration;
      expect(child1Stack.locations.length, 3);
      expect(child1Stack.locations[0], isA<Child1Location>());
      expect(child1Stack.locations[1], isA<HomeLocation>());
      expect(child1Stack.locations[2], isA<Page1Location>());

      // Step 2: Switch to Child2 (Tab B)
      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();

      // Verify we're now on child2, which should be at root (1 level)
      expect(find.byType(Page2Screen), findsOneWidget);
      expect(find.byType(Page1Screen), findsNothing);

      final child2Stack = shellState.currentRouterDelegate.currentConfiguration;
      expect(child2Stack.locations.length, 1);
      expect(child2Stack.locations[0], isA<Child2Location>());

      // Step 3: Press back button multiple times while on Child2
      // This should NOT affect Child1's stack since it's inactive

      // Press back button 3 times
      for (var i = 0; i < 3; i++) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }

      // Verify Child1's stack was NOT modified
      await tester.tap(find.text('Page 1'));
      await tester.pumpAndSettle();
      final child1FinalSize = shellState
          .currentRouterDelegate.currentConfiguration.locations.length;

      // Switch back to Child2 to verify its stack
      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();
      final child2FinalSize = shellState
          .currentRouterDelegate.currentConfiguration.locations.length;

      // The bug was: Child1's stack would get popped even though it's not visible
      // Expected behavior: Child1 should still have 3 locations
      expect(
        child1FinalSize,
        3,
        reason: 'Bug #74: Child1 (inactive tab) stack should not be modified '
            'when back button is pressed while viewing Child2',
      );

      // Child2 should still be at root
      expect(
        child2FinalSize,
        1,
        reason: 'Child2 should still be at root',
      );
    });

    // Regression test for other bug in issue #74:
    // https://github.com/JaspervanRiet/duck_router/issues/74#issuecomment-2534896635
    // When navigating from deep inside a tab to a root-level screen,
    // back button should exit immediately, not traverse the tab's stack
    testWidgets(
        'Back button should exit immediately from root screen after navigating from deep tab stack',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      await tester.pumpAndSettle();

      // Verify we're on tab 1 (Child1) at root
      expect(find.byType(Page1Screen), findsOneWidget);

      final rootLocation = router
          .routerDelegate.currentConfiguration.locations.first as RootLocation;
      final shellState = rootLocation.state;

      // Step 1: Navigate deep inside Child1 (Tab A)
      // Child1 -> Home -> Page2 (2 levels deep)
      router.navigate(to: HomeLocation());
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      // Verify we're 3 levels deep in child1's stack
      final child1Stack = shellState.currentRouterDelegate.currentConfiguration;
      expect(child1Stack.locations.length, 3);
      expect(child1Stack.locations[0], isA<Child1Location>());
      expect(child1Stack.locations[1], isA<HomeLocation>());
      expect(child1Stack.locations[2], isA<Page2Location>());

      // Step 2: Navigate to a root-level screen
      router.navigate(to: LoginLocation(), root: true);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(Page2Screen), findsNothing);

      final rootStack = router.routerDelegate.currentConfiguration;
      expect(rootStack.locations.length, 2);
      expect(rootStack.locations[0], isA<RootLocation>());
      expect(rootStack.locations[1], isA<LoginLocation>());

      // Step 3: Press back button once
      // Expected: Should pop back to RootLocation (the tab view)
      // Bug: Have to press back multiple times (as many as screens in the tab)
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // After one back press, we should be back at RootLocation
      final rootStackAfterPop = router.routerDelegate.currentConfiguration;
      expect(
        rootStackAfterPop.locations.length,
        1,
        reason: 'Bug #74 (latest comment): Should only need one back press to '
            'return to RootLocation, not multiple presses for each screen '
            'that was in the tab stack',
      );
      expect(rootStackAfterPop.locations[0], isA<RootLocation>());

      // We should be seeing the tab view again (Child1's stack should be preserved)
      expect(find.byType(Page2Screen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // Now should be able to traverse all the way back up to root
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(Page2Screen), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(Page1Screen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('can reset', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');

      router.navigate(to: HomeLocation());
      await tester.pumpAndSettle();

      final locations2 = router.routerDelegate.currentConfiguration;
      final statefulLocation = locations2.locations.last as StatefulLocation;
      final child =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(child.uri.path, '/child1/home');
      expect(find.byType(HomeScreen), findsOneWidget);

      router.root();
      await tester.pumpAndSettle();
      expect(
          statefulLocation
              .state.currentRouterDelegate.currentConfiguration.uri.path,
          '/child1');

      // Now we should start seeing an error because we're trying to pop
      // the root.
      expect(router.pop, throwsException);
    });

    testWidgets('can await navigate that gets cleared via clearStack',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/root');

      int result = 0;
      Exception? error;
      router
          .navigate<int>(
        to: Page1Location(),
      )
          .then((value) {
        return result = 1;
      }).catchError((e) {
        error = e;
        return 2;
      });
      await tester.pumpAndSettle();
      expect(find.byType(Page1Screen), findsOneWidget);

      router.navigate(to: Page2Location(), clearStack: true);
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      expect(result, equals(0));
      expect(error, TypeMatcher<ClearStackException>());
    });

    /// Screen A --- opens nested screen B
    /// Screen B --- navigates to and waits for result of ---> Screen C
    /// Screen C --- exits ---> Screen A
    /// Screen B's navigate should throw a ClearStackException
    testWidgets('can await navigate that gets cleared via exit',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      router.navigate(to: NestedChildRootLocation());
      await tester.pumpAndSettle();

      int result = 0;
      Exception? error;
      router
          .navigate<int>(
        to: Page2Location(),
      )
          .then((value) {
        return result = 1;
      }).catchError((e) {
        error = e;
        return 2;
      });
      await tester.pumpAndSettle();
      expect(find.byType(Page2Screen), findsOneWidget);

      router.exit();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      expect(result, equals(0));
      expect(error, TypeMatcher<ClearStackException>());
    });

    /// Screen A --- opens nested screen B
    /// Screen B --- navigates to and waits for result of ---> Screen C
    /// Screen C --- navigates to with replace:true ---> Screen D
    /// Screen D --- pops to ---> Screen B
    testWidgets('shows correct screen after replace and pop', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      router.navigate(to: RootLocation());
      await tester.pumpAndSettle();

      expect(find.byType(Page1Screen), findsOneWidget);

      int result = 0;
      router
          .navigate<int>(
        to: Page2Location(),
      )
          .then((value) {
        return result = value!;
      });
      await tester.pumpAndSettle();

      router.navigate(to: Page3Location(), replace: true);
      await tester.pumpAndSettle();

      expect(find.byType(Page3Screen), findsOneWidget);

      router.pop(1);
      await tester.pumpAndSettle();

      expect(find.byType(Page1Screen), findsOneWidget);

      expect(result, equals(1));
    });

    /// Screen A --- opens nested screen B
    /// Screen B --- navigates to and waits for result of ---> Screen C
    /// Screen C --- navigates to with replace:true ---> Screen D
    /// Screen D --- pops to ---> Screen B
    testWidgets('can await navigate that gets replaced', (tester) async {
      const timeout = Duration(seconds: 10);

      // Initial screen A
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      /// A -> B: expect timeout, since we never pop it
      final navigateFuture1 = expectLater(
        router.navigate(to: RootLocation()).timeout(timeout),
        throwsA(isA<TimeoutException>()),
      );
      await tester.pumpAndSettle();

      /// A -> B -> C: expect result 1 from C
      final navigateFuture2 = expectLater(
        router.navigate<int>(to: Page2Location()).timeout(timeout),
        completion(equals(1)),
      );
      await tester.pumpAndSettle();

      /// A -> B -> C replaces to D: expect result 1 from D
      /// This is expected to produce result on its own and propagate result
      /// back to creator of C (to the screen B)
      final navigateFuture3 = expectLater(
        router.navigate(to: Page3Location(), replace: true).timeout(timeout),
        completion(equals(1)),
      );
      await tester.pumpAndSettle();

      /// D pops with result 1. This result should be delivered to function from
      /// screen C (the original caller) and to screen B (since D took place of C).
      router.pop(1);
      await tester.pumpAndSettle();

      await (
        navigateFuture1,
        navigateFuture2,
        navigateFuture3,
        tester.pump(Duration(seconds: 25)),
      ).wait;
    });

    /// Screen A -> Screen B (awaited, timeout)
    /// Screen B -> Screen C (awaited, result 42)
    /// Screen C -> Screen D (replaced, result 42)
    /// Screen D -> Screen E (replaced, result 42)
    /// Screen E -> Screen F (replaced, result 42)
    /// Screen F -> Screen G (replaced, result 42)
    /// Screen G pops with result 42, which should propagate back through the chain
    testWidgets(
        'can handle more awaited navigations with multiple replacements',
        (tester) async {
      const timeout = Duration(seconds: 15);

      // Initial screen A
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      final locations = router.routerDelegate.currentConfiguration;
      expect(locations.uri.path, '/home');

      /// A -> B: expect timeout, since we never pop it
      final navigateFuture1 = expectLater(
        router.navigate(to: RootLocation()).timeout(timeout),
        throwsA(isA<TimeoutException>()),
      );
      await tester.pumpAndSettle();

      /// A -> B -> C: expect result 42 from C
      final navigateFuture2 = expectLater(
        router.navigate<int>(to: Page2Location()).timeout(timeout),
        completion(equals(42)),
      );
      await tester.pumpAndSettle();

      /// A -> B -> C replaces to D: expect result 42 from D
      final navigateFuture3 = expectLater(
        router.navigate(to: Page3Location(), replace: true).timeout(timeout),
        completion(equals(42)),
      );
      await tester.pumpAndSettle();

      /// A -> B -> D replaces to E: expect result 42 from E
      final navigateFuture4 = expectLater(
        router.navigate(to: Page1Location(), replace: true).timeout(timeout),
        completion(equals(42)),
      );
      await tester.pumpAndSettle();

      /// A -> B -> E replaces to F: expect result 42 from F
      final navigateFuture5 = expectLater(
        router.navigate(to: LoginLocation(), replace: true).timeout(timeout),
        completion(equals(42)),
      );
      await tester.pumpAndSettle();

      /// A -> B -> F replaces to G: expect result 42 from G
      final navigateFuture6 = expectLater(
        router.navigate(to: Page4Location(), replace: true).timeout(timeout),
        completion(equals(42)),
      );
      await tester.pumpAndSettle();

      /// F pops with result 42. This result should be delivered to function from
      /// screen F (the original caller) and propagate back through the entire chain
      router.pop(42);
      await tester.pumpAndSettle();

      await (
        navigateFuture1,
        navigateFuture2,
        navigateFuture3,
        navigateFuture4,
        navigateFuture5,
        navigateFuture6,
        tester.pump(Duration(seconds: 30)),
      ).wait;
    });

    group('Custom', () {
      testWidgets('can host', (tester) async {
        final config = DuckRouterConfiguration(
          initialLocation: RootLocationWithCustomPage(),
        );

        final router = await createRouter(config, tester);
        final locations = router.routerDelegate.currentConfiguration;
        expect(locations.locations.length, 1);
        expect(locations.uri.path, '/root');
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(CustomScreen), findsOneWidget);
        expect(find.byType(Page2Screen), findsNothing);
      });

      testWidgets('Can pop from custom page', (tester) async {
        final config = DuckRouterConfiguration(
          initialLocation: RootLocation(),
        );

        final router = await createRouter(config, tester);
        await tester.pumpAndSettle();
        router.navigate(to: CustomPageLocation());
        await tester.pumpAndSettle();
        expect(find.byType(CustomScreen), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(Page1Screen), findsOneWidget);
      });
    });

    group('FlowLocation', () {
      testWidgets('can navigate to page', (tester) async {
        final config = DuckRouterConfiguration(
          initialLocation: HomeLocation(),
        );

        final router = await createRouter(config, tester);
        await tester.pumpAndSettle();
        router.navigate(to: TestFlowLocation());
        await tester.pumpAndSettle();
        expect(find.byType(Page1Screen), findsOneWidget);
        final locations = router.routerDelegate.currentConfiguration;
        expect(locations.uri.path, '/home/flow');
      });

      testWidgets('can navigate to another page from start', (tester) async {
        final config = DuckRouterConfiguration(
          initialLocation: HomeLocation(),
        );

        final router = await createRouter(config, tester);
        await tester.pumpAndSettle();
        router.navigate(to: TestFlowLocation());
        await tester.pumpAndSettle();
        expect(find.byType(Page1Screen), findsOneWidget);
        router.navigate(to: Page2Location());
        await tester.pumpAndSettle();
        expect(find.byType(Page2Screen), findsOneWidget);
        final locations = router.routerDelegate.currentConfiguration;
        expect(locations.uri.path, '/home/flow');
        final flowLocation = locations.locations.last as FlowLocation;
        final innerLocations =
            flowLocation.state.currentRouterDelegate.currentConfiguration;
        expect(innerLocations.uri.path, '/page1/page2');
      });

      testWidgets('can render with container', (tester) async {
        final config = DuckRouterConfiguration(
          initialLocation: HomeLocation(),
        );

        final router = await createRouter(config, tester);
        await tester.pumpAndSettle();
        router.navigate(to: TestFlowLocationWithContainer());
        await tester.pumpAndSettle();
        expect(find.byType(Page1Screen), findsOneWidget);
      });
    });

    testWidgets('nested provider value reflects current stack after pop',
        (tester) async {
      final streamController = StreamController<int>.broadcast();
      addTearDown(() => streamController.close());

      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = DuckRouter.withConfig(configuration: config);
      final appKey = GlobalKey();

      await tester.pumpWidget(
        StreamBuilder(
          stream: streamController.stream,
          builder: (context, snapshot) {
            Widget child = KeyedSubtree(
              key: appKey,
              child: MaterialApp.router(routerConfig: router),
            );
            if (snapshot.data == 3) {
              child = Container(child: child);
            }
            return child;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Navigate inside the nested (stateful) location.
      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();

      final statefulLocation = router.routerDelegate.currentConfiguration
          .locations.last as StatefulLocation;
      var innerConfig =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(innerConfig.uri.path, '/child1/page2');

      // Pop inside the nested stack.
      router.pop();
      await tester.pumpAndSettle();

      innerConfig =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(innerConfig.locations.length, 1);
      expect(innerConfig.uri.path, '/child1');

      // Trigger a rebuild (simulates hot reload).
      streamController.add(3);
      await tester.pumpAndSettle();

      // The popped page should NOT reappear.
      innerConfig =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(
        innerConfig.locations.length,
        1,
        reason: 'Nested provider value should be updated after pop. '
            'A stale value causes hot reload to re-push the popped route.',
      );
      expect(innerConfig.uri.path, '/child1');
    });

    testWidgets(
        'nested provider value reflects current stack after back button pop',
        (tester) async {
      final streamController = StreamController<int>.broadcast();
      addTearDown(() => streamController.close());

      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
      );

      final router = DuckRouter.withConfig(configuration: config);

      await tester.pumpWidget(
        StreamBuilder(
          stream: streamController.stream,
          builder: (context, snapshot) {
            Widget child = MaterialApp.router(routerConfig: router);
            if (snapshot.data == 3) {
              child = Container(child: child);
            }
            return child;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Navigate inside the nested (stateful) location.
      router.navigate(to: Page2Location());
      await tester.pumpAndSettle();

      final statefulLocation = router.routerDelegate.currentConfiguration
          .locations.last as StatefulLocation;
      var innerConfig =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(innerConfig.uri.path, '/child1/page2');

      // Pop inside the nested stack via system back button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      innerConfig =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(innerConfig.locations.length, 1);
      expect(innerConfig.uri.path, '/child1');

      // Trigger a rebuild (simulates hot reload).
      streamController.add(3);
      await tester.pumpAndSettle();

      // The popped page should NOT reappear.
      innerConfig =
          statefulLocation.state.currentRouterDelegate.currentConfiguration;
      expect(
        innerConfig.locations.length,
        1,
        reason: 'Nested provider value should be updated after back button '
            'pop. A stale value causes hot reload to re-push the popped route.',
      );
      expect(innerConfig.uri.path, '/child1');
    });

    testWidgets('provider value reflects current stack after pop',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      await tester.pumpAndSettle();

      // Navigate to Page1.
      router.navigate(to: Page1Location());
      await tester.pumpAndSettle();

      var locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 2);
      expect(locations.uri.path, '/home/page1');

      // Verify provider value points to Page1.
      expect(router.routeInformationProvider.currentLocation,
          isA<Page1Location>());

      // Pop Page1.
      router.pop();
      await tester.pumpAndSettle();

      locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 1);
      expect(locations.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);

      // BUG: After pop, provider value should reflect the current stack
      // (HomeLocation), but it still points to the popped Page1Location.
      expect(
        router.routeInformationProvider.currentLocation,
        isA<HomeLocation>(),
        reason: 'Provider value should be updated after pop to reflect '
            'the current stack. A stale value causes hot reload to '
            're-push the popped route.',
      );
    });

    testWidgets('provider value reflects current stack after back button pop',
        (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(config, tester);
      await tester.pumpAndSettle();

      // Navigate to a FlowLocation.
      router.navigate(to: TestFlowLocation());
      await tester.pumpAndSettle();

      var locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 2);

      // Verify provider value points to the flow.
      expect(router.routeInformationProvider.currentLocation,
          isA<TestFlowLocation>());

      // Pop via system back button (bypasses DuckRouter.pop).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      locations = router.routerDelegate.currentConfiguration;
      expect(locations.locations.length, 1);
      expect(locations.uri.path, '/home');

      // After back button pop, provider value should reflect current stack.
      expect(
        router.routeInformationProvider.currentLocation,
        isA<HomeLocation>(),
        reason: 'Provider value should be updated after back button pop. '
            'A stale value causes hot reload to re-push the popped route.',
      );
    });

    testWidgets('dispose tears down the delegate and provider', (tester) async {
      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = DuckRouter.withConfig(configuration: config);

      router.dispose();

      // Calling dispose() again on an already-disposed ChangeNotifier throws,
      // which lets us assert disposal happened on both components.
      expect(() => router.routerDelegate.dispose(), throwsFlutterError);
      expect(
        () => router.routeInformationProvider.dispose(),
        throwsFlutterError,
      );
    });
  });

  group('Deeplinking', () {
    testWidgets('receives deep links', (tester) async {
      final binding = _retrieveTestBinding(tester);
      binding.platformDispatcher.defaultRouteNameTestValue = '/page1';

      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        onDeepLink: (deeplink, initialLocation) {
          return [Page1Location()];
        },
      );

      final router = await createRouter(
        config,
        tester,
      );
      final locations = router.routerDelegate.currentConfiguration;
      await tester.pumpAndSettle();

      expect(locations.uri.path, '/page1');
      expect(find.byType(Page1Screen), findsOneWidget);
    });

    testWidgets('handles full URLs', (tester) async {
      final binding = _retrieveTestBinding(tester);
      binding.platformDispatcher.defaultRouteNameTestValue =
          'https://app.onsi.com/page1';

      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        onDeepLink: (deeplink, initialLocation) {
          if (deeplink.path == '/page1') {
            return [Page1Location()];
          }
          return [HomeLocation()];
        },
      );

      final router = await createRouter(
        config,
        tester,
      );
      final locations = router.routerDelegate.currentConfiguration;
      await tester.pumpAndSettle();

      expect(locations.uri.path, '/page1');
      expect(find.byType(Page1Screen), findsOneWidget);
    });

    testWidgets('ignores deep links if no handler set', (tester) async {
      final binding = _retrieveTestBinding(tester);
      binding.platformDispatcher.defaultRouteNameTestValue = '/page1';

      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
      );

      final router = await createRouter(
        config,
        tester,
      );
      final locations = router.routerDelegate.currentConfiguration;
      await tester.pumpAndSettle();

      expect(locations.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(Page1Screen), findsNothing);
    });

    testWidgets(
        'ignores deep links if location stack returned (supports the fire-and-forget scenario)',
        (tester) async {
      final binding = _retrieveTestBinding(tester);
      binding.platformDispatcher.defaultRouteNameTestValue = '/page1';

      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        onDeepLink: (_, __) => null,
      );

      final router = await createRouter(
        config,
        tester,
      );
      final locations = router.routerDelegate.currentConfiguration;
      await tester.pumpAndSettle();

      expect(locations.uri.path, '/home');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(Page1Screen), findsNothing);
    });

    testWidgets('sends empty deep link to initial location', (tester) async {
      final binding = _retrieveTestBinding(tester);
      binding.platformDispatcher.defaultRouteNameTestValue = '';

      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        onDeepLink: (deeplink, initialLocation) {
          return [Page1Location()];
        },
      );

      final router = await createRouter(
        config,
        tester,
      );
      final locations = router.routerDelegate.currentConfiguration;
      await tester.pumpAndSettle();

      expect(locations.uri.path, '/home');
    });

    testWidgets('classes base URL as empty deep link', (tester) async {
      final binding = _retrieveTestBinding(tester);
      binding.platformDispatcher.defaultRouteNameTestValue =
          'https://google.com';

      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        onDeepLink: (deeplink, initialLocation) {
          return [Page1Location()];
        },
      );

      final router = await createRouter(
        config,
        tester,
      );
      final locations = router.routerDelegate.currentConfiguration;
      await tester.pumpAndSettle();

      expect(locations.uri.path, '/home');
    });

    testWidgets('handles deep link while router is active', (tester) async {
      final binding = _retrieveTestBinding(tester);
      binding.platformDispatcher.defaultRouteNameTestValue = '';

      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        onDeepLink: (deeplink, initialLocation) {
          return [Page1Location()];
        },
      );

      final router = await createRouter(
        config,
        tester,
      );
      final locations = router.routerDelegate.currentConfiguration;
      await tester.pumpAndSettle();

      expect(locations.uri.path, '/home');

      const Map<String, dynamic> testRouteInformation = <String, dynamic>{
        'location': '/page1',
        'state': 'state',
        'restorationData': <dynamic, dynamic>{'test': 'config'},
      };
      final ByteData message = const JSONMethodCodec().encodeMethodCall(
        const MethodCall('pushRouteInformation', testRouteInformation),
      );

      await tester.binding.defaultBinaryMessenger
          .handlePlatformMessage('flutter/navigation', message, (_) {});

      await tester.pumpAndSettle();
      final locations2 = router.routerDelegate.currentConfiguration;

      expect(locations2.uri.path, '/page1');
    });

    testWidgets(
        'handles deep link while router is active but returns null as location stack',
        (tester) async {
      final binding = _retrieveTestBinding(tester);
      binding.platformDispatcher.defaultRouteNameTestValue = '';

      final config = DuckRouterConfiguration(
        initialLocation: HomeLocation(),
        onDeepLink: (deeplink, initialLocation) {
          return null;
        },
      );

      final router = await createRouter(
        config,
        tester,
      );
      final locations = router.routerDelegate.currentConfiguration;
      await tester.pumpAndSettle();

      expect(locations.uri.path, '/home');

      const Map<String, dynamic> testRouteInformation = <String, dynamic>{
        'location': '/page1',
        'state': 'state',
        'restorationData': <dynamic, dynamic>{'test': 'config'},
      };
      final ByteData message = const JSONMethodCodec().encodeMethodCall(
        const MethodCall('pushRouteInformation', testRouteInformation),
      );

      await tester.binding.defaultBinaryMessenger
          .handlePlatformMessage('flutter/navigation', message, (_) {});

      await tester.pumpAndSettle();
      final locations2 = router.routerDelegate.currentConfiguration;

      expect(locations2.uri.path, '/home');
    });

    // We intentionally do not support this feature, see
    // [_platformReportsNewRouteInformation] in [DuckInformationProvider].
    testWidgets('does not start nesting for the user', (tester) async {
      final binding = _retrieveTestBinding(tester);
      binding.platformDispatcher.defaultRouteNameTestValue = '';

      final config = DuckRouterConfiguration(
        initialLocation: RootLocation(),
        onDeepLink: (deeplink, initialLocation) {
          return [
            RootLocation(),
            Child1Location(),
            HomeLocation(),
          ];
        },
      );

      final router = await createRouter(
        config,
        tester,
      );
      final locations = router.routerDelegate.currentConfiguration;
      await tester.pumpAndSettle();

      expect(locations.uri.path, '/root');

      const Map<String, dynamic> testRouteInformation = <String, dynamic>{
        'location': '/root/child1/home',
        'state': 'state',
        'restorationData': <dynamic, dynamic>{'test': 'config'},
      };
      final ByteData message = const JSONMethodCodec().encodeMethodCall(
        const MethodCall('pushRouteInformation', testRouteInformation),
      );

      await tester.binding.defaultBinaryMessenger
          .handlePlatformMessage('flutter/navigation', message, (_) {});

      await tester.pumpAndSettle();
      final locations2 = router.routerDelegate.currentConfiguration;

      expect(locations2.uri.path, '/root/child1/home');
    });
  });
}

TestWidgetsFlutterBinding _retrieveTestBinding(WidgetTester tester) {
  final WidgetsBinding binding = tester.binding;
  assert(binding is TestWidgetsFlutterBinding);
  final TestWidgetsFlutterBinding testBinding =
      binding as TestWidgetsFlutterBinding;
  return testBinding;
}

class PushRouteObserver with WidgetsBindingObserver {
  late String pushedRoute;

  @override
  Future<bool> didPushRoute(String route) async {
    pushedRoute = route;
    return true;
  }
}
