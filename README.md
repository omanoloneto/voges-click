# Voges Click

An image editor with layers for the desktop, in the spirit of Photoshop: paint, select, move and blend layers, and open `.psd` files. Part of the Voges suite, next to [Voges Word](https://github.com/omanoloneto/voges-word), [Voges Pencil](https://github.com/omanoloneto/voges-pencil), [Voges Tables](https://github.com/omanoloneto/voges-tables) and [Voges Slides](https://github.com/omanoloneto/voges-slides). Built with Flutter for macOS, Windows and Linux.

Voges Click is at its first version and has no release yet: for now it runs from the source (see [Build](#build)).

## What it does

- **Layout:** the tools on the left, the options of the current tool on top, the color and the layers panels on the right, the picture in the middle.
- **Layers:** add, duplicate, rename, delete, hide and reorder layers, merge a layer into the one below and flatten the picture. Each layer has its opacity and one of 17 blend modes (multiply, screen, overlay, soft light, difference, hue, color, luminosity…).
- **Painting:** brush with size, hardness and opacity, pencil, eraser, paint bucket with tolerance, gradient, line, rectangle and ellipse, and text with size and bold. Foreground and background colors, with a color picker tool.
- **Selecting:** rectangle, ellipse and lasso. Painting stays inside the selection; invert it, fill it, copy, cut and paste it as a new layer, or crop the picture to it.
- **Moving:** drag the active layer with the move tool or nudge it with the arrows.
- **Picture:** crop, resize, rotate and flip.
- **Adjustments:** brightness and contrast, hue and saturation (both with a live preview), invert colors and grayscale, on the active layer.
- **Editing:** undo and redo for every change.
- **Files:** opens `.psd`, PNG, JPEG, BMP, GIF, WebP, TIFF, TGA and ICO, and saves `.psd` (with the layers), PNG, JPEG and BMP. It also opens files from the system's "Open with", without becoming the default app.
- Zoom and hand tools, and the zoom and picture size in the status bar.
- Interface in English, Portuguese and Spanish. It follows the system language, and you can pick another one in the File menu.

### PSD files

Voges Click reads RGB and grayscale `.psd` files of 8 or 16 bits with their layers (name, position, opacity, blend mode and visibility) and writes 8-bit RGB ones.

- Groups, masks, layer effects, adjustment layers and editable text are not kept: the layers come as plain pixels, the app says so, and saving asks for a new file, so the original stays as it is.
- Other kinds of PSD (32 bits, CMYK, indexed, `.psb`…) open as a single layer with the finished picture, when the file carries one.
- A picture can have up to 8192 px per side.

## Build

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.41 or newer.

```sh
flutter pub get --enforce-lockfile
flutter run -d macos     # or windows, linux
flutter test
```
