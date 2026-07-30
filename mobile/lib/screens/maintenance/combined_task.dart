import '../../data/maintenance_api.dart';
import '../../data/road_distress_api.dart';

const statusColors = {
  'Pending': 0xFF6B88C7,
  'Assigned': 0xFF3B82F6,
  'In Progress': 0xFFD6A23A,
  'Completed': 0xFF8FA06A,
  'Closed': 0xFF94A3B8,
};

const priorityColors = {
  'Critical': 0xFFC45C45,
  'High': 0xFFC87B35,
  'Medium': 0xFFD6A23A,
  'Low': 0xFF6B88C7,
};

String titleCaseFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

String titleCaseWords(String s) =>
    s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');

String formatCost(num amount) {
  if (amount >= 10000000) return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
  if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
  return '₹${amount.toStringAsFixed(0)}';
}

/// Direct Dart port of MaintenanceDashboard.tsx's `CombinedTask` -- a join
/// of a raw maintenance recommendation, its underlying distress record, and
/// the assigned user, computed client-side exactly as the React source
/// does (no backend endpoint returns this joined shape).
class CombinedTask {
  const CombinedTask({
    required this.taskId,
    required this.distressId,
    required this.trackingId,
    required this.distressType,
    required this.priority,
    required this.severity,
    required this.estimatedCost,
    required this.roadHealthImpact,
    required this.assignedEngineer,
    required this.dueDate,
    required this.damageArea,
    required this.gps,
    required this.recommendation,
    required this.status,
    this.detectionImage,
    this.annotatedImage,
  });

  final int taskId;
  final int distressId;
  final String trackingId;
  final String distressType;
  final String priority;
  final String severity;
  final int estimatedCost;
  final String roadHealthImpact;
  final String assignedEngineer;
  final String dueDate;
  final String? detectionImage;
  final String? annotatedImage;
  final String damageArea;
  final String gps;
  final String recommendation;
  final String status;

  String get id => 'TASK-$taskId';

  CombinedTask copyWith({String? status, String? assignedEngineer, String? dueDate}) {
    return CombinedTask(
      taskId: taskId,
      distressId: distressId,
      trackingId: trackingId,
      distressType: distressType,
      priority: priority,
      severity: severity,
      estimatedCost: estimatedCost,
      roadHealthImpact: roadHealthImpact,
      assignedEngineer: assignedEngineer ?? this.assignedEngineer,
      dueDate: dueDate ?? this.dueDate,
      detectionImage: detectionImage,
      annotatedImage: annotatedImage,
      damageArea: damageArea,
      gps: gps,
      recommendation: recommendation,
      status: status ?? this.status,
    );
  }

  static List<CombinedTask> combine(
    List<MaintenanceRecommendation> recommendations,
    List<DistressRecord> distresses,
    List<AppUser> users,
  ) {
    return recommendations.map((task) {
      final distress = distresses.where((d) => d.id == task.distressId).firstOrNull;
      final userMatch = users.where((u) => u.id == task.assignedTo).firstOrNull;
      final engineer = userMatch?.fullName ?? 'Unassigned';
      final severity = distress?.severity ?? 'medium';
      final distressType = distress?.distressType ?? 'pothole';
      final gps = distress != null
          ? '${distress.latitude.toStringAsFixed(6)}, ${distress.longitude.toStringAsFixed(6)}'
          : '18.520430, 73.856743';
      final damageArea =
          distress?.affectedArea != null ? '${distress!.affectedArea!.toStringAsFixed(2)} sq m' : '0.50 sq m';
      final severityLower = severity.toLowerCase();
      final penalty = switch (severityLower) {
        'critical' => '5.0',
        'high' => '3.0',
        'medium' => '1.5',
        _ => '0.5',
      };
      final defaultDueDate = DateTime.now().add(const Duration(days: 5)).toIso8601String().split('T').first;

      return CombinedTask(
        taskId: task.id,
        distressId: task.distressId,
        trackingId: distress?.trackingId != null
            ? 'RD-TRK-${distress!.trackingId}'
            : 'RD-TRK-${task.distressId}',
        distressType: titleCaseWords(distressType.replaceAll('_', ' ')),
        priority: task.priority != null ? titleCaseFirst(task.priority!) : 'Medium',
        severity: titleCaseFirst(severity),
        estimatedCost: (task.estimatedCost ?? 120000).round(),
        roadHealthImpact: 'Penalty: -$penalty pts',
        assignedEngineer: engineer,
        dueDate: task.dueDate ?? defaultDueDate,
        detectionImage: distress?.detectionImagePath ?? distress?.imageUrl,
        annotatedImage: distress?.imageUrl,
        damageArea: damageArea,
        gps: gps,
        recommendation: task.recommendation ?? 'Standard rehabilitation procedure required.',
        status: task.status != null ? titleCaseWords(task.status!.replaceAll('_', ' ')) : 'Pending',
      );
    }).toList();
  }
}

extension FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
