import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/http_overrides_stub.dart'
    if (dart.library.io) 'data/http_overrides_io.dart';
import 'data/live_detection_api.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureHttpOverrides();
  await loadSavedServerUrl();
  runApp(const ProviderScope(child: RoadDistressApp()));
}

class RoadDistressApp extends ConsumerWidget {
  const RoadDistressApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Road Inspection Control Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
