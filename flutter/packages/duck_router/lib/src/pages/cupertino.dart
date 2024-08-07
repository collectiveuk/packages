// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

import '../navigator.dart';

bool isCupertinoApp(BuildContext context) =>
    context.findAncestorWidgetOfExactType<CupertinoApp>() != null;

HeroController createCupertinoHeroController() =>
    CupertinoApp.createCupertinoHeroController();

CupertinoPage<void> pageBuilderForCupertinoApp({
  required LocalKey key,
  required String? name,
  required Widget child,
  required OnPopInvokedCallback onPopInvoked,
}) =>
    CupertinoPage<void>(
      name: name,
      key: key,
      child: child,
      onPopInvoked: onPopInvoked,
    );
