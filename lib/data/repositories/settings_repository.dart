import '../../core/utils/logger.dart';
import '../storage/key_value_store.dart';

/// Module 1 audio/vibration toggles and the last-used scheduling choice.
class AppSettings {
  const AppSettings({
    this.vibrate = true,
    this.useSystemRingtone = true,
    this.screenOnWhileRinging = true,
    this.logCalls = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      vibrate: (json['vibrate'] as bool?) ?? true,
      useSystemRingtone: (json['useSystemRingtone'] as bool?) ?? true,
      screenOnWhileRinging: (json['screenOnWhileRinging'] as bool?) ?? true,
      logCalls: (json['logCalls'] as bool?) ?? true,
    );
  }

  final bool vibrate;
  final bool useSystemRingtone;
  final bool screenOnWhileRinging;

  /// Module 6: write the record into the native call log when a call ends.
  final bool logCalls;

  AppSettings copyWith({
    bool? vibrate,
    bool? useSystemRingtone,
    bool? screenOnWhileRinging,
    bool? logCalls,
  }) {
    return AppSettings(
      vibrate: vibrate ?? this.vibrate,
      useSystemRingtone: useSystemRingtone ?? this.useSystemRingtone,
      screenOnWhileRinging: screenOnWhileRinging ?? this.screenOnWhileRinging,
      logCalls: logCalls ?? this.logCalls,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'vibrate': vibrate,
    'useSystemRingtone': useSystemRingtone,
    'screenOnWhileRinging': screenOnWhileRinging,
    'logCalls': logCalls,
  };
}

class SettingsRepository {
  SettingsRepository(this._store);

  static const String _key = 'app_settings_v1';

  final KeyValueStore _store;

  Future<AppSettings> load() async {
    final Map<String, dynamic>? json = await _store.readJson(_key);
    return json == null ? const AppSettings() : AppSettings.fromJson(json);
  }

  Future<void> save(AppSettings settings) async {
    await _store.writeJson(_key, settings.toJson());
    AppLogger.instance.info('settings-repo', settings.toJson().toString());
  }
}
