String formatDuration(Duration value) {
  final h = value.inHours;
  final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String formatPace(double? minPerKm) {
  if (minPerKm == null || minPerKm.isInfinite || minPerKm.isNaN) return '--:--';
  final minutes = minPerKm.floor();
  final seconds = ((minPerKm - minutes) * 60).round().clamp(0, 59);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String shortDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}
