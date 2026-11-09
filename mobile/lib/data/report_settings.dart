import 'package:shared_preferences/shared_preferences.dart';

/// Which pavement type the repair strategies in generated reports are based on:
/// bituminous roads follow IRC:82-2015, cement concrete roads follow IRC:SP:83-2018.
///
/// The choice is remembered on the device and sent as `?pavement=` when a PDF / Excel report is generated, wherever
/// that happens (Reports screen, Video Review, live Session report).
class ReportSettings {
  ReportSettings._();

  static const bituminous = 'bituminous';
  static const concrete = 'concrete';
  static const _key = 'report_pavement_type';

  static String pavement = bituminous;

  /// Reads the saved choice (call before showing the selector). Failures leave the default in place.
  static Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved == bituminous || saved == concrete) pavement = saved!;
    } catch (_) {}
  }

  static Future<void> setPavement(String value) async {
    if (value != bituminous && value != concrete) return;
    pavement = value;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, value);
    } catch (_) {}
  }
}
