// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../navigator.dart';

bool isMaterialApp(BuildContext context) =>
    context.findAncestorWidgetOfExactType<MaterialApp>() != null;

HeroController createMaterialHeroController() =>
    MaterialApp.createMaterialHeroController();

MaterialPage<void> pageBuilderForMaterialApp({
  required LocalKey key,
  required String? name,
  required Widget child,
  required OnPopInvokedCallback onPopInvoked,
}) =>
    MaterialPage<void>(
      name: name,
      key: key,
      child: child,
      onPopInvoked: onPopInvoked,
    );
