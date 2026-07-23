import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/live_detection_api.dart';
import '../../theme/app_colors.dart';
import 'widgets/mjpeg_view.dart';
import 'widgets/real_time_detection_feed.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// LiveMonitoring/LiveMonitoringDashboard.tsx and its CSS — the one screen
/// in this port wired to a real (not mocked) backend: FastAPI's
/// `/api/v1/live/*` REST + WebSocket routes, which run a real YOLOX
/// inference pipeline against a physical USB camera on whatever machine
/// hosts the backend (see backend/app/services/live/live_camera_service.py).
/// There is no client-uploads-frames path — this only works with the
/// backend actually running locally with a camera attached.
class LiveDetectionScreen extends StatefulWidget {
  const LiveDetectionScreen({super.key});

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  final _api = LiveDetectionApi();
  final _cameraIndexController = TextEditingController(text: '1');

  bool _running = false;
  bool _starting = false;
  LiveStatus? _status;
  final List<LiveEvent> _events = [];
  String? _error;
  int _streamKey = 0;
  bool _isFullscreen = false;

  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSubscription;

  int get _cameraIndex => int.tryParse(_cameraIndexController.text) ?? 1;

  @override
  void initState() {
    super.initState();
    _probeStatus();
  }

  Future<void> _probeStatus() async {
    final status = await _api.fetchStatus();
    if (!mounted || status == null) return;
    if (status.running) {
      setState(() {
        _running = true;
        _status = status;
      });
      _connectWs();
    }
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await _api.start(cameraIndex: _cameraIndex);
      if (!mounted) return;
      setState(() {
        _running = true;
        _streamKey++;
      });
      _connectWs();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is LiveDetectionException
            ? e.message
            : 'Failed to start live camera';
      });
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop() async {
    await _api.stop();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    if (!mounted) return;
    setState(() => _running = false);
  }

  void _connectWs() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    final channel = _api.connectWs();
    _wsChannel = channel;
    _wsSubscription = channel.stream.listen(
      (dynamic message) {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          final statusJson = data['status'] as Map<String, dynamic>?;
          if (statusJson != null) {
            _status = LiveStatus.fromJson(statusJson);
            if (!_status!.running) _running = false;
            if (_status!.error != null) _error = _status!.error;
          }
          final eventsJson = data['events'] as List<dynamic>?;
          if (eventsJson != null && eventsJson.isNotEmpty) {
            final newEvents = eventsJson
                .map((e) => LiveEvent.fromJson(e as Map<String, dynamic>))
                .toList()
                .reversed;
            _events.insertAll(0, newEvents);
            if (_events.length > 30) _events.removeRange(30, _events.length);
          }
        });
      },
      onError: (Object _) {
        if (mounted) setState(() => _error = 'WebSocket connection lost');
      },
    );
  }

  void _acknowledgeAlert(int seq) {
    setState(() => _events.removeWhere((e) => e.seq == seq));
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _api.dispose();
    _cameraIndexController.dispose();
    super.dispose();
  }

  List<FeedDetection> get _feedDetections => _events
      .map(
        (ev) => FeedDetection(
          id: 'DET-${ev.seq}',
          time: ev.time,
          roadId: ev.modelSource == 'road' ? 'RD-PAVEMENT' : 'RD-SIGNAGE',
          distressType: ev.className,
          severity: ev.severity.isEmpty
              ? ev.severity
              : ev.severity[0].toUpperCase() + ev.severity.substring(1),
          confidence: (ev.confidence * 100).round(),
          coordinates:
              '${ev.latitude.toStringAsFixed(6)}, ${ev.longitude.toStringAsFixed(6)}',
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final activeOverlay = _events.isNotEmpty ? _events.first : null;
    final criticalAlerts =
        _events.where((e) => e.severity.toLowerCase() == 'critical').toList();

    final feedCard = _CameraFeedCard(
      running: _running,
      starting: _starting,
      status: _status,
      error: _error,
      streamUrl: _api.streamUrlFor(_streamKey),
      cameraIndexController: _cameraIndexController,
      onStart: _start,
      onStop: _stop,
      isFullscreen: _isFullscreen,
      onToggleFullscreen: () => setState(() => _isFullscreen = !_isFullscreen),
    );

    // This screen is embedded as DashboardShell's `child` (which already
    // provides the Scaffold/background/scrolling/centering), so it must
    // return plain content — nesting another Scaffold here breaks layout
    // under the shell's unbounded-height scroll view (same category of bug
    // as the IntrinsicHeight/GridView issue fixed on other screens).
    //
    // The React source's "fullscreen" is itself just a CSS position:fixed
    // trick (not the real Fullscreen API), so this mirrors that intent by
    // collapsing the page down to just the feed card rather than trying to
    // visually escape above the dashboard shell/sidebar.
    if (_isFullscreen) {
      return feedCard;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          running: _running,
          isFullscreen: _isFullscreen,
          onToggleFullscreen: () =>
              setState(() => _isFullscreen = !_isFullscreen),
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 1200;
            final sidebar = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_running && activeOverlay != null) ...[
                  _CurrentDetectionCard(event: activeOverlay),
                  const SizedBox(height: 32),
                ],
                _CriticalWarningsCard(
                  alerts: criticalAlerts,
                  onAcknowledge: _acknowledgeAlert,
                ),
              ],
            );

            if (narrow) {
              return Column(
                children: [feedCard, const SizedBox(height: 32), sidebar],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: feedCard),
                const SizedBox(width: 32),
                Expanded(flex: 3, child: sidebar),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        RealTimeDetectionFeed(detections: _feedDetections),
        const SizedBox(height: 32),
        _DetectionHistoryCard(events: _events),
        const SizedBox(height: 32),
        _KpiFooter(status: _status, running: _running),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.running,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  final bool running;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      radius: 20,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        spacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentBlueLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0x263B82F6),
                  ),
                ),
                child: const Icon(
                  LucideIcons.tv,
                  size: 28,
                  color: AppColors.accentBlue,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Live Monitoring Center',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time road distress detection and AI video stream diagnostics',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.secondaryText.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBg,
                  border: Border.all(color: AppColors.cardBorder),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: running ? AppColors.danger : AppColors.secondaryText,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      running ? 'LIVE: ACTIVE' : 'FEED: IDLE',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _IconActionButton(
                icon: isFullscreen ? LucideIcons.minimize2 : LucideIcons.maximize2,
                onTap: onToggleFullscreen,
                tooltip: isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.primaryBg,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 16, color: AppColors.secondaryText),
          ),
        ),
      ),
    );
  }
}

class _CameraFeedCard extends StatelessWidget {
  const _CameraFeedCard({
    required this.running,
    required this.starting,
    required this.status,
    required this.error,
    required this.streamUrl,
    required this.cameraIndexController,
    required this.onStart,
    required this.onStop,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  final bool running;
  final bool starting;
  final LiveStatus? status;
  final String? error;
  final String streamUrl;
  final TextEditingController cameraIndexController;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.radio,
                    size: 16,
                    color: running ? AppColors.danger : AppColors.secondaryText,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Camera Feed Analysis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              if (running && status != null)
                Wrap(
                  spacing: 15,
                  children: [
                    _TelemetryStat(label: 'Display FPS', value: status!.fps.toStringAsFixed(1)),
                    _TelemetryStat(
                      label: 'Inference FPS',
                      value: (status!.inferenceFps ?? 0).toStringAsFixed(1),
                    ),
                    _TelemetryStat(label: 'Inferences', value: '${status!.inferences}'),
                  ],
                ),
              if (isFullscreen)
                _IconActionButton(
                  icon: LucideIcons.minimize2,
                  onTap: onToggleFullscreen,
                  tooltip: 'Exit Fullscreen',
                ),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: isFullscreen ? 16 / 7 : 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: running
                  ? MjpegView(
                      url: streamUrl,
                      onError: (_) {},
                    )
                  : const _StreamOfflineState(),
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 20),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Camera Index:',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: cameraIndexController,
                      enabled: !running,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13, color: AppColors.primaryText),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        filled: true,
                        fillColor: AppColors.primaryBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!running)
                _SolidButton(
                  label: starting ? 'Initializing Models...' : 'Start Live Detection',
                  icon: starting ? null : LucideIcons.play,
                  loading: starting,
                  color: AppColors.success,
                  onTap: starting ? null : onStart,
                )
              else
                _SolidButton(
                  label: 'Stop Detection',
                  icon: LucideIcons.square,
                  color: AppColors.danger,
                  onTap: onStop,
                ),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: Color(0xFFF87171),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreamOfflineState extends StatelessWidget {
  const _StreamOfflineState();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.radio, size: 48, color: AppColors.secondaryText),
              const SizedBox(height: 12),
              const Text(
                'Live Video Stream Offline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select camera index below and start live monitoring to activate '
                'YOLO inference scanning.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelemetryStat extends StatelessWidget {
  const _TelemetryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
        ],
      ),
    );
  }
}

class _SolidButton extends StatelessWidget {
  const _SolidButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final bool loading;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled ? color.withValues(alpha: 0.5) : color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else if (icon != null)
                Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentDetectionCard extends StatelessWidget {
  const _CurrentDetectionCard({required this.event});
  final LiveEvent event;

  static const _severityColors = {
    'critical': Color(0xFFEF4444),
    'high': Color(0xFFF59E0B),
    'medium': Color(0xFF3B82F6),
    'low': Color(0xFF10B981),
  };

  @override
  Widget build(BuildContext context) {
    final sevColor = _severityColors[event.severity.toLowerCase()] ?? AppColors.accentBlue;
    return _PremiumCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 16, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 10),
              const Text(
                'Current Detection HUD',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Divider(height: 1, color: AppColors.cardBorder),
          ),
          const SizedBox(height: 16),
          const Text(
            'DISTRESS CATEGORY',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            event.className,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HudProp(
                  label: 'Severity',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.12),
                      border: Border.all(color: sevColor.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      event.severity.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sevColor),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _HudProp(
                  label: 'AI Confidence',
                  child: Text(
                    '${(event.confidence * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HudProp(
                  label: 'Source Model',
                  child: Text(
                    event.modelSource.toUpperCase(),
                    style: const TextStyle(fontFamily: 'JetBrains Mono', color: AppColors.primaryText),
                  ),
                ),
              ),
              Expanded(
                child: _HudProp(
                  label: 'Frame Number',
                  child: Text(
                    '#${event.frame}',
                    style: const TextStyle(fontFamily: 'JetBrains Mono', color: AppColors.primaryText),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.cardBorder, style: BorderStyle.solid)),
            ),
            child: _HudProp(
              label: 'Coordinates',
              child: Text(
                '📍 ${event.latitude.toStringAsFixed(6)}, ${event.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudProp extends StatelessWidget {
  const _HudProp({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _CriticalWarningsCard extends StatelessWidget {
  const _CriticalWarningsCard({required this.alerts, required this.onAcknowledge});
  final List<LiveEvent> alerts;
  final ValueChanged<int> onAcknowledge;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.danger),
              const SizedBox(width: 10),
              const Text(
                'Critical Warnings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Divider(height: 1, color: AppColors.cardBorder),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: alerts.isEmpty
                ? const _EmptyAlertsView()
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < alerts.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _AlertItem(alert: alerts[i], onAcknowledge: onAcknowledge),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAlertsView extends StatelessWidget {
  const _EmptyAlertsView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.check, size: 28, color: AppColors.success),
          const SizedBox(height: 10),
          Text(
            'No critical distress alerts active',
            style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  const _AlertItem({required this.alert, required this.onAcknowledge});
  final LiveEvent alert;
  final ValueChanged<int> onAcknowledge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        border: Border(
          top: BorderSide(color: const Color(0x26EF4444)),
          right: BorderSide(color: const Color(0x26EF4444)),
          bottom: BorderSide(color: const Color(0x26EF4444)),
          left: const BorderSide(color: AppColors.danger, width: 3.5),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DET-${alert.seq}',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '[${alert.time.length >= 19 ? alert.time.substring(11, 19) : alert.time}]',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  alert.className,
                  style: const TextStyle(fontSize: 13, color: AppColors.primaryText),
                ),
                const SizedBox(height: 2),
                Text(
                  '📍 ${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onAcknowledge(alert.seq),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x33EF4444)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Acknowledge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionHistoryCard extends StatelessWidget {
  const _DetectionHistoryCard({required this.events});
  final List<LiveEvent> events;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.history, size: 18, color: AppColors.accentBlue),
              const SizedBox(width: 10),
              const Text(
                'Detection History Logs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.primaryBg),
              columns: const [
                DataColumn(label: _TableHeader('Detection ID')),
                DataColumn(label: _TableHeader('Timestamp')),
                DataColumn(label: _TableHeader('Source Model')),
                DataColumn(label: _TableHeader('Distress Category')),
                DataColumn(label: _TableHeader('Severity')),
                DataColumn(label: _TableHeader('Confidence')),
                DataColumn(label: _TableHeader('Coordinates')),
                DataColumn(label: _TableHeader('Status')),
              ],
              rows: events.isEmpty
                  ? [
                      const DataRow(
                        cells: [
                          DataCell(
                            Text(
                              'Waiting for camera detections...',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                        ],
                      ),
                    ]
                  : [for (final row in events) _historyRow(row)],
            ),
          ),
        ],
      ),
    );
  }

  static const _badgeColors = {
    'critical': (bg: Color(0x14EF4444), fg: Color(0xFFEF4444)),
    'high': (bg: Color(0x14EF4444), fg: Color(0xFFEF4444)),
    'medium': (bg: Color(0x14F59E0B), fg: Color(0xFFF59E0B)),
    'low': (bg: Color(0x143B82F6), fg: Color(0xFF3B82F6)),
  };

  DataRow _historyRow(LiveEvent row) {
    final colors = _badgeColors[row.severity.toLowerCase()] ?? _badgeColors['low']!;
    return DataRow(
      cells: [
        DataCell(
          Text(
            'DET-${row.seq}',
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
        ),
        DataCell(Text(row.time.length >= 19 ? row.time.substring(11, 19) : row.time)),
        DataCell(Text(row.modelSource.toUpperCase())),
        DataCell(Text(row.className)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(9999)),
            child: Text(
              row.severity.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.fg),
            ),
          ),
        ),
        DataCell(Text('${(row.confidence * 100).round()}%', style: const TextStyle(fontFamily: 'JetBrains Mono'))),
        DataCell(
          Text(
            '${row.latitude.toStringAsFixed(6)}, ${row.longitude.toStringAsFixed(6)}',
            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11.5),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentBlueLight,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accentBlue),
            ),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: AppColors.secondaryText,
      ),
    );
  }
}

class _KpiFooter extends StatelessWidget {
  const _KpiFooter({required this.status, required this.running});
  final LiveStatus? status;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiData(
        icon: LucideIcons.activity,
        iconColor: const Color(0xFF3B82F6),
        label: 'Total Detections',
        value: '${status?.detectionsTotal ?? 0}',
        caption: 'distresses flagged',
      ),
      _KpiData(
        icon: LucideIcons.cpu,
        iconColor: const Color(0xFF10B981),
        label: 'Average Accuracy',
        value: status != null ? '${(status!.avgConfidence * 100).round()}%' : '0%',
        caption: 'confidence rating',
      ),
      _KpiData(
        icon: LucideIcons.radio,
        iconColor: const Color(0xFFF59E0B),
        label: 'Display / Inference FPS',
        value: status != null
            ? '${status!.fps.toStringAsFixed(1)} / ${(status!.inferenceFps ?? 0).toStringAsFixed(1)} FPS'
            : '0.0 / 0.0 FPS',
        caption: 'stream / inference rates',
      ),
      _KpiData(
        icon: LucideIcons.loader2,
        iconColor: const Color(0xFF8B5CF6),
        label: 'Frames Processed',
        value: '${status?.frames ?? 0}',
        caption: 'total frame count',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 20.0;
        final columns = constraints.maxWidth < 700
            ? 1
            : constraints.maxWidth < 1100
                ? 2
                : 4;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards) SizedBox(width: width, child: _KpiCard(data: c)),
          ],
        );
      },
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.caption,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String caption;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, size: 18, color: data.iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.label,
                  style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.caption,
            style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

/// Matches `.premium-card` in index.css (card-bg fill, card-border, radius).
class _PremiumCard extends StatelessWidget {
  const _PremiumCard({
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
