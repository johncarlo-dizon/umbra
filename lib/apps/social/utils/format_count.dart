/// Formats a count compactly, Facebook-stats style: 999, 1.2k, 3.4M.
String formatCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final k = n / 1000;
    return '${k.toStringAsFixed(k < 10 ? 1 : 0)}k';
  }
  final m = n / 1000000;
  return '${m.toStringAsFixed(m < 10 ? 1 : 0)}M';
}
