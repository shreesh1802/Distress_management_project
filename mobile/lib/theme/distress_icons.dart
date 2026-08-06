import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Shared icon + color mapping per distress/signage class, used anywhere a
/// distress type is shown (Video Review, Road Distresses, GIS Map,
/// Dashboard). Distinct from the screen-local `formatDistressType()`
/// helpers (which only reformat the label text) -- this is new,
/// cross-screen functionality, not part of the original React source, so
/// it lives in one shared place rather than being duplicated per screen
/// the way ported helpers are.
///
/// Keys match `app.services.ai.utils.CLASS_MAPPING` on the backend exactly
/// (case-sensitive for the three signage classes, which the model was
/// trained on as upper-case strings): longitudinal_crack, transverse_crack,
/// alligator_crack, pothole, "TRAFFIC SIGN", "SIGN BOARD", "POLES".
IconData distressTypeIcon(String rawType) {
  final type = rawType.trim().toLowerCase();
  if (type.contains('pothole')) return LucideIcons.circleDot;
  if (type.contains('alligator')) return LucideIcons.gitBranch;
  if (type.contains('transverse')) return LucideIcons.squareSplitHorizontal;
  if (type.contains('longitudinal')) return LucideIcons.activity;
  if (type.contains('crack')) return LucideIcons.activity;
  if (type.contains('traffic sign') || type == 'traffic_sign' || type == 'traffic_signs') {
    return LucideIcons.octagonAlert;
  }
  if (type.contains('sign board') || type.contains('signboard') || type == 'sign_board' || type == 'sign_boards') {
    return LucideIcons.signpostBig;
  }
  if (type.contains('pole')) return LucideIcons.signpost;
  return LucideIcons.alertTriangle;
}

/// Matches app.services.ai.inference_service.CLASS_COLORS (converted from
/// BGR to Flutter's RGB Color) so a given distress type reads as the same
/// color in the app as it does drawn on the AI-annotated video feed.
Color distressTypeIconColor(String rawType) {
  final type = rawType.trim().toLowerCase();
  if (type.contains('pothole')) return const Color(0xFFFF0000); // Red
  if (type.contains('alligator')) return const Color(0xFFFFA500); // Orange
  if (type.contains('transverse')) return const Color(0xFFFFD700); // Yellow
  if (type.contains('longitudinal')) return const Color(0xFFFFD700); // Yellow
  if (type.contains('crack')) return const Color(0xFFFFD700);
  if (type.contains('traffic sign') || type == 'traffic_sign' || type == 'traffic_signs') {
    return const Color(0xFFFF00FF); // Magenta
  }
  if (type.contains('sign board') || type.contains('signboard') || type == 'sign_board' || type == 'sign_boards') {
    return const Color(0xFF00CC00); // Green
  }
  if (type.contains('pole')) return const Color(0xFF3366FF); // Blue
  return const Color(0xFF9E9E9E);
}
