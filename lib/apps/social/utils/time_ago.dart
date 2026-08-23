/// Formats a DateTime as a short relative string, Facebook/Twitter style:
/// "just now", "5m", "2h", "3d", "4w", then falls back to a date.
String timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
  return '${(diff.inDays / 365).floor()}y';
}
