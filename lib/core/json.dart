/// Small, forgiving JSON readers. The backend is the source of truth, but a
/// missing or null field should never crash a screen.
String? str(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int intOf(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double? doubleOf(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool boolOf(dynamic v, [bool fallback = false]) => v is bool ? v : fallback;

DateTime? dateOf(dynamic v) {
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  return null;
}

Map<String, dynamic> mapOf(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> mapsOf(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
