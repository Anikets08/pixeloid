import 'package:flutter/material.dart';

class DraggableText extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  final Function(Key) onRemove;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final GlobalKey deleteZoneKey;
  final Function(Key, String) onTextEdit;

  const DraggableText({
    required Key key,
    required this.text,
    required this.textStyle,
    required this.onRemove,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.deleteZoneKey,
    required this.onTextEdit,
  }) : super(key: key);

  @override
  State<DraggableText> createState() => _DraggableTextState();
}

class _DraggableTextState extends State<DraggableText> {
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

        // Handle double tap to edit text
        onDoubleTap: () {
          widget.onTextEdit(widget.key!, widget.text);
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

            // Check if the text is over the delete zone
            if (_isOverDeleteZone()) {
              // Visual feedback that the text will be deleted
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

          // If the text is over the delete zone, remove it
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
              // Single finger drag - move the text
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: _isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.text,
                style: widget.textStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show dialog to edit text
  void _showEditTextDialog(BuildContext context) {
    final TextEditingController textController =
        TextEditingController(text: widget.text);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Text'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'Enter your text...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (textController.text.trim().isNotEmpty) {
                  widget.onTextEdit(widget.key!, textController.text);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
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

    final textCenter = Offset(_x + 60, _y + 60);

    return deleteZoneRect.contains(textCenter);
  }
}
