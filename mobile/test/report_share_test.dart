import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/report_share.dart';

void main() {
  group('reportFileName', () {
    test('keeps a clean name and adds the right extension', () {
      expect(reportFileName('Road_Inspection_Report_Video_7', excel: false), 'Road_Inspection_Report_Video_7.pdf');
      expect(reportFileName('Road_Inspection_Audit_Video_7', excel: true), 'Road_Inspection_Audit_Video_7.xlsx');
    });

    test('replaces characters chat apps and file systems dislike', () {
      expect(reportFileName('Report / Video #12 (final)', excel: false), 'Report_Video_12_final.pdf');
      expect(reportFileName('a:b*c?d"e<f>g|h', excel: true), 'a_b_c_d_e_f_g_h.xlsx');
    });

    test('does not double the extension and strips path tricks', () {
      expect(reportFileName('summary.PDF', excel: false), 'summary.pdf');
      expect(reportFileName('../../etc/passwd', excel: false), 'etc_passwd.pdf');
    });

    test('falls back to a default when nothing usable is left', () {
      expect(reportFileName('   ', excel: false), 'Road_Inspection_Report.pdf');
      expect(reportFileName('***', excel: true), 'Road_Inspection_Report.xlsx');
    });
  });
}
