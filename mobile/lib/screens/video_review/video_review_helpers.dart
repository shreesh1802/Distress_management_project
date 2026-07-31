import 'package:flutter/material.dart';

/// Direct port of VideoReview.tsx's small severity-derived helper
/// functions (`getPriorityScore`, `getHealthImpactScore`,
/// `getEstimatedCost`, `getRecommendation`) and formatting helpers
/// (`formatTime`, `formatDistressType`).

int priorityScore(String severity) {
  final s = severity.toLowerCase();
  if (s == 'critical') return 95;
  if (s == 'high') return 80;
  if (s == 'medium') return 55;
  return 30;
}

String healthImpactScore(String severity) {
  final s = severity.toLowerCase();
  if (s == 'critical') return '-5.0 pts';
  if (s == 'high') return '-3.0 pts';
  if (s == 'medium') return '-1.5 pts';
  return '-0.5 pts';
}

String estimatedCost(String severity) {
  final s = severity.toLowerCase();
  if (s == 'critical') return '₹95,000';
  if (s == 'high') return '₹65,000';
  if (s == 'medium') return '₹45,000';
  return '₹25,000';
}

Color severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return const Color(0xFFEF4444);
    case 'high':
      return const Color(0xFFF97316);
    case 'medium':
      return const Color(0xFFFACC15);
    default:
      return const Color(0xFF10B981);
  }
}

/// Direct port of `formatDistressType`: only the first underscore is
/// replaced with a space, and only the very first character of the whole
/// string is capitalized (not each word) -- matching the source's exact
/// `type.replace('_', ' ').charAt(0).toUpperCase() + ...slice(1)` quirk.
String formatDistressType(String type) {
  final spaced = type.replaceFirst('_', ' ');
  if (spaced.isEmpty) return spaced;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String recommendationFor(String type) {
  final t = type.toLowerCase();
  if (t.contains('pothole')) {
    return 'Clean pothole crater, fill with hot asphalt mix, and roll compact.';
  } else if (t.contains('crack')) {
    return 'Blow out crack channel and fill with elastomeric hot-pour sealant.';
  } else if (t.contains('rutting')) {
    return 'Mill surface rut channels level and pave with high-stability mix.';
  } else if (t.contains('edge')) {
    return 'Reconstruct unstable road shoulders and overlay edge binder.';
  }
  return 'Pavement patch repair or minor surface restoration recommended.';
}

String formatTime(Duration d) {
  final totalSeconds = d.inSeconds;
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
