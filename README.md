# Voges Click

An image editor with layers for the desktop, in the spirit of Photoshop: paint, select, move and blend layers, and open `.psd` files. Part of the Voges suite, next to [Voges Word](https://github.com/omanoloneto/voges-word), [Voges Pencil](https://github.com/omanoloneto/voges-pencil), [Voges Tables](https://github.com/omanoloneto/voges-tables) and [Voges Slides](https://github.com/omanoloneto/voges-slides). Built with Flutter for macOS, Windows and Linux.

## Install

The installers are in the [latest release](https://github.com/omanoloneto/voges-click/releases/latest) and on the [omanoloneto.pro/voges/click](https://omanoloneto.pro/voges/click/) page.

- **macOS** 10.15 or newer, Apple Silicon and Intel: [`VogesClick-macos.dmg`](https://github.com/omanoloneto/voges-click/releases/latest/download/VogesClick-macos.dmg). Open it and drag Voges Click to Applications. The app is not notarized by Apple; the first time, allow it in System Settings → Privacy & Security → Open Anyway.
- **Windows** 10 or 11, 64-bit: [`VogesClick-windows-setup.exe`](https://github.com/omanoloneto/voges-click/releases/latest/download/VogesClick-windows-setup.exe). It installs without administrator rights and shows up in "Open with" for `.psd` and the other images it opens, without becoming the default program. If SmartScreen warns you, click "More info" and then "Run anyway".
- **Linux** (Ubuntu 22.04, Debian 12 or newer and derivatives, 64-bit): [`voges-click-linux-amd64.deb`](https://github.com/omanoloneto/voges-click/releases/latest/download/voges-click-linux-amd64.deb), then `sudo apt install ./voges-click-linux-amd64.deb`.

`SHA256SUMS.txt` in each release lists the SHA-256 of every installer, and `SHA256SUMS.txt.sig` is its signature.

### Updates

Voges Click checks for a new version every time it opens and says in the status bar whether it is up to date. When there is an update, clicking it asks about unsaved changes, closes the app and opens **Voges Updater**, which lists every installed app of the Voges suite that has an update; update all of them or only some. When it finishes, Voges Click opens again.

- The check reads the number of the latest release from github.com; nothing about you or your pictures is sent.
- Every update is verified before it is installed: its files must match the `SHA256SUMS.txt` of the release, and that file must carry the Ed25519 signature of the project's key, which is built into the app. A download that doesn't match is never installed.
- **macOS:** the updater replaces the app in its folder; if your account can't write to it, it puts the verified `.dmg` in Downloads for you to install. Voges Click stays sandboxed: the updater is a separate app inside it (`Contents/Helpers/Voges Updater.app`).
- **Windows:** the installer runs silently; installs for all users ask for administrator permission.
- **Linux:** the update is installed with `apt`, after the system asks for your password (polkit). Without a password window, the updater shows the command to run in a terminal.

## What it does

- **Layout:** the tools on the left, the options of the current tool on top, the color and the layers panels on the right, the picture in the middle.
- **Tabs:** several pictures open at once, each in its tab above the canvas, with its own zoom, place and undo history. What is copied in one picture can be pasted in another, and closing a picture with unsaved changes asks first.
- **Layers:** add, duplicate, rename, delete, hide and reorder layers, merge a layer into the one below and flatten the picture. Each layer has its opacity and one of 17 blend modes (multiply, screen, overlay, soft light, difference, hue, color, luminosity…).
- **Painting:** brush with size, hardness and opacity, pencil, eraser, paint bucket with tolerance, gradient, line, rectangle and ellipse, and text with size and bold. Foreground and background colors, with a color picker tool.
- **Selecting:** rectangle, ellipse and lasso. Painting stays inside the selection; invert it, fill it, copy, cut and paste it as a new layer, or crop the picture to it.
- **Moving:** drag the active layer with the move tool or nudge it with the arrows.
- **Free transform:** a box with handles around the layer, or around what is selected, to move, scale, flip and rotate it before it is painted back.
- **Picture:** crop, resize, rotate and flip.
- **Adjustments:** brightness and contrast, hue and saturation (both with a live preview), invert colors and grayscale, on the active layer.
- **Editing:** undo and redo for every change.
- **Files:** opens `.psd`, PNG, JPEG, BMP, GIF, WebP, TIFF, TGA and ICO, and saves `.psd` (with the layers), PNG, JPEG and BMP. Open takes several files at once, each in its tab. It also opens files from the system's "Open with", without becoming the default app.
- Zoom and hand tools, and the zoom and picture size in the status bar.
- Interface in English, Portuguese and Spanish. It follows the system language, and you can pick another one in the File menu.

### Keyboard shortcuts

The keys are the ones Photoshop uses for the same things. `Ctrl` is `⌘` and `Alt` is `⌥` on macOS.

| Keys | What they do |
| --- | --- |
| `V` `M` `L` `C` `I` `B` `E` `G` `T` `U` `H` `Z` | Pick a tool. Tools that share a key take turns, with or without `Shift` |
| `X`, `D` | Swap the two colors, back to black and white |
| `[`, `]` | Smaller and larger brush |
| `{`, `}` | Softer and harder brush |
| `1`…`9`, `0` | Opacity of the tool from 10% to 100%, or of the layer when the tool has none |
| `Alt` + click | Pick a color while painting |
| `Space` + drag | Move around the picture |
| `Ctrl+N`, `Ctrl+O`, `Ctrl+S`, `Ctrl+Shift+S` | New, open, save, save as |
| `Ctrl+W` | Close the picture |
| `Ctrl+Tab`, `Ctrl+Shift+Tab` | Next picture, previous picture. These two are `Ctrl` on macOS too |
| `Ctrl+Z`, `Ctrl+Alt+Z` | Undo |
| `Ctrl+Shift+Z`, `Ctrl+Y` | Redo |
| `Ctrl+C`, `Ctrl+X`, `Ctrl+V` | Copy, cut, paste |
| `Ctrl+A`, `Ctrl+D`, `Ctrl+Shift+I` | Select all, deselect, invert the selection |
| `Delete` | Erase what is selected |
| `Alt+Delete`, `Shift+F5` | Fill with the foreground color |
| `Ctrl+Delete` | Fill with the background color |
| `Enter`, `Esc` | Apply the crop or the free transform, cancel it |
| `Ctrl+T` | Free transform: drag a handle to scale, outside the box to rotate, inside to move |
| `Shift` + drag, in free transform | Change the proportions from a corner, rotate in steps of 15°, move along one axis |
| `Alt` + drag, in free transform | Scale around the middle |
| `Ctrl+Shift+N` | New layer |
| `Ctrl+J` | New layer with what is selected, or a copy of the layer |
| `Ctrl+E` | Merge the layer into the one below |
| `Ctrl+]`, `Ctrl+[` | Layer up, layer down |
| `Ctrl+Shift+]`, `Ctrl+Shift+[` | Layer to the top, to the bottom |
| `Alt+]`, `Alt+[` | Go to the layer above, below |
| `Ctrl+,` | Show or hide the layer |
| Arrows, `Shift` + arrows | With the move tool or in free transform, move by 1 px, by 10 px |
| `Ctrl+Alt+I` | Resize the picture |
| `Ctrl+U` | Hue and saturation |
| `Ctrl+I`, `Ctrl+Shift+U` | Invert the colors, grayscale |
| `Ctrl++`, `Ctrl+-` | Zoom in, zoom out |
| `Ctrl+0`, `Ctrl+1` | Fit the picture in the window, 100% |

`Delete` is also the Backspace key.

### PSD files

Voges Click reads RGB and grayscale `.psd` files of 8 or 16 bits with their layers (name, position, opacity, blend mode and visibility) and writes 8-bit RGB ones.

- Groups, masks, layer effects, adjustment layers and editable text are not kept: the layers come as plain pixels, the app says so, and saving asks for a new file, so the original stays as it is.
- Other kinds of PSD (32 bits, CMYK, indexed, `.psb`…) open as a single layer with the finished picture, when the file carries one.
- A picture can have up to 8192 px per side. What was measured on one of that size is in [docs/performance.md](docs/performance.md).

## Roadmap

What comes next, in order of priority, is in [docs/roadmap.md](docs/roadmap.md).

## Build

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.41 or newer.

```sh
flutter pub get --enforce-lockfile
flutter run -d macos     # or windows, linux
flutter test
```

Updates come from the `voges_updater` package of [Voges Word](https://github.com/omanoloneto/voges-word/tree/main/packages/voges_updater), a git dependency pinned to a commit in `pubspec.yaml` and `pubspec.lock`; `--enforce-lockfile` gets the locked commit.

## Releases

1. Set the new `version` in `pubspec.yaml` and write `packaging/release-notes.md`.
2. Push a `vX.Y.Z` tag with the same version. `.github/workflows/release.yml` builds the three installers (the macOS one with Voges Updater embedded) and creates a draft release with them and `SHA256SUMS.txt`.
3. Sign and publish the draft on the owner's Mac, from a Voges Word checkout:

   ```sh
   cd packages/voges_updater
   dart run tool/release_signing.dart publish omanoloneto/voges-click vX.Y.Z --clone <path to the voges-click clone>
   ```

Release builds pass `--dart-define=VOGES_VERSION=<version>`; without it, as in `flutter run`, the update indicator stays hidden.
