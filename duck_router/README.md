[![Badge](https://img.shields.io/pub/v/duck_router.svg)](https://pub.dev/packages/duck_router)

The DuckRouter is a Flutter router using intents. It has been tested at scale at [Onsi](https://onsi.com/). DuckRouter has been designed using a philosophy of no "magic", while focusing on reliability.

See also: https://onsi.com/blog/app-navigation-at-scale-introducing-duckrouter

# Features

DuckRouter aims to be a router that _just works_. It is not interested in managing state,
in tracking analytics, it is just a good router. It has many inspirations, but one to
highlight is the [The Evolution of Routing at Airbnb](https://speakerdeck.com/amiekweon/the-evolution-of-routing-at-airbnb).

- Intent-based navigation using types
- Dynamic route registry
- Interceptors for routes
- Stack-based routing

# Getting started

Add the router:

```dart
    final router = DuckRouter(initialLocation: ...);
    return MaterialApp.router(
      ...
      routerConfig: router,
    );
```

Define some routes:

```dart
class HomeLocation extends Location {
  const HomeLocation() : super(path: 'home');

  @override
  LocationBuilder get builder => (context) => const HomeScreen();
}

class Page1Location extends Location {
  const Page1Location() : super(path: 'page1');

  @override
  LocationBuilder get builder => (context) => const Page1Screen();
}
```

Now you can navigate:

```dart
DuckRouter.of(context).navigate(to: const Page1Location());
```

Adding parameters to these routes is easy:

```dart
class Page1Location extends Location {
  const Page1Location(this.icon) : super(path: 'page1');

  // Contrived example to show that you can provide any type here.
  // Remember: it's just a class!
  final Icon icon;

  @override
  LocationBuilder get builder => (context) => const Page1Screen(icon);
}
```

See also the example.

# Key features

DuckRouter is an intent-based router. This makes navigation intentional. We try to avoid magic, since it's easy to get into edge cases where the magic starts posing a problem. DuckRouter uses a dynamic registry. That means that you do not have to map your routes beforehand. You do have to define them, but from then on you can add them anywhere inside the backstack. This approach means you can no longer forget to add routes, nor do you have to declare all the entrypoints for a page. Your page is declared in one page, and you can navigate to it whenever you wish. Easy!

## Nested navigation

To enable nested navigation, such as for a bottom bar implementation, you can use `StatefulLocation`:

```dart
class RootLocation extends StatefulLocation {
  @override
  String get path => 'root';

  @override
  List<Location> get children => [
        const Child1Location(),
        const Child2Location(),
      ];

  /// Note: here, we have implemented the childBuilder in place. We of
  /// course recommend making this its own class.
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
```

That's it. Then, when navigating you have two options:

```dart
// Navigate while still showing the bottom bar, i.e. inside the child navigator
DuckRouter.of(context).navigate(to: const DetailLocation());

// Navigate while not showing the bottom bar, i.e. on root navigator
DuckRouter.of(context).navigate(to: const DetailLocation(), root: true);
```

Note that you might want to consider saving location instances in memory to avoid the instantiation.

## Deep linking

To enable deeplinking support, add an `onDeepLink` handler to the configuration:

```dart
final router = DuckRouter(
  onDeepLink: (uri, currentLocation) {
    // Do something with the deep link. You can choose how to handle the deeplink:
    // - Immediately return a stack of locations
    // - Fire-and-forget: save the deeplink in memory and return null here, so you can act upon it later in your own service.
  },
);
```

This gives you the current location and the URI for the deeplink, and asks you to return an optional stack of locations, with the last entry being the page shown. In cases where it's considered likely for the route to be intercepted (e.g. by a login screen), consider keeping the deeplink location in memory and acting upon it later, and returning `null` instead.

## Custom transitions and custom pages

DuckRouter uses the [Pages](https://api.flutter.dev/flutter/widgets/Page-class.html) API from Flutter to handle the conversions to [Routes](https://api.flutter.dev/flutter/widgets/Route-class.html).

To have a page animate with a custom transition, we can use `DuckPage`:

```dart
class CustomPageTransitionLocation extends Location {
  const CustomPageTransitionLocation();

  @override
  String get path => 'custom-page-transition';

  @override
  LocationPageBuilder get pageBuilder => (context) => DuckPage(
        name: path,
        child: HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}
```

In this case `DuckPage` will create a custom route for you. This means that to specify a non-default route, such as a dialog, we need to override `DuckPage`.

Let's take the case of a dialog (but you can implement any type of Route in this way):

```dart
class DialogPage<T> extends DuckPage<T> {
  const DialogPage({
    required String name,
    required this.builder,
    super.key,
    super.arguments,
    super.restorationId,
  }) : super.custom(name: name);

  final WidgetBuilder builder;

   @override
   Route<T> createRoute(BuildContext context) => DialogRoute<T>(
         context: context,
         settings: this,
         builder: (context) => Dialog(
           child: builder(context),
         ),
       );
 }
```

We can then use this page like so:

```dart
class DialogPageLocation extends Location {
  const DialogPageLocation();

  @override
  String get path => 'dialog-page';

  @override
  LocationPageBuilder get pageBuilder=> (context) => DialogPage(
    name: path,
    builder: ...
  );
}
```

And to open it, all we do is:

```dart
DuckRouter.of(context).navigate(to: DialogPageLocation);
```

## Navigator observers

Adding support for [NavigatorObservers](https://api.flutter.dev/flutter/widgets/NavigatorObserver-class.html) to the standard we would like is not trivial, due to the many limitations it has, and the fact we want to hide the implementation details of this package as much as possible.

Because of this, the support for this feature is kept basic, and users of this feature should be aware of the limitations!
- Observers should always be **stateless**
- Observers **can not be shared** between Navigators

When creating the DuckRouter instance, it is possible to pass a builder function for adding NavigatorObservers to each (nested) navigator, like the example below:

```dart
final router = DuckRouter(
  initialLocation: RootLocation(),
  onDeepLink: (uri, currentLocation) {
    return [const DetailLocation()];
  },
  interceptors: [AuthInterceptor()],
  navigatorObserverBuilder: (navigatorKey) {
    return [
      LoggerNavigatorObserver(),
    ];
  },
);
```

This builder will be called for every Navigator that is created. Because of the limitations above, it is important that each time this callback is triggered, new instances of the observers are returned!