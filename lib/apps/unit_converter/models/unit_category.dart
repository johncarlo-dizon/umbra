import 'package:flutter/material.dart';

/// A single unit within a category (e.g. "Kilometer" within "Length").
///
/// Conversion is always done via a common base unit for the category
/// (e.g. meters for Length, Celsius for Temperature) rather than unit-to-unit
/// factors directly — this keeps the model O(n) instead of O(n²) and makes
/// temperature's non-linear conversion (offset, not just a factor) trivial
/// to express alongside the linear ones.
class UnitDef {
  final String id;
  final String name;
  final String symbol;
  final double Function(double value) toBase;
  final double Function(double value) fromBase;

  const UnitDef({
    required this.id,
    required this.name,
    required this.symbol,
    required this.toBase,
    required this.fromBase,
  });

  /// Convenience constructor for the common case: a simple multiplicative
  /// factor relative to the category's base unit.
  factory UnitDef.linear({
    required String id,
    required String name,
    required String symbol,
    required double factor,
  }) {
    return UnitDef(
      id: id,
      name: name,
      symbol: symbol,
      toBase: (v) => v * factor,
      fromBase: (v) => v / factor,
    );
  }
}

class UnitCategory {
  final String id;
  final String name;
  final IconData icon;

  /// A fixed brand-style accent color for this category — deliberately NOT
  /// derived from `Theme.of(context).colorScheme` (secondary/tertiary render
  /// as drab olive/gray in this app's palette). This is the same kind of
  /// fixed, intentional color as an AppTile's accentColor on the Home grid:
  /// it doesn't need to adapt between light/dark because it's branding,
  /// not a background or text color that has to stay readable everywhere.
  final Color accentColor;

  final List<UnitDef> units;

  const UnitCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.accentColor,
    required this.units,
  });

  UnitDef unitById(String id) => units.firstWhere((u) => u.id == id);
}

/// All supported categories. Base units chosen per-category (see comments).
final List<UnitCategory> unitCategories = [
  UnitCategory(
    id: 'length',
    name: 'Length',
    icon: Icons.straighten,
    accentColor: const Color(0xFF3D5AFE),
    units: [
      UnitDef.linear(id: 'mm', name: 'Millimeter', symbol: 'mm', factor: 0.001),
      UnitDef.linear(id: 'cm', name: 'Centimeter', symbol: 'cm', factor: 0.01),
      UnitDef.linear(id: 'm', name: 'Meter', symbol: 'm', factor: 1),
      UnitDef.linear(id: 'km', name: 'Kilometer', symbol: 'km', factor: 1000),
      UnitDef.linear(id: 'in', name: 'Inch', symbol: 'in', factor: 0.0254),
      UnitDef.linear(id: 'ft', name: 'Foot', symbol: 'ft', factor: 0.3048),
      UnitDef.linear(id: 'yd', name: 'Yard', symbol: 'yd', factor: 0.9144),
      UnitDef.linear(id: 'mi', name: 'Mile', symbol: 'mi', factor: 1609.344),
    ], // base unit: meter
  ),
  UnitCategory(
    id: 'weight',
    name: 'Weight',
    icon: Icons.monitor_weight_outlined,
    accentColor: const Color(0xFF7C4DFF),
    units: [
      UnitDef.linear(id: 'mg', name: 'Milligram', symbol: 'mg', factor: 1e-6),
      UnitDef.linear(id: 'g', name: 'Gram', symbol: 'g', factor: 0.001),
      UnitDef.linear(id: 'kg', name: 'Kilogram', symbol: 'kg', factor: 1),
      UnitDef.linear(
        id: 'oz',
        name: 'Ounce',
        symbol: 'oz',
        factor: 0.028349523125,
      ),
      UnitDef.linear(id: 'lb', name: 'Pound', symbol: 'lb', factor: 0.45359237),
      UnitDef.linear(id: 'st', name: 'Stone', symbol: 'st', factor: 6.35029318),
      UnitDef.linear(id: 't', name: 'Metric Ton', symbol: 't', factor: 1000),
    ], // base unit: kilogram
  ),
  UnitCategory(
    id: 'temperature',
    name: 'Temperature',
    icon: Icons.thermostat_outlined,
    accentColor: const Color(0xFFFF5252),
    units: [
      UnitDef(
        id: 'c',
        name: 'Celsius',
        symbol: '°C',
        toBase: (v) => v,
        fromBase: (v) => v,
      ),
      UnitDef(
        id: 'f',
        name: 'Fahrenheit',
        symbol: '°F',
        toBase: (v) => (v - 32) * 5 / 9,
        fromBase: (v) => v * 9 / 5 + 32,
      ),
      UnitDef(
        id: 'k',
        name: 'Kelvin',
        symbol: 'K',
        toBase: (v) => v - 273.15,
        fromBase: (v) => v + 273.15,
      ),
    ], // base unit: Celsius
  ),
  UnitCategory(
    id: 'volume',
    name: 'Volume',
    icon: Icons.local_drink_outlined,
    accentColor: const Color(0xFF00ACC1),
    units: [
      UnitDef.linear(id: 'ml', name: 'Milliliter', symbol: 'mL', factor: 0.001),
      UnitDef.linear(id: 'l', name: 'Liter', symbol: 'L', factor: 1),
      UnitDef.linear(id: 'm3', name: 'Cubic Meter', symbol: 'm³', factor: 1000),
      UnitDef.linear(
        id: 'tsp',
        name: 'Teaspoon',
        symbol: 'tsp',
        factor: 0.00492892159375,
      ),
      UnitDef.linear(
        id: 'tbsp',
        name: 'Tablespoon',
        symbol: 'tbsp',
        factor: 0.01478676478125,
      ),
      UnitDef.linear(
        id: 'floz',
        name: 'Fluid Ounce',
        symbol: 'fl oz',
        factor: 0.0295735295625,
      ),
      UnitDef.linear(
        id: 'cup',
        name: 'Cup',
        symbol: 'cup',
        factor: 0.2365882365,
      ),
      UnitDef.linear(
        id: 'qt',
        name: 'Quart',
        symbol: 'qt',
        factor: 0.946352946,
      ),
      UnitDef.linear(
        id: 'gal',
        name: 'Gallon',
        symbol: 'gal',
        factor: 3.785411784,
      ),
    ], // base unit: liter
  ),
  UnitCategory(
    id: 'area',
    name: 'Area',
    icon: Icons.crop_square,
    accentColor: const Color(0xFF43A047),
    units: [
      UnitDef.linear(
        id: 'mm2',
        name: 'Sq Millimeter',
        symbol: 'mm²',
        factor: 1e-6,
      ),
      UnitDef.linear(
        id: 'cm2',
        name: 'Sq Centimeter',
        symbol: 'cm²',
        factor: 1e-4,
      ),
      UnitDef.linear(id: 'm2', name: 'Sq Meter', symbol: 'm²', factor: 1),
      UnitDef.linear(id: 'ha', name: 'Hectare', symbol: 'ha', factor: 10000),
      UnitDef.linear(
        id: 'km2',
        name: 'Sq Kilometer',
        symbol: 'km²',
        factor: 1e6,
      ),
      UnitDef.linear(
        id: 'in2',
        name: 'Sq Inch',
        symbol: 'in²',
        factor: 0.00064516,
      ),
      UnitDef.linear(
        id: 'ft2',
        name: 'Sq Foot',
        symbol: 'ft²',
        factor: 0.09290304,
      ),
      UnitDef.linear(
        id: 'acre',
        name: 'Acre',
        symbol: 'ac',
        factor: 4046.8564224,
      ),
      UnitDef.linear(
        id: 'mi2',
        name: 'Sq Mile',
        symbol: 'mi²',
        factor: 2589988.110336,
      ),
    ], // base unit: square meter
  ),
  UnitCategory(
    id: 'speed',
    name: 'Speed',
    icon: Icons.speed_outlined,
    accentColor: const Color(0xFFEC407A),
    units: [
      UnitDef.linear(id: 'mps', name: 'Meters/sec', symbol: 'm/s', factor: 1),
      UnitDef.linear(
        id: 'kph',
        name: 'Kilometers/hr',
        symbol: 'km/h',
        factor: 0.277778,
      ),
      UnitDef.linear(
        id: 'mph',
        name: 'Miles/hr',
        symbol: 'mph',
        factor: 0.44704,
      ),
      UnitDef.linear(id: 'knot', name: 'Knot', symbol: 'kn', factor: 0.514444),
      UnitDef.linear(
        id: 'fps',
        name: 'Feet/sec',
        symbol: 'ft/s',
        factor: 0.3048,
      ),
    ], // base unit: meters/second
  ),
  UnitCategory(
    id: 'time',
    name: 'Time',
    icon: Icons.schedule_outlined,
    accentColor: const Color(0xFF8D6E63),
    units: [
      UnitDef.linear(
        id: 'ms',
        name: 'Millisecond',
        symbol: 'ms',
        factor: 0.001,
      ),
      UnitDef.linear(id: 's', name: 'Second', symbol: 's', factor: 1),
      UnitDef.linear(id: 'min', name: 'Minute', symbol: 'min', factor: 60),
      UnitDef.linear(id: 'hr', name: 'Hour', symbol: 'hr', factor: 3600),
      UnitDef.linear(id: 'day', name: 'Day', symbol: 'day', factor: 86400),
      UnitDef.linear(id: 'week', name: 'Week', symbol: 'wk', factor: 604800),
    ], // base unit: second
  ),
  UnitCategory(
    id: 'data',
    name: 'Data Storage',
    icon: Icons.storage_outlined,
    accentColor: const Color(0xFF546E7A),
    units: [
      UnitDef.linear(id: 'bit', name: 'Bit', symbol: 'bit', factor: 0.125),
      UnitDef.linear(id: 'byte', name: 'Byte', symbol: 'B', factor: 1),
      UnitDef.linear(id: 'kb', name: 'Kilobyte', symbol: 'KB', factor: 1024),
      UnitDef.linear(
        id: 'mb',
        name: 'Megabyte',
        symbol: 'MB',
        factor: 1024 * 1024,
      ),
      UnitDef.linear(
        id: 'gb',
        name: 'Gigabyte',
        symbol: 'GB',
        factor: 1024 * 1024 * 1024,
      ),
      UnitDef.linear(
        id: 'tb',
        name: 'Terabyte',
        symbol: 'TB',
        factor: 1024 * 1024 * 1024 * 1024,
      ),
    ], // base unit: byte (binary/1024-based, the common convention for storage)
  ),
  UnitCategory(
    id: 'pressure',
    name: 'Pressure',
    icon: Icons.compress_outlined,
    accentColor: const Color(0xFFFB8C00),
    units: [
      UnitDef.linear(id: 'pa', name: 'Pascal', symbol: 'Pa', factor: 1),
      UnitDef.linear(
        id: 'kpa',
        name: 'Kilopascal',
        symbol: 'kPa',
        factor: 1000,
      ),
      UnitDef.linear(id: 'bar', name: 'Bar', symbol: 'bar', factor: 100000),
      UnitDef.linear(
        id: 'psi',
        name: 'PSI',
        symbol: 'psi',
        factor: 6894.757293168,
      ),
      UnitDef.linear(
        id: 'atm',
        name: 'Atmosphere',
        symbol: 'atm',
        factor: 101325,
      ),
      UnitDef.linear(
        id: 'mmhg',
        name: 'mmHg',
        symbol: 'mmHg',
        factor: 133.322387415,
      ),
    ], // base unit: pascal
  ),
];
