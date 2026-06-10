/// Navigation helper mapping [AppDestination] to its screen and switching to it.
library;

import 'package:flutter/material.dart';

import '../../../core/navigation/app_navigation_drawer.dart';
import 'dashboard_screen.dart';
import 'video_screen.dart';

/// Replaces the current route with the screen for [destination].
///
/// Uses [Navigator.pushReplacement] so the drawer doesn't build a back-stack;
/// Riverpod state (connection, video stream) lives at the root ProviderScope
/// and is unaffected by the swap.
void navigateToDestination(BuildContext context, AppDestination destination) {
  final Widget screen = switch (destination) {
    AppDestination.dashboard => const DashboardScreen(),
    AppDestination.video => const VideoScreen(),
  };
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}
