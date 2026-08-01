import 'package:flutter/material.dart';

/// A standard (non-scientific) calculator.
///
/// Fully local — no Supabase, no network calls, no resilience pattern needed
/// since there is nothing that can fail asynchronously. Follows the theming
/// rule: every color is pulled from `Theme.of(context).colorScheme`, nothing
/// is hardcoded, so it behaves correctly in both light and dark mode.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

enum _Op { add, subtract, multiply, divide }

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _expression = '';
  double? _accumulator;
  _Op? _pendingOp;
  bool _startNewEntry = true;
  bool _hasError = false;
  String? _computeError;

  void _inputDigit(String digit) {
    setState(() {
      if (_hasError) {
        _display = digit == '.' ? '0.' : digit;
        _hasError = false;
        _startNewEntry = false;
        return;
      }
      if (_startNewEntry) {
        _display = digit == '.' ? '0.' : digit;
        _startNewEntry = false;
      } else {
        if (digit == '.' && _display.contains('.')) return;
        // Avoid unbounded growth of digits on screen.
        if (_display.replaceAll('-', '').replaceAll('.', '').length >= 12) {
          return;
        }
        _display += digit;
      }
    });
  }

  void _toggleSign() {
    setState(() {
      if (_display == '0' || _hasError) return;
      _display = _display.startsWith('-')
          ? _display.substring(1)
          : '-$_display';
    });
  }

  void _percent() {
    setState(() {
      if (_hasError) return;
      final value = double.tryParse(_display) ?? 0;
      _display = _formatResult(value / 100);
      _startNewEntry = true;
    });
  }

  void _clear() {
    setState(() {
      _display = '0';
      _expression = '';
      _accumulator = null;
      _pendingOp = null;
      _startNewEntry = true;
      _hasError = false;
      _computeError = null;
    });
  }

  void _applyOp(_Op op) {
    setState(() {
      if (_hasError) return;
      final current = double.tryParse(_display) ?? 0;

      if (_accumulator == null) {
        _accumulator = current;
      } else if (!_startNewEntry) {
        final result = _compute(_accumulator!, current, _pendingOp!);
        if (result == null) {
          _expression =
              '${_formatResult(_accumulator!)} ${_opSymbol(_pendingOp!)} ${_formatResult(current)}';
          _display = _computeError ?? 'Error';
          _hasError = true;
          _accumulator = null;
          _pendingOp = null;
          _startNewEntry = true;
          return;
        }
        _accumulator = result;
        _display = _formatResult(result);
      }

      _pendingOp = op;
      _expression = '${_formatResult(_accumulator!)} ${_opSymbol(op)}';
      _startNewEntry = true;
    });
  }

  void _equals() {
    setState(() {
      if (_hasError) return;
      if (_pendingOp == null || _accumulator == null) return;
      final current = double.tryParse(_display) ?? 0;
      final result = _compute(_accumulator!, current, _pendingOp!);

      if (result == null) {
        _expression =
            '${_formatResult(_accumulator!)} ${_opSymbol(_pendingOp!)} ${_formatResult(current)} =';
        _display = _computeError ?? 'Error';
        _hasError = true;
      } else {
        _expression =
            '${_formatResult(_accumulator!)} ${_opSymbol(_pendingOp!)} ${_formatResult(current)} =';
        _display = _formatResult(result);
      }
      _accumulator = null;
      _pendingOp = null;
      _startNewEntry = true;
    });
  }

  double? _compute(double a, double b, _Op op) {
    switch (op) {
      case _Op.add:
        return a + b;
      case _Op.subtract:
        return a - b;
      case _Op.multiply:
        return a * b;
      case _Op.divide:
        if (b == 0) {
          _computeError = 'Cannot divide by zero';
          return null;
        }
        return a / b;
    }
  }

  String _opSymbol(_Op op) {
    switch (op) {
      case _Op.add:
        return '+';
      case _Op.subtract:
        return '−';
      case _Op.multiply:
        return '×';
      case _Op.divide:
        return '÷';
    }
  }

  String _formatResult(double value) {
    if (value.isNaN || value.isInfinite) return 'Error';
    if (value == value.roundToDouble() && value.abs() < 1e12) {
      return value.toInt().toString();
    }
    var s = value.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Calculator'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_expression.isNotEmpty)
                      Text(
                        _expression,
                        style: TextStyle(
                          fontSize: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomRight,
                      child: Text(
                        _display,
                        style: TextStyle(
                          fontSize: _hasError ? 28 : 56,
                          fontWeight: FontWeight.w600,
                          color: _hasError ? scheme.error : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buttonExpanded(
                        label: 'C',
                        onTap: _clear,
                        background: scheme.errorContainer,
                        foreground: scheme.onErrorContainer,
                      ),
                      _buttonExpanded(
                        label: '±',
                        onTap: _toggleSign,
                        background: scheme.secondaryContainer,
                        foreground: scheme.onSecondaryContainer,
                      ),
                      _buttonExpanded(
                        label: '%',
                        onTap: _percent,
                        background: scheme.secondaryContainer,
                        foreground: scheme.onSecondaryContainer,
                      ),
                      _buttonExpanded(
                        label: '÷',
                        onTap: () => _applyOp(_Op.divide),
                        background: scheme.primary,
                        foreground: scheme.onPrimary,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _numButton('7'),
                      _numButton('8'),
                      _numButton('9'),
                      _buttonExpanded(
                        label: '×',
                        onTap: () => _applyOp(_Op.multiply),
                        background: scheme.primary,
                        foreground: scheme.onPrimary,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _numButton('4'),
                      _numButton('5'),
                      _numButton('6'),
                      _buttonExpanded(
                        label: '−',
                        onTap: () => _applyOp(_Op.subtract),
                        background: scheme.primary,
                        foreground: scheme.onPrimary,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _numButton('1'),
                      _numButton('2'),
                      _numButton('3'),
                      _buttonExpanded(
                        label: '+',
                        onTap: () => _applyOp(_Op.add),
                        background: scheme.primary,
                        foreground: scheme.onPrimary,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buttonExpanded(
                        label: '0',
                        flex: 2,
                        onTap: () => _inputDigit('0'),
                        background: scheme.surfaceContainerHighest,
                        foreground: scheme.onSurface,
                      ),
                      _numButton('.'),
                      _buttonExpanded(
                        label: '=',
                        onTap: _equals,
                        background: scheme.primary,
                        foreground: scheme.onPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numButton(String label) {
    final scheme = Theme.of(context).colorScheme;
    return _buttonExpanded(
      label: label,
      onTap: () => _inputDigit(label),
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurface,
    );
  }

  Widget _buttonExpanded({
    required String label,
    required VoidCallback onTap,
    required Color background,
    required Color foreground,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AspectRatio(
          aspectRatio: flex == 1 ? 1 : 2.2,
          child: Material(
            color: background,
            shape: flex == 1 ? const CircleBorder() : const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
