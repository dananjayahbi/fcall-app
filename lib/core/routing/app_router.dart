import 'package:flutter/material.dart';

/// Named routes for the non-call navigation (the call takeover itself is
/// phase-driven and does not go through the router — see `CallFlowHost`).
abstract final class AppRoutes {
  static const String home = '/';
  static const String callLog = '/call-log';
  static const String setupGuide = '/setup-guide';
}

/// Transition used for the secondary pages, so they read as a drill-in.
Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (_, Animation<double> animation, __, Widget child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
    },
  );
}
