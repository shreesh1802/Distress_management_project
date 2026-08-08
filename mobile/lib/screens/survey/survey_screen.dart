import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../router/app_router.dart';
import '../../theme/app_colors.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/Survey/
/// SurveyInitialization.tsx and SurveyInitialization.css.
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _LogEntry {
  const _LogEntry(this.timestamp, this.text);
  final String timestamp;
  final String text;
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  late final String _inspectionId;

  final _highwayNameCtrl = TextEditingController(
    text: 'NH-48 Delhi–Jaipur Expressway',
  );
  final _highwayNumberCtrl = TextEditingController(text: 'NH-48');
  final _startingChainageCtrl = TextEditingController(text: 'Km 118+250');
  final _endingChainageCtrl = TextEditingController(text: 'Km 136+900');
  final _latitudeCtrl = TextEditingController(text: '28.4595');
  final _longitudeCtrl = TextEditingController(text: '77.0266');
  final _stateCtrl = TextEditingController(text: 'Haryana');
  final _districtCtrl = TextEditingController(text: 'Gurugram');
  final _inspectorNameCtrl = TextEditingController(text: 'Monitoring Engineer (ME)');
  final _departmentCtrl = TextEditingController(text: 'NHAI Operations');
  final _organizationCtrl = TextEditingController(
    text: 'AKCM Infrastructure',
  );
  final _vehicleNumberCtrl = TextEditingController(text: 'HR-26-CP-4812');
  final _surveyTeamCtrl = TextEditingController(text: 'AKCM Survey Unit-01');
  final _inspectionNotesCtrl = TextEditingController();

  late DateTime _inspectionDate;
  late TimeOfDay _inspectionTime;
  String _surveyType = 'Routine Inspection';
  String _roadDirection = 'Northbound';
  String _weather = 'Sunny';
  String _trafficDensity = 'Medium';
  String _roadSurface = 'Bituminous';

  static const _camera = 'RunCam 4K Orange';

  Map<String, String> _errors = {};
  bool _isInitializing = false;
  final _pipelineLogs = <_LogEntry>[];
  final _logScrollController = ScrollController();
  final List<Timer> _pendingTimers = [];

  final _highwayCardKey = GlobalKey();
  final _chainageCardKey = GlobalKey();
  final _teamCardKey = GlobalKey();
  final _conditionsCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final randomNum = 100000 + Random().nextInt(900000);
    _inspectionId = 'RIMS-2026-$randomNum';

    final now = DateTime.now();
    _inspectionDate = DateTime(now.year, now.month, now.day);
    _inspectionTime = TimeOfDay.fromDateTime(now);

    for (final c in [
      _highwayNameCtrl,
      _highwayNumberCtrl,
      _startingChainageCtrl,
      _endingChainageCtrl,
      _latitudeCtrl,
      _longitudeCtrl,
      _stateCtrl,
      _districtCtrl,
      _inspectorNameCtrl,
      _departmentCtrl,
      _organizationCtrl,
      _vehicleNumberCtrl,
      _surveyTeamCtrl,
      _inspectionNotesCtrl,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    for (final c in [
      _highwayNameCtrl,
      _highwayNumberCtrl,
      _startingChainageCtrl,
      _endingChainageCtrl,
      _latitudeCtrl,
      _longitudeCtrl,
      _stateCtrl,
      _districtCtrl,
      _inspectorNameCtrl,
      _departmentCtrl,
      _organizationCtrl,
      _vehicleNumberCtrl,
      _surveyTeamCtrl,
      _inspectionNotesCtrl,
    ]) {
      c.dispose();
    }
    _logScrollController.dispose();
    super.dispose();
  }

  double? _parseChainage(String val) {
    final cleaned = val.toLowerCase().replaceAll(RegExp(r'[^0-9+.]'), '');
    if (cleaned.contains('+')) {
      final parts = cleaned.split('+');
      if (parts.length == 2) {
        final km = double.tryParse(parts[0]);
        final m = double.tryParse(parts[1]);
        if (km != null && m != null) return km + m / 1000;
      }
    }
    return double.tryParse(cleaned);
  }

  double? get _parsedStart => _parseChainage(_startingChainageCtrl.text);
  double? get _parsedEnd => _parseChainage(_endingChainageCtrl.text);

  double get _surveyLength {
    final start = _parsedStart;
    final end = _parsedEnd;
    if (start != null && end != null) {
      final length = end - start;
      return length > 0 ? length : 0;
    }
    return 0;
  }

  bool get _isHighwayOk => _highwayNameCtrl.text.trim().isNotEmpty;
  bool get _isChainageOk {
    final start = _parsedStart;
    final end = _parsedEnd;
    return _startingChainageCtrl.text.trim().isNotEmpty &&
        _endingChainageCtrl.text.trim().isNotEmpty &&
        start != null &&
        end != null &&
        end > start;
  }

  bool get _isInspectorOk => _inspectorNameCtrl.text.trim().isNotEmpty;
  bool get _isVehicleOk => _vehicleNumberCtrl.text.trim().isNotEmpty;
  bool get _isWeatherOk => _weather.isNotEmpty;

  bool get _isFormComplete =>
      _isHighwayOk &&
      _isChainageOk &&
      _isInspectorOk &&
      _isVehicleOk &&
      _isWeatherOk;

  bool _validateForm() {
    final newErrors = <String, String>{};

    if (_highwayNameCtrl.text.trim().isEmpty) {
      newErrors['highwayName'] = 'Highway Name is required.';
    }

    if (_startingChainageCtrl.text.trim().isEmpty) {
      newErrors['startingChainage'] = 'Starting Chainage is required.';
    } else if (_parsedStart == null) {
      newErrors['startingChainage'] =
          'Invalid format. E.g., Km 118+250 or 118.25';
    }

    if (_endingChainageCtrl.text.trim().isEmpty) {
      newErrors['endingChainage'] = 'Ending Chainage is required.';
    } else if (_parsedEnd == null) {
      newErrors['endingChainage'] =
          'Invalid format. E.g., Km 136+900 or 136.90';
    }

    final start = _parsedStart;
    final end = _parsedEnd;
    if (start != null && end != null && end <= start) {
      newErrors['endingChainage'] =
          'Ending chainage must be greater than starting chainage.';
    }

    if (_inspectorNameCtrl.text.trim().isEmpty) {
      newErrors['inspectorName'] = 'Inspector Name is required.';
    }

    if (_vehicleNumberCtrl.text.trim().isEmpty) {
      newErrors['vehicleNumber'] = 'Vehicle Number is required.';
    }

    if (_weather.isEmpty) {
      newErrors['weather'] = 'Weather selection is required.';
    }

    setState(() => _errors = newErrors);
    return newErrors.isEmpty;
  }

  void _scrollToFirstError() {
    if (_errors.isEmpty) return;
    final firstKey = _errors.keys.first;
    GlobalKey? target;
    switch (firstKey) {
      case 'highwayName':
        target = _highwayCardKey;
      case 'startingChainage':
      case 'endingChainage':
        target = _chainageCardKey;
      case 'inspectorName':
      case 'vehicleNumber':
        target = _teamCardKey;
      case 'weather':
        target = _conditionsCardKey;
    }
    final ctx = target?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  void _handleStartInspection() {
    if (!_validateForm()) {
      _scrollToFirstError();
      return;
    }

    setState(() {
      _isInitializing = true;
      _pipelineLogs.clear();
    });

    final logsSequence = <(String, int)>[
      ('Initializing AI Inspection Environment...', 100),
      (
        'Target Highway: ${_highwayNameCtrl.text} | Range: '
            '${_startingChainageCtrl.text} to ${_endingChainageCtrl.text}',
        250,
      ),
      (
        'Verifying active session credentials for inspector '
            '${_inspectorNameCtrl.text}...',
        400,
      ),
      ('Loading YOLOv11 Road Distress Model weights (CUDA active)...', 550),
      (
        'Allocating GPU buffers for stream feed capture ($_camera)...',
        700,
      ),
      ('Calibrating GPS positioning coordinates and GIS link layer...', 850),
      ('Systems nominal. Redirecting to Inspection Dashboard...', 950),
    ];

    for (final (text, delay) in logsSequence) {
      _pendingTimers.add(
        Timer(Duration(milliseconds: delay), () {
          if (!mounted) return;
          setState(() {
            _pipelineLogs.add(_LogEntry(_formatTime(DateTime.now()), text));
          });
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        }),
      );
    }

    _pendingTimers.add(
      Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() => _isInitializing = false);
        context.go(AppRoutes.dashboard);
      }),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m:$s $period';
  }

  Future<void> _handleSaveDraft() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Draft Saved'),
        content: const Text(
          'Inspection configuration draft saved successfully locally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Setup?'),
        content: const Text(
          'Are you sure you want to cancel? Any unsaved setup details will '
          'be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.go(AppRoutes.login);
    }
  }

  String get _dateText =>
      '${_inspectionDate.year.toString().padLeft(4, '0')}-'
      '${_inspectionDate.month.toString().padLeft(2, '0')}-'
      '${_inspectionDate.day.toString().padLeft(2, '0')}';

  String get _timeText =>
      '${_inspectionTime.hour.toString().padLeft(2, '0')}:'
      '${_inspectionTime.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _inspectionDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _inspectionTime,
    );
    if (picked != null) setState(() => _inspectionTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/highway_background.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.loginOverlayStart,
                        AppColors.loginOverlayEnd,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(40, 40, 40, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderRow(),
                          const SizedBox(height: 30),
                          _buildTimeline(),
                          const SizedBox(height: 24),
                          _buildRow1(),
                          const SizedBox(height: 24),
                          _buildRow2(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildActionBar(),
        ),
        if (_isInitializing) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final titleGroup = Column(
          crossAxisAlignment: narrow
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            const Text(
              'INSPECTION MISSION SETUP',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Road Inspection Control Center',
              textAlign: narrow ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),
              child: Text(
                'Configure and verify survey details before launching the '
                'AI-powered Road Distress Monitoring System.',
                textAlign: narrow ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ),
          ],
        );

        final userCard = _UserCard(
          name: _inspectorNameCtrl.text,
          team: _surveyTeamCtrl.text,
        );

        if (narrow) {
          return Column(
            children: [
              titleGroup,
              const SizedBox(height: 20),
              userCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleGroup),
            const SizedBox(width: 32),
            userCard,
          ],
        );
      },
    );
  }

  Widget _buildTimeline() {
    final steps = [
      (LucideIcons.lock, 'Step 1', 'Secure Login', 'Completed', _StepState.completed),
      (LucideIcons.sliders, 'Step 2', 'Inspection Mission Setup', 'Current Step', _StepState.active),
      (LucideIcons.play, 'Step 3', 'Live Road Inspection', 'Upcoming', _StepState.upcoming),
      (LucideIcons.cpu, 'Step 4', 'AI Distress Detection', 'Upcoming', _StepState.upcoming),
      (LucideIcons.mapPin, 'Step 5', 'GIS Mapping', 'Upcoming', _StepState.upcoming),
      (LucideIcons.wrench, 'Step 6', 'Maintenance Recommendation', 'Upcoming', _StepState.upcoming),
      (LucideIcons.fileText, 'Step 7', 'Report Generation', 'Upcoming', _StepState.upcoming),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.glassCardFill,
        border: Border.all(color: AppColors.glassCardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 35,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          if (narrow) {
            return Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: i < steps.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            )
                          : null,
                    ),
                    child: _TimelineStep(
                      icon: steps[i].$1,
                      stepNumber: steps[i].$2,
                      title: steps[i].$3,
                      status: steps[i].$4,
                      state: steps[i].$5,
                      horizontal: true,
                    ),
                  ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned(
                left: 60,
                right: 60,
                top: 18,
                child: Container(
                  height: 2,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              Row(
                children: [
                  for (final s in steps)
                    Expanded(
                      child: _TimelineStep(
                        icon: s.$1,
                        stepNumber: s.$2,
                        title: s.$3,
                        status: s.$4,
                        state: s.$5,
                        horizontal: false,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow1() {
    final cards = [
      _buildInspectionDetailsCard(),
      _buildChainageCard(),
      _buildLocationCard(),
      _buildTeamCard(),
    ];
    return _CardGrid(cards: cards, wideColumns: 4);
  }

  Widget _buildRow2() {
    final cards = [
      _buildConditionsCard(),
      _buildSummaryCard(),
      _buildChecklistCard(),
    ];
    return _CardGrid(cards: cards, wideColumns: 3);
  }

  Widget _buildInspectionDetailsCard() {
    return _GlassCard(
      key: _highwayCardKey,
      icon: LucideIcons.fileText,
      title: 'Inspection Details',
      children: [
        _SurveyField(
          label: 'Inspection ID',
          child: _SurveyTextField(
            controller: TextEditingController(text: _inspectionId),
            enabled: false,
          ),
        ),
        _SurveyField(
          label: 'Highway Name',
          required: true,
          error: _errors['highwayName'],
          child: _SurveyTextField(
            controller: _highwayNameCtrl,
            hint: 'e.g. NH-48 Delhi–Jaipur Expressway',
            hasError: _errors['highwayName'] != null,
          ),
        ),
        _SurveyField(
          label: 'Highway Number',
          child: _SurveyTextField(
            controller: _highwayNumberCtrl,
            hint: 'e.g. NH-48',
          ),
        ),
        _SurveyField(
          label: 'Inspection Date',
          child: _PickerField(
            icon: LucideIcons.calendar,
            text: _dateText,
            onTap: _pickDate,
          ),
        ),
        _SurveyField(
          label: 'Inspection Time',
          child: _PickerField(
            icon: LucideIcons.clock,
            text: _timeText,
            onTap: _pickTime,
          ),
        ),
        _SurveyField(
          label: 'Survey Type',
          child: _SurveyDropdown(
            value: _surveyType,
            items: const [
              'Routine Inspection',
              'Emergency Inspection',
              'Post Construction',
              'Complaint Based',
            ],
            onChanged: (v) => setState(() => _surveyType = v),
          ),
        ),
      ],
    );
  }

  Widget _buildChainageCard() {
    return _GlassCard(
      key: _chainageCardKey,
      icon: LucideIcons.navigation,
      title: 'Road Chainage',
      children: [
        _SurveyField(
          label: 'Starting Chainage',
          required: true,
          error: _errors['startingChainage'],
          child: _SurveyTextField(
            controller: _startingChainageCtrl,
            hint: 'e.g. Km 118+250',
            hasError: _errors['startingChainage'] != null,
          ),
        ),
        _SurveyField(
          label: 'Ending Chainage',
          required: true,
          error: _errors['endingChainage'],
          child: _SurveyTextField(
            controller: _endingChainageCtrl,
            hint: 'e.g. Km 136+900',
            hasError: _errors['endingChainage'] != null,
          ),
        ),
        _SurveyField(
          label: 'Total Survey Length',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _surveyLength > 0
                  ? '${_surveyLength.toStringAsFixed(2)} km'
                  : '0.00 km',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return _GlassCard(
      icon: LucideIcons.mapPin,
      title: 'Location',
      children: [
        _SurveyField(
          label: 'Latitude',
          child: _SurveyTextField(
            controller: _latitudeCtrl,
            hint: 'e.g. 28.5355',
          ),
        ),
        _SurveyField(
          label: 'Longitude',
          child: _SurveyTextField(
            controller: _longitudeCtrl,
            hint: 'e.g. 77.3910',
          ),
        ),
        _SurveyField(
          label: 'State',
          child: _SurveyTextField(controller: _stateCtrl, hint: 'State'),
        ),
        _SurveyField(
          label: 'District',
          child: _SurveyTextField(
            controller: _districtCtrl,
            hint: 'District',
          ),
        ),
        _SurveyField(
          label: 'Road Direction',
          child: _SurveyDropdown(
            value: _roadDirection,
            items: const [
              'Northbound',
              'Southbound',
              'Eastbound',
              'Westbound',
            ],
            onChanged: (v) => setState(() => _roadDirection = v),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard() {
    return _GlassCard(
      key: _teamCardKey,
      icon: LucideIcons.users,
      title: 'Inspection Team',
      children: [
        _SurveyField(
          label: 'Inspector Name',
          required: true,
          error: _errors['inspectorName'],
          child: _SurveyTextField(
            controller: _inspectorNameCtrl,
            hint: 'Inspector Name',
            hasError: _errors['inspectorName'] != null,
          ),
        ),
        _SurveyField(
          label: 'Department',
          child: _SurveyTextField(
            controller: _departmentCtrl,
            hint: 'Department',
          ),
        ),
        _SurveyField(
          label: 'Organization',
          child: _SurveyTextField(
            controller: _organizationCtrl,
            hint: 'Organization',
          ),
        ),
        _SurveyField(
          label: 'Vehicle Registration',
          required: true,
          error: _errors['vehicleNumber'],
          child: _SurveyTextField(
            controller: _vehicleNumberCtrl,
            hint: 'Vehicle Number',
            hasError: _errors['vehicleNumber'] != null,
            icon: LucideIcons.car,
          ),
        ),
        _SurveyField(
          label: 'Survey Team',
          child: _SurveyTextField(
            controller: _surveyTeamCtrl,
            hint: 'e.g. AKCM Survey Unit-01',
          ),
        ),
      ],
    );
  }

  Widget _buildConditionsCard() {
    return _GlassCard(
      key: _conditionsCardKey,
      icon: LucideIcons.cloudSun,
      title: 'Road Conditions',
      children: [
        _SurveyField(
          label: 'Weather',
          required: true,
          error: _errors['weather'],
          child: _SurveyDropdown(
            value: _weather,
            items: const ['Sunny', 'Cloudy', 'Rainy', 'Fog', 'Night'],
            hasError: _errors['weather'] != null,
            onChanged: (v) => setState(() => _weather = v),
          ),
        ),
        _SurveyField(
          label: 'Traffic Density',
          child: _SurveyDropdown(
            value: _trafficDensity,
            items: const ['Low', 'Medium', 'High'],
            onChanged: (v) => setState(() => _trafficDensity = v),
          ),
        ),
        _SurveyField(
          label: 'Road Surface',
          child: _SurveyDropdown(
            value: _roadSurface,
            items: const ['Bituminous', 'Concrete', 'Composite'],
            onChanged: (v) => setState(() => _roadSurface = v),
          ),
        ),
        _SurveyField(
          label: 'Inspection Notes',
          child: _SurveyTextField(
            controller: _inspectionNotesCtrl,
            hint: 'Enter any observations before beginning inspection...',
            minLines: 3,
            maxLines: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final items = [
      ('Highway', _highwayNameCtrl.text.isEmpty ? '--' : _highwayNameCtrl.text, false),
      (
        'Chainage',
        '${_startingChainageCtrl.text.isEmpty ? '--' : _startingChainageCtrl.text} to '
            '${_endingChainageCtrl.text.isEmpty ? '--' : _endingChainageCtrl.text}',
        false,
      ),
      (
        'Survey Length',
        _surveyLength > 0 ? '${_surveyLength.toStringAsFixed(2)} km' : '0.00 km',
        true,
      ),
      ('Inspector', _inspectorNameCtrl.text.isEmpty ? '--' : _inspectorNameCtrl.text, false),
      ('Vehicle', _vehicleNumberCtrl.text.isEmpty ? '--' : _vehicleNumberCtrl.text, false),
      ('Weather', _weather.isEmpty ? '--' : _weather, false),
      ('Date', _dateText, false),
      ('Time', _timeText, false),
      ('Road Surface', _roadSurface, false),
      ('Direction', _roadDirection, false),
    ];

    return _GlassCard(
      icon: LucideIcons.fileText,
      title: 'Mission Summary',
      children: [
        // Plain Row/Column grid, not GridView: GridView is Viewport-based
        // and doesn't implement intrinsic-height computation, which throws
        // in debug mode (silently breaks hit-testing in release) once this
        // card sits inside _CardGrid's IntrinsicHeight-wrapped row.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i += 2) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: items[i].$1,
                      value: items[i].$2,
                      highlight: items[i].$3,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: i + 1 < items.length
                        ? _SummaryItem(
                            label: items[i + 1].$1,
                            value: items[i + 1].$2,
                            highlight: items[i + 1].$3,
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChecklistCard() {
    return _GlassCard(
      icon: LucideIcons.sliders,
      title: 'Inspection Readiness Checklist',
      children: [
        const _ChecklistItem(checked: true, label: 'Login Verified'),
        _ChecklistItem(checked: _isHighwayOk, label: 'Highway Selected'),
        _ChecklistItem(checked: _isChainageOk, label: 'Chainage Configured'),
        _ChecklistItem(checked: _isInspectorOk, label: 'Inspector Assigned'),
        _ChecklistItem(checked: _isVehicleOk, label: 'Vehicle Registered'),
        _ChecklistItem(
          checked: _isWeatherOk,
          label: 'Road Conditions Selected',
        ),
        _ChecklistItem(
          checked: _isFormComplete,
          label: 'Survey Information Complete',
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'INSPECTION STATUS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: (_isFormComplete
                        ? AppColors.success
                        : AppColors.warning)
                    .withValues(alpha: 0.15),
                border: Border.all(
                  color: (_isFormComplete
                          ? AppColors.success
                          : AppColors.warning)
                      .withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isFormComplete
                          ? const Color(0xFF34D399)
                          : const Color(0xFFFBBF24),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isFormComplete
                        ? 'READY TO START'
                        : 'Awaiting Configuration',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _isFormComplete
                          ? const Color(0xFF34D399)
                          : const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xB30F172A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ActionButton(
              label: 'Cancel Setup',
              icon: LucideIcons.arrowLeft,
              variant: _ButtonVariant.text,
              onTap: _handleCancel,
            ),
            _ActionButton(
              label: 'Save Draft',
              icon: LucideIcons.save,
              variant: _ButtonVariant.secondary,
              onTap: _handleSaveDraft,
            ),
            _ActionButton(
              label: 'Start Inspection',
              icon: LucideIcons.play,
              variant: _ButtonVariant.primary,
              onTap: _handleStartInspection,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xF5081930),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: AppColors.glassCardFill,
                border: Border.all(color: AppColors.glassCardBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.warning,
                      backgroundColor: Color(0x1AFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Initializing AI Inspection Environment...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 110,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xB30F172A),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: _pipelineLogs.length,
                      itemBuilder: (context, index) {
                        final log = _pipelineLogs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11.5,
                                color: Color(0xFF34D399),
                              ),
                              children: [
                                TextSpan(
                                  text: '[${log.timestamp}] ',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                TextSpan(text: log.text),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StepState { completed, active, upcoming }

enum _ButtonVariant { text, secondary, primary }

class _UserCard extends StatelessWidget {
  const _UserCard({required this.name, required this.team});

  final String name;
  final String team;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glassCardFill,
        border: Border.all(color: AppColors.glassCardBorder),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentBlueHover,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(LucideIcons.user, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? '--' : name,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                team.isEmpty ? '--' : team,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.stepNumber,
    required this.title,
    required this.status,
    required this.state,
    required this.horizontal,
  });

  final IconData icon;
  final String stepNumber;
  final String title;
  final String status;
  final _StepState state;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    Color circleBg;
    Color circleBorder;
    Color circleColor;
    Color titleColor;
    Color statusColor;

    switch (state) {
      case _StepState.completed:
        circleBg = AppColors.success.withValues(alpha: 0.2);
        circleBorder = AppColors.success;
        circleColor = AppColors.success;
        titleColor = Colors.white;
        statusColor = AppColors.success;
      case _StepState.active:
        circleBg = AppColors.accentBlueHover;
        circleBorder = AppColors.warning;
        circleColor = Colors.white;
        titleColor = Colors.white;
        statusColor = AppColors.warning;
      case _StepState.upcoming:
        circleBg = const Color(0xB30F172A);
        circleBorder = Colors.white.withValues(alpha: 0.2);
        circleColor = const Color(0xFF94A3B8);
        titleColor = const Color(0xFF94A3B8);
        statusColor = const Color(0xFF64748B);
    }

    final circle = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: circleBg,
        shape: BoxShape.circle,
        border: Border.all(color: circleBorder, width: 2),
      ),
      child: Icon(icon, size: 14, color: circleColor),
    );

    final labels = Column(
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stepNumber.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.warning,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          textAlign: horizontal ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          status,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ],
    );

    if (horizontal) {
      return Row(
        children: [
          circle,
          const SizedBox(width: 12),
          Expanded(child: labels),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [circle, const SizedBox(height: 8), labels],
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards, required this.wideColumns});

  final List<Widget> cards;
  final int wideColumns;

  static const _gap = 24.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 768 ? 1 : (width < 1200 ? 2 : wideColumns);

        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += columns) {
          final rowCards = cards.sublist(
            i,
            min(i + columns, cards.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < rowCards.length; j++) ...[
                    if (j > 0) const SizedBox(width: _gap),
                    Expanded(child: rowCards[j]),
                  ],
                ],
              ),
            ),
          );
          if (i + columns < cards.length) {
            rows.add(const SizedBox(height: _gap));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.glassCardFill,
        border: Border.all(color: AppColors.glassCardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 35,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlueHover.withValues(alpha: 0.3),
                    border: Border.all(
                      color: AppColors.accentBlueHover.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SurveyField extends StatelessWidget {
  const _SurveyField({
    required this.label,
    required this.child,
    this.required = false,
    this.error,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE2E8F0),
              ),
            ),
            if (required)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  '*',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
        if (error != null) ...[
          const SizedBox(height: 2),
          Text(
            error!,
            style: const TextStyle(
              color: Color(0xFFFCA5A5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _SurveyTextField extends StatelessWidget {
  const _SurveyTextField({
    required this.controller,
    this.hint,
    this.enabled = true,
    this.hasError = false,
    this.icon,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final bool hasError;
  final IconData? icon;
  final int? minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? const Color(0x99DC2626)
        : Colors.white.withValues(alpha: 0.15);

    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: minLines != null ? maxLines : 1,
      style: TextStyle(
        fontSize: 13.5,
        color: enabled ? Colors.white : const Color(0xFF94A3B8),
      ),
      cursorColor: AppColors.warning,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        isDense: true,
        prefixIcon: icon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
              )
            : null,
        prefixIconConstraints: icon != null
            ? const BoxConstraints(minWidth: 38, minHeight: 16)
            : null,
        filled: true,
        fillColor: enabled
            ? (hasError ? const Color(0x1ADC2626) : const Color(0x590F172A))
            : const Color(0x260F172A),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.warning),
        ),
      ),
    );
  }
}

/// A tap-to-open select field styled like `.glass-survey-input`. Replaces
/// DropdownButtonFormField, whose selected-value text rendered invisible
/// (default black-on-dark) even after explicitly styling menu items.
class _SurveyDropdown extends StatelessWidget {
  const _SurveyDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hasError = false,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool hasError;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                title: Text(
                  item,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: item == value ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                trailing: item == value
                    ? const Icon(LucideIcons.check, color: AppColors.warning, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(item),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? const Color(0x99DC2626)
        : Colors.white.withValues(alpha: 0.15);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasError ? const Color(0x1ADC2626) : const Color(0x590F172A),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 13.5, color: Colors.white),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF94A3B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x590F172A),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(fontSize: 13.5, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.checked, required this.label});

  final bool checked;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (checked)
            const Icon(LucideIcons.check, size: 14, color: AppColors.success)
          else
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
          const SizedBox(width: 12),
          Text(
            '✓ $label',
            style: TextStyle(
              fontSize: 13,
              color: checked ? Colors.white : const Color(0xFFCBD5E1),
              fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: highlight ? 14 : 13,
              fontWeight: FontWeight.w700,
              fontFamily: highlight ? 'JetBrains Mono' : null,
              color: highlight ? AppColors.warning : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.variant,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final _ButtonVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Border? border;
    Gradient? gradient;
    List<BoxShadow>? shadow;

    switch (variant) {
      case _ButtonVariant.text:
        bg = Colors.transparent;
        fg = const Color(0xFFCBD5E1);
      case _ButtonVariant.secondary:
        bg = Colors.white.withValues(alpha: 0.05);
        fg = Colors.white;
        border = Border.all(color: Colors.white.withValues(alpha: 0.2));
      case _ButtonVariant.primary:
        bg = Colors.transparent;
        fg = Colors.white;
        gradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentBlueHover, AppColors.accentBlue],
        );
        shadow = [
          BoxShadow(
            color: AppColors.accentBlueHover.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          gradient: gradient,
          border: border,
          borderRadius: BorderRadius.circular(8),
          boxShadow: shadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
