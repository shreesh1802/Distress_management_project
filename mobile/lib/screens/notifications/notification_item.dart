import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Direct Dart port of Notifications.tsx's `NotificationItem` and its
/// hardcoded initial `notifications` state. This whole screen is a mock/
/// demo screen in the source -- there's no `apiService` import and no
/// fetch call anywhere in the file, just a fixed local array mutated via
/// local state (mark read/unread, delete, assign) -- so this port follows
/// the same "port the mock data as designed" precedent as Overview
/// Dashboard, rather than treating any of it as a "fake data to trim"
/// situation (there's no real/fake split within this screen to trim; it's
/// uniformly a demo).
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.dateGroup,
    required this.unread,
    required this.priority,
    required this.category,
    this.roadId,
    this.location,
    this.district,
    this.pipeline,
    this.thumbnailUrl,
    this.assignedTo,
  });

  final String id;
  final String title;
  final String message;
  final String time;
  final String dateGroup; // Today, Yesterday, Last 7 Days, Earlier
  final bool unread;
  final String priority; // Critical, High, Medium, Information, Success
  final String category; // Detection, Maintenance, Reports, System, GIS, Uploads
  final String? roadId;
  final String? location;
  final String? district;
  final String? pipeline;
  final String? thumbnailUrl;
  final String? assignedTo;

  NotificationItem copyWith({bool? unread, String? assignedTo, String? priority}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      time: time,
      dateGroup: dateGroup,
      unread: unread ?? this.unread,
      priority: priority ?? this.priority,
      category: category,
      roadId: roadId,
      location: location,
      district: district,
      pipeline: pipeline,
      thumbnailUrl: thumbnailUrl,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }
}

Color priorityColor(String priority) {
  switch (priority) {
    case 'Critical':
      return const Color(0xFFEF4444);
    case 'High':
      return const Color(0xFFF97316);
    case 'Medium':
      return const Color(0xFFF59E0B);
    case 'Information':
      return const Color(0xFF3B82F6);
    case 'Success':
      return const Color(0xFF10B981);
    default:
      return const Color(0xFF6B7280);
  }
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'Detection':
      return LucideIcons.shieldAlert;
    case 'Maintenance':
      return LucideIcons.activity;
    case 'Reports':
      return LucideIcons.fileText;
    case 'System':
      return LucideIcons.slidersHorizontal;
    case 'GIS':
      return LucideIcons.mapPin;
    case 'Uploads':
      return LucideIcons.checkCircle2;
    default:
      return LucideIcons.bell;
  }
}

List<NotificationItem> buildInitialNotifications() {
  return const [
    NotificationItem(
      id: 'NT-101',
      title: 'Critical Distress Found',
      message: 'Pothole detected on NH-48 (KM 42.5 near Lonavala Ghats) requires immediate work order scheduling.',
      time: '10 mins ago',
      dateGroup: 'Today',
      unread: true,
      priority: 'Critical',
      category: 'Detection',
      roadId: 'NH-48',
      location: 'KM 42.5, Lonavala Ghats',
      district: 'Pune',
      pipeline: 'YOLOv11-Heavy',
      thumbnailUrl: 'pothole_1',
    ),
    NotificationItem(
      id: 'NT-107',
      title: 'Bridge Structural Crack',
      message: 'Severe structural cracking identified on Bridge deck section #4, Western Express Highway.',
      time: '45 mins ago',
      dateGroup: 'Today',
      unread: true,
      priority: 'Critical',
      category: 'Detection',
      roadId: 'WEH-01',
      location: 'Bridge #4, Bandra Flyover',
      district: 'Mumbai',
      pipeline: 'YOLOv11-Heavy',
      thumbnailUrl: 'bridge_crack',
    ),
    NotificationItem(
      id: 'NT-102',
      title: 'YOLOv11 Inference Complete',
      message: 'Video upload log surveillance_cam_mumbai.mp4 processed successfully. 12 distresses tagged.',
      time: '2 hours ago',
      dateGroup: 'Today',
      unread: true,
      priority: 'Success',
      category: 'Uploads',
      roadId: 'WEH-03',
      location: 'Bandra Reclamation Checkpoint',
      district: 'Mumbai',
      pipeline: 'YOLOv11-Base',
    ),
    NotificationItem(
      id: 'NT-103',
      title: 'PDF Report Exported',
      message: 'Maintenance team generated and compiled NH-48 quarterly repair estimates document.',
      time: 'Yesterday at 17:30',
      dateGroup: 'Yesterday',
      unread: false,
      priority: 'Information',
      category: 'Reports',
      roadId: 'NH-48',
      location: 'Mumbai-Pune Expressway Section',
      district: 'Thane',
      pipeline: 'System Export',
    ),
    NotificationItem(
      id: 'NT-104',
      title: 'Camera CAM-04 Offline',
      message: 'Surveillance feed stream from sector 4 has been interrupted for more than 5 minutes.',
      time: 'Yesterday at 12:15',
      dateGroup: 'Yesterday',
      unread: false,
      priority: 'High',
      category: 'System',
      roadId: 'SH-4',
      location: 'CAM-04 Sector 4 Junction',
      district: 'Nagpur',
      pipeline: 'Hardware Watchdog',
    ),
    NotificationItem(
      id: 'NT-109',
      title: 'Severe Alligator Cracking',
      message: 'Widespread fatigue alligator cracking flagged on Pune-Solapur road segment (KM 118).',
      time: 'Yesterday at 09:00',
      dateGroup: 'Yesterday',
      unread: true,
      priority: 'Critical',
      category: 'Detection',
      roadId: 'NH-965',
      location: 'KM 118, Hadapsar Bypass',
      district: 'Pune',
      pipeline: 'YOLOv11-Heavy',
      thumbnailUrl: 'cracks_2',
    ),
    NotificationItem(
      id: 'NT-106',
      title: 'Distress Markers Verified',
      message: 'GIS specialist completed verification of 18 crack coordinates on SH-4 corridor.',
      time: '3 days ago',
      dateGroup: 'Last 7 Days',
      unread: false,
      priority: 'Medium',
      category: 'GIS',
      roadId: 'SH-4',
      location: 'Sector 2 verification zone',
      district: 'Nagpur',
      pipeline: 'GIS Linker',
    ),
    NotificationItem(
      id: 'NT-108',
      title: 'Database Auto-Backup Sync',
      message: 'Core RoadVision system database full backup completed and synchronized with S3 bucket.',
      time: '5 days ago',
      dateGroup: 'Last 7 Days',
      unread: false,
      priority: 'Information',
      category: 'System',
      roadId: 'SYS-SRV',
      location: 'Primary Server Subnet',
      district: 'All',
      pipeline: 'Backup Service',
    ),
    NotificationItem(
      id: 'NT-105',
      title: 'Work Order Closed',
      message: 'Maharashtra highway repair team completed sealing operations on Eastern Express cracks.',
      time: 'June 25, 2026',
      dateGroup: 'Earlier',
      unread: false,
      priority: 'Success',
      category: 'Maintenance',
      roadId: 'EEH-12',
      location: 'Ghatkopar flyover northbound lane',
      district: 'Mumbai',
      pipeline: 'Workforce Sync',
      assignedTo: 'Crew Bravo',
    ),
  ];
}
