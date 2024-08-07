// ignore_for_file: prefer_const_constructors

import 'package:duck_router/src/configuration.dart';
import 'package:duck_router/src/duck_router.dart';
import 'package:duck_router/src/interceptor.dart';
import 'package:duck_router/src/location.dart';
import 'package:duck_router/src/pages/pages.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DuckRouter> createRouter(
  DuckRouterConfiguration routerConfiguration,
  WidgetTester tester, {
  String? restorationScopeId,
}) async {
  final router = DuckRouter.withConfig(
    configuration: routerConfiguration,
  );
  await tester.pumpWidget(
    MaterialApp.router(
      restorationScopeId:
          restorationScopeId != null ? '$restorationScopeId-root' : null,
      routerConfig: router,
    ),
  );
  return router;
}

Future<DuckRouter> createRouterOnIos(
  DuckRouterConfiguration routerConfiguration,
  WidgetTester tester, {
  String? restorationScopeId,
}) async {
  final router = DuckRouter.withConfig(
    configuration: routerConfiguration,
  );
  await tester.pumpWidget(
    CupertinoApp.router(
      restorationScopeId:
          restorationScopeId != null ? '$restorationScopeId-root' : null,
      routerConfig: router,
    ),
  );
  return router;
}

class DummyScreen extends StatelessWidget {
  const DummyScreen({
    this.queryParametersAll = const <String, dynamic>{},
    super.key,
  });

  final Map<String, dynamic> queryParametersAll;

  @override
  Widget build(BuildContext context) => const Placeholder();
}

class HomeScreen extends DummyScreen {
  const HomeScreen({super.key});
}

class HomeLocation extends Location {
  const HomeLocation();

  @override
  String get path => 'home';

  @override
  LocationBuilder get builder => (context) => const HomeScreen();
}

class Page1Screen extends DummyScreen {
  const Page1Screen({super.key});
}

class Page1Location extends Location {
  const Page1Location();

  @override
  String get path => 'page1';

  @override
  LocationBuilder get builder => (context) => const Page1Screen();
}

class Page2Screen extends DummyScreen {
  const Page2Screen({super.key});
}

class Page2Location extends Location {
  const Page2Location();

  @override
  String get path => 'page2';

  @override
  LocationBuilder get builder => (context) => const Page2Screen();
}

class LoginScreen extends DummyScreen {
  const LoginScreen({super.key});
}

class LoginLocation extends Location {
  const LoginLocation();

  @override
  String get path => 'login';

  @override
  LocationBuilder get builder => (context) => const LoginScreen();
}

class SensitiveScreen extends DummyScreen {
  const SensitiveScreen({super.key});
}

class SensitiveLocation extends Location {
  const SensitiveLocation();

  @override
  String get path => 'sensitive';

  @override
  LocationBuilder get builder => (context) => const SensitiveScreen();
}

class AuthInterceptor extends LocationInterceptor {
  AuthInterceptor({
    required this.isLoggedIn,
  });

  final bool Function() isLoggedIn;

  @override
  Location? execute(Location to, Location? from) {
    if (to is SensitiveLocation && !isLoggedIn()) {
      return LoginLocation();
    }
    return null;
  }
}

class PushesOnTopInterceptor extends LocationInterceptor {
  PushesOnTopInterceptor() : super(pushesOnTop: true);

  @override
  Location? execute(Location to, Location? from) {
    return Page1Location();
  }
}

class RootLocation extends StatefulLocation {
  @override
  String get path => 'root';

  @override
  List<Location> get children => [
        const Child1Location(),
        const Child2Location(),
      ];

  @override
  StatefulLocationBuilder get childBuilder => (c, shell) => Scaffold(
        body: shell,
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Page 1',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Page 2',
            ),
          ],
          onTap: (value) => shell.switchChild(value),
        ),
      );
}

class NestedChildRootLocation extends StatefulLocation {
  @override
  String get path => 'nested';

  @override
  List<Location> get children => [Child1Location()];

  @override
  StatefulLocationBuilder get childBuilder => (c, shell) => shell;
}

class Child1Location extends Location {
  const Child1Location();

  @override
  String get path => 'child1';

  @override
  LocationBuilder get builder => (context) => const Page1Screen();
}

class Child2Location extends Location {
  const Child2Location();

  @override
  String get path => 'child2';

  @override
  LocationBuilder get builder => (context) => const Page2Screen();
}

class DetailLocation extends Location {
  const DetailLocation({
    required this.message,
  });

  final String message;

  @override
  String get path => 'detail';

  @override
  LocationBuilder get builder => (context) => DetailScreen(message: message);
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({
    required this.message,
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message);
  }
}

class CustomPageLocation extends Location {
  const CustomPageLocation();

  @override
  String get path => 'custom-page';

  @override
  LocationPageBuilder get pageBuilder => (context) => CustomPage();
}

class CustomPageTransitionLocation extends Location {
  const CustomPageTransitionLocation();

  @override
  String get path => 'custom-page-transition';

  @override
  LocationPageBuilder get pageBuilder => (context) => DuckPage(
        child: HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        onPopInvoked: (didPop, result) =>
            DuckRouter.of(context).onPopInvoked(this, didPop, result),
      );
}

class CustomPage<T> extends Page<T> {
  @override
  Route<T> createRoute(BuildContext context) {
    return MaterialPageRoute<T>(
      settings: this,
      builder: (context) => const CustomScreen(),
    );
  }
}

class CustomScreen extends StatelessWidget {
  const CustomScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) => const Placeholder();
}
