import 'package:flutter/material.dart';

/// A small fixed palette of accent colors for initials-avatar badges,
/// picked to read clearly on the dark theme (same spirit as Unit
/// Converter's per-category fixed-color pattern in the brief).
const List<Color> _avatarPalette = [
  Color(0xFF3B5BDB), // blue (matches the Social app tile accent)
  Color(0xFF2F9E44), // green
  Color(0xFFE8590C), // orange
  Color(0xFFAE3EC9), // purple
  Color(0xFFE64980), // pink
  Color(0xFF1098AD), // teal
  Color(0xFFF08C00), // amber
  Color(0xFF495057), // slate
];

/// Deterministic so the same user always gets the same color, without a
/// dedicated color column in the database.
Color avatarColorFor(String userId) {
  final hash = userId.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return _avatarPalette[hash % _avatarPalette.length];
}

/// Up to two initials from a display name, e.g. "John Carlo" -> "JC",
/// "cat" -> "C". Falls back to "?" for an empty name.
String initialsFor(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
