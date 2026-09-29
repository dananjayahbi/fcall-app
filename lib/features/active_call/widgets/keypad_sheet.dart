import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Module 5's dummy keypad.
///
/// Tapping the digits appends them to a local buffer so the interaction is real,
/// but the buffer is never dialled and no audio is produced — the call stays
/// completely silent.
class KeypadSheet extends StatefulWidget {
  const KeypadSheet({super.key});

  @override
  State<KeypadSheet> createState() => _KeypadSheetState();
}

class _KeypadSheetState extends State<KeypadSheet> {
  String _buffer = '';

  static const List<List<String>> _keys = <List<String>>[
    <String>['1', '2', '3'],
    <String>['4', '5', '6'],
    <String>['7', '8', '9'],
    <String>['*', '0', '#'],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              _buffer.isEmpty ? '—' : _buffer,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final List<String> row in _keys)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map(
                      (String key) => _Key(
                        label: key,
                        onTap: () => setState(
                          () => _buffer = _buffer.length >= 15
                              ? _buffer
                              : '$_buffer$key',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Close keypad'),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          width: 58,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
