import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../shell/platform.dart';
import 'open_pictures.dart';
import 'panel_controls.dart';

const _tabHeight = 32.0;
const _nameMaxWidth = 180.0;

/// The strip above the canvas with one tab for each open picture.
class PictureTabs extends StatefulWidget {
  const PictureTabs({required this.pictures, required this.onClose, super.key});

  final OpenPictures pictures;

  /// Asked to close a picture; whoever listens checks for unsaved changes.
  final ValueChanged<OpenPicture> onClose;

  @override
  State<PictureTabs> createState() => _PictureTabsState();
}

class _PictureTabsState extends State<PictureTabs> {
  final _scroll = ScrollController();
  late OpenPicture _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.pictures.active;
    widget.pictures.addListener(_onPictures);
  }

  @override
  void didUpdateWidget(PictureTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pictures == widget.pictures) return;
    oldWidget.pictures.removeListener(_onPictures);
    _shown = widget.pictures.active;
    widget.pictures.addListener(_onPictures);
  }

  @override
  void dispose() {
    widget.pictures.removeListener(_onPictures);
    _scroll.dispose();
    super.dispose();
  }

  void _onPictures() {
    setState(() {});
    final active = widget.pictures.active;
    if (identical(active, _shown)) return;
    _shown = active;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(active));
  }

  /// Scrolls the strip until the tab of [picture] is all in sight.
  void _reveal(OpenPicture picture) {
    final tab = _TabKey(picture).currentContext;
    if (tab == null) return;
    for (final policy in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      Scrollable.ensureVisible(tab, alignmentPolicy: policy);
    }
  }

  /// A plain mouse wheel has no sideways move: it scrolls the strip.
  void _onWheel(PointerSignalEvent signal) {
    if (signal is! PointerScrollEvent || signal.scrollDelta.dx != 0) return;
    GestureBinding.instance.pointerSignalResolver.register(signal, (_) {
      final position = _scroll.position;
      _scroll.jumpTo(
        (position.pixels + signal.scrollDelta.dy).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pictures = widget.pictures;
    return Container(
      height: _tabHeight,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Listener(
        onPointerSignal: _onWheel,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final picture in pictures.pictures)
                _Tab(
                  key: _TabKey(picture),
                  picture: picture,
                  active: identical(picture, pictures.active),
                  onTap: () => pictures.activate(picture),
                  onClose: () => widget.onClose(picture),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabKey extends GlobalObjectKey {
  const _TabKey(OpenPicture super.picture);
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.picture,
    required this.active,
    required this.onTap,
    required this.onClose,
    super.key,
  });

  final OpenPicture picture;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final color = active ? colors.onSurface : colors.onSurfaceVariant;
    return ListenableBuilder(
      listenable: picture.document,
      builder: (context, _) => Semantics(
        button: true,
        selected: active,
        child: GestureDetector(
          onTertiaryTapUp: (_) => onClose(),
          child: Material(
            // the tab in front is one piece with the desk under it
            color: active ? colors.surfaceContainerHigh : Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: _tabHeight,
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: active ? colors.primary : Colors.transparent,
                      width: 2,
                    ),
                    right: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _nameMaxWidth,
                      ),
                      child: Text(
                        picture.document.name ?? l10n.untitled,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: active ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    if (picture.document.dirty) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: l10n.unsavedChanges,
                        child: Icon(Icons.circle, size: 8, color: color),
                      ),
                    ],
                    const SizedBox(width: 2),
                    PanelIconButton(
                      // the key closes the picture in front, not this one
                      tooltip: active
                          ? '${l10n.close} (${shortcutLabel('W')})'
                          : l10n.close,
                      onPressed: onClose,
                      child: const Icon(Icons.close, size: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
