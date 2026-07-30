import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';

class _ManualObservation {
  const _ManualObservation({
    required this.time,
    required this.highway,
    required this.chainage,
    required this.category,
    required this.severity,
    required this.observation,
  });

  final String time;
  final String highway;
  final String chainage;
  final String category;
  final String severity;
  final String observation;
}

const _kCategories = [
  'Pole Obstruction',
  'Tree Fall',
  'Road Block',
  'Water Logging',
  'Accident',
  'Construction Debris',
  'Damaged Barrier',
  'Broken Sign Board',
  'Other',
];

const _kSeverities = ['Critical', 'High', 'Medium', 'Low'];

/// Direct port of DashboardGrid.tsx's "Manual Field Observations" section:
/// a logging form on the left, a registry table on the right. This is
/// local-state-only in the React source too (nothing is persisted to a
/// backend), so it's ported the same way -- entries reset on reload.
///
/// Trimmed vs. the React source: the voice-note recorder (real mic capture
/// via `getUserMedia`/`MediaRecorder`) and the snapshot image uploader.
/// Neither is backend-persisted there either (playback/preview is entirely
/// local-blob), so they were left out to avoid pulling in mic-permission
/// and image-picker plumbing for a feature that doesn't survive a reload
/// either way.
class ManualObservationsSection extends StatefulWidget {
  const ManualObservationsSection({super.key, required this.defaultHighway});

  final String defaultHighway;

  @override
  State<ManualObservationsSection> createState() => _ManualObservationsSectionState();
}

class _ManualObservationsSectionState extends State<ManualObservationsSection> {
  final List<_ManualObservation> _observations = [
    const _ManualObservation(
      time: '11:32 AM',
      highway: 'NH-48 Mumbai–Pune Expressway',
      chainage: 'Km 124+350',
      category: 'Broken Sign Board',
      severity: 'Medium',
      observation: 'Speed limit board at Km 124+350 is damaged and bent.',
    ),
  ];

  final _observationController = TextEditingController();
  final _chainageController = TextEditingController();
  final _gpsController = TextEditingController();
  String _category = 'Pole Obstruction';
  String _severity = 'Medium';

  @override
  void dispose() {
    _observationController.dispose();
    _chainageController.dispose();
    _gpsController.dispose();
    super.dispose();
  }

  void _save() {
    if (_observationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter observation details.')));
      return;
    }
    if (_chainageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please specify the chainage location.')));
      return;
    }
    final now = TimeOfDay.now();
    final hour12 = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    setState(() {
      _observations.insert(
        0,
        _ManualObservation(
          time: '$hour12:${now.minute.toString().padLeft(2, '0')} $period',
          highway: widget.defaultHighway,
          chainage: _chainageController.text.trim(),
          category: _category,
          severity: _severity,
          observation: _observationController.text.trim(),
        ),
      );
      _observationController.clear();
      _chainageController.clear();
      _gpsController.clear();
      _category = 'Pole Obstruction';
      _severity = 'Medium';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manual Field Observations',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryTextLight),
        ),
        const SizedBox(height: 4),
        const Text(
          'Record events and obstructions manually for inspection validation.',
          style: TextStyle(fontSize: 13, color: AppColors.secondaryTextLight),
        ),
        const SizedBox(height: 16),
        _formCard(),
        const SizedBox(height: 20),
        _tableCard(),
      ],
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _labeledDropdown('Observation Category *', _category, _kCategories, (v) => setState(() => _category = v))),
              const SizedBox(width: 16),
              Expanded(child: _labeledDropdown('Severity Level', _severity, _kSeverities, (v) => setState(() => _severity = v))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _labeledField('Location Chainage *', _chainageController, 'Km 124+350')),
              const SizedBox(width: 16),
              Expanded(child: _labeledField('GPS Coordinates (Optional)', _gpsController, '18.5321, 73.8450')),
            ],
          ),
          const SizedBox(height: 14),
          _labeledField(
            'Observation Details *',
            _observationController,
            'Example: Electric pole lying across lane. Immediate removal required.',
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(LucideIcons.save, size: 14),
              label: const Text('Save Observation', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C7354),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledDropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              style: const TextStyle(fontSize: 13, color: AppColors.primaryText),
              items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o))],
              onChanged: (v) => onChanged(v ?? value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _labeledField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            filled: true,
            fillColor: AppColors.primaryBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.cardBorder),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.layers, size: 16, color: AppColors.primaryText),
              SizedBox(width: 8),
              Text(
                'Recent Manual Observations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryText),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.primaryBg),
              columns: const [
                DataColumn(label: Text('TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText))),
                DataColumn(label: Text('HIGHWAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText))),
                DataColumn(label: Text('CHAINAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText))),
                DataColumn(label: Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText))),
                DataColumn(label: Text('SEVERITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText))),
                DataColumn(label: Text('OBSERVATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText))),
              ],
              rows: _observations.isEmpty
                  ? [
                      const DataRow(cells: [
                        DataCell(Text('No manual observations recorded yet.', style: TextStyle(color: AppColors.secondaryText))),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                      ]),
                    ]
                  : [
                      for (final o in _observations)
                        DataRow(cells: [
                          DataCell(Text(o.time, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(o.highway, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(o.chainage, style: const TextStyle(fontSize: 12))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accentBlueLight,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(o.category, style: const TextStyle(fontSize: 11, color: AppColors.accentBlue)),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _severityBg(o.severity),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                o.severity,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _severityFg(o.severity)),
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Text(o.observation, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const DataCell(Text('Logged', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success))),
                        ]),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityFg(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  Color _severityBg(String severity) => _severityFg(severity).withValues(alpha: 0.12);
}
