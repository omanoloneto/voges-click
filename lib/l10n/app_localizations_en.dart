// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get fileMenu => 'File';

  @override
  String get newImage => 'New';

  @override
  String get openImage => 'Open';

  @override
  String get save => 'Save';

  @override
  String get saveAs => 'Save as';

  @override
  String saveAsFormat(String format) {
    return 'Save as $format';
  }

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System language';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get restore => 'Restore';

  @override
  String get close => 'Close';

  @override
  String get untitled => 'Untitled';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String get selectAll => 'Select all';

  @override
  String get deleteSelection => 'Delete selection';

  @override
  String get crop => 'Crop';

  @override
  String get resize => 'Resize';

  @override
  String get rotateLeft => 'Rotate left';

  @override
  String get rotateRight => 'Rotate right';

  @override
  String get flipHorizontal => 'Flip horizontally';

  @override
  String get flipVertical => 'Flip vertically';

  @override
  String get toolPencil => 'Pencil';

  @override
  String get toolBrush => 'Brush';

  @override
  String get toolEraser => 'Eraser';

  @override
  String get toolFill => 'Fill with color';

  @override
  String get toolPicker => 'Color picker';

  @override
  String get toolLine => 'Line';

  @override
  String get toolRectangle => 'Rectangle';

  @override
  String get toolEllipse => 'Ellipse';

  @override
  String get shapeOutline => 'Outline';

  @override
  String get shapeFilled => 'Filled';

  @override
  String get swapColors => 'Swap colors';

  @override
  String get editColors => 'Edit colors';

  @override
  String get editColorTitle => 'Edit color';

  @override
  String get red => 'Red';

  @override
  String get green => 'Green';

  @override
  String get blue => 'Blue';

  @override
  String get hexColor => 'Hex';

  @override
  String sizePixels(int size) {
    return '$size px';
  }

  @override
  String get brushSize => 'Size';

  @override
  String get newImageTitle => 'New image';

  @override
  String get width => 'Width';

  @override
  String get height => 'Height';

  @override
  String get pixelsUnit => 'px';

  @override
  String get create => 'Create';

  @override
  String get resizeTitle => 'Resize image';

  @override
  String get keepProportions => 'Keep proportions';

  @override
  String get stretchDrawing => 'Stretch the drawing';

  @override
  String get stretchDrawingHint =>
      'Off: only the canvas grows or shrinks, and the drawing stays the same size.';

  @override
  String sizeLimit(int max) {
    return 'Between 1 and $max px.';
  }

  @override
  String get apply => 'Apply';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get saveChangesTitle => 'Save changes?';

  @override
  String saveChangesMessage(String name) {
    return 'Do you want to save the changes to \"$name\"?';
  }

  @override
  String get dontSave => 'Don\'t save';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get openImageTitle => 'Open image';

  @override
  String get saveImageTitle => 'Save image';

  @override
  String get openFailed => 'This file could not be opened as an image.';

  @override
  String get saveFailed => 'The image could not be saved.';

  @override
  String imageTooLarge(int max) {
    return 'This image is too large. The limit is $max px per side.';
  }

  @override
  String get nothingToPaste => 'There is no image to paste.';

  @override
  String get copyFailed => 'The image could not be copied.';

  @override
  String cursorPosition(int x, int y) {
    return '$x, $y px';
  }

  @override
  String imageSize(int width, int height) {
    return '$width × $height px';
  }

  @override
  String selectionSize(int width, int height) {
    return 'Selection: $width × $height px';
  }

  @override
  String get zoom => 'Zoom';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get fitToWindow => 'Fit to window';

  @override
  String get backgroundLayer => 'Background';

  @override
  String layerNumber(int number) {
    return 'Layer $number';
  }

  @override
  String toolWithKey(String name, String key) {
    return '$name ($key)';
  }

  @override
  String get toolMove => 'Move';

  @override
  String get toolMarquee => 'Rectangular selection';

  @override
  String get toolEllipseMarquee => 'Elliptical selection';

  @override
  String get toolLasso => 'Lasso';

  @override
  String get toolCrop => 'Crop';

  @override
  String get toolGradient => 'Gradient';

  @override
  String get toolText => 'Text';

  @override
  String get toolHand => 'Hand';

  @override
  String get toolZoom => 'Zoom';

  @override
  String get foregroundColor => 'Foreground color';

  @override
  String get backgroundColor => 'Background color';

  @override
  String get defaultColors => 'Black and white';

  @override
  String get menuImage => 'Image';

  @override
  String get menuLayer => 'Layer';

  @override
  String get menuSelect => 'Select';

  @override
  String get menuAdjustments => 'Adjustments';

  @override
  String get resizeImage => 'Resize…';

  @override
  String get cropToSelection => 'Crop to selection';

  @override
  String get flattenImage => 'Flatten image';

  @override
  String get newLayer => 'New layer';

  @override
  String get duplicateLayer => 'Duplicate layer';

  @override
  String get deleteLayer => 'Delete layer';

  @override
  String get renameLayer => 'Rename layer…';

  @override
  String get mergeDown => 'Merge down';

  @override
  String get raiseLayer => 'Bring forward';

  @override
  String get lowerLayer => 'Send backward';

  @override
  String get deselect => 'Deselect';

  @override
  String get invertSelection => 'Invert selection';

  @override
  String get fillSelection => 'Fill with foreground color';

  @override
  String get brightnessContrast => 'Brightness and contrast…';

  @override
  String get hueSaturation => 'Hue and saturation…';

  @override
  String get invertColors => 'Invert colors';

  @override
  String get grayscale => 'Grayscale';

  @override
  String get brightness => 'Brightness';

  @override
  String get contrast => 'Contrast';

  @override
  String get hue => 'Hue';

  @override
  String get saturation => 'Saturation';

  @override
  String get layersPanel => 'Layers';

  @override
  String get colorPanel => 'Color';

  @override
  String get swatchHint => 'Click: foreground. Right click: background.';

  @override
  String get opacity => 'Opacity';

  @override
  String get blendMode => 'Blend mode';

  @override
  String get showLayer => 'Show layer';

  @override
  String get hideLayer => 'Hide layer';

  @override
  String get hardness => 'Hardness';

  @override
  String get tolerance => 'Tolerance';

  @override
  String percent(int value) {
    return '$value%';
  }

  @override
  String get hiddenLayerHint => 'The active layer is hidden.';

  @override
  String get cancelCrop => 'Cancel crop';

  @override
  String get applyCrop => 'Apply crop';

  @override
  String get textTitle => 'Text';

  @override
  String get textHint => 'Type the text';

  @override
  String get fontSize => 'Size';

  @override
  String get bold => 'Bold';

  @override
  String get renameLayerTitle => 'Rename layer';

  @override
  String get layerNameLabel => 'Name';

  @override
  String get psdSimplified =>
      'Some things in this PSD (groups, masks, effects or editable text) were simplified. Save keeps the original untouched and asks for a new file.';

  @override
  String get psdOpenedFlat =>
      'This kind of PSD opens as a single layer. Save keeps the original untouched and asks for a new file.';

  @override
  String exportedCopy(String format) {
    return 'A flat $format copy was saved. Save as PSD to keep the layers.';
  }

  @override
  String get blendNormal => 'Normal';

  @override
  String get blendDarken => 'Darken';

  @override
  String get blendMultiply => 'Multiply';

  @override
  String get blendColorBurn => 'Color burn';

  @override
  String get blendLighten => 'Lighten';

  @override
  String get blendScreen => 'Screen';

  @override
  String get blendColorDodge => 'Color dodge';

  @override
  String get blendLinearDodge => 'Linear dodge (add)';

  @override
  String get blendOverlay => 'Overlay';

  @override
  String get blendSoftLight => 'Soft light';

  @override
  String get blendHardLight => 'Hard light';

  @override
  String get blendDifference => 'Difference';

  @override
  String get blendExclusion => 'Exclusion';

  @override
  String get blendHue => 'Hue';

  @override
  String get blendSaturation => 'Saturation';

  @override
  String get blendColor => 'Color';

  @override
  String get blendLuminosity => 'Luminosity';
}
