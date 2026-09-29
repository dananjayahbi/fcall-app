import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/logger.dart';

/// The live bridge log.
///
/// Included because "the call did not appear" is always answered by "what did
/// the platform layer actually do?" — and the ringtone console is not
/// reachable while the call overlay covers the screen.
class LogView extends StatelessWidget {
  const LogView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _LogTicker.stream,
      builder: (BuildContext context, _) {
        final List<String> entries = AppLogger.instance.entries;
        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'PLATFORM ACTIVITY (${entries.length})',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: AppLogger.instance.clear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: entries.isEmpty
                  ? const Text(
                      'No platform calls yet.',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: entries.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            entries[index],
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              height: 1.35,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Forces a rebuild when a log line is added.
class _LogTicker {
  static final Stream<void> stream = _build();

  static Stream<void> _build() {
    final controller = StreamController<void>.broadcast();
    AppLogger.instance.addSink((String _) => controller.add(null));
    return controller.stream;
  }
}
