import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @fileMenu.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileMenu;

  /// No description provided for @newImage.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newImage;

  /// No description provided for @openImage.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openImage;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get saveAs;

  /// No description provided for @saveAsFormat.
  ///
  /// In en, this message translates to:
  /// **'Save as {format}'**
  String saveAsFormat(String format);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get systemLanguage;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @maximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @deleteSelection.
  ///
  /// In en, this message translates to:
  /// **'Delete selection'**
  String get deleteSelection;

  /// No description provided for @crop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// No description provided for @resize.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get resize;

  /// No description provided for @rotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get rotateLeft;

  /// No description provided for @rotateRight.
  ///
  /// In en, this message translates to:
  /// **'Rotate right'**
  String get rotateRight;

  /// No description provided for @flipHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Flip horizontally'**
  String get flipHorizontal;

  /// No description provided for @flipVertical.
  ///
  /// In en, this message translates to:
  /// **'Flip vertically'**
  String get flipVertical;

  /// No description provided for @toolPencil.
  ///
  /// In en, this message translates to:
  /// **'Pencil'**
  String get toolPencil;

  /// No description provided for @toolBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get toolBrush;

  /// No description provided for @toolEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get toolEraser;

  /// No description provided for @toolFill.
  ///
  /// In en, this message translates to:
  /// **'Fill with color'**
  String get toolFill;

  /// No description provided for @toolPicker.
  ///
  /// In en, this message translates to:
  /// **'Color picker'**
  String get toolPicker;

  /// No description provided for @toolLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get toolLine;

  /// No description provided for @toolRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get toolRectangle;

  /// No description provided for @toolEllipse.
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get toolEllipse;

  /// No description provided for @shapeOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get shapeOutline;

  /// No description provided for @shapeFilled.
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get shapeFilled;

  /// No description provided for @swapColors.
  ///
  /// In en, this message translates to:
  /// **'Swap colors'**
  String get swapColors;

  /// No description provided for @editColors.
  ///
  /// In en, this message translates to:
  /// **'Edit colors'**
  String get editColors;

  /// No description provided for @editColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit color'**
  String get editColorTitle;

  /// No description provided for @red.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get red;

  /// No description provided for @green.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get green;

  /// No description provided for @blue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get blue;

  /// No description provided for @hexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get hexColor;

  /// No description provided for @sizePixels.
  ///
  /// In en, this message translates to:
  /// **'{size} px'**
  String sizePixels(int size);

  /// No description provided for @brushSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get brushSize;

  /// No description provided for @newImageTitle.
  ///
  /// In en, this message translates to:
  /// **'New image'**
  String get newImageTitle;

  /// No description provided for @width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @pixelsUnit.
  ///
  /// In en, this message translates to:
  /// **'px'**
  String get pixelsUnit;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @resizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Resize image'**
  String get resizeTitle;

  /// No description provided for @keepProportions.
  ///
  /// In en, this message translates to:
  /// **'Keep proportions'**
  String get keepProportions;

  /// No description provided for @stretchDrawing.
  ///
  /// In en, this message translates to:
  /// **'Stretch the drawing'**
  String get stretchDrawing;

  /// No description provided for @stretchDrawingHint.
  ///
  /// In en, this message translates to:
  /// **'Off: only the canvas grows or shrinks, and the drawing stays the same size.'**
  String get stretchDrawingHint;

  /// No description provided for @sizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Between 1 and {max} px.'**
  String sizeLimit(int max);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @saveChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save changes?'**
  String get saveChangesTitle;

  /// No description provided for @saveChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save the changes to \"{name}\"?'**
  String saveChangesMessage(String name);

  /// No description provided for @dontSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get dontSave;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @openImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Open image'**
  String get openImageTitle;

  /// No description provided for @saveImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get saveImageTitle;

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'This file could not be opened as an image.'**
  String get openFailed;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'The image could not be saved.'**
  String get saveFailed;

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This image is too large. The limit is {max} px per side.'**
  String imageTooLarge(int max);

  /// No description provided for @nothingToPaste.
  ///
  /// In en, this message translates to:
  /// **'There is no image to paste.'**
  String get nothingToPaste;

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'The image could not be copied.'**
  String get copyFailed;

  /// No description provided for @cursorPosition.
  ///
  /// In en, this message translates to:
  /// **'{x}, {y} px'**
  String cursorPosition(int x, int y);

  /// No description provided for @imageSize.
  ///
  /// In en, this message translates to:
  /// **'{width} × {height} px'**
  String imageSize(int width, int height);

  /// No description provided for @selectionSize.
  ///
  /// In en, this message translates to:
  /// **'Selection: {width} × {height} px'**
  String selectionSize(int width, int height);

  /// No description provided for @zoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get zoom;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @fitToWindow.
  ///
  /// In en, this message translates to:
  /// **'Fit to window'**
  String get fitToWindow;

  /// No description provided for @backgroundLayer.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get backgroundLayer;

  /// No description provided for @layerNumber.
  ///
  /// In en, this message translates to:
  /// **'Layer {number}'**
  String layerNumber(int number);

  /// No description provided for @toolWithKey.
  ///
  /// In en, this message translates to:
  /// **'{name} ({key})'**
  String toolWithKey(String name, String key);

  /// No description provided for @toolMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get toolMove;

  /// No description provided for @toolMarquee.
  ///
  /// In en, this message translates to:
  /// **'Rectangular selection'**
  String get toolMarquee;

  /// No description provided for @toolEllipseMarquee.
  ///
  /// In en, this message translates to:
  /// **'Elliptical selection'**
  String get toolEllipseMarquee;

  /// No description provided for @toolLasso.
  ///
  /// In en, this message translates to:
  /// **'Lasso'**
  String get toolLasso;

  /// No description provided for @toolCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get toolCrop;

  /// No description provided for @toolGradient.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get toolGradient;

  /// No description provided for @toolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get toolText;

  /// No description provided for @toolHand.
  ///
  /// In en, this message translates to:
  /// **'Hand'**
  String get toolHand;

  /// No description provided for @toolZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get toolZoom;

  /// No description provided for @foregroundColor.
  ///
  /// In en, this message translates to:
  /// **'Foreground color'**
  String get foregroundColor;

  /// No description provided for @backgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get backgroundColor;

  /// No description provided for @defaultColors.
  ///
  /// In en, this message translates to:
  /// **'Black and white'**
  String get defaultColors;

  /// No description provided for @menuImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get menuImage;

  /// No description provided for @menuLayer.
  ///
  /// In en, this message translates to:
  /// **'Layer'**
  String get menuLayer;

  /// No description provided for @menuSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get menuSelect;

  /// No description provided for @menuAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get menuAdjustments;

  /// No description provided for @resizeImage.
  ///
  /// In en, this message translates to:
  /// **'Resize…'**
  String get resizeImage;

  /// No description provided for @cropToSelection.
  ///
  /// In en, this message translates to:
  /// **'Crop to selection'**
  String get cropToSelection;

  /// No description provided for @flattenImage.
  ///
  /// In en, this message translates to:
  /// **'Flatten image'**
  String get flattenImage;

  /// No description provided for @newLayer.
  ///
  /// In en, this message translates to:
  /// **'New layer'**
  String get newLayer;

  /// No description provided for @duplicateLayer.
  ///
  /// In en, this message translates to:
  /// **'Duplicate layer'**
  String get duplicateLayer;

  /// No description provided for @deleteLayer.
  ///
  /// In en, this message translates to:
  /// **'Delete layer'**
  String get deleteLayer;

  /// No description provided for @renameLayer.
  ///
  /// In en, this message translates to:
  /// **'Rename layer…'**
  String get renameLayer;

  /// No description provided for @freeTransform.
  ///
  /// In en, this message translates to:
  /// **'Free transform'**
  String get freeTransform;

  /// No description provided for @mergeDown.
  ///
  /// In en, this message translates to:
  /// **'Merge down'**
  String get mergeDown;

  /// No description provided for @raiseLayer.
  ///
  /// In en, this message translates to:
  /// **'Bring forward'**
  String get raiseLayer;

  /// No description provided for @lowerLayer.
  ///
  /// In en, this message translates to:
  /// **'Send backward'**
  String get lowerLayer;

  /// No description provided for @deselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get deselect;

  /// No description provided for @invertSelection.
  ///
  /// In en, this message translates to:
  /// **'Invert selection'**
  String get invertSelection;

  /// No description provided for @fillSelection.
  ///
  /// In en, this message translates to:
  /// **'Fill with foreground color'**
  String get fillSelection;

  /// No description provided for @brightnessContrast.
  ///
  /// In en, this message translates to:
  /// **'Brightness and contrast…'**
  String get brightnessContrast;

  /// No description provided for @hueSaturation.
  ///
  /// In en, this message translates to:
  /// **'Hue and saturation…'**
  String get hueSaturation;

  /// No description provided for @invertColors.
  ///
  /// In en, this message translates to:
  /// **'Invert colors'**
  String get invertColors;

  /// No description provided for @grayscale.
  ///
  /// In en, this message translates to:
  /// **'Grayscale'**
  String get grayscale;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @contrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrast;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @layersPanel.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get layersPanel;

  /// No description provided for @colorPanel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorPanel;

  /// No description provided for @swatchHint.
  ///
  /// In en, this message translates to:
  /// **'Click: foreground. Right click: background.'**
  String get swatchHint;

  /// No description provided for @opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get opacity;

  /// No description provided for @blendMode.
  ///
  /// In en, this message translates to:
  /// **'Blend mode'**
  String get blendMode;

  /// No description provided for @showLayer.
  ///
  /// In en, this message translates to:
  /// **'Show layer'**
  String get showLayer;

  /// No description provided for @hideLayer.
  ///
  /// In en, this message translates to:
  /// **'Hide layer'**
  String get hideLayer;

  /// No description provided for @hardness.
  ///
  /// In en, this message translates to:
  /// **'Hardness'**
  String get hardness;

  /// No description provided for @tolerance.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get tolerance;

  /// No description provided for @percent.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percent(int value);

  /// No description provided for @hiddenLayerHint.
  ///
  /// In en, this message translates to:
  /// **'The active layer is hidden.'**
  String get hiddenLayerHint;

  /// No description provided for @cancelCrop.
  ///
  /// In en, this message translates to:
  /// **'Cancel crop'**
  String get cancelCrop;

  /// No description provided for @applyCrop.
  ///
  /// In en, this message translates to:
  /// **'Apply crop'**
  String get applyCrop;

  /// No description provided for @textTitle.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textTitle;

  /// No description provided for @textHint.
  ///
  /// In en, this message translates to:
  /// **'Type the text'**
  String get textHint;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fontSize;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @renameLayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename layer'**
  String get renameLayerTitle;

  /// No description provided for @layerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get layerNameLabel;

  /// No description provided for @psdSimplified.
  ///
  /// In en, this message translates to:
  /// **'Some things in this PSD (groups, masks, effects or editable text) were simplified. Save keeps the original untouched and asks for a new file.'**
  String get psdSimplified;

  /// No description provided for @psdOpenedFlat.
  ///
  /// In en, this message translates to:
  /// **'This kind of PSD opens as a single layer. Save keeps the original untouched and asks for a new file.'**
  String get psdOpenedFlat;

  /// No description provided for @exportedCopy.
  ///
  /// In en, this message translates to:
  /// **'A flat {format} copy was saved. Save as PSD to keep the layers.'**
  String exportedCopy(String format);

  /// No description provided for @blendNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get blendNormal;

  /// No description provided for @blendDarken.
  ///
  /// In en, this message translates to:
  /// **'Darken'**
  String get blendDarken;

  /// No description provided for @blendMultiply.
  ///
  /// In en, this message translates to:
  /// **'Multiply'**
  String get blendMultiply;

  /// No description provided for @blendColorBurn.
  ///
  /// In en, this message translates to:
  /// **'Color burn'**
  String get blendColorBurn;

  /// No description provided for @blendLighten.
  ///
  /// In en, this message translates to:
  /// **'Lighten'**
  String get blendLighten;

  /// No description provided for @blendScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get blendScreen;

  /// No description provided for @blendColorDodge.
  ///
  /// In en, this message translates to:
  /// **'Color dodge'**
  String get blendColorDodge;

  /// No description provided for @blendLinearDodge.
  ///
  /// In en, this message translates to:
  /// **'Linear dodge (add)'**
  String get blendLinearDodge;

  /// No description provided for @blendOverlay.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get blendOverlay;

  /// No description provided for @blendSoftLight.
  ///
  /// In en, this message translates to:
  /// **'Soft light'**
  String get blendSoftLight;

  /// No description provided for @blendHardLight.
  ///
  /// In en, this message translates to:
  /// **'Hard light'**
  String get blendHardLight;

  /// No description provided for @blendDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get blendDifference;

  /// No description provided for @blendExclusion.
  ///
  /// In en, this message translates to:
  /// **'Exclusion'**
  String get blendExclusion;

  /// No description provided for @blendHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get blendHue;

  /// No description provided for @blendSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get blendSaturation;

  /// No description provided for @blendColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get blendColor;

  /// No description provided for @blendLuminosity.
  ///
  /// In en, this message translates to:
  /// **'Luminosity'**
  String get blendLuminosity;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
