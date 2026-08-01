import 'package:flutter/material.dart';

import '../models/unit_category.dart';
import '../services/unit_converter_service.dart';

/// Conversion screen for a single category.
///
/// UX deliberately departs from the classic "two dropdowns + one output"
/// pattern: the user types a value once, against whichever unit is
/// currently the "anchor" (shown pinned at the top, in a bold solid-color
/// card), and every other unit in the category updates live below it as a
/// scrollable, visually neutral list — so the one thing you're editing
/// stands out and the results read cleanly instead of every row competing
/// for attention in the same tinted color. Tapping any result re-anchors
/// the input to that unit, carrying its currently-shown value forward.
class UnitConverterDetailScreen extends StatefulWidget {
  final String categoryId;

  const UnitConverterDetailScreen({super.key, required this.categoryId});

  @override
  State<UnitConverterDetailScreen> createState() =>
      _UnitConverterDetailScreenState();
}

class _UnitConverterDetailScreenState extends State<UnitConverterDetailScreen> {
  final _service = const UnitConverterService();
  final _inputController = TextEditingController(text: '1');
  final _inputFocusNode = FocusNode();

  late UnitCategory _category;
  late UnitDef _anchorUnit;

  @override
  void initState() {
    super.initState();
    _category = unitCategories.firstWhere((c) => c.id == widget.categoryId);
    _anchorUnit = _category.units.first;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  double get _inputValue => double.tryParse(_inputController.text) ?? 0;

  void _reanchor(UnitDef newUnit, double carriedValue) {
    setState(() {
      _anchorUnit = newUnit;
      _inputController.text = _service.format(carriedValue);
    });
    // Keep focus off the field after a re-anchor tap so the on-screen
    // keyboard doesn't pop up unexpectedly on mobile.
    _inputFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _category.accentColor;
    final results = _service.convertToAll(
      category: _category,
      fromUnit: _anchorUnit,
      value: _inputValue,
    );
    final otherUnits = _category.units
        .where((u) => u.id != _anchorUnit.id)
        .toList();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(_category.name),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _anchorCard(accent),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: otherUnits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final unit = otherUnits[index];
                      final value = results[unit.id]!;
                      return _resultCard(scheme, accent, unit, value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bold, solid-color "hero" card for the value the user is actively
  /// editing. This is the one card on screen allowed to be fully saturated
  /// with the category's accent color — it's what makes it obvious which
  /// unit you're typing into, versus which units are just showing results.
  Widget _anchorCard(Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _anchorUnit.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  // The underline + edit icon are the affordance that tells
                  // the user this number is editable — without it, this
                  // looked visually identical to the read-only "0" values
                  // in the result rows below, with no cue to tap and type.
                  padding: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          autofocus: false,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          cursorColor: Colors.white,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            isCollapsed: true,
                            filled: false,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _anchorUnit.symbol,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Neutral, uniform list rows for every other unit — intentionally NOT
  /// tinted with the category color, so the list reads as a clean, calm
  /// set of results rather than every row shouting for attention. Each row
  /// gets a small accent-colored symbol chip so the category's color is
  /// still present, just as an accent rather than the whole background.
  Widget _resultCard(
    ColorScheme scheme,
    Color accent,
    UnitDef unit,
    double value,
  ) {
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _reanchor(unit, value),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _service.format(value),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unit.symbol,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.swap_horiz_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
