import 'package:flutter/material.dart';

import '../../../data/report_settings.dart';
import '../../../theme/app_colors.dart';

/// Chooses the pavement type the repair strategies in generated reports follow
/// (bituminous: IRC:82-2015, cement concrete: IRC:SP:83-2018). The choice is remembered on the device.
class PavementTypeSelector extends StatefulWidget {
  const PavementTypeSelector({super.key, this.showHint = true});

  /// Show the line explaining which code each choice follows.
  final bool showHint;

  @override
  State<PavementTypeSelector> createState() => _PavementTypeSelectorState();
}

class _PavementTypeSelectorState extends State<PavementTypeSelector> {
  String _value = ReportSettings.pavement;

  @override
  void initState() {
    super.initState();
    ReportSettings.load().then((_) {
      if (mounted) setState(() => _value = ReportSettings.pavement);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Pavement type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: ReportSettings.bituminous, label: Text('Bituminous', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: ReportSettings.concrete, label: Text('Concrete', style: TextStyle(fontSize: 12))),
              ],
              selected: {_value},
              onSelectionChanged: (selection) {
                final next = selection.first;
                setState(() => _value = next);
                ReportSettings.setPavement(next);
              },
            ),
          ],
        ),
        if (widget.showHint) ...[
          const SizedBox(height: 4),
          const Text(
            'Repair strategies in the report follow IRC:82-2015 (bituminous) or IRC:SP:83-2018 (concrete).',
            style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
          ),
        ],
      ],
    );
  }
}
