import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/reports_api.dart';
import '../../data/video_api.dart';
import '../../theme/app_colors.dart';
import 'timeline_event.dart';
import 'widgets/activity_timeline.dart';
import 'widgets/history_analytics_footer.dart';
import 'widgets/history_filters_bar.dart';
import 'widgets/history_kpi_row.dart';
import 'widgets/history_sidebar_widgets.dart';
import 'widgets/inference_run_logs.dart';
import 'widgets/reports_archive_table.dart';

const _kShortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _shortDate(DateTime d) => '${_kShortMonths[d.month - 1]} ${d.day}';

const _kReportsPerPage = 5;

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// History/History.tsx (~1,535 lines): real data from GET /api/v1/reports/
/// and GET /api/v1/videos/, combined client-side into an activity timeline
/// exactly as the source's `allActivities` does, plus a sortable/paginated
/// reports archive table, expandable per-video inference run cards, and
/// three real analytics charts (category distribution, 7-day activity
/// trend, top event types).
///
/// This is the one screen in the port whose source has no error state at
/// all: `fetchHistory`'s catch block only does `console.error` -- there's
/// no `setError` call anywhere in the file. So on a fetch failure, this
/// port (matching that faithfully) just ends up with empty `reports`/
/// `videos` lists and shows each section's ordinary empty state, rather
/// than a dedicated error banner like every other screen has.
///
/// Trimmed: the 8 hardcoded "system events" the source seeds into the
/// timeline (Backend Server Restarted, YOLOv8 Model Loaded, Database
/// Auto-Backup, Secured Admin Login, Maintenance Task Raised, Road Segment
/// Verified, Detection Record Purged, Alert Notification Broadcasted) --
/// 100% fabricated strings with no backend tie, seeded (per the source's
/// own comment) just "to make timeline enterprise-grade". Dropping them
/// also removes the source's "System Events Log" section (which filters
/// specifically for those seeded events -- with none seeded, it would
/// render permanently empty) and the `Maintenance`/`GIS`/`Notifications`
/// timeline categories (see timeline_event.dart and
/// widgets/history_filters_bar.dart for the follow-on trims). Also
/// trimmed: the "Recent Active Users" widget (a fully static array of 4
/// fabricated names/roles/timestamps), the fake per-KPI-card trend badges
/// and SVG sparklines (see widgets/history_kpi_row.dart), and the "Export
/// Logs" CSV button (client-side Blob+`<a>`+click, no backend tie -- same
/// reasoning as the CSV/Excel export trims on GIS Map, Road Distresses,
/// and Maintenance).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _reportsApi = ReportsApi();
  final _videoApi = VideoApi();

  List<ReportRecord> _reports = [];
  List<UploadedVideo> _videos = [];
  bool _isLoading = true;

  String _search = '';
  String _dateRange = 'All';
  HistoryFilters _filters = const HistoryFilters();

  int _reportsPage = 1;
  ReportsSort _reportsSort = const ReportsSort(ReportSortKey.generatedAt, false);

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _reportsApi.dispose();
    _videoApi.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _reportsApi.fetchReports(skip: 0, limit: 100),
        _videoApi.fetchVideos(skip: 0, limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as List<ReportRecord>;
        _videos = results[1] as List<UploadedVideo>;
        _isLoading = false;
      });
    } catch (_) {
      // Matches the source: no error state exists here, just log-and-move-on.
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<TimelineEvent> get _allActivities => buildTimeline(_reports, _videos);

  List<TimelineEvent> get _filteredTimeline {
    final query = _search.toLowerCase();
    return _allActivities.where((act) {
      final matchesSearch = act.title.toLowerCase().contains(query) ||
          act.description.toLowerCase().contains(query) ||
          act.user.toLowerCase().contains(query) ||
          act.category.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (_filters.activityType != 'All' && act.category.toLowerCase() != _filters.activityType.toLowerCase()) return false;
      if (_filters.status != 'All' && act.status.toLowerCase() != _filters.status.toLowerCase()) return false;
      if (_filters.user != 'All' && !act.user.toLowerCase().contains(_filters.user.toLowerCase())) return false;
      if (_filters.district != 'All' && act.district != _filters.district) return false;
      if (_filters.road != 'All' && act.road != _filters.road) return false;
      if (_filters.modelVersion != 'All' && act.modelVersion != _filters.modelVersion) return false;
      if (_dateRange != 'All') {
        final hrs = int.tryParse(_dateRange);
        if (hrs != null && act.timestamp.isBefore(DateTime.now().subtract(Duration(hours: hrs)))) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTimeline;
    final allActivities = _allActivities;

    final categoryCounts = {'Inference': 0, 'Reports': 0, 'Uploads': 0};
    for (final a in filtered) {
      if (categoryCounts.containsKey(a.category)) categoryCounts[a.category] = categoryCounts[a.category]! + 1;
    }

    final daysMap = <String, int>{};
    for (var i = 6; i >= 0; i--) {
      daysMap[_shortDate(DateTime.now().subtract(Duration(days: i)))] = 0;
    }
    for (final a in filtered) {
      final key = _shortDate(a.timestamp);
      if (daysMap.containsKey(key)) daysMap[key] = daysMap[key]! + 1;
    }

    var success = 0, failed = 0, other = 0;
    for (final a in filtered) {
      if (a.status == 'Success') {
        success++;
      } else if (a.status == 'Failed') {
        failed++;
      } else {
        other++;
      }
    }

    final typeCounts = <String, int>{};
    for (final a in filtered) {
      typeCounts[a.type] = (typeCounts[a.type] ?? 0) + 1;
    }
    final topTypes = typeCounts.entries.map((e) => EventTypeCount(e.key, e.value)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final totalSuccessOps = allActivities.where((a) => a.status == 'Success').length;
    final totalFailedOps = allActivities.where((a) => a.status == 'Failed').length;
    final successRate = allActivities.isNotEmpty ? (totalSuccessOps / allActivities.length * 100).toStringAsFixed(1) : '100';

    final filteredReports = _filteredReportsList;
    final sortedReports = _sortReports(filteredReports);
    final totalReportsPages = (sortedReports.length / _kReportsPerPage).ceil().clamp(1, 1 << 30);
    final page = _reportsPage.clamp(1, totalReportsPages);
    final paginatedReports = sortedReports.skip((page - 1) * _kReportsPerPage).take(_kReportsPerPage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 20),
        HistoryKpiRow(
          totalLogs: filtered.length,
          reportsExported: _reports.length,
          inferenceRuns: _videos.length,
          failedOps: _videos.where((v) => v.processingStatus.toLowerCase() == 'failed').length,
        ),
        const SizedBox(height: 20),
        HistoryFiltersBar(
          filters: _filters,
          onChanged: (f) => setState(() => _filters = f),
          onClearAll: () => setState(() {
            _filters = const HistoryFilters();
            _dateRange = 'All';
            _search = '';
          }),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final timeline = ActivityTimeline(
              events: filtered,
              isLoading: _isLoading,
              onDownloadReport: _downloadReportEvent,
              onViewReport: _viewReportEvent,
              onDeleteReport: (act) => _handleDeleteReport(act.reportId!),
              onRetryVideo: (act) => _handleRetryVideo(act.videoId!),
              onDeleteVideo: (act) => _handleDeleteVideo(act.videoId!),
            );
            final sidebar = Column(
              children: [
                SystemStatisticsCard(successOps: totalSuccessOps, failedOps: totalFailedOps, successRate: successRate),
                const SizedBox(height: 20),
                ActivityDistributionCard(data: categoryCounts),
              ],
            );
            if (constraints.maxWidth < 1100) {
              return Column(children: [timeline, const SizedBox(height: 20), sidebar]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: timeline),
                const SizedBox(width: 20),
                Expanded(flex: 3, child: sidebar),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        ReportsArchiveTable(
          paginatedReports: paginatedReports,
          totalFiltered: sortedReports.length,
          sort: _reportsSort,
          onSortChanged: _handleSort,
          currentPage: page,
          totalPages: totalReportsPages,
          itemsPerPage: _kReportsPerPage,
          onPageChanged: (p) => setState(() => _reportsPage = p),
          onDownload: _downloadReport,
          onView: _viewReport,
          onDelete: (r) => _handleDeleteReport(r.id),
          isLoading: _isLoading,
        ),
        const SizedBox(height: 20),
        InferenceRunLogs(
          videos: _videos,
          reports: _reports,
          isLoading: _isLoading,
          onRetry: (v) => _handleRetryVideo(v.id),
          onDelete: (v) => _handleDeleteVideo(v.id),
          onReviewVideo: _reviewVideo,
          onOpenReport: (video, report) => _downloadReport(report),
        ),
        const SizedBox(height: 20),
        HistoryAnalyticsFooter(
          areaChart: [for (final e in daysMap.entries) DayCount(e.key, e.value)],
          successCount: success == 0 ? 1 : success,
          failedCount: failed,
          infoWarningCount: other,
          topEventTypes: topTypes.take(5).toList(),
        ),
      ],
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.accentBlueLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.history, size: 22, color: AppColors.accentBlue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational History',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTextLight,
                      shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
                    ),
                  ),
                  Text(
                    'Audit trail of AI detections, inference runs, exported reports, and operational activities.',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryTextLight),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(LucideIcons.search, size: 14),
                  hintText: 'Search audit trail...',
                  hintStyle: const TextStyle(fontSize: 12),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cardBorder)),
                ),
              ),
            ),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: AppColors.cardBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _dateRange,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Time', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: '1', child: Text('Last 1 Hour', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: '24', child: Text('Last 24 Hours', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: '72', child: Text('Last 3 Days', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: '168', child: Text('Last 7 Days', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => _dateRange = v ?? 'All'),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _fetchHistory,
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: Text(_isLoading ? 'Syncing...' : 'Refresh', style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryTextLight, side: const BorderSide(color: AppColors.secondaryTextLight)),
            ),
          ],
        ),
      ],
    );
  }

  List<ReportRecord> get _filteredReportsList {
    final query = _search.toLowerCase();
    return _reports.where((r) {
      final matchesSearch = r.reportName.toLowerCase().contains(query) || r.reportType.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (_filters.status != 'All' && _filters.status.toLowerCase() != 'success') return false;
      if (_filters.activityType != 'All' && _filters.activityType != 'Reports') return false;
      return true;
    }).toList();
  }

  List<ReportRecord> _sortReports(List<ReportRecord> list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      int cmp;
      switch (_reportsSort.key) {
        case ReportSortKey.name:
          cmp = a.reportName.compareTo(b.reportName);
        case ReportSortKey.format:
          cmp = a.reportType.compareTo(b.reportType);
        case ReportSortKey.generatedAt:
          final aT = DateTime.tryParse(a.generatedAt ?? a.createdAt) ?? DateTime(1970);
          final bT = DateTime.tryParse(b.generatedAt ?? b.createdAt) ?? DateTime(1970);
          cmp = aT.compareTo(bT);
        case ReportSortKey.size:
          final aSize = double.tryParse(reportSizeFor(a.id).split(' ').first) ?? 0;
          final bSize = double.tryParse(reportSizeFor(b.id).split(' ').first) ?? 0;
          cmp = aSize.compareTo(bSize);
      }
      return _reportsSort.ascending ? cmp : -cmp;
    });
    return sorted;
  }

  void _handleSort(ReportSortKey key) {
    setState(() {
      _reportsSort = (_reportsSort.key == key && !_reportsSort.ascending) ? ReportsSort(key, true) : ReportsSort(key, false);
    });
  }

  Future<void> _downloadReport(ReportRecord r) async {
    final url = r.reportType.toLowerCase() == 'excel' ? _reportsApi.excelReportDownloadUrl(r.id) : _reportsApi.reportDownloadUrl(r.id);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _viewReport(ReportRecord r) async {
    await launchUrl(Uri.parse(_reportsApi.reportPreviewUrl(r.id)), mode: LaunchMode.externalApplication);
  }

  Future<void> _downloadReportEvent(TimelineEvent act) async {
    final id = act.reportId!;
    final url = (act.reportType ?? '').toLowerCase() == 'excel' ? _reportsApi.excelReportDownloadUrl(id) : _reportsApi.reportDownloadUrl(id);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _viewReportEvent(TimelineEvent act) async {
    await launchUrl(Uri.parse(_reportsApi.reportPreviewUrl(act.reportId!)), mode: LaunchMode.externalApplication);
  }

  Future<void> _handleDeleteReport(int id) async {
    final confirmed = await _confirm('Are you sure you want to delete this historical report record?');
    if (!confirmed) return;
    try {
      await _reportsApi.deleteReport(id);
      if (!mounted) return;
      setState(() {
        _reports = _reports.where((r) => r.id != id).toList();
        final totalPages = (_sortReports(_filteredReportsList).length / _kReportsPerPage).ceil().clamp(1, 1 << 30);
        if (_reportsPage > totalPages) _reportsPage = totalPages;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete report.')));
    }
  }

  Future<void> _handleDeleteVideo(int id) async {
    final confirmed = await _confirm('Are you sure you want to delete this video run log and associated distresses?');
    if (!confirmed) return;
    try {
      await _videoApi.deleteVideo(id);
      if (!mounted) return;
      setState(() => _videos = _videos.where((v) => v.id != id).toList());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete video run.')));
    }
  }

  Future<void> _handleRetryVideo(int id) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('Restarting AI pipeline for Video Run #$id... (Simulated)'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  void _reviewVideo(UploadedVideo v) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video Review is not wired up yet.')),
    );
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    return result ?? false;
  }
}
