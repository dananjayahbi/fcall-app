import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/call_trigger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Unit selector plus a numeric field for a hand-entered delay.
///
/// ## Why this is separate from [ExactTimePickerCard]
///
/// The two answer genuinely different questions — "how long from now" versus
/// "at what wall-clock moment" — and they behave differently: a relative delay
/// keeps counting from the moment it is *armed*, so a schedule edited hours
/// later means something different than the same number typed on the exact-time
/// picker. Folding them into one control would force the user to think in
/// absolute time to express a relative intent.
///
/// The field is numeric-only: a unit-less "5" is ambiguous, and the toggle
/// beside it resolves it.
class RelativeDelayCard extends StatefulWidget {
  const RelativeDelayCard({
    required this.onChanged,
    super.key,
    this.initialUnit = RelativeUnit.minutes,
    this.initialValue = CallTriggerPresets.defaultMinutes,
  });

  final void Function(RelativeUnit unit, int value) onChanged;
  final RelativeUnit initialUnit;
  final int initialValue;

  @override
  State<RelativeDelayCard> createState() => _RelativeDelayCardState();
}

class _RelativeDelayCardState extends State<RelativeDelayCard> {
  late RelativeUnit _unit = widget.initialUnit;
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initialValue}',
  );

  /// The value the card believes is current.
  ///
  /// Held here rather than read straight from the controller because the
  /// preview has to update as the user types. Reading the controller alone
  /// works only if the *parent* happens to call `setState` — and it does not
  /// while the user is mid-keystroke, so the preview would sit stale until
  /// something unrelated rebuilt the screen.
  late int _value = widget.initialValue;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit(int raw) {
    // Clamped to 1 by CallTrigger.relative as well; doing it here too keeps the
    // preview honest instead of showing "0 min" for an empty field.
    final int next = raw < 1 ? 1 : raw;
    setState(() => _value = next);
    widget.onChanged(_unit, next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'After',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    // Bounded so the field cannot be filled with a number that
                    // overflows the native int the alarm layer takes.
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String raw) => _emit(int.tryParse(raw) ?? 1),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _UnitToggle(
                unit: _unit,
                onChanged: (RelativeUnit next) {
                  // The number is reinterpreted, not converted: typing "30"
                  // and switching to hours should mean 30 hours, because the
                  // user is editing a quantity they chose. Silently converting
                  // to 1800 minutes would be a surprise.
                  setState(() => _unit = next);
                  _emit(int.tryParse(_controller.text) ?? 1);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Rings in ${_previewLabel()} from now',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// "10 min" / "2 hr" — stated in the unit the user is looking at.
  ///
  /// Converting to minutes unconditionally would print "600 min" while the
  /// control reads "2 hr", which is both ugly and wrong-looking.
  String _previewLabel() => '$_value ${_unit.shortLabel}';
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.unit, required this.onChanged});

  final RelativeUnit unit;
  final ValueChanged<RelativeUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: RelativeUnit.values.map((RelativeUnit option) {
          final bool selected = option == unit;
          return GestureDetector(
            onTap: () => onChanged(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                option.shortLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.background
                      : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
