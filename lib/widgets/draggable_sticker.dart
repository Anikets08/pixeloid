import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DraggableSticker extends StatefulWidget {
  final String stickerPath;
  final Function(Key) onRemove;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final GlobalKey deleteZoneKey;

  const DraggableSticker({
    required Key key,
    required this.stickerPath,
    required this.onRemove,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.deleteZoneKey,
  }) : super(key: key);

  @override
  State<DraggableSticker> createState() => _DraggableStickerState();
}

class _DraggableStickerState extends State<DraggableSticker> {
  double _x = 100;
  double _y = 100;
  double _scale = 1.0;
  double _rotation = 0.0;
  bool _isSelected = false;
  bool _isDragging = false;
  double _initialScale = 1.0;
  double _initialRotation = 0.0;
  Offset _lastPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        // Handle tap to select/deselect
        onTap: () {
          setState(() {
            _isSelected = !_isSelected;
          });
        },

        // Handle long press to start dragging for delete
        onLongPressStart: (details) {
          setState(() {
            _isSelected = true;
            _isDragging = true;
            _lastPosition = details.globalPosition;
          });
          widget.onDragStarted();
        },

        // Handle long press movement
        onLongPressMoveUpdate: (details) {
          final currentPosition = details.globalPosition;
          final dx = currentPosition.dx - _lastPosition.dx;
          final dy = currentPosition.dy - _lastPosition.dy;

          setState(() {
            _x += dx;
            _y += dy;
            _lastPosition = currentPosition;

            // Check if the sticker is over the delete zone
            if (_isOverDeleteZone()) {
              // Visual feedback that the sticker will be deleted
              _scale = 0.8;
            } else {
              _scale = _initialScale;
            }
          });
        },

        // Handle long press end
        onLongPressEnd: (details) {
          setState(() {
            _isDragging = false;
          });
          widget.onDragEnded();

          // If the sticker is over the delete zone, remove it
          if (_isOverDeleteZone()) {
            widget.onRemove(widget.key!);
          } else {
            setState(() {
              _scale = _initialScale;
            });
          }
        },

        // Handle scale and rotation gestures
        onScaleStart: (details) {
          if (_isDragging) return;

          _initialScale = _scale;
          _initialRotation = _rotation;
          _lastPosition = details.focalPoint;
        },

        onScaleUpdate: (details) {
          if (_isDragging) return;

          setState(() {
            // Handle movement (pan)
            final dx = details.focalPoint.dx - _lastPosition.dx;
            final dy = details.focalPoint.dy - _lastPosition.dy;

            if (details.pointerCount == 1) {
              // Single finger drag - move the sticker
              _x += dx;
              _y += dy;
              _isSelected = true;
            }

            _lastPosition = details.focalPoint;

            // Handle scaling
            if (details.scale != 1.0) {
              _scale = (_initialScale * details.scale).clamp(0.5, 3.0);
            }

            // Handle rotation
            if (details.rotation != 0.0) {
              _rotation = _initialRotation + details.rotation;
            }
          });
        },

        child: Transform.scale(
          scale: _scale,
          child: Transform.rotate(
            angle: _rotation,
            child: Container(
              width: 120,
              height: 120,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: _isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(
                widget.stickerPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isOverDeleteZone() {
    if (widget.deleteZoneKey.currentContext == null) return false;

    final RenderBox deleteZoneBox =
        widget.deleteZoneKey.currentContext!.findRenderObject() as RenderBox;
    final Offset deleteZonePosition = deleteZoneBox.localToGlobal(Offset.zero);

    final deleteZoneRect = Rect.fromLTWH(
      deleteZonePosition.dx,
      deleteZonePosition.dy,
      deleteZoneBox.size.width,
      deleteZoneBox.size.height,
    );

    final stickerCenter = Offset(_x + 60, _y + 60);

    return deleteZoneRect.contains(stickerCenter);
  }
}
