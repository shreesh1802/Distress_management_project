import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/screens/dashboard/dashboard_shell.dart';
import 'package:mobile/screens/live_detection/live_detection_screen.dart' show safeAspectRatio;
import 'package:mobile/screens/video_review/widgets/dual_player_panel.dart';
import 'package:mobile/utils/landscape_fullscreen.dart';

Widget _panel() {
  void noop() {}
  return DualPlayerPanel(
    selectedVideo: null,
    originalController: null,
    annotatedController: null,
    originalLoadFailed: false,
    annotatedLoadFailed: false,
    hasAnnotatedVideo: false,
    isPlaying: false,
    currentTime: const Duration(seconds: 3),
    duration: const Duration(seconds: 30),
    playbackSpeed: 1.0,
    volume: 1.0,
    isMuted: false,
    syncWarning: null,
    detections: const [],
    selectedDetection: null,
    isFullscreen: true,
    immersive: true,
    onPlayPause: noop,
    onStop: noop,
    onReplay: noop,
    onSeek: (_) {},
    onSpeedChange: (_) {},
    onVolumeChange: (_) {},
    onToggleMute: noop,
    onFocusDetection: (_) {},
    onToggleFullscreen: noop,
  );
}

/// Stands in for the live screen: counts how many times it was built from scratch / thrown away.
class _Probe extends StatefulWidget {
  const _Probe(this.log);
  final List<String> log;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.log.add('created');
  }

  @override
  void dispose() {
    widget.log.add('disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('probe');
}

void main() {
  test('a camera that has not reported a usable size never gives a broken picture ratio', () {
    expect(safeAspectRatio(double.nan), closeTo(16 / 9, 1e-9)); // 0 / 0
    expect(safeAspectRatio(double.infinity), closeTo(16 / 9, 1e-9)); // n / 0
    expect(safeAspectRatio(0), closeTo(16 / 9, 1e-9));
    expect(safeAspectRatio(-1.5), closeTo(16 / 9, 1e-9));
    expect(safeAspectRatio(4 / 3), closeTo(4 / 3, 1e-9)); // a real size is left alone
  });

  testWidgets('switching full screen on and off does not rebuild the screen (the camera would close)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => gHideDashboardChrome.value = false);

    final log = <String>[];
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => DashboardShell(child: _Probe(log))),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(log, ['created']);

    gHideDashboardChrome.value = true; // enter full screen
    await tester.pump();
    expect(find.text('probe'), findsOneWidget);

    gHideDashboardChrome.value = false; // leave full screen
    await tester.pump();
    expect(find.text('probe'), findsOneWidget);

    expect(log, ['created'], reason: 'the screen must survive the layout change with its state intact');
  });

  // Full-screen video review must fit a phone held sideways (and upright) without overflowing.
  for (final size in const [Size(844, 390), Size(667, 375), Size(390, 844)]) {
    testWidgets('immersive video review fits ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: _panel()))),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Original Surveillance Feed'), findsOneWidget);
      expect(find.text('AI Annotated Feed'), findsOneWidget);
    });
  }

  testWidgets('the dashboard shows only the screen when full screen is on', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => gHideDashboardChrome.value = false);

    gHideDashboardChrome.value = true;
    await tester.pumpWidget(const MaterialApp(home: DashboardShell(child: Text('only-the-screen'))));
    await tester.pump();

    expect(find.text('only-the-screen'), findsOneWidget);
    expect(find.text('THAPAR - AKCM'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
