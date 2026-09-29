/// A JSON object as decoded from the API.
typedef J = Map<String, dynamic>;

/// Safe readers for API JSON: a missing or odd value never crashes a screen.
extension JsonRead on Map<String, dynamic> {
  String str(String key, [String fallback = '']) {
    final v = this[key];
    return v == null ? fallback : v.toString();
  }

  String? strOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  int integer(String key, [int fallback = 0]) => intOrNull(key) ?? fallback;

  int? intOrNull(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? dbl(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool flag(String key) => this[key] == true;

  J obj(String key) => objOrNull(key) ?? <String, dynamic>{};

  J? objOrNull(String key) {
    final v = this[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  List<J> list(String key) {
    final v = this[key];
    if (v is! List) return <J>[];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<String> strings(String key) {
    final v = this[key];
    if (v is! List) return <String>[];
    return v.map((e) => e.toString()).toList();
  }

  List<int> ints(String key) {
    final v = this[key];
    if (v is! List) return <int>[];
    return v.map((e) => e is num ? e.toInt() : int.tryParse(e.toString())).whereType<int>().toList();
  }

  DateTime? time(String key) {
    final v = this[key];
    return v is String ? DateTime.tryParse(v)?.toLocal() : null;
  }
}
