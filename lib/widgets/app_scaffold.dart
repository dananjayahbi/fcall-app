import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// Page shell: consistent background, safe-area padding and an optional
/// full-bleed mode for the call screens.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    super.key,
    this.appBar,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.background,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final EdgeInsetsGeometry padding;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: appBar,
      body: SafeArea(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
