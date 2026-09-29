import 'package:incoming_call/data/repositories/caller_repository.dart';
import 'package:incoming_call/data/repositories/settings_repository.dart';
import 'package:incoming_call/data/repositories/call_log_store.dart';
import 'package:incoming_call/data/storage/key_value_store.dart';
import 'package:incoming_call/services/call_log/native_call_log_service.dart';
import 'package:incoming_call/services/call_orchestrator.dart';

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
  }

  final FakeBridge bridge;
  final InMemoryKeyValueStore store;
  late final CallOrchestrator orchestrator;

  Future<void> dispose() => orchestrator.dispose();
}
