import 'package:flutter/widgets.dart';

import '../data/repositories/caller_repository.dart';
import '../data/repositories/call_log_store.dart';
import '../data/repositories/settings_repository.dart';
import '../data/storage/key_value_store.dart';
import '../data/storage/storage_factory.dart';
import '../services/call_log/native_call_log_service.dart';
import '../services/call_orchestrator.dart';
import '../services/launch_dispatcher.dart';
import '../services/platform/bridge_service.dart';
import '../services/platform/platform_bridge.dart';

/// Dependency container.
///
/// A hand-rolled `InheritedWidget` instead of a state-management package: the
/// graph is small, entirely singleton, and needs no rebuild scoping — keeping
/// the pubspec to `web` alone means the Android build shares the exact same
/// dependency resolution as the web build.
///
/// The bridge is held **here** rather than looked up from a global inside each
/// widget. That is what makes the UI testable: a widget test injects a
/// recording bridge, so no test ever reaches a real MethodChannel (which in
/// `flutter_test` never completes and hangs `pumpAndSettle`).
class AppScope extends InheritedWidget {
  const AppScope({
    required this.orchestrator,
    required this.dispatcher,
    required this.bridge,
    required this.callerRepository,
    required this.settingsRepository,
    required this.callLogService,
    required super.child,
    super.key,
  });

  final CallOrchestrator orchestrator;
  final LaunchDispatcher dispatcher;
  final PlatformBridge bridge;
  final CallerRepository callerRepository;
  final SettingsRepository settingsRepository;
  final NativeCallLogService callLogService;

  static AppScope of(BuildContext context) {
    final AppScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing from the widget tree');
    return scope!;
  }

  /// Non-listening read, for callbacks that only need to fire an action.
  static AppScope read(BuildContext context) {
    final AppScope? scope = context
        .getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing from the widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      orchestrator != oldWidget.orchestrator;
}

/// Builds the whole graph.
abstract final class AppScopeFactory {
  /// Production entry point: resolves the real platform bridge and store.
  static AppScope create() => build(
    bridge: BridgeService.instance.bridge,
    store: StorageFactory.create(),
  );

  /// Test entry point: injects a bridge and store, so nothing touches a
  /// platform channel.
  static AppScope build({
    required PlatformBridge bridge,
    required KeyValueStore store,
  }) {
    final CallerRepository callerRepository = CallerRepository(store);
    final SettingsRepository settingsRepository = SettingsRepository(store);
    final NativeCallLogService callLogService = NativeCallLogService(
      dao: CallLogStore(store),
      bridge: bridge,
    );
    final CallOrchestrator orchestrator = CallOrchestrator(
      callerRepository: callerRepository,
      settingsRepository: settingsRepository,
      callLogService: callLogService,
      bridge: bridge,
    );
    return AppScope(
      orchestrator: orchestrator,
      dispatcher: LaunchDispatcher(orchestrator: orchestrator, bridge: bridge),
      bridge: bridge,
      callerRepository: callerRepository,
      settingsRepository: settingsRepository,
      callLogService: callLogService,
      child: const SizedBox.shrink(),
    );
  }
}
