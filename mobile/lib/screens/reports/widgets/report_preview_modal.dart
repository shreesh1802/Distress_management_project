import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/reports_api.dart';
import '../../../theme/app_colors.dart';

/// Direct port of ReportsDashboard.tsx's "Visual Report Preview Modal
/// Dialog": a header (id, format/size, Download, close) plus a body that
/// renders one of two static/decorative document mockups depending on
/// `reportType`. The source also has a third `renderJSONPreview` branch,
/// but every real code path (backend-generated and the fake custom-report
/// generator alike) only ever produces `reportType` 'PDF' or 'EXCEL' --
/// `'JSON'` is unreachable dead code, so it isn't ported here.
class ReportPreviewModal extends StatelessWidget {
  const ReportPreviewModal({super.key, required this.report, required this.onClose, required this.onDownload});

  final ReportItem report;
  final VoidCallback onClose;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: const Color(0x99000000),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 32, offset: Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.fileText, size: 18, color: AppColors.accentBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(report.id, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                              Text(
                                'Format: ${report.reportType} • Size: ${report.size}',
                                style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: onDownload,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white),
                          child: const Text('Download Document', style: TextStyle(fontSize: 12)),
                        ),
                        IconButton(onPressed: onClose, icon: const Icon(LucideIcons.x, size: 16)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: report.reportType == 'EXCEL' ? _excelPreview() : _pdfCoverPreview(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pdfCoverPreview() {
    final severityColor = Color(kReportSeverityColors[report.severity] ?? 0xFF999999);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ROADVISION AI TELEMETRIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: Color(0xFF6C7354))),
          const SizedBox(height: 4),
          const Text('ROAD DISTRESS AUDIT DOCUMENT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _metaCell('Audit Identifier', report.id)),
              Expanded(child: _metaCell('Generated Date', report.generatedDate)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _metaCell('Target Segment', report.roadId)),
              Expanded(child: _metaCell('District Location', report.district)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EXECUTIVE SUMMARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
                const SizedBox(height: 6),
                Text.rich(TextSpan(style: const TextStyle(fontSize: 12, color: AppColors.primaryText), children: [
                  const TextSpan(text: 'Target Severity index: '),
                  TextSpan(text: report.severity.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: severityColor)),
                ])),
                const SizedBox(height: 4),
                Text.rich(TextSpan(style: const TextStyle(fontSize: 12, color: AppColors.primaryText), children: [
                  const TextSpan(text: 'Principal Distress Class: '),
                  TextSpan(text: report.distressType, style: const TextStyle(fontWeight: FontWeight.w700)),
                ])),
                const SizedBox(height: 4),
                Text.rich(TextSpan(style: const TextStyle(fontSize: 12, color: AppColors.primaryText), children: [
                  const TextSpan(text: 'Compiled By: '),
                  TextSpan(text: report.generatedBy, style: const TextStyle(fontWeight: FontWeight.w700)),
                ])),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 10),
          const Text(
            'CONFIDENTIAL PWD ROAD AUDIT TELEMETRIES • PUBLIC WORKS DEPARTMENT • STATE AGENCY FORECASTS',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _metaCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _excelPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.fileSpreadsheet, size: 14, color: Color(0xFF10B981)),
            const SizedBox(width: 6),
            Expanded(child: Text('Sheet1 - ${report.id} Summary', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 36,
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text('Index', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Road segment', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Coordinates', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Distress type', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Severity rating', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Estimated Cost', style: TextStyle(fontSize: 11))),
            ],
            rows: [
              DataRow(cells: [
                const DataCell(Text('1', style: TextStyle(fontSize: 11))),
                DataCell(Text(report.roadId, style: const TextStyle(fontSize: 11))),
                const DataCell(Text('18.520, 73.856', style: TextStyle(fontSize: 11))),
                DataCell(Text(report.distressType.split(' ').first, style: const TextStyle(fontSize: 11))),
                DataCell(Text(
                  report.severity.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(kReportSeverityColors[report.severity] ?? 0xFF999999)),
                )),
                const DataCell(Text('₹1,45,000', style: TextStyle(fontSize: 11))),
              ]),
              DataRow(cells: [
                const DataCell(Text('2', style: TextStyle(fontSize: 11))),
                DataCell(Text(report.roadId, style: const TextStyle(fontSize: 11))),
                const DataCell(Text('18.524, 73.861', style: TextStyle(fontSize: 11))),
                const DataCell(Text('Longitudinal Crack', style: TextStyle(fontSize: 11))),
                const DataCell(Text('MEDIUM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFACC15)))),
                const DataCell(Text('₹48,000', style: TextStyle(fontSize: 11))),
              ]),
              DataRow(cells: [
                const DataCell(Text('3', style: TextStyle(fontSize: 11))),
                DataCell(Text(report.roadId, style: const TextStyle(fontSize: 11))),
                const DataCell(Text('18.530, 73.865', style: TextStyle(fontSize: 11))),
                const DataCell(Text('Patch Defect', style: TextStyle(fontSize: 11))),
                const DataCell(Text('LOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)))),
                const DataCell(Text('₹35,000', style: TextStyle(fontSize: 11))),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
