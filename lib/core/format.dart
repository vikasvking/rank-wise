const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

/// "5 Oct 2026, 10:00"
String fmtDateTime(DateTime? t) {
  if (t == null) return '—';
  return '${t.day} ${_months[t.month - 1]} ${t.year}, ${_two(t.hour)}:${_two(t.minute)}';
}

/// "5 Oct 2026"
String fmtDate(DateTime? t) => t == null ? '—' : '${t.day} ${_months[t.month - 1]} ${t.year}';

/// "10:00"
String fmtTime(DateTime? t) => t == null ? '—' : '${_two(t.hour)}:${_two(t.minute)}';

/// 754 -> "12m 34s", 3700 -> "1h 1m"
String fmtDuration(int? seconds) {
  if (seconds == null) return '—';
  if (seconds < 60) return '${seconds}s';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m ${_two(s)}s';
}

/// Countdown clock: 754 -> "12:34", 3700 -> "1:01:40"
String fmtClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

/// 12.0 -> "12", 12.5 -> "12.5", null -> "—"
String fmtNum(num? v, {int decimals = 2}) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return v.round().toString();
  var s = v.toStringAsFixed(decimals);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
