import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/field_notes_api.dart';
import '../../data/live_detection_api.dart';
import '../../data/reports_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/landscape_fullscreen.dart';
import '../../utils/screen_awake.dart';
import '../../utils/voice_note_player.dart';
import '../../utils/voice_recorder.dart';
import '../reports/widgets/pavement_type_selector.dart';
import '../reports/widgets/report_ready_sheet.dart';
import 'widgets/field_note_tile.dart';
import 'widgets/mjpeg_view.dart';
import 'widgets/real_time_detection_feed.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// LiveMonitoring/LiveMonitoringDashboard.tsx and its CSS, extended with a
/// second camera source: alongside the original USB-camera-on-the-server
/// path (FastAPI's `/api/v1/live/start` + a physical camera attached to
/// whatever machine hosts the backend), this device's own camera can also
/// be used, streaming frames to `/api/v1/live/phone-stream` -- necessary
/// once the backend runs on a remote server rather than the field device.
/// Both paths feed the exact same detection loop server-side; only where
/// the frames come from differs.
enum LiveSource { usbCamera, thisDeviceCamera }

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

  LiveSource _source = LiveSource.usbCamera;

  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSubscription;

  CameraController? _cameraController;
  // The camera picture keeps this key in both the normal card and the full-screen view, so
  // expanding moves the same picture instead of building a second one (on the web that would
  // mean a second video view for the one camera).
  final GlobalKey _previewKey = GlobalKey(debugLabel: 'live-camera-preview');

  // Field notes: snapshots and voice notes the surveyor adds by hand to this session's report.
  static const int _maxVoiceSeconds = 120;
  final _notesApi = FieldNotesApi();
  final _voice = VoiceRecorder();
  late final VoiceNotePlayer _player = VoiceNotePlayer(
    onFinished: () {
      if (mounted) setState(() => _playingNoteId = null);
    },
  );
  List<FieldNote> _notes = [];
  int? _notesVideoId;
  bool _recordingVoice = false;
  bool _savingNote = false;
  int _voiceSeconds = 0;
  Timer? _voiceTicker;
  int? _playingNoteId;
  List<CameraDescription> _availableCameras = [];
  WebSocketChannel? _phoneStreamChannel;
  Timer? _captureTimer;
  bool _captureBusy = false;
  // Flow control: the server acknowledges every frame it receives. Once it has done so at
  // least once, never keep more than _maxFramesInFlight unacknowledged, so a slow connection
  // lowers the frame rate instead of building a queue of stale pictures. (An older server
  // never acknowledges, so nothing is held back until the first acknowledgement arrives.)
  static const int _maxFramesInFlight = 2;
  int _framesInFlight = 0;
  bool _serverAcks = false;
  DateTime _lastAckAt = DateTime.now();
  LiveEvent? _overlayEvent;
  Timer? _overlayClearTimer;

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
      _loadNotes(status.sessionVideoId);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB91C1C) : null,
        duration: const Duration(seconds: 3),
      ));
  }

  Future<void> _loadNotes([int? videoId]) async {
    final id = videoId ?? _notesVideoId ?? _status?.sessionVideoId;
    if (id == null) return;
    try {
      final list = await _notesApi.list(id);
      if (!mounted) return;
      setState(() {
        _notesVideoId = id;
        _notes = list;
      });
    } catch (_) {
      // The list is a convenience; a failed refresh must not disturb detection.
    }
  }

  /// Saves the newest camera picture to this session's report.
  Future<void> _addSnapshot() async {
    if (!_running || _savingNote) return;
    setState(() => _savingNote = true);
    try {
      final note = await _notesApi.addToLiveSession(snapshot: true);
      await _loadNotes(note.videoId);
      _toast('Snapshot added to the report');
    } on FieldNotesException catch (e) {
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  /// Starts a voice note, or (when one is being recorded) stops it and saves it to the report.
  Future<void> _toggleVoiceNote() async {
    if (_recordingVoice) {
      await _finishVoiceNote();
      return;
    }
    if (!_running || _savingNote) return;
    try {
      if (!await _voice.start()) {
        _toast('Allow the microphone to record a voice note.', error: true);
        return;
      }
    } catch (_) {
      _toast('Could not start the microphone.', error: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _recordingVoice = true;
      _voiceSeconds = 0;
    });
    _voiceTicker?.cancel();
    _voiceTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _voiceSeconds++);
      if (_voiceSeconds >= _maxVoiceSeconds) _finishVoiceNote();
    });
  }

  Future<void> _finishVoiceNote() async {
    _voiceTicker?.cancel();
    _voiceTicker = null;
    if (!_recordingVoice) return;
    setState(() {
      _recordingVoice = false;
      _savingNote = true;
    });
    try {
      final clip = await _voice.stop();
      if (clip == null) {
        _toast('Nothing was recorded.', error: true);
        return;
      }
      final note = await _notesApi.addToLiveSession(
        audio: clip.bytes,
        audioFilename: clip.filename,
        audioSeconds: clip.seconds,
      );
      await _loadNotes(note.videoId);
      _toast('Voice note added to the report');
    } on FieldNotesException catch (e) {
      _toast(e.message, error: true);
    } catch (_) {
      _toast('Could not save the voice note.', error: true);
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _deleteNote(FieldNote note) async {
    try {
      await _notesApi.delete(note.id);
      if (!mounted) return;
      if (_playingNoteId == note.id) _player.stop();
      setState(() {
        _notes = _notes.where((n) => n.id != note.id).toList();
        if (_playingNoteId == note.id) _playingNoteId = null;
      });
    } on FieldNotesException catch (e) {
      _toast(e.message, error: true);
    }
  }

  Future<void> _togglePlayNote(FieldNote note) async {
    final url = note.audioUrl;
    if (url == null) return;
    if (_playingNoteId == note.id) {
      _player.stop();
      setState(() => _playingNoteId = null);
      return;
    }
    // No `await` before the player starts: browsers only allow sound that starts straight from the tap.
    setState(() => _playingNoteId = note.id);
    try {
      await _player.play(url);
    } on VoicePlaybackException catch (e) {
      if (mounted) setState(() => _playingNoteId = null);
      _toast(e.message, error: true);
    }
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
      _notes = [];
      _notesVideoId = null;
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

  Future<void> _startThisDeviceCamera() async {
    setState(() {
      _starting = true;
      _error = null;
      _notes = [];
      _notesVideoId = null;
    });
    try {
      if (_availableCameras.isEmpty) {
        _availableCameras = await availableCameras();
      }
      if (_availableCameras.isEmpty) {
        throw Exception('No camera found on this device');
      }
      final chosen = _availableCameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );
      final controller = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      // No flash, and keep refocusing on the road as the vehicle moves. Each call is
      // best-effort: not every phone supports every mode.
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cameraController = controller;

      final channel = _api.connectPhoneStreamWs();
      _phoneStreamChannel = channel;
      // Surface a connection failure the same way the USB path does — this
      // channel is send-only otherwise, so errors are the only thing worth
      // listening for.
      _framesInFlight = 0;
      _serverAcks = false;
      channel.stream.listen(
        (dynamic message) {
          // 0x01 = "frame received"; 0x00 is the periodic keepalive.
          if (message is List<int> && message.isNotEmpty && message[0] == 1) {
            _serverAcks = true;
            _lastAckAt = DateTime.now();
            if (_framesInFlight > 0) _framesInFlight--;
          }
        },
        onError: (Object e) {
          if (mounted) setState(() => _error = 'Camera stream connection lost: $e');
        },
      );

      setState(() {
        _running = true;
        _streamKey++;
      });
      keepScreenAwake(true);
      _connectWs();
      // Check often, but only start a new capture once the previous frame has been
      // sent (see _captureBusy), so frames go out as fast as the phone can take them.
      _captureTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _captureAndSendFrame(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to start this device\'s camera: $e');
      await _cameraController?.dispose();
      _cameraController = null;
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _captureAndSendFrame() async {
    final controller = _cameraController;
    final channel = _phoneStreamChannel;
    if (controller == null || !controller.value.isInitialized) return;
    if (_captureBusy || controller.value.isTakingPicture || channel == null) return;
    if (_serverAcks && _framesInFlight >= _maxFramesInFlight) {
      // Wait for the server to catch up. If acknowledgements stop for a while, carry on anyway.
      if (DateTime.now().difference(_lastAckAt) < const Duration(seconds: 5)) return;
      _framesInFlight = 0;
    }
    _captureBusy = true;
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      channel.sink.add(bytes);
      _framesInFlight++;
    } catch (_) {
      // Transient capture failure (e.g. controller mid-disposal on stop) —
      // skip this tick, the next timer fire tries again.
    } finally {
      _captureBusy = false;
    }
  }

  Future<void> _stopThisDeviceCamera() async {
    keepScreenAwake(false);
    _captureTimer?.cancel();
    _captureTimer = null;
    _overlayClearTimer?.cancel();
    _overlayClearTimer = null;
    await _phoneStreamChannel?.sink.close();
    _phoneStreamChannel = null;
    await _cameraController?.dispose();
    _cameraController = null;
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    // The backend already stops itself when the phone-stream socket closes
    // (see the WS handler's `finally`), but this is idempotent and cheap —
    // cheaper to call it than to trust two independent shutdown paths agree.
    await _api.stop();
    if (!mounted) return;
    setState(() {
      _running = false;
      _overlayEvent = null;
    });
  }

  Future<void> _stop() async {
    if (_recordingVoice) await _finishVoiceNote();
    if (_source == LiveSource.thisDeviceCamera) {
      await _stopThisDeviceCamera();
      return;
    }
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
            if (!_status!.running) {
              _running = false;
              keepScreenAwake(false);
            }
            if (_status!.error != null) _error = _status!.error;
          }
          final eventsJson = data['events'] as List<dynamic>?;
          if (eventsJson != null && eventsJson.isNotEmpty) {
            final newEvents = eventsJson
                .map((e) => LiveEvent.fromJson(e as Map<String, dynamic>))
                .toList();
            if (_source == LiveSource.thisDeviceCamera) {
              final withBox = newEvents.lastWhere(
                (e) => e.box != null,
                orElse: () => newEvents.last,
              );
              if (withBox.box != null) {
                _overlayEvent = withBox;
                _overlayClearTimer?.cancel();
                _overlayClearTimer = Timer(const Duration(milliseconds: 1500), () {
                  if (mounted) setState(() => _overlayEvent = null);
                });
              }
            }
            _events.insertAll(0, newEvents.reversed);
            if (_events.length > 30) _events.removeRange(30, _events.length);
          }
        });
      },
      onError: (Object _) {
        if (mounted) setState(() => _error = 'WebSocket connection lost');
      },
    );
  }

  /// Full screen: landscape, system bars hidden, dashboard menus hidden (see landscape_fullscreen.dart).
  void _setFullscreen(bool value) {
    setState(() => _isFullscreen = value);
    if (value) {
      enterLandscapeFullscreen();
    } else {
      exitLandscapeFullscreen();
    }
  }

  void _acknowledgeAlert(int seq) {
    setState(() => _events.removeWhere((e) => e.seq == seq));
  }

  @override
  void dispose() {
    keepScreenAwake(false);
    if (_isFullscreen) {
      // Leaving this screen while full screen: give the phone its normal rotation and bars back.
      WidgetsBinding.instance.addPostFrameCallback((_) => exitLandscapeFullscreen());
    }
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _captureTimer?.cancel();
    _overlayClearTimer?.cancel();
    _phoneStreamChannel?.sink.close();
    _cameraController?.dispose();
    _voiceTicker?.cancel();
    _voice.cancel();
    _voice.dispose();
    _player.dispose();
    _notesApi.dispose();
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
      onToggleFullscreen: () => _setFullscreen(!_isFullscreen),
      source: _source,
      onSourceChange: _running
          ? null
          : (s) => setState(() => _source = s),
      cameraController: _cameraController,
      previewKey: _previewKey,
      overlayEvent: _overlayEvent,
      onStartThisDeviceCamera: _startThisDeviceCamera,
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
      // True full screen: just the camera picture with a few floating controls. The phone's
      // Back button leaves full screen first instead of leaving this screen.
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _setFullscreen(false);
        },
        child: _LiveFullscreenView(
          source: _source,
          running: _running,
          starting: _starting,
          status: _status,
          error: _error,
          streamUrl: _api.streamUrlFor(_streamKey),
          cameraController: _cameraController,
          previewKey: _previewKey,
          overlayEvent: _overlayEvent,
          latestEvent: _events.isEmpty ? null : _events.first,
          onStart: _source == LiveSource.usbCamera ? _start : _startThisDeviceCamera,
          onStop: _stop,
          onExit: () => _setFullscreen(false),
          recordingVoice: _recordingVoice,
          voiceSeconds: _voiceSeconds,
          savingNote: _savingNote,
          onSnapshot: _addSnapshot,
          onVoice: _toggleVoiceNote,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          running: _running,
          isFullscreen: _isFullscreen,
          onToggleFullscreen: () => _setFullscreen(!_isFullscreen),
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
        if (_running || _notes.isNotEmpty) ...[
          _FieldNotesCard(
            notes: _notes,
            running: _running,
            recording: _recordingVoice,
            voiceSeconds: _voiceSeconds,
            saving: _savingNote,
            playingNoteId: _playingNoteId,
            onSnapshot: _addSnapshot,
            onVoice: _toggleVoiceNote,
            onDelete: _deleteNote,
            onPlay: _togglePlayNote,
          ),
          const SizedBox(height: 32),
        ],
        RealTimeDetectionFeed(detections: _feedDetections),
        const SizedBox(height: 32),
        _DetectionHistoryCard(events: _events),
        const SizedBox(height: 32),
        if (_status?.sessionVideoId != null) ...[
          _SessionReportCard(status: _status!),
          const SizedBox(height: 32),
        ],
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
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        spacing: 16,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Row(
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
              Flexible(
                child: Column(
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
              ),
            ],
            ),
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
    required this.source,
    required this.onSourceChange,
    required this.cameraController,
    required this.previewKey,
    required this.overlayEvent,
    required this.onStartThisDeviceCamera,
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
  final LiveSource source;
  final ValueChanged<LiveSource>? onSourceChange;
  final CameraController? cameraController;
  final GlobalKey previewKey;
  final LiveEvent? overlayEvent;
  final VoidCallback onStartThisDeviceCamera;

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
          const SizedBox(height: 16),
          _SourceToggle(source: source, onChange: onSourceChange),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: isFullscreen ? 16 / 7 : 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreview(),
                  if (source == LiveSource.thisDeviceCamera && running)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _OverlayIconButton(
                        icon: LucideIcons.maximize2,
                        tooltip: 'Full screen',
                        onTap: onToggleFullscreen,
                      ),
                    ),
                ],
              ),
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
              if (source == LiveSource.usbCamera)
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
                  label: starting
                      ? 'Initializing...'
                      : source == LiveSource.usbCamera
                          ? 'Start Live Detection'
                          : 'Start Using This Camera',
                  icon: starting ? null : LucideIcons.play,
                  loading: starting,
                  color: AppColors.success,
                  onTap: starting
                      ? null
                      : (source == LiveSource.usbCamera ? onStart : onStartThisDeviceCamera),
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

  Widget _buildPreview() => _buildLivePreview(
        source: source,
        running: running,
        streamUrl: streamUrl,
        cameraController: cameraController,
        previewKey: previewKey,
        overlayEvent: overlayEvent,
      );
}

/// Width / height of the camera picture, or a sensible default when the camera has not reported a
/// size yet (some browsers report 0 x 0 for a moment, which would otherwise give a ratio that is
/// not a number and break the layout).
@visibleForTesting
double safeAspectRatio(double raw) => raw.isFinite && raw > 0 ? raw : 16 / 9;

double _previewAspectRatio(CameraController controller) {
  try {
    return safeAspectRatio(controller.value.aspectRatio);
  } catch (_) {
    return 16 / 9;
  }
}

/// The live picture (the server's stream for a USB camera, or this device's own camera with the
/// latest detection box on top). Shared by the normal card and the full-screen view.
Widget _buildLivePreview({
  required LiveSource source,
  required bool running,
  required String streamUrl,
  required CameraController? cameraController,
  required GlobalKey previewKey,
  required LiveEvent? overlayEvent,
}) {
  if (source == LiveSource.usbCamera) {
    return running
        ? MjpegView(url: streamUrl, onError: (_) {})
        : const _StreamOfflineState(sourceLabel: 'USB camera');
  }
  final controller = cameraController;
  if (!running || controller == null || !controller.value.isInitialized) {
    return const _StreamOfflineState(sourceLabel: 'this device\'s camera');
  }
  return AspectRatio(
    aspectRatio: _previewAspectRatio(controller),
    child: Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(key: previewKey, child: CameraPreview(controller)),
        CustomPaint(painter: _BoxOverlayPainter(event: overlayEvent)),
      ],
    ),
  );
}

class _SourceToggle extends StatelessWidget {
  const _SourceToggle({required this.source, required this.onChange});
  final LiveSource source;
  final ValueChanged<LiveSource>? onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SourceChip(
          label: 'USB Camera (server)',
          icon: LucideIcons.usb,
          selected: source == LiveSource.usbCamera,
          onTap: onChange == null ? null : () => onChange!(LiveSource.usbCamera),
        ),
        _SourceChip(
          label: 'This Device\'s Camera',
          icon: LucideIcons.smartphone,
          selected: source == LiveSource.thisDeviceCamera,
          onTap: onChange == null ? null : () => onChange!(LiveSource.thisDeviceCamera),
        ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentBlueLight : AppColors.primaryBg,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: selected ? AppColors.accentBlue : AppColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? AppColors.accentBlue : AppColors.secondaryText),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.accentBlue : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the most recent detection's box on top of the local camera preview.
/// Box coordinates arrive relative to the frame that was actually sent to
/// the backend (event.frameWidth/frameHeight), not this widget's on-screen
/// size, so they're scaled proportionally here.
class _BoxOverlayPainter extends CustomPainter {
  _BoxOverlayPainter({required this.event, this.cover = false});
  final LiveEvent? event;

  /// The picture under this overlay fills its box and crops the overflow (like a video call),
  /// instead of being stretched to fit it exactly.
  final bool cover;

  static const _severityColors = {
    'critical': Color(0xFFEF4444),
    'high': Color(0xFFF59E0B),
    'medium': Color(0xFF3B82F6),
    'low': Color(0xFF10B981),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final ev = event;
    final box = ev?.box;
    final fw = ev?.frameWidth;
    final fh = ev?.frameHeight;
    if (ev == null || box == null || box.length < 4 || fw == null || fh == null || fw == 0 || fh == 0) {
      return;
    }
    final color = _severityColors[ev.severity.toLowerCase()] ?? AppColors.accentBlue;
    var scaleX = size.width / fw;
    var scaleY = size.height / fh;
    var offsetX = 0.0;
    var offsetY = 0.0;
    if (cover) {
      // One scale for both directions (the larger one fills the box); centre the cropped picture.
      final scale = scaleX > scaleY ? scaleX : scaleY;
      scaleX = scale;
      scaleY = scale;
      offsetX = (size.width - fw * scale) / 2;
      offsetY = (size.height - fh * scale) / 2;
    }
    final rect = Rect.fromLTRB(
      box[0] * scaleX + offsetX,
      box[1] * scaleY + offsetY,
      box[2] * scaleX + offsetX,
      box[3] * scaleY + offsetY,
    );

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );

    final label = '${ev.className} ${(ev.confidence * 100).round()}%';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, backgroundColor: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelTop = (rect.top - textPainter.height).clamp(0.0, size.height);
    textPainter.paint(canvas, Offset(rect.left, labelTop));
  }

  @override
  bool shouldRepaint(covariant _BoxOverlayPainter oldDelegate) =>
      oldDelegate.event != event || oldDelegate.cover != cover;
}

class _StreamOfflineState extends StatelessWidget {
  const _StreamOfflineState({this.sourceLabel = 'the camera'});
  final String sourceLabel;

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
              Text(
                'Start live monitoring below to activate YOLO inference scanning using $sourceLabel.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
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

/// Turns the detections saved during this live session into a PDF / Excel report (then offers to share it).
class _SessionReportCard extends StatefulWidget {
  const _SessionReportCard({required this.status});
  final LiveStatus status;

  @override
  State<_SessionReportCard> createState() => _SessionReportCardState();
}

class _SessionReportCardState extends State<_SessionReportCard> {
  final _reportsApi = ReportsApi();
  bool _busyPdf = false;
  bool _busyExcel = false;

  @override
  void dispose() {
    _reportsApi.dispose();
    super.dispose();
  }

  Future<void> _generate({required bool excel}) async {
    final videoId = widget.status.sessionVideoId;
    if (videoId == null) return;
    setState(() => excel ? _busyExcel = true : _busyPdf = true);
    try {
      final record = excel
          ? await _reportsApi.generateExcelReport(videoId)
          : await _reportsApi.generatePdfReport(videoId);
      if (!mounted) return;
      await showReportReadySheet(
        context,
        api: _reportsApi,
        reportId: record.id,
        excel: excel,
        name: record.reportName,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(excel ? 'Could not build the Excel report.' : 'Could not build the PDF report.')),
      );
    } finally {
      if (mounted) setState(() => excel ? _busyExcel = false : _busyPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busyPdf || _busyExcel;
    final saved = widget.status.persisted;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(LucideIcons.fileText, size: 22, color: AppColors.accentBlue),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Session report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(
                '$saved detection${saved == 1 ? '' : 's'} saved from this live session',
                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
            ],
          ),
          const PavementTypeSelector(showHint: false),
          FilledButton.icon(
            onPressed: busy ? null : () => _generate(excel: false),
            icon: _busyPdf
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.fileText, size: 16),
            label: const Text('PDF report'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _generate(excel: true),
            icon: _busyExcel
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.sheet, size: 16),
            label: const Text('Excel report'),
          ),
        ],
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

/// A small round button that sits on top of the camera picture.
class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({required this.icon, required this.tooltip, required this.onTap, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color ?? const Color(0x99000000),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Small dark label that sits on top of the camera picture.
class _OverlayChip extends StatelessWidget {
  const _OverlayChip(this.text, {this.color = Colors.white});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Live detection in full screen, like a video call: the camera picture covers the whole screen
/// (with the detection box and its label drawn on it) and nothing else shows until you tap the
/// picture. A tap brings up the exit button, the live status and the start / stop button for a few
/// seconds.
class _LiveFullscreenView extends StatefulWidget {
  const _LiveFullscreenView({
    required this.source,
    required this.running,
    required this.starting,
    required this.status,
    required this.error,
    required this.streamUrl,
    required this.cameraController,
    required this.previewKey,
    required this.overlayEvent,
    required this.latestEvent,
    required this.onStart,
    required this.onStop,
    required this.onExit,
    required this.recordingVoice,
    required this.voiceSeconds,
    required this.savingNote,
    required this.onSnapshot,
    required this.onVoice,
  });

  final LiveSource source;
  final bool running;
  final bool starting;
  final LiveStatus? status;
  final String? error;
  final String streamUrl;
  final CameraController? cameraController;
  final GlobalKey previewKey;
  final LiveEvent? overlayEvent;
  final LiveEvent? latestEvent;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onExit;
  final bool recordingVoice;
  final int voiceSeconds;
  final bool savingNote;
  final VoidCallback onSnapshot;
  final VoidCallback onVoice;

  @override
  State<_LiveFullscreenView> createState() => _LiveFullscreenViewState();
}

class _LiveFullscreenViewState extends State<_LiveFullscreenView> {
  static const _hideAfter = Duration(seconds: 4);
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant _LiveFullscreenView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Just started: show the controls for a moment, then get out of the way.
    if (!oldWidget.running && widget.running) _reveal();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _reveal() {
    setState(() => _showControls = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_showControls) {
      _hideTimer?.cancel();
      setState(() => _showControls = false);
    } else {
      _reveal();
    }
  }

  bool get _cameraReady {
    final c = widget.cameraController;
    return widget.source == LiveSource.thisDeviceCamera &&
        widget.running &&
        c != null &&
        c.value.isInitialized;
  }

  Widget _picture() {
    final controller = widget.cameraController;
    if (_cameraReady && controller != null && kIsWeb) {
      // In a browser the video element already crops itself to fill whatever box it is given
      // (object-fit: cover), so give it the whole screen and add no scaling around it. The
      // detection box is mapped onto the cropped picture by the painter (cover: true).
      return SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(key: widget.previewKey, child: CameraPreview(controller)),
            CustomPaint(painter: _BoxOverlayPainter(event: widget.overlayEvent, cover: true)),
          ],
        ),
      );
    }
    if (_cameraReady && controller != null) {
      // Installed app: cover the whole screen (crop the edges if the shapes differ). The detection
      // box is drawn inside the same scaled box, so it stays exactly on what it marks.
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _previewAspectRatio(controller) * 1000,
            height: 1000,
            child: Stack(
              fit: StackFit.expand,
              children: [
                KeyedSubtree(key: widget.previewKey, child: CameraPreview(controller)),
                CustomPaint(painter: _BoxOverlayPainter(event: widget.overlayEvent)),
              ],
            ),
          ),
        ),
      );
    }
    final preview = _buildLivePreview(
      source: widget.source,
      running: widget.running,
      streamUrl: widget.streamUrl,
      cameraController: controller,
      previewKey: widget.previewKey,
      overlayEvent: widget.overlayEvent,
    );
    if (widget.source == LiveSource.usbCamera && widget.running) {
      return Center(child: AspectRatio(aspectRatio: 16 / 9, child: preview));
    }
    return SizedBox.expand(child: preview);
  }

  Widget _controls() {
    final s = widget.status;
    final detection =
        widget.overlayEvent ?? (widget.source == LiveSource.usbCamera ? widget.latestEvent : null);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 8,
          left: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OverlayIconButton(
                icon: LucideIcons.minimize2,
                tooltip: 'Exit full screen',
                onTap: widget.onExit,
              ),
              const SizedBox(width: 8),
              _OverlayChip(
                widget.running ? 'LIVE' : 'IDLE',
                color: widget.running ? const Color(0xFFF87171) : Colors.white70,
              ),
            ],
          ),
        ),
        if (widget.running && s != null)
          Positioned(
            top: 8,
            right: 8,
            child: _OverlayChip(
              '${(s.inferenceFps ?? 0).toStringAsFixed(1)} detections/s  ·  ${s.inferences} checked',
            ),
          ),
        if (widget.running && detection != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: _OverlayChip(
              '${detection.className}  ·  ${detection.severity}  ·  ${(detection.confidence * 100).round()}%',
              color: const Color(0xFFFBBF24),
            ),
          ),
        if (widget.running)
          Positioned(
            right: 8,
            bottom: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _OverlayIconButton(
                  icon: LucideIcons.camera,
                  tooltip: 'Add a snapshot to the report',
                  onTap: widget.savingNote ? () {} : widget.onSnapshot,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.recordingVoice) ...[
                      _OverlayChip(
                        'REC  ${_clock(widget.voiceSeconds)}',
                        color: const Color(0xFFF87171),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _OverlayIconButton(
                      icon: widget.recordingVoice ? LucideIcons.square : LucideIcons.mic,
                      tooltip: widget.recordingVoice
                          ? 'Stop and add the voice note to the report'
                          : 'Record a voice note for the report',
                      onTap: widget.savingNote ? () {} : widget.onVoice,
                      color: widget.recordingVoice ? const Color(0xCCDC2626) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        Positioned(
          right: 8,
          bottom: 8,
          child: widget.running
              ? _SolidButton(
                  label: 'Stop',
                  icon: LucideIcons.square,
                  color: AppColors.danger,
                  onTap: widget.onStop,
                )
              : _SolidButton(
                  label: widget.starting ? 'Starting...' : 'Start',
                  icon: widget.starting ? null : LucideIcons.play,
                  loading: widget.starting,
                  color: AppColors.success,
                  onTap: widget.starting ? null : widget.onStart,
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Until it is running there is nothing to look at, so the controls stay (you need Start).
    // (and keep them while a voice note is being recorded, so it can be stopped)
    final visible = !widget.running || _showControls || widget.recordingVoice;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: _picture(),
          ),
          IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _controls(),
            ),
          ),
          if (widget.error != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 56,
              child: IgnorePointer(
                child: Text(
                  widget.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFF87171)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _clock(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final sec = totalSeconds % 60;
  return '$m:${sec.toString().padLeft(2, '0')}';
}

/// Snapshots and voice notes the surveyor adds by hand, for places the camera detection missed. They are
/// saved to this session's report (PDF and Excel).
class _FieldNotesCard extends StatelessWidget {
  const _FieldNotesCard({
    required this.notes,
    required this.running,
    required this.recording,
    required this.voiceSeconds,
    required this.saving,
    required this.playingNoteId,
    required this.onSnapshot,
    required this.onVoice,
    required this.onDelete,
    required this.onPlay,
  });

  final List<FieldNote> notes;
  final bool running;
  final bool recording;
  final int voiceSeconds;
  final bool saving;
  final int? playingNoteId;
  final VoidCallback onSnapshot;
  final VoidCallback onVoice;
  final ValueChanged<FieldNote> onDelete;
  final ValueChanged<FieldNote> onPlay;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clipboardList, size: 16, color: AppColors.accentBlue),
              const SizedBox(width: 12),
              Text(
                notes.isEmpty ? 'Field Notes' : 'Field Notes (${notes.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Something the camera missed? Add a snapshot or a voice note. They are saved to this '
            'session\'s report.',
            style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SolidButton(
                label: 'Add snapshot',
                icon: LucideIcons.camera,
                color: AppColors.accentBlue,
                onTap: running && !saving && !recording ? onSnapshot : null,
              ),
              _SolidButton(
                label: recording ? 'Stop  ${_clock(voiceSeconds)}' : 'Record voice note',
                icon: recording ? LucideIcons.square : LucideIcons.mic,
                color: recording ? AppColors.danger : AppColors.success,
                onTap: running && !saving ? onVoice : null,
              ),
              if (saving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (!running && notes.isNotEmpty)
                const Text(
                  'Start live detection to add more notes.',
                  style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.cardBorder),
            for (final note in notes.reversed)
              FieldNoteTile(
                note: note,
                playing: playingNoteId == note.id,
                onDelete: () => onDelete(note),
                onPlay: () => onPlay(note),
              ),
          ],
        ],
      ),
    );
  }
}
