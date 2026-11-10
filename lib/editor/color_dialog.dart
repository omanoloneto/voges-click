import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

Future<Color?> askColor(BuildContext context, Color initial) =>
    showDialog<Color>(
      context: context,
      builder: (context) => _ColorDialog(initial: initial),
    );

String hexOf(Color color) => (color.toARGB32() & 0xFFFFFF)
    .toRadixString(16)
    .padLeft(6, '0')
    .toUpperCase();

/// Six hex digits, with or without "#"; null when it is not a color.
Color? parseHex(String text) {
  final digits = text.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(digits)) return null;
  return Color(0xFF000000 | int.parse(digits, radix: 16));
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late Color _color = widget.initial;
  late final _hex = TextEditingController(text: hexOf(widget.initial));

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setChannel(int shift, double value) {
    final argb = _color.toARGB32() & ~(0xFF << shift) | value.round() << shift;
    setState(() => _color = Color(argb));
    _hex.text = hexOf(_color);
  }

  Widget _slider(String label, int shift, Color tint) {
    final value = (_color.toARGB32() >> shift & 0xFF).toDouble();
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            max: 255,
            divisions: 255,
            activeColor: tint,
            label: '${value.round()}',
            onChanged: (value) => _setChannel(shift, value),
          ),
        ),
        SizedBox(width: 32, child: Text('${value.round()}')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.editColorTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _hex,
                    decoration: InputDecoration(
                      labelText: l10n.hexColor,
                      prefixText: '#',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    onChanged: (text) {
                      if (parseHex(text) case final color?) {
                        setState(() => _color = color);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _slider(l10n.red, 16, Colors.red),
            _slider(l10n.green, 8, Colors.green),
            _slider(l10n.blue, 0, Colors.blue),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
