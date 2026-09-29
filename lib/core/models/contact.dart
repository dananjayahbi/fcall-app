/// One person the user can be called by.
///
/// A distinct type from [CallerProfile] on purpose: a profile is "whoever is
/// typed into the form right now" and is a single mutable slot, while a contact
/// is a saved, addressable entry the scheduler can reference by id. Merging
/// them would mean every scheduled call silently captured whatever the form
/// happened to contain at the moment it was armed.
class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.number,
    this.simLabel = 'SIM 1',
    this.avatarSeed = 0,
  });

  final String id;
  final String name;
  final String number;
  final String simLabel;
  final int avatarSeed;

  /// Falls back to the number so a contact saved with only a number is still
  /// identifiable in the list rather than rendering as a blank row.
  String get displayName => name.trim().isNotEmpty ? name.trim() : number;

  bool get isUsable => number.trim().isNotEmpty;

  /// Derived from the name so the avatar colour is stable for a given contact
  /// across sessions — a seed that changed on every reload would make the list
  /// look like it reshuffled itself.
  int get colourSeed => avatarSeed != 0 ? avatarSeed : name.hashCode;

  Contact copyWith({
    String? name,
    String? number,
    String? simLabel,
    int? avatarSeed,
  }) {
    return Contact(
      id: id,
      name: name ?? this.name,
      number: number ?? this.number,
      simLabel: simLabel ?? this.simLabel,
      avatarSeed: avatarSeed ?? this.avatarSeed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'number': number,
    'simLabel': simLabel,
    'avatarSeed': avatarSeed,
  };

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      number: (json['number'] as String?) ?? '',
      simLabel: (json['simLabel'] as String?) ?? 'SIM 1',
      avatarSeed: (json['avatarSeed'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Contact && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
