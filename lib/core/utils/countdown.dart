/// Human-readable countdown until a time-locked withdrawal releases.
/// Pure function of the remaining duration (trivially unit-testable).
String formatCountdown(Duration remaining) {
  if (remaining.inSeconds <= 0) return 'releasing…';
  if (remaining.inDays >= 1) {
    return '${remaining.inDays}d ${remaining.inHours % 24}h';
  }
  if (remaining.inHours >= 1) {
    return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
  }
  if (remaining.inMinutes >= 1) {
    return '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
  }
  return '${remaining.inSeconds}s';
}

/// Human-readable age of a timestamp ("just now", "12s ago", "3m ago",
/// "2h ago"). Pure function, unit-tested.
String formatAge(DateTime at) {
  final seconds = DateTime.now().difference(at).inSeconds;
  if (seconds < 5) return 'just now';
  if (seconds < 60) return '${seconds}s ago';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ago';
  return '${minutes ~/ 60}h ago';
}
