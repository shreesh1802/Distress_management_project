import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/local_time.dart';

void main() {
  test('server times are read as UTC and shown in local time', () {
    final expected = DateTime.utc(2026, 11, 27, 20, 30).toLocal();
    expect(parseServerTime('2026-11-27T20:30:00+00:00'), expected);
    expect(parseServerTime('2026-11-27T20:30:00Z'), expected);
    // older servers sent UTC without a zone
    expect(parseServerTime('2026-11-27T20:30:00'), expected);
    expect(parseServerTime('2026-11-27T20:30:00.123456'), DateTime.utc(2026, 11, 27, 20, 30, 0, 123, 456).toLocal());
    expect(parseServerTime(''), isNull);
    expect(parseServerTime(null), isNull);
    expect(parseServerTime('not a time'), isNull);
  });

  test('local day and clock text follow the local time', () {
    final local = DateTime.utc(2026, 11, 27, 20, 30, 15).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final day = '${local.year}-${two(local.month)}-${two(local.day)}';
    expect(localIsoDay('2026-11-27T20:30:15+00:00'), day);
    expect(localIsoTime('2026-11-27T20:30:15+00:00'), '${day}T${two(local.hour)}:${two(local.minute)}:${two(local.second)}');
    expect(localIsoDay('garbage'), 'garbage');
  });
}
