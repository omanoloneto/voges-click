# Performance on large pictures

How Voges Click copes with a picture of 8192 × 8192 with 24 layers: what was measured, what was changed and what the same measurements give now. This is item 1 of Phase 0 of the [roadmap](roadmap.md).

In short: painting, undoing, moving a layer, previewing an adjustment, zooming and panning now run at the pace of the display on that picture, where each frame used to take 50 to 80 ms. The memory in use while painting went from as much as 5 GB to about 1.5 GB, and twelve strokes on the background can all be undone where only the last two could. Saving takes as long as it did, and applying an adjustment to a whole layer got slower. Both are under [Known limits](#known-limits).

## The benchmark

`benchmark/large_picture.dart` opens the real window with the whole interface, builds the picture and drives the editor the way a hand would: one pointer move per frame, then the button let go. Each step prints how long it took, how its frames went and how much memory the process held.

The picture has an opaque background of the full size, three layers of 4096 px and twenty of 512 to 2047 px scattered over it. Every fifth layer is at 60% opacity and every eighth blends with Multiply.

```sh
flutter build macos --profile -t benchmark/large_picture.dart
BENCH=fit "build/macos/Build/Products/Profile/Voges Click.app/Contents/MacOS/Voges Click"
```

`BENCH` takes the groups of steps to run, separated by commas. With none, all of them run.

| Group | Steps |
| --- | --- |
| `fit` | With the whole picture on the screen: four strokes, undo and redo, the opacity slider, moving a layer, an adjustment and a free transform |
| `actual` | The same at 100% zoom |
| `bucket` | The paint bucket on the background, and its undo |
| `view` | Zooming and panning |
| `save` | Saving as PNG, JPEG and PSD |
| `history` | Twelve strokes on the background, then how many of them can still be undone |

Two more words can go in the same list: `quiet` leaves the window where the system put it and does not take the keyboard, so the machine can be used while it runs, and `plain` leaves the blend modes out. The quiet runs on this page were started behind the other windows:

```sh
open -g -n "build/macos/Build/Products/Profile/Voges Click.app" --env BENCH=quiet,fit --stdout out.txt --stderr out.txt
```

A line of the output:

```
fit brush 40 px soft, small layer: stroke         1016 ms |  61 frames    16.5 each | build     2.0     2.9     3.1 | raster     4.1     5.7     6.5 | rss 247 MB, peak 250 | 1794327232201
```

It gives the time the step took, the number of frames and the time from one frame to the next, then how long the frames took to build and to draw (raster): average, 90th percentile and slowest. The last number is the clock when the step ended. `rss` leaves out the memory of the graphics card, which is where the pixels are, so the memory figures on this page are the `phys_footprint` that the `footprint` tool of macOS reports, read about every 0.4 s by a shell loop while the benchmark ran and matched to the steps by that clock.

## What it ran on

MacBook Pro 14-inch 2021, Apple M1 Pro, 16 GB, macOS 26.5.1. Flutter 3.41.6, profile build, Skia on Metal. A window of 1280 × 860 at 1x on a 60 Hz display, where 16.7 ms from one frame to the next is as fast as it goes.

"Before" is the editor as it stood before this work: version 1.1 plus the fixes and the tabs made after it, which did not change how pixels are kept or drawn. Its numbers come from the same script with the layers built as the single images that version kept them in.

## Results

### Painting and editing

Time from one frame to the next in ms, with the slowest frame's raster time in parentheses. A value a little under 16.7 means the last frame of the step was counted only until it was drawn.

| Step | Before, whole picture | Now, whole picture | Now, at 100% |
| --- | --- | --- | --- |
| Brush, 40 px soft, on a small layer | 53.5 (197.0) | 16.5 (6.5) | 16.5 (11.5) |
| Brush, 400 px soft, on a 4096 px layer | 56.3 (128.7) | 16.5 (8.2) | 16.5 (6.0) |
| Pencil, 12 px, on the background | 73.2 (213.4) | 16.5 (11.2) | 16.5 (8.6) |
| Eraser, 80 px hard, on the background | 61.0 (106.9) | 16.5 (8.8) | 16.5 (8.3) |
| Undo, four times | 60.7 (63.4) | 14.9 (8.6) | 15.1 (5.7) |
| Redo, four times | 72.3 (120.6) | 15.0 (4.3) | 14.8 (2.0) |
| Layer opacity slider | 58.6 (62.6) | 16.4 (7.3) | 16.4 (3.4) |
| Moving a 4096 px layer | 59.8 (70.6) | 16.4 (8.5) | 16.4 (22.8) |
| Adjustment preview on the background | 79.6 (232.3) | 16.4 (12.5) | 16.4 (7.2) |
| Free transform, nudging a 4096 px layer | not measured | 16.3 (10.4) | 16.2 (8.0) |

What the step took when it is a single action, in ms:

| Step | Before, whole picture | Now, whole picture | Now, at 100% |
| --- | --- | --- | --- |
| Letting go of the 40 px brush | 525 | 54 | 53 |
| Letting go of the 400 px brush | 93 | 53 | 40 |
| Letting go of the pencil | 90 | 37 | 37 |
| Letting go of the eraser | 107 | 40 | 38 |
| Dropping the moved layer | 74 | 36 | 36 |
| Applying the adjustment to the background | 90 | 289 | 53 |
| Starting the free transform | not measured | 103 | 106 |
| Applying the free transform | not measured | 38 | 47 |

Applying an adjustment to the whole background got slower with the whole picture on the screen. All 64 tiles of the layer are made again and the frame that first shows them takes 140 ms to draw. At 100% only the tiles on the screen are made in that frame and the others follow in the background.

### Zooming and panning

Same units as the first table.

| Step | Before | Now |
| --- | --- | --- |
| Zoom from the whole picture to 100% in 12 steps | 41.4 (184.3) | 17.8 (48.2) |
| Pan at 100%, 60 frames | 17.7 (65.4) | 16.5 (9.1) |
| Zoom from 100% to 800% in 12 steps | 17.0 (30.2) | 15.5 (17.5) |
| Zoom from 800% back to the whole picture in 24 steps | 30.9 (105.8) | 16.3 (12.3) |

### Undo history

Twelve strokes on the background, one after the other.

| | Before | Now |
| --- | --- | --- |
| From one frame to the next | 48.5 ms (138.3) | 16.6 ms (9.0) |
| Footprint after the twelve | 4469 MB | 1310 MB |
| Strokes that can still be undone | 2 | 12 |

The history already had a budget of 1 GB, but it counted every image its steps held, the layers nobody had touched included, and each stroke kept a whole copy of the layer it was on: 256 MB for this background. The benchmark then puts a dot on each of eight small layers: before, the footprint passed 7.8 GB there and the run was stopped; now it ends at 1452 MB.

### The paint bucket

| | Before | Now |
| --- | --- | --- |
| Filling an area of the background | 1856 ms | 1055 ms |
| Footprint, before and after it | 1593 and 4010 MB | 1045 and 2392 MB |
| Undoing it | 27 ms | 22 ms |

### Saving

| Format | Before | Now |
| --- | --- | --- |
| PNG, 8.1 MB | 3823 ms | 3475 ms |
| JPEG, 3.1 MB | 4107 ms | 3953 ms |
| PSD, 89.1 MB | 4579 ms | 4088 ms |

Saving was not worked on. The footprint is at 3.3 GB after the three (3.8 GB before).

### Memory

Footprint through the steps of the first two tables, with the whole picture on the screen.

| Moment | Before | Now |
| --- | --- | --- |
| Picture open | 1598 MB | 1195 MB |
| Through the four strokes | 1482 to 5365 MB | 1147 to 1498 MB |
| After the adjustment is applied | 5060 MB | 2131 MB |
| Highest | 6253 MB | 2278 MB |

The highest value now is reached while the picture is being built, before its tiles settle. The run of "before" went on to the paint bucket with what it had gathered and was stopped there at 8.1 GB.

### What the numbers leave out

- Before this work, the 100% pass and the free transform were not measured, to spare the machine: each run of the old code took 4 to 8 GB on a computer in use.
- The "before" numbers of the first two tables and of the memory table come from a run with the window in front. All the others, before and now, come from runs with the window left behind (`quiet`), a group or two per run.
- The old code was measured with every layer in the state an edit left it in. A layer that came from a file and had never been changed was quicker to show than these numbers say, and that case was not measured.
- The first frames of a run vary too much with the setup of the window to be a result, and are left out.

## What changed

- The pixels of a layer are kept as tiles of 1024 px instead of one image. Undo steps and duplicated layers share the tiles they have in common, so an undo step costs only the tiles its edit changed.
- An edit makes again only the tiles it touches, and a long stroke only the ones it passes through, not the whole box around it.
- A new tile is drawn by the graphics card and then, in the background, traded for a plain texture with smaller copies of itself. That is what makes a picture seen from afar cheap to draw, and it lets go of the tiles the new one was drawn from. The smaller copies cost a third more memory per tile.
- Painting skips the tiles outside the part of the picture that is on the screen.
- The budget of the undo history, 1 GB per picture as before, counts only what the history alone keeps in memory.
- Free transform works on the tiles of the layer instead of one image cut from it.
- The paint bucket hands back only the box around what it filled instead of a copy of the layer.

## Known limits

- Saving reads each layer whole: about 4 s for this picture, as before. The footprint stays near 3.3 GB afterwards until the buffers that were read are collected.
- The paint bucket still reads the whole layer to find what to fill: about 1 s on the 8192 px background, and 2.4 GB of footprint afterwards until collected.
- An edit that covers a whole layer, such as an adjustment with nothing selected, makes every tile again through one image of the full size (256 MB at 8192 px): one long frame, as in the table above.
- Resizing the picture with its content, rotating it and flipping it go through one whole image per layer.
- The line, shape and gradient tools make again every tile in the box around what they drew.
- After an edit, memory of the graphics card of about the size of what was painted (256 MB at most at 8192 px) stays held until the next edit. It does not pile up.
- A picture that has just been opened holds its layers twice for a moment, as they came and as tiles, until the tiles settle: 2.3 GB at the start of the benchmark, then 1.2 GB.
- Zooming from the whole picture to 100% raises the footprint by about 0.9 GB for a few seconds. The old code did the same.
- The history budget is per picture. Several large pictures open in tabs can each keep 1 GB of history.
- At 100%, one of the three idle frames after the last step took 130 to 185 ms to draw in each of three runs, and it does not happen with the whole picture on the screen. A sample of the threads over that stretch shows the raster thread waiting for Metal to schedule the frame (`waitUntilScheduled`) instead of drawing, and tiles being read back to be settled. What keeps the graphics card busy at that moment was not found.
- A picture is still limited to 8192 px a side: saving and a few edits draw it in one piece.
