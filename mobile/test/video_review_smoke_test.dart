import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/road_distress_api.dart';
import 'package:mobile/data/video_api.dart';
import 'package:mobile/screens/video_review/widgets/detections_sidebar.dart';
import 'package:mobile/screens/video_review/widgets/dual_player_panel.dart';

List<DistressRecord> _sampleDetections() {
  return [
    DistressRecord(
      id: 1,
      distressType: 'alligator_cracks_with_a_very_long_type_name_for_overflow',
      severity: 'critical',
      confidenceScore: 0.94,
      latitude: 18.52043,
      longitude: 73.85674,
      detectedAt: DateTime(2026, 7, 20),
      status: 'under_review',
      videoId: 10,
      videoTimestamp: 12.5,
      trackingId: 501,
      boxWidth: 140,
      boxHeight: 90,
      affectedArea: 0.42,
    ),
    DistressRecord(
      id: 2,
      distressType: 'pothole',
      severity: 'medium',
      confidenceScore: 0.81,
      latitude: 18.523,
      longitude: 73.861,
      detectedAt: DateTime(2026, 7, 21),
      status: 'resolved',
      videoId: 10,
      videoTimestamp: 45.2,
      trackingId: 502,
    ),
  ];
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('DetectionsSidebar renders the list tab with sample detections', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 420,
      height: 700,
      child: DetectionsSidebar(
        detections: _sampleDetections(),
        selectedDetection: null,
        activeTab: 'list',
        isLoading: false,
        onTabChanged: (_) {},
        onSelect: (_) {},
        onNavigate: (_) {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Detections (2)'), findsOneWidget);
    expect(find.text('#501'), findsOneWidget);
  });

  testWidgets('DetectionsSidebar renders the inspector tab with a long distress type', (tester) async {
    final detections = _sampleDetections();
    await tester.pumpWidget(_wrap(SizedBox(
      width: 420,
      height: 900,
      child: DetectionsSidebar(
        detections: detections,
        selectedDetection: detections.first,
        activeTab: 'details',
        isLoading: false,
        onTabChanged: (_) {},
        onSelect: (_) {},
        onNavigate: (_) {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Inspector Details'), findsOneWidget);
    expect(find.text('Maintenance Guideline' .toUpperCase()), findsOneWidget);
  });

  testWidgets('DualPlayerPanel renders placeholder states with no controllers', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1200,
      child: DualPlayerPanel(
        selectedVideo: UploadedVideo(id: 10, filename: 'Video_10.mp4', processingStatus: 'completed', uploadTimestamp: DateTime(2026, 7, 20)),
        originalController: null,
        annotatedController: null,
        originalLoadFailed: false,
        annotatedLoadFailed: false,
        hasAnnotatedVideo: false,
        isPlaying: false,
        currentTime: Duration.zero,
        duration: const Duration(seconds: 120),
        playbackSpeed: 1.0,
        volume: 0.8,
        isMuted: false,
        syncWarning: 'Re-syncing feeds (offset: 0.45s)',
        detections: _sampleDetections(),
        selectedDetection: _sampleDetections().first,
        isFullscreen: false,
        onPlayPause: () {},
        onStop: () {},
        onReplay: () {},
        onSeek: (_) {},
        onSpeedChange: (_) {},
        onVolumeChange: (_) {},
        onToggleMute: () {},
        onFocusDetection: (_) {},
        onToggleFullscreen: () {},
      ),
    )));
    // Not pumpAndSettle: the original-feed card falls back to an
    // indeterminate CircularProgressIndicator while a controller hasn't
    // been attached yet (a legitimate transient loading state, matching
    // the source's "video loading" state), which animates forever.
    await tester.pump();
    expect(find.text('Annotated Video Unresolved'), findsOneWidget);
    expect(find.textContaining('Re-syncing feeds'), findsOneWidget);
  });

  testWidgets('DualPlayerPanel renders the no-video-selected state', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1200,
      child: DualPlayerPanel(
        selectedVideo: null,
        originalController: null,
        annotatedController: null,
        originalLoadFailed: false,
        annotatedLoadFailed: false,
        hasAnnotatedVideo: false,
        isPlaying: false,
        currentTime: Duration.zero,
        duration: Duration.zero,
        playbackSpeed: 1.0,
        volume: 0.8,
        isMuted: false,
        syncWarning: null,
        detections: const [],
        selectedDetection: null,
        isFullscreen: false,
        onPlayPause: () {},
        onStop: () {},
        onReplay: () {},
        onSeek: (_) {},
        onSpeedChange: (_) {},
        onVolumeChange: (_) {},
        onToggleMute: () {},
        onFocusDetection: (_) {},
        onToggleFullscreen: () {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('No footage selected.'), findsWidgets);
  });

  testWidgets('DualPlayerPanel shows a failed-to-load state, not an infinite spinner', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1200,
      child: DualPlayerPanel(
        selectedVideo: UploadedVideo(id: 11, filename: 'Video_11.mp4', processingStatus: 'completed', uploadTimestamp: DateTime(2026, 7, 20)),
        originalController: null,
        annotatedController: null,
        originalLoadFailed: true,
        annotatedLoadFailed: true,
        hasAnnotatedVideo: true,
        isPlaying: false,
        currentTime: Duration.zero,
        duration: const Duration(seconds: 60),
        playbackSpeed: 1.0,
        volume: 0.8,
        isMuted: false,
        syncWarning: null,
        detections: const [],
        selectedDetection: null,
        isFullscreen: false,
        onPlayPause: () {},
        onStop: () {},
        onReplay: () {},
        onSeek: (_) {},
        onSpeedChange: (_) {},
        onVolumeChange: (_) {},
        onToggleMute: () {},
        onFocusDetection: (_) {},
        onToggleFullscreen: () {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Failed to load video.'), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
