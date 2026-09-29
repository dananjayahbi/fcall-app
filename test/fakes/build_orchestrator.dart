import 'package:incoming_call/data/repositories/caller_repository.dart';
import 'package:incoming_call/data/repositories/settings_repository.dart';
import 'package:incoming_call/data/repositories/call_log_store.dart';
import 'package:incoming_call/data/storage/key_value_store.dart';
import 'package:incoming_call/services/call_log/native_call_log_service.dart';
import 'package:incoming_call/services/call_orchestrator.dart';
import 'package:incoming_call/services/launch_dispatcher.dart';

import 'fake_bridge.dart';

/// Wires a [CallOrchestrator] onto an in-memory store and a [FakeBridge].
class TestHarness {
  TestHarness({FakeBridge? bridge})
    : bridge = bridge ?? FakeBridge(),
      store = InMemoryKeyValueStore() {
    final CallLogStore dao = CallLogStore(store);
    orchestrator = CallOrchestrator(
      callerRepository: CallerRepository(store),
      settingsRepository: SettingsRepository(store),
      callLogService: NativeCallLogService(dao: dao, bridge: this.bridge),
      bridge: this.bridge,
    );
    dispatcher = LaunchDispatcher(orchestrator: orchestrator, bridge: this.bridge);
  }

  final FakeBridge bridge;
  final InMemoryKeyValueStore store;
  late final CallOrchestrator orchestrator;

  /// Routes the native launch EventChannel, mirroring production wiring.
  late final LaunchDispatcher dispatcher;

  Future<void> dispose() async {
    await dispatcher.dispose();
    await orchestrator.dispose();
  }
}
