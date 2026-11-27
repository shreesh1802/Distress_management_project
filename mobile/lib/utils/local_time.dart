/// Times from the server are in UTC. These helpers turn them into this phone's (or browser's) local time
/// before anything is shown, so a session recorded at 2:00 am in India shows as 2:00 am, not 8:30 pm.
library;

final RegExp _hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false);
final RegExp _hasClock = RegExp(r'\d{2}:\d{2}');

/// A server timestamp as local time, or null if it is missing or unreadable.
/// A timestamp without a time zone is taken to be UTC (older servers sent them that way).
DateTime? parseServerTime(String? value) {
  if (value == null) return null;
  var text = value.trim();
  if (text.isEmpty) return null;
  if (_hasClock.hasMatch(text) && !_hasZone.hasMatch(text)) text = '${text}Z';
  return DateTime.tryParse(text)?.toLocal();
}

String _two(int n) => n.toString().padLeft(2, '0');

/// The local calendar day of a server timestamp, as "YYYY-MM-DD" (the text itself if it cannot be read).
String localIsoDay(String? value) {
  final t = parseServerTime(value);
  if (t == null) return (value ?? '').split('T').first;
  return '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';
}

/// A server timestamp as local "YYYY-MM-DDTHH:MM:SS" (no zone), for screens that show the time part.
String localIsoTime(String value) {
  final t = parseServerTime(value);
  if (t == null) return value;
  return '${localIsoDay(value)}T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}
