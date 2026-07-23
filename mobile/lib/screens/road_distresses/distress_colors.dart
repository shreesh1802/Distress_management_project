import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Severity/status color + derived-field helpers shared across the Road
/// Distresses screen widgets, matching RoadDistresses.tsx's
/// `getSeverityBadgeClass`/`getStatusBadgeClass`/`getPriorityScore`/
/// `getHealthImpactScore`/`getEstimatedCost` (none of which have real CSS
/// defined for their badge classes in the React source either -- these are
/// sensible colors chosen to match the app's existing severity palette).
Color severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return AppColors.danger;
    case 'high':
      return const Color(0xFFF97316);
    case 'medium':
      return AppColors.warning;
    default:
      return AppColors.success;
  }
}

Color statusColor(String status) {
  switch (status.toLowerCase().replaceAll('_', '')) {
    case 'detected':
      return AppColors.secondaryText;
    case 'scheduled':
      return AppColors.accentBlue;
    case 'inprogress':
      return AppColors.warning;
    case 'completed':
      return AppColors.success;
    default:
      return const Color(0xFFA855F7);
  }
}

int priorityScore(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return 95;
    case 'high':
      return 80;
    case 'medium':
      return 55;
    default:
      return 30;
  }
}

String healthImpactScore(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return '-5.0 pts';
    case 'high':
      return '-3.0 pts';
    case 'medium':
      return '-1.5 pts';
    default:
      return '-0.5 pts';
  }
}

String estimatedCost(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return '₹95,000';
    case 'high':
      return '₹65,000';
    case 'medium':
      return '₹45,000';
    default:
      return '₹25,000';
  }
}

String formatDistressType(String type) {
  final spaced = type.replaceAll('_', ' ');
  if (spaced.isEmpty) return spaced;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

String getRecommendation(String type) {
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
