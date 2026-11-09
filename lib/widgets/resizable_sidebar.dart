import 'package:flutter/material.dart';

enum SidebarSide { left, right }

/// Contenitore per una barra laterale che si può nascondere (con animazione)
/// e ridimensionare trascinando il bordo interno. Doppio clic sul bordo:
/// torna alla larghezza predefinita.
class ResizableSidebar extends StatefulWidget {
  final Widget child;
  final SidebarSide side;
  final bool visible;
  final double width;
  final double defaultWidth;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onResizeEnd;

  const ResizableSidebar({
    super.key,
    required this.child,
    required this.side,
    required this.visible,
    required this.width,
    required this.defaultWidth,
    required this.onWidthChanged,
    required this.onResizeEnd,
  });

  @override
  State<ResizableSidebar> createState() => _ResizableSidebarState();
}

class _ResizableSidebarState extends State<ResizableSidebar> {
  bool _dragging = false;
  bool _hovering = false;

  void _onDragUpdate(DragUpdateDetails details) {
    // Il bordo trascinabile è quello verso il centro della finestra
    final delta = widget.side == SidebarSide.left
        ? details.delta.dx
        : -details.delta.dx;
    widget.onWidthChanged(widget.width + delta);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLeft = widget.side == SidebarSide.left;
    final highlight = _dragging || _hovering;

    return AnimatedContainer(
      // Nessuna animazione durante il trascinamento, per seguire il mouse
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: widget.visible ? widget.width : 0,
      child: ClipRect(
        child: OverflowBox(
          // Il contenuto mantiene la sua larghezza mentre la barra si chiude
          alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          minWidth: widget.width,
          maxWidth: widget.width,
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              Positioned(
                top: 0,
                bottom: 0,
                left: isLeft ? null : 0,
                right: isLeft ? 0 : null,
                width: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  onEnter: (_) => setState(() => _hovering = true),
                  onExit: (_) => setState(() => _hovering = false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => setState(() => _dragging = true),
                    onHorizontalDragUpdate: _onDragUpdate,
                    onHorizontalDragEnd: (_) {
                      setState(() => _dragging = false);
                      widget.onResizeEnd();
                    },
                    onDoubleTap: () {
                      widget.onWidthChanged(widget.defaultWidth);
                      widget.onResizeEnd();
                    },
                    child: Align(
                      alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: highlight ? 3 : 0,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
