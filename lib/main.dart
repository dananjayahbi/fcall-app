import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'core/utils/logger.dart';
import 'services/platform/bridge_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Build the bridge before the first frame so a cold start from a quick-action
  // tile can hand its payload to the config screen.
  final bridge = BridgeService.instance.bridge;
  AppLogger.instance.info('main', 'bridge = ${bridge.kind.name}');

  final launchIntent = await bridge.consumeLaunchIntent();
  BridgeService.instance.setPendingLaunchPayload(launchIntent);

  runApp(IncomingCallApp(scope: AppScopeFactory.create()));
}
