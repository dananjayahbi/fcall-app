import 'dart:math' as math;

/// Module 1 configuration state: who is calling.
///
/// Immutable + value equality so it can be diffed in tests and stored directly
/// as JSON without a serialisation dependency.
class CallerProfile {
  const CallerProfile({
    this.name = '',
    this.number = '',
    this.simLabel = 'SIM 1',
    this.avatarSeed = 0,
  });

  factory CallerProfile.fromJson(Map<String, dynamic> json) {
    return CallerProfile(
      name: (json['name'] as String?) ?? '',
      number: (json['number'] as String?) ?? '',
      simLabel: (json['simLabel'] as String?) ?? 'SIM 1',
      avatarSeed: (json['avatarSeed'] as num?)?.toInt() ?? 0,
    );
  }

  final String name;
  final String number;
  final String simLabel;

  /// Drives the generated contact image (initials + colour) so no image
  /// dependency or asset is needed for the default case.
  final int avatarSeed;

  bool get hasName => name.trim().isNotEmpty;
  bool get hasNumber => number.trim().isNotEmpty;

  /// What the dialer would show if the contact were not in the address book.
  String get displayName =>
      hasName ? name.trim() : (hasNumber ? number.trim() : 'Unknown');

  /// Up to two characters, derived the way a dialer derives them.
  String get initials {
    final String source = name.trim();
    if (source.isEmpty) {
      final String digits = number.trim();
      if (digits.isNotEmpty) {
        return digits.substring(0, math.min(2, digits.length)).toUpperCase();
      }
      return '?';
    }
    final List<String> parts = source
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final String word = parts.first;
      return word.substring(0, math.min(2, word.length)).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  /// Deterministic hue so the same profile always renders the same avatar.
  double get avatarHue => (avatarSeed * 47) % 360;

  CallerProfile copyWith({
    String? name,
    String? number,
    String? simLabel,
    int? avatarSeed,
  }) {
    return CallerProfile(
      name: name ?? this.name,
      number: number ?? this.number,
      simLabel: simLabel ?? this.simLabel,
      avatarSeed: avatarSeed ?? this.avatarSeed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'number': number,
    'simLabel': simLabel,
    'avatarSeed': avatarSeed,
  };

  @override
  bool operator ==(Object other) {
    return other is CallerProfile &&
        other.name == name &&
        other.number == number &&
        other.simLabel == simLabel &&
        other.avatarSeed == avatarSeed;
  }

  @override
  int get hashCode => Object.hash(name, number, simLabel, avatarSeed);
}
