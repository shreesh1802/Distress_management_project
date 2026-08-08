import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/road_distress_api.dart';
import 'package:mobile/screens/road_distresses/widgets/inspection_drawer.dart';

// A 1x1 transparent PNG, used so Image.network resolves deterministically
// in the test sandbox instead of hitting the real (unreachable) network.
final Uint8List _kOnePixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0xDA, 0x63, 0x64, 0x60, 0x60, 0x60,
  0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0xE2, 0x26, 0x05, 0x9B, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeHttpResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kOnePixelPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_kOnePixelPng]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

DistressRecord _sampleRecord() {
  return DistressRecord(
    id: 1,
    distressType: 'pothole',
    severity: 'high',
    confidenceScore: 0.91,
    latitude: 18.52,
    longitude: 73.85,
    detectedAt: DateTime(2026, 7, 1),
    status: 'detected',
    imageUrl: null,
    trackingId: 42,
  );
}

/// Reproduces the real production layout around InspectionDrawer:
/// RoadDistressesScreen's build() returns a Stack([mainContent, drawer])
/// and DashboardShell places that Stack inside a SingleChildScrollView,
/// which hands its child an *unbounded* height. A SizedBox-bounded harness
/// (as used for other drawer smoke tests in this suite) would not catch a
/// regression here, so this test intentionally leaves height unbounded.
Widget _wrapLikeDashboardShell(Widget drawer, {required double mainContentHeight}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 390, // narrow/mobile viewport width
          child: Stack(
            children: [
              // Stand-in for the screen's tall main content (KPI strip +
              // toolbar + data table + pagination), which is what actually
              // determines the Stack's height in production.
              SizedBox(height: mainContentHeight),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: drawer,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => HttpOverrides.global = _FakeHttpOverrides());
  tearDown(() => HttpOverrides.global = null);

  testWidgets('InspectionDrawer renders without layout errors when main content is short',
      (tester) async {
    await tester.pumpWidget(_wrapLikeDashboardShell(
      InspectionDrawer(
        record: _sampleRecord(),
        onClose: () {},
        onDownloadPdf: () {},
        onLocateGis: () {},
      ),
      mainContentHeight: 400,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('RD-1'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
  });

  testWidgets('InspectionDrawer renders without layout errors when main content is very tall',
      (tester) async {
    // A long results table easily exceeds one screen's height; the drawer
    // must not blow up (or shrink its image / overflow its text) just
    // because the surrounding scrollable content is much taller than the
    // viewport.
    await tester.pumpWidget(_wrapLikeDashboardShell(
      InspectionDrawer(
        record: _sampleRecord(),
        onClose: () {},
        onDownloadPdf: () {},
        onLocateGis: () {},
      ),
      mainContentHeight: 4000,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('RD-1'), findsOneWidget);

    // The image container keeps its fixed 200px height rather than being
    // squashed by a broken (infinite/garbage) constraint chain.
    final imageContainerFinder = find.byWidgetPredicate(
      (w) => w is Container && w.constraints?.maxHeight == 200,
    );
    expect(imageContainerFinder, findsOneWidget);
  });
}
