Voges Click: an image editor with layers for macOS, Windows and Linux, in the spirit of Photoshop. Part of the Voges suite, next to Voges Word, Voges Pencil, Voges Tables and Voges Slides.

## What's in Voges Click 1.0.0

- **Layout:** the tools on the left, the options of the current tool on top, the color and the layers panels on the right, the picture in the middle.
- **Layers:** add, duplicate, rename, delete, hide and reorder layers, merge a layer into the one below and flatten the picture. Each layer has its opacity and one of 17 blend modes.
- **Painting:** brush with size, hardness and opacity, pencil, eraser, paint bucket with tolerance, gradient, line, rectangle and ellipse, and text with size and bold. Foreground and background colors, with a color picker tool.
- **Selecting:** rectangle, ellipse and lasso. Painting stays inside the selection; invert it, fill it, copy, cut and paste it as a new layer, or crop the picture to it.
- **Picture:** move layers, crop, resize, rotate and flip.
- **Adjustments:** brightness and contrast, hue and saturation (both with a live preview), invert colors and grayscale, on the active layer.
- **Files:** opens `.psd`, PNG, JPEG, BMP, GIF, WebP, TIFF, TGA and ICO, and saves `.psd` with the layers, PNG, JPEG and BMP. From a `.psd` come the layers of 8 and 16-bit RGB and grayscale files, with name, position, opacity, blend mode and visibility. Groups, masks, layer effects, adjustment layers and editable text are not supported yet: the layers come as plain pixels, the app says so and saves to a new file, so the original stays as it is.
- Undo and redo for every change, and a warning before closing with unsaved changes.
- Updates itself through Voges Updater, which verifies every download against the signed `SHA256SUMS.txt` of the release.
- Interface in English, Portuguese and Spanish.

## Install

Page with the downloads and step-by-step instructions: https://omanoloneto.pro/voges/click/

- **macOS** (10.15 or newer, Apple Silicon and Intel): open `VogesClick-macos.dmg` and drag Voges Click to Applications. The first time, macOS blocks the app because it is not notarized by Apple: go to System Settings → Privacy & Security → Open Anyway.
- **Windows** (10 or 11, 64-bit): run `VogesClick-windows-setup.exe`; it does not need administrator rights. If SmartScreen warns you, click "More info" and then "Run anyway".
- **Linux** (Ubuntu 22.04, Debian 12 or newer and derivatives, 64-bit): `sudo apt install ./voges-click-linux-amd64.deb`

`SHA256SUMS.txt` lists the SHA-256 of each file, so you can verify the download, and `SHA256SUMS.txt.sig` is its signature.
