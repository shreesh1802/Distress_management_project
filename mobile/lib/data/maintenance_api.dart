import 'dart:convert';

import 'package:http/http.dart' as http;

import 'live_detection_api.dart' show kApiV1;

/// Direct Dart port of `MaintenanceTaskResponse` (raw, unmapped) as used by
/// MaintenanceDashboard.tsx's `getMaintenanceRecommendations` call.
class MaintenanceRecommendation {
  const MaintenanceRecommendation({
    required this.id,
    required this.distressId,
    this.recommendation,
    this.priority,
    this.assignedTo,
    this.dueDate,
    this.status,
    this.estimatedCost,
  });

  final int id;
  final int distressId;
  final String? recommendation;
  final String? priority;
  final int? assignedTo;
  final String? dueDate;
  final String? status;
  final double? estimatedCost;

  factory MaintenanceRecommendation.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecommendation(
      id: json['id'] as int,
      distressId: json['distress_id'] as int,
      recommendation: json['recommendation'] as String?,
      priority: json['priority'] as String?,
      assignedTo: (json['assigned_to'] as num?)?.toInt(),
      dueDate: (json['due_date'] as String?)?.split('T').first,
      status: json['status'] as String?,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
    );
  }
}

/// Direct Dart port of `UserResponse`.
class AppUser {
  const AppUser({required this.id, required this.email, this.fullName});

  final int id;
  final String email;
  final String? fullName;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
    );
  }
}

/// Direct port of the `getMaintenanceRecommendations`/`getUsers` calls in
/// apiService.ts as used by MaintenanceDashboard.tsx.
class MaintenanceApi {
  MaintenanceApi();

  final http.Client _client = http.Client();

  Future<List<MaintenanceRecommendation>> fetchRecommendations() async {
    final response = await _client.get(Uri.parse('$kApiV1/maintenance/recommendations'));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch maintenance recommendations');
    }
    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((e) => MaintenanceRecommendation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppUser>> fetchUsers({int skip = 0, int limit = 200}) async {
    final uri = Uri.parse(
      '$kApiV1/users/',
    ).replace(queryParameters: {'skip': '$skip', 'limit': '$limit'});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch users');
    }
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  void dispose() => _client.close();
}
