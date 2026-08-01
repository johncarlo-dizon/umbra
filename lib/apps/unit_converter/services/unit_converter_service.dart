import '../models/unit_category.dart';

/// Pure local conversion logic — no network, no Supabase. Kept as its own
/// service class (rather than static functions scattered in the UI) purely
/// so it's easy to unit-test independently of any widget.
class UnitConverterService {
  const UnitConverterService();

  /// Converts [value] from [fromUnit] to [toUnit] within [category].
  double convert({
    required UnitCategory category,
    required UnitDef fromUnit,
    required UnitDef toUnit,
    required double value,
  }) {
    final baseValue = fromUnit.toBase(value);
    return toUnit.fromBase(baseValue);
  }

  /// Converts [value] from [fromUnit] to every other unit in [category].
  /// Returns a map of unit id -> converted value, in the category's declared
  /// unit order. This powers the "live list" UI — one input, every unit
  /// updates at once instead of a single dropdown-to-dropdown conversion.
  Map<String, double> convertToAll({
    required UnitCategory category,
    required UnitDef fromUnit,
    required double value,
  }) {
    final baseValue = fromUnit.toBase(value);
    return {
      for (final unit in category.units) unit.id: unit.fromBase(baseValue),
    };
  }

  /// Formats a converted value for display as a plain decimal wherever
  /// realistically possible — every category in this app deals in everyday
  /// magnitudes (milligrams to tons, millimeters to miles), and scientific
  /// notation like "1.5747e-7" is not something a general user can read at
  /// a glance. Exponential notation is reserved for genuinely extreme
  /// values that fall well outside anything these categories produce.
  String format(double value) {
    if (value.isNaN || value.isInfinite) return '—';
    if (value == 0) return '0';

    final absValue = value.abs();

    // Only truly extreme magnitudes fall back to exponential notation.
    if (absValue >= 1e15 || absValue < 1e-12) {
      return value.toStringAsExponential(4);
    }

    if (value == value.roundToDouble() && absValue < 1e12) {
      return value.toInt().toString();
    }

    // More decimal places for small numbers so they don't round to "0",
    // fewer for large numbers so they don't turn into a wall of digits.
    final decimals = absValue >= 1000
        ? 2
        : absValue >= 1
        ? 4
        : absValue >= 0.001
        ? 6
        : 10;

    var s = value.toStringAsFixed(decimals);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }
}
