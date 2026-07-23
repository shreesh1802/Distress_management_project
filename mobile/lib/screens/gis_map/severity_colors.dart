import 'package:flutter/material.dart';

/// Shared severity color mapping used across the GIS Map screen, matching
/// the hex values hardcoded throughout GISMapContainer.tsx/DistressMarkers.tsx
/// (`getSeverityColor`).
Color severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return const Color(0xFFEF4444);
    case 'high':
      return const Color(0xFFF97316);
    case 'medium':
      return const Color(0xFFEAB308);
    case 'low':
      return const Color(0xFF22C55E);
    default:
      return const Color(0xFFA855F7);
  }
}

String formatDistressType(String type) {
  final spaced = type.replaceAll('_', ' ');
  if (spaced.isEmpty) return spaced;
  return spaced[0].toUpperCase() + spaced.substring(1);
}
