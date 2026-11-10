import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../painting/color_matrix.dart';
import '../painting/rgba_image.dart';

enum UnsavedChoice { save, discard, cancel }

Future<UnsavedChoice> askToSave(BuildContext context, String name) async {
  final choice = await showDialog<UnsavedChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.saveChangesTitle),
      content: Text(context.l10n.saveChangesMessage(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChoice.cancel),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChoice.discard),
          child: Text(context.l10n.dontSave),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, UnsavedChoice.save),
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
  return choice ?? UnsavedChoice.cancel;
}

class SizeRequest {
  const SizeRequest(this.width, this.height, {this.stretch = true});

  final int width;
  final int height;
  final bool stretch;
}

Future<SizeRequest?> askNewImageSize(BuildContext context, Size initial) =>
    showDialog<SizeRequest>(
      context: context,
      builder: (context) => _SizeDialog(
        title: context.l10n.newImageTitle,
        action: context.l10n.create,
        initial: initial,
        offersStretch: false,
      ),
    );

Future<SizeRequest?> askResize(BuildContext context, Size current) =>
    showDialog<SizeRequest>(
      context: context,
      builder: (context) => _SizeDialog(
        title: context.l10n.resizeTitle,
        action: context.l10n.apply,
        initial: current,
        offersStretch: true,
      ),
    );

class _SizeDialog extends StatefulWidget {
  const _SizeDialog({
    required this.title,
    required this.action,
    required this.initial,
    required this.offersStretch,
  });

  final String title;
  final String action;
  final Size initial;
  final bool offersStretch;

  @override
  State<_SizeDialog> createState() => _SizeDialogState();
}

class _SizeDialogState extends State<_SizeDialog> {
  late final _width = TextEditingController(
    text: '${widget.initial.width.round()}',
  );
  late final _height = TextEditingController(
    text: '${widget.initial.height.round()}',
  );
  var _keepProportions = true;
  var _stretch = true;

  double get _ratio => widget.initial.width / widget.initial.height;

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  int? _valid(TextEditingController field) {
    final value = int.tryParse(field.text);
    return value != null && value >= 1 && value <= maxImageSide ? value : null;
  }

  void _follow(TextEditingController changed) {
    if (!_keepProportions) return setState(() {});
    final value = int.tryParse(changed.text);
    if (value == null) return setState(() {});
    final other = identical(changed, _width) ? _height : _width;
    final linked = identical(changed, _width) ? value / _ratio : value * _ratio;
    other.text = '${linked.round().clamp(1, maxImageSide)}';
    setState(() {});
  }

  void _submit() {
    final width = _valid(_width), height = _valid(_height);
    if (width == null || height == null) return;
    Navigator.pop(context, SizeRequest(width, height, stretch: _stretch));
  }

  Widget _field(String label, TextEditingController controller) {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: controller,
        autofocus: identical(controller, _width),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          suffixText: context.l10n.pixelsUnit,
          errorText: _valid(controller) == null ? '' : null,
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
        onChanged: (_) => _follow(controller),
        onSubmitted: (_) => _submit(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final valid = _valid(_width) != null && _valid(_height) != null;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _field(l10n.width, _width),
                const SizedBox(width: 16),
                _field(l10n.height, _height),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.sizeLimit(maxImageSide),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _keepProportions,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.keepProportions),
              onChanged: (value) {
                setState(() => _keepProportions = value ?? true);
                if (_keepProportions) _follow(_width);
              },
            ),
            if (widget.offersStretch)
              CheckboxListTile(
                value: _stretch,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.stretchDrawing),
                subtitle: _stretch ? null : Text(l10n.stretchDrawingHint),
                onChanged: (value) => setState(() => _stretch = value ?? true),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: valid ? _submit : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

class TextRequest {
  const TextRequest(this.text, {required this.fontSize, required this.bold});

  final String text;
  final double fontSize;
  final bool bold;
}

Future<TextRequest?> askText(BuildContext context) => showDialog<TextRequest>(
  context: context,
  builder: (context) => const _TextDialog(),
);

class _TextDialog extends StatefulWidget {
  const _TextDialog();

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  // the last choices stay for the next text of the session
  static var _lastSize = 48;
  static var _lastBold = false;

  final _text = TextEditingController();
  late final _size = TextEditingController(text: '$_lastSize');
  late var _bold = _lastBold;

  @override
  void dispose() {
    _text.dispose();
    _size.dispose();
    super.dispose();
  }

  int? get _validSize {
    final value = int.tryParse(_size.text);
    return value != null && value >= 4 && value <= 1000 ? value : null;
  }

  bool get _valid => _text.text.trim().isNotEmpty && _validSize != null;

  void _submit() {
    if (!_valid) return;
    _lastSize = _validSize!;
    _lastBold = _bold;
    Navigator.pop(
      context,
      TextRequest(
        _text.text.trimRight(),
        fontSize: _lastSize.toDouble(),
        bold: _bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.textTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(hintText: l10n.textHint),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _size,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.fontSize,
                      suffixText: l10n.pixelsUnit,
                      errorText: _validSize == null ? '' : null,
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CheckboxListTile(
                    value: _bold,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.bold),
                    onChanged: (value) =>
                        setState(() => _bold = value ?? false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _valid ? _submit : null, child: Text(l10n.ok)),
      ],
    );
  }
}

Future<String?> askLayerName(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(current: current),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.current});

  final String current;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.current)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.current.length,
    );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.renameLayerTitle),
      content: SizedBox(
        width: 300,
        child: TextField(
          controller: _name,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(labelText: l10n.layerNameLabel),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}

enum Adjustment { brightnessContrast, hueSaturation }

/// Asks how strong an adjustment is, calling [onPreview] at every change.
/// The matrix to apply, or null when cancelled.
Future<ColorMatrix?> askAdjustment(
  BuildContext context,
  Adjustment adjustment, {
  required ValueChanged<ColorMatrix> onPreview,
}) => showDialog<ColorMatrix>(
  context: context,
  // the image behind has to show its true colors
  barrierColor: Colors.transparent,
  builder: (context) =>
      _AdjustmentDialog(adjustment: adjustment, onPreview: onPreview),
);

class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog({required this.adjustment, required this.onPreview});

  final Adjustment adjustment;
  final ValueChanged<ColorMatrix> onPreview;

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  var _first = 0.0;
  var _second = 0.0;

  bool get _isHue => widget.adjustment == Adjustment.hueSaturation;

  ColorMatrix get _matrix => _isHue
      ? adjustmentMatrix(hue: _first, saturation: _second / 100)
      : adjustmentMatrix(brightness: _first / 100, contrast: _second / 100);

  void _change(VoidCallback apply) {
    setState(apply);
    widget.onPreview(_matrix);
  }

  Widget _slider(
    String label,
    double value,
    double limit,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: -limit,
            max: limit,
            semanticFormatterCallback: (value) => '$label: ${value.round()}',
            onChanged: (value) => onChanged(value.roundToDouble()),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${value.round()}', textAlign: TextAlign.end),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.fromLTRB(40, 24, 40, 56),
      title: Text(
        (_isHue ? l10n.hueSaturation : l10n.brightnessContrast).replaceAll(
          '…',
          '',
        ),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slider(
              _isHue ? l10n.hue : l10n.brightness,
              _first,
              _isHue ? 180 : 100,
              (value) => _change(() => _first = value),
            ),
            _slider(
              _isHue ? l10n.saturation : l10n.contrast,
              _second,
              100,
              (value) => _change(() => _second = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _matrix),
          child: Text(l10n.apply),
        ),
      ],
    );
  }
}
