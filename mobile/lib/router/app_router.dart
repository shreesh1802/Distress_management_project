import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_provider.dart';
import '../screens/dashboard/dashboard_shell.dart';
import '../screens/dashboard/overview_screen.dart';
import '../screens/gis_map/gis_map_screen.dart';
import '../screens/live_detection/live_detection_screen.dart';
import '../screens/live_processing/live_processing_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/survey/survey_screen.dart';
import '../screens/upload_video/upload_video_screen.dart';

/// Route paths mirror Road-Distress-Management-System/frontend/src/routes/AppRoutes.tsx
/// 1:1, so links and navigation logic stay recognizable across both apps.
class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const survey = '/survey';
  static const dashboard = '/dashboard';
  static const overview = '/overview';
  static const liveMonitoring = '/live-monitoring';
  static const gisMap = '/gis-map';
  static const uploadVideo = '/upload-video';
  static const liveProcessing = '/live-processing';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.survey,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final isAuthenticated = ref.read(authProvider).isAuthenticated;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.login;
      }
      if (isAuthenticated && isLoggingIn) {
        return AppRoutes.survey;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.survey,
        builder: (context, state) => const SurveyScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardShell(),
      ),
      GoRoute(
        path: AppRoutes.overview,
        builder: (context, state) =>
            const DashboardShell(child: OverviewScreen()),
      ),
      GoRoute(
        path: AppRoutes.liveMonitoring,
        builder: (context, state) =>
            const DashboardShell(child: LiveDetectionScreen()),
      ),
      GoRoute(
        path: AppRoutes.gisMap,
        builder: (context, state) => const DashboardShell(child: GisMapScreen()),
      ),
      GoRoute(
        path: AppRoutes.uploadVideo,
        builder: (context, state) => const DashboardShell(child: UploadVideoScreen()),
      ),
      GoRoute(
        path: AppRoutes.liveProcessing,
        builder: (context, state) => const DashboardShell(child: LiveProcessingScreen()),
      ),
    ],
  );
});

/// Bridges Riverpod's authProvider to go_router's Listenable-based redirect
/// refresh, so navigating after login/logout re-evaluates `redirect` above.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this.ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
        notifyListeners();
      }
    });
  }

  final Ref ref;
}
