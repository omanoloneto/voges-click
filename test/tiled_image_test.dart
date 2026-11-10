import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_click/canvas/image_ops.dart';
import 'package:voges_click/document/tile.dart';
import 'package:voges_click/document/tiled_image.dart';
import 'package:voges_click/painting/rgba_image.dart';

import 'support/pixels.dart';

Image _plain(int width, int height, Color color) => renderImage(
  width,
  height,
  (canvas) => canvas.drawColor(color, BlendMode.src),
);

Future<RgbaImage> _read(TiledImage pixels) async {
  final image = pixels.toImage();
  final read = await readPixels(image);
  image.dispose();
  return read;
}

void main() {
  testWidgets('an image is cut into tiles and comes back whole', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixels = TiledImage.fromImage(
        renderImage(2100, 1100, (canvas) {
          canvas
            ..drawColor(white, BlendMode.src)
            // on the corner four tiles share
            ..drawRect(
              const Rect.fromLTWH(1000, 1000, 48, 48),
              Paint()..color = red,
            )
            // on the last column, a narrow one
            ..drawRect(
              const Rect.fromLTWH(2090, 0, 10, 10),
              Paint()..color = blue,
            );
        }),
      );
      expect((pixels.width, pixels.height), (2100, 1100));
      expect(pixels.tiles, hasLength(6));

      final read = await _read(pixels);
      expect((read.width, read.height), (2100, 1100));
      for (final (x, y) in [
        (1000, 1000),
        (1023, 1023),
        (1024, 1023),
        (1023, 1024),
        (1024, 1024),
        (1047, 1047),
      ]) {
        expect(read.colorAt(x, y), 0xFFFF0000, reason: '$x, $y');
      }
      expect(read.colorAt(999, 1000), 0xFFFFFFFF);
      expect(read.colorAt(1048, 1047), 0xFFFFFFFF);
      expect(read.colorAt(2095, 5), 0xFF0000FF);
      expect(read.colorAt(2089, 5), 0xFFFFFFFF);
    });
  });

  testWidgets('a patch makes again only the tiles it touches', (tester) async {
    await tester.runAsync(() async {
      final before = TiledImage.filled(2100, 1100, white);
      expect(before.tiles, hasLength(6));
      // tiles of one color and one size are a single tile
      expect(before.tiles.toSet(), hasLength(4));

      final dot = _plain(10, 10, red);
      final after = before.patched(
        const Rect.fromLTWH(0, 0, 2100, 1100),
        patch: dot,
        at: const Offset(1020, 500),
      );
      dot.dispose();
      final was = before.tiles.toList(), now = after.tiles.toList();
      expect(
        [for (var i = 0; i < 6; i++) identical(now[i], was[i])],
        [false, false, true, true, true, true],
      );

      final read = await _read(after);
      expect(read.colorAt(1019, 505), 0xFFFFFFFF);
      expect(read.colorAt(1020, 500), 0xFFFF0000);
      expect(read.colorAt(1023, 509), 0xFFFF0000);
      expect(read.colorAt(1024, 500), 0xFFFF0000);
      expect(read.colorAt(1029, 509), 0xFFFF0000);
      expect(read.colorAt(1030, 505), 0xFFFFFFFF);
      // the image it came from is never changed
      expect((await _read(before)).colorAt(1024, 505), 0xFFFFFFFF);
    });
  });

  testWidgets('a patch keeps the tiles it is said to leave as they were', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final before = TiledImage.fromImage(_plain(2048, 2048, white));
      final was = before.tiles.toList();
      expect(was, hasLength(4));

      // as large as the image, but different only in two of its corners
      final patch = renderImage(2048, 2048, (canvas) {
        canvas
          ..drawColor(white, BlendMode.src)
          ..drawRect(const Rect.fromLTWH(10, 10, 10, 10), Paint()..color = red)
          ..drawRect(
            const Rect.fromLTWH(2000, 2000, 10, 10),
            Paint()..color = blue,
          );
      });
      final after = before.patched(
        const Rect.fromLTWH(0, 0, 2048, 2048),
        patch: patch,
        changes: (area) => area.left == area.top,
      );
      final now = after.tiles.toList();
      expect(
        [for (var i = 0; i < 4; i++) identical(now[i], was[i])],
        [false, true, true, false],
      );
      var read = await _read(after);
      expect(read.colorAt(15, 15), 0xFFFF0000);
      expect(read.colorAt(2005, 2005), 0xFF0000FF);
      expect(read.colorAt(1500, 500), 0xFFFFFFFF);

      patch.dispose();

      // a tile that changes its size is made again from what it had
      final narrow = TiledImage.fromImage(_plain(1000, 1000, white));
      final cover = _plain(1500, 1000, red);
      final wider = narrow.patched(
        const Rect.fromLTWH(0, 0, 1500, 1000),
        patch: cover,
        changes: (area) => false,
      );
      cover.dispose();
      expect(wider.tiles.single, isNot(same(narrow.tiles.single)));
      read = await _read(wider);
      expect(read.colorAt(500, 500), 0xFFFFFFFF);
      expect(read.colorAt(1010, 500), 0);
      expect(read.colorAt(1200, 500), 0);
    });
  });

  testWidgets('growing and cropping keep the tiles that stay whole', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final image = TiledImage.fromImage(_plain(1500, 800, red));
      final tiles = image.tiles.toList();
      expect(tiles, hasLength(2));

      // more room to the left and above: no tile moves on the picture
      final grown = image.patched(const Rect.fromLTWH(-300, -200, 1800, 1000));
      expect((grown.width, grown.height), (1800, 1000));
      expect(grown.tiles.toList(), tiles);
      var read = await _read(grown);
      expect(read.colorAt(299, 500), 0);
      expect(read.colorAt(500, 199), 0);
      expect(read.colorAt(300, 200), 0xFFFF0000);
      expect(read.colorAt(1799, 999), 0xFFFF0000);

      final back = grown.patched(const Rect.fromLTWH(300, 200, 1500, 800));
      expect((back.width, back.height), (1500, 800));
      expect(back.tiles.toList(), tiles);
      read = await _read(back);
      expect(read.colorAt(0, 0), 0xFFFF0000);
      expect(read.colorAt(1499, 799), 0xFFFF0000);

      // a cut through a tile makes that one again, smaller
      final cut = image.patched(const Rect.fromLTWH(100, 100, 900, 600));
      expect((cut.width, cut.height), (900, 600));
      expect(tiles, isNot(contains(cut.tiles.single)));
      read = await _read(cut);
      expect(read.colorAt(0, 0), 0xFFFF0000);
      expect(read.colorAt(899, 599), 0xFFFF0000);
    });
  });

  testWidgets('what is transparent has no tiles, whatever its size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final empty = TiledImage.transparent(8192, 8192);
      expect(empty.tiles, isEmpty);

      final dot = _plain(10, 10, red);
      final dotted = empty.patched(
        const Rect.fromLTWH(0, 0, 8192, 8192),
        patch: dot,
        at: const Offset(5000, 5000),
      );
      dot.dispose();
      expect(dotted.tiles, hasLength(1));

      final around = renderImage(20, 20, (canvas) {
        canvas.translate(-4995, -4995);
        dotted.paint(canvas, Offset.zero, Paint());
      });
      final read = await readPixels(around);
      around.dispose();
      expect(read.colorAt(4, 4), 0);
      expect(read.colorAt(5, 5), 0xFFFF0000);
      expect(read.colorAt(14, 14), 0xFFFF0000);
      expect(read.colorAt(15, 15), 0);
    });
  });

  testWidgets('the box of what there is to see is found tile by tile', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(await TiledImage.transparent(3000, 2100).opaqueBounds(), isNull);
      expect(
        await TiledImage.filled(3000, 2100, white).opaqueBounds(),
        const Rect.fromLTWH(0, 0, 3000, 2100),
      );

      // from the first row of tiles to the last, through the middle one
      final bar = _plain(100, 1160, red);
      final barred = TiledImage.transparent(3000, 2100).patched(
        const Rect.fromLTWH(0, 0, 3000, 2100),
        patch: bar,
        at: const Offset(1000, 900),
      );
      bar.dispose();
      expect(barred.tiles, hasLength(6));
      expect(
        await barred.opaqueBounds(),
        const Rect.fromLTWH(1000, 900, 100, 1160),
      );

      // a tile with nothing left in it counts for nothing
      final hole = _plain(2048, 1024, const Color(0x00000000));
      final cut = barred.patched(
        const Rect.fromLTWH(0, 0, 3000, 2100),
        patch: hole,
        at: Offset.zero,
      );
      hole.dispose();
      expect(
        await cut.opaqueBounds(),
        const Rect.fromLTRB(1000, 1024, 1100, 2060),
      );

      // room added around it moves the box along
      final grown = barred.patched(const Rect.fromLTWH(-500, -300, 3500, 2400));
      expect(
        await grown.opaqueBounds(),
        const Rect.fromLTWH(1500, 1200, 100, 1160),
      );
    });
  });

  testWidgets('a tile settles into a plain image with the same pixels', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixels = TiledImage.fromImage(
        renderImage(64, 64, (canvas) {
          canvas
            ..drawRect(
              const Rect.fromLTWH(0, 0, 32, 64),
              Paint()..color = const Color(0x80FF4000),
            )
            ..drawRect(
              const Rect.fromLTWH(16, 16, 32, 32),
              Paint()..color = const Color(0x40102030),
            )
            ..drawRect(
              const Rect.fromLTWH(40, 40, 10, 10),
              Paint()..color = const Color(0xFF123456),
            );
        }),
      );
      final tile = pixels.tiles.single;
      final rendered = tile.image;
      expect(tile.settled, isFalse);
      final before = await _read(pixels);

      await tileSettler.done;
      expect(tile.settled, isTrue);
      expect(tile.image, isNot(same(rendered)));
      expect(rendered.debugDisposed, isTrue);
      final after = await _read(pixels);
      expect(after.pixels, before.pixels);
      expect(after.colorAt(45, 45), 0xFF123456);
      expect(after.colorAt(60, 60), 0);
      expect(after.colorAt(4, 4) >>> 24, 0x80);
    });
  });

  testWidgets('a tile thrown away while it settles stays thrown away', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final settler = TileSettler();
      var drained = 0;
      settler.addListener(() => drained++);
      final kept = Tile(_plain(8, 8, red), settler: settler);
      final dropped = Tile(_plain(8, 8, blue), settler: settler);
      dropped.dispose();

      await settler.done;
      // told once, when no tile was left waiting
      expect(drained, 1);
      expect(kept.settled, isTrue);
      expect(dropped.settled, isFalse);
      expect(dropped.disposed, isTrue);
      expect(dropped.image.debugDisposed, isTrue);
    });
  });
}
