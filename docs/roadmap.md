# Roadmap

Voges Click wants to do what people open Photoshop for, in the order they miss it. This page lists Photoshop's features, says which ones version 1.0 already has, and puts the rest in order of priority.

Three rules decide the order:

1. **Speed comes first.** A feature that makes painting, zooming or opening a file slower waits until it can be done without that cost.
2. **What is used every day comes before what is used once a month.** Transforming a layer comes before Liquify.
3. **Files must survive the trip.** Whatever the app learns to do, it should read from and write to `.psd` so the file still opens in Photoshop with that feature intact.

Each phase is a set of releases, not a single one. Inside a phase, the items are in order of priority too.

## What 1.0 has

| Area | In 1.0 |
| --- | --- |
| Layers | Add, duplicate, rename, delete, hide, reorder, merge down, flatten, opacity, 17 blend modes |
| Selection | Rectangular and elliptical marquee, lasso, invert, fill, copy, cut, paste as a new layer |
| Painting | Brush (size, hardness, opacity), pencil, eraser, paint bucket, gradient, color picker |
| Shapes and text | Line, rectangle, ellipse, text with size and bold, all turned into pixels |
| Picture | Crop to the selection, resize, rotate, flip |
| Adjustments | Brightness/contrast, hue/saturation, invert, grayscale, applied to the layer's pixels |
| History | Undo and redo |
| Files | Opens PSD, PNG, JPEG, BMP, GIF, WebP, TIFF, TGA, ICO; saves PSD, PNG, JPEG, BMP |
| View | Zoom, hand |

## Phase 0: solid ground

Nothing new to show, but everything after this depends on it.

1. **Large pictures stay fast.** Measure painting, zooming, panning, undo and saving on an 8192 px picture with dozens of layers, and fix what lags: draw only the part of the picture that changed, keep undo steps as the changed region instead of whole layers, and give the undo history a memory budget.
2. **PSD checked against the real thing.** Open files saved by Photoshop, GIMP, Photopea, Krita and Affinity, and open ours in each of them. Fix what differs.
3. ~~**Known flaws of 1.0.** A brush click outside the picture creates an empty undo step; Enter in the text dialog adds a line instead of confirming; the adjustment dialogs on small windows.~~ Fixed after 1.1.
4. **Installers and updater checked on real Windows and Linux machines.**
5. ~~**Several pictures open at once**, in tabs, with copy and paste between them.~~ Done after 1.1.
6. ~~**Photoshop's keyboard shortcuts** for everything that already exists.~~ Done after 1.0; the README lists the keys.

## Phase 1: the everyday tools

What almost every editing session needs and 1.0 lacks.

1. **Free transform** (`Ctrl+T`): ~~scale and rotate with handles, on a layer or a selection~~ (done); still missing: skew, distort, perspective and numeric fields.
2. **Crop tool with handles**, aspect ratios, straighten, and the choice to keep the cropped pixels.
3. **Magic wand** with tolerance, contiguous and sample-all-layers.
4. **Selection arithmetic**: add, subtract and intersect with Shift/Alt, select all, deselect, reselect.
5. **Selection edges**: feather, anti-alias, grow, shrink, border, smooth.
6. **Layers panel**: drag to reorder, select several layers, thumbnails, lock (pixels, position, transparency), merge visible, merge selected.
7. **Layer groups** (folders), with their own opacity and blend mode, read from and written to PSD.
8. **Polygonal lasso.**
9. **Brush engine**: flow, spacing, smoothing, and pen pressure for size and opacity on tablets.
10. **Clone stamp.**
11. **Fill and stroke** of a selection (Edit → Fill, Edit → Stroke), and the paint bucket with patterns.
12. **Canvas size** (grow or cut the picture without scaling it) and **trim**.
13. **Rulers, guides, grid and snapping**, with smart guides when moving a layer.
14. **History panel**: the list of steps, clicking one to go back to it.
15. **Move tool**: auto-select the layer under the click, align and distribute.
16. **Text**: font family, italic, color, alignment, line spacing, and typing on the picture instead of in a dialog.
17. **Gradient editor**: several color stops, radial, angle, reflected and diamond gradients, saved gradients.
18. **Swatches** and recent colors; HSB, RGB and hex fields in the color panel.
19. **Navigator and info panels**; fit on screen, 100 %, zoom to the selection.
20. **Export as** WebP and GIF, with quality and size preview, and export of a single layer.

## Phase 2: editing without destroying

The features that make Photoshop files what they are. Each one arrives together with its PSD reading and writing.

1. **Layer masks**: paint on them, turn a selection into one, disable, apply, unlink from the layer.
2. **Clipping masks.**
3. **Adjustment layers**, in this order: levels, curves, hue/saturation, brightness/contrast, color balance, black and white, vibrance, exposure, photo filter, invert, threshold, posterize, gradient map, selective color, channel mixer.
4. **The same adjustments as direct commands** (Image → Adjustments), plus auto tone, auto contrast and auto color.
5. **Histogram panel.**
6. **Editable text layers**: the text stays text, in the app and in the PSD.
7. **Layer styles**: drop shadow, stroke, outer glow, inner shadow, inner glow, color overlay, gradient overlay, bevel and emboss, pattern overlay, satin. Copy and paste a style between layers.
8. **Fill layers**: solid color, gradient, pattern.
9. **Fill opacity** and the advanced blending options (blend if).
10. **Quick mask mode.**

## Phase 3: retouching and filters

1. **Blur filters**: Gaussian, box, motion, radial, lens, surface.
2. **Sharpen filters**: unsharp mask, smart sharpen, high pass.
3. **Noise**: add noise, reduce noise, median, dust and scratches.
4. **Spot healing brush and healing brush.**
5. **Dodge, burn and sponge tools.**
6. **Blur, sharpen and smudge tools.**
7. **Patch tool and red eye tool.**
8. **Content-aware fill** of a selection.
9. **Liquify.**
10. **Distort filters**: wave, ripple, twirl, pinch, spherize, polar coordinates, displace.
11. **Pixelate and stylize**: mosaic, crystallize, halftone, find edges, emboss, oil paint.
12. **Render**: clouds, lens flare, lighting effects.
13. **Filter gallery** with preview, and "repeat the last filter".
14. **Background eraser and magic eraser.**
15. **History brush.**

## Phase 4: precise selections and vectors

1. **Quick selection tool.**
2. **Select and mask** (refine edge): hair and soft edges, with the result as a mask.
3. **Color range** and **focus area**.
4. **Magnetic lasso.**
5. **Pen tool** and the **paths panel**: draw, edit points, turn a path into a selection, stroke a path.
6. **Shape layers**: rectangle, rounded rectangle, ellipse, polygon, line and custom shapes that stay vectors, with fill and stroke.
7. **Vector masks.**
8. **Text on a path** and text in a box; character and paragraph panels (tracking, kerning, baseline, justification).
9. **Warp**, **puppet warp** and **perspective warp**.
10. **Content-aware scale.**
11. **Select subject** and **object selection**, if they can run on the machine without a service.

## Phase 5: professional work

1. **Smart objects**: a layer that keeps its original and transforms without losing quality; linked and embedded.
2. **Smart filters**: filters that stay editable on a smart object.
3. **Channels panel**: see and edit each channel, alpha channels, save and load a selection.
4. **16 and 32 bits per channel** while editing, not only when opening.
5. **Color management**: ICC profiles, assign and convert, proof colors.
6. **CMYK, Lab, indexed and grayscale modes**, and spot channels.
7. **Raw photos**: open camera files with a developing step (exposure, white balance, highlights, shadows, lens correction).
8. **Actions**: record steps and play them again; **batch** over a folder.
9. **Brush presets**: a brushes panel, importing `.abr`, shape dynamics, scattering, texture, dual brush.
10. **Patterns, styles and shapes libraries**, importing `.pat`, `.asl` and `.csh`.
11. **Artboards** and **layer comps**.
12. **Slices and export for the web**; export layers and artboards to files.
13. **More formats**: large documents (`.psb`), TIFF with layers, PDF, SVG, HEIC, AVIF, OpenEXR.
14. **Photomerge, HDR merge and panorama.**
15. **Workspaces**: move, dock and save the panels' layout.
16. **Print** with size and position preview.
17. **Animated GIF** with a frames timeline.

## Not planned

These exist in Photoshop and are out, for now and maybe for good:

- **3D.** Photoshop itself retired it.
- **Video timeline and video layers.** Voges Action is the place for video.
- **Generative fill, neural filters and anything that needs an online service.** Voges Click works offline and sends nothing anywhere.
- **Cloud documents, libraries and sharing for review.**
- **Third-party plug-ins** (`.8bf`, UXP).
- **Scripting.** Actions cover the need until someone asks for more.

## How this page changes

When a feature ships, it leaves its phase and goes into "What 1.0 has" (which then takes the name of the current version). A feature can jump the line when people ask for it; the three rules at the top still decide ties.
