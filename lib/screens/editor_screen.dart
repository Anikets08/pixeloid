import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pixeloid/models/enum/tool_bar_button_type.dart';
import 'package:pixeloid/widgets/custom_button.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_state.dart';
import '../widgets/sticker_picker.dart';
import '../widgets/draggable_sticker.dart';
import '../widgets/draggable_text.dart';
import '../services/instagram_share_service.dart';

/*
 * Editor Screen
 *
 * This screen allows users to edit photos by drawing on them and adding stickers and text.
 * Users can double-tap on text to edit it after placement.
 *
 * Note: We've switched from image_painter to flutter_painter_v2 for better drawing capabilities
 * and more reliable API.
 */

// Define the editor modes
enum EditorMode {
  normal,
  drawing,
  text,
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _textInputController = TextEditingController();
  late PainterController _controller;
  List<Widget> _stickers = [];
  List<Widget> _textElements = [];
  bool _isLoading = false;
  ui.Image? _backgroundImage;
  bool _isImageLoaded = false;
  bool _showDeleteZone = false;
  final GlobalKey _deleteZoneKey = GlobalKey();

  // Current editor mode
  EditorMode _currentMode = EditorMode.normal;

  // Text style properties
  double _fontSize = 24.0;
  Color _textColor = Colors.white;
  FontWeight _fontWeight = FontWeight.normal;
  String _currentFontFamily = 'Roboto';

  // List of available Google Fonts
  final List<String> _availableFonts = [
    'Roboto',
    'Lato',
    'Open Sans',
    'Montserrat',
    'Oswald',
    'Raleway',
    'Poppins',
    'Playfair Display',
    'Dancing Script',
    'Pacifico',
    'Shadows Into Light',
    'Caveat',
    'Satisfy',
    'Lobster',
  ];

  // Add these properties to track image dimensions and aspect ratio
  double? _imageAspectRatio;
  Color _backgroundColor = Colors.black;

  // Add a line height property to the class
  double _lineHeight = 1.2;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _captionController.text = appState.caption;
    _controller = PainterController();
    _controller.freeStyleMode = FreeStyleMode.none;
    _controller.freeStyleStrokeWidth = 5;
    _controller.freeStyleColor = Colors.red;
    _loadImage();
  }

  Future<void> _loadImage() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.capturedImage != null) {
      setState(() {
        _isImageLoaded = false;
      });

      final File imageFile = appState.capturedImage!;
      final Uint8List bytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      // Calculate aspect ratio of the loaded image
      final double imageWidth = frameInfo.image.width.toDouble();
      final double imageHeight = frameInfo.image.height.toDouble();
      final double aspectRatio = imageWidth / imageHeight;

      // Instagram's standard aspect ratio is 9:16 (0.5625)
      const double instagramAspectRatio = 9 / 16;

      setState(() {
        _backgroundImage = frameInfo.image;
        _imageAspectRatio = aspectRatio;
        _isImageLoaded = true;

        // If the image has a different aspect ratio than Instagram's standard,
        // we'll use a custom background drawable that maintains the aspect ratio
        if ((aspectRatio - instagramAspectRatio).abs() > 0.01) {
          _controller.background = CustomImageBackgroundDrawable(
            image: _backgroundImage!,
            aspectRatio: aspectRatio,
            backgroundColor: _backgroundColor,
          );
        } else {
          // For images with standard aspect ratio, use the default background
          _controller.background = ImageBackgroundDrawable(
            image: _backgroundImage!,
          );
        }
      });
    }
  }

  void _enterDrawMode() {
    setState(() {
      _currentMode = EditorMode.drawing;
      _controller.freeStyleMode = FreeStyleMode.draw;
    });
  }

  void _exitDrawMode() {
    setState(() {
      _currentMode = EditorMode.normal;
      _controller.freeStyleMode = FreeStyleMode.none;
    });
  }

  void _enterTextMode() {
    setState(() {
      // _currentMode = EditorMode.text;
      _textInputController.clear();
    });
    _showTextBottomSheet();
  }

  void _exitTextMode() {
    setState(() {
      _currentMode = EditorMode.normal;
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _textInputController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _addSticker(String stickerPath) {
    setState(() {
      _stickers.add(
        DraggableSticker(
          key: UniqueKey(),
          stickerPath: stickerPath,
          onRemove: (key) {
            setState(() {
              _stickers.removeWhere((sticker) => sticker.key == key);
            });
          },
          onDragStarted: () {
            setState(() {
              _showDeleteZone = true;
            });
          },
          onDragEnded: () {
            setState(() {
              _showDeleteZone = false;
            });
          },
          deleteZoneKey: _deleteZoneKey,
        ),
      );
    });
  }

  void _addText(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _textElements.add(
        DraggableText(
          key: UniqueKey(),
          text: text,
          textStyle: GoogleFonts.getFont(
            _currentFontFamily,
            color: _textColor,
            fontSize: _fontSize,
            fontWeight: _fontWeight,
            height: _lineHeight, // Add line height to the text style
          ),
          onRemove: (key) {
            setState(() {
              _textElements
                  .removeWhere((textElement) => textElement.key == key);
            });
          },
          onDragStarted: () {
            setState(() {
              _showDeleteZone = true;
            });
          },
          onDragEnded: () {
            setState(() {
              _showDeleteZone = false;
            });
          },
          deleteZoneKey: _deleteZoneKey,
          onTextEdit: _updateTextElement,
        ),
      );
    });

    _exitTextMode();
  }

  // Method to update text when edited
  void _updateTextElement(Key key, String existingText) {
    // Show the text bottom sheet with the existing text for editing
    _showTextBottomSheet(editingKey: key, initialText: existingText);
  }

  // Method to actually update the text element with new text
  void _applyTextUpdate(Key key, String newText) {
    if (newText.trim().isEmpty) return;

    setState(() {
      final int index =
          _textElements.indexWhere((element) => element.key == key);
      if (index != -1) {
        final DraggableText oldText = _textElements[index] as DraggableText;
        _textElements[index] = DraggableText(
          key: oldText.key!,
          text: newText,
          textStyle: GoogleFonts.getFont(
            _currentFontFamily,
            color: _textColor,
            fontSize: _fontSize,
            fontWeight: _fontWeight,
            height: _lineHeight, // Add line height to the text style
          ),
          onRemove: oldText.onRemove,
          onDragStarted: oldText.onDragStarted,
          onDragEnded: oldText.onDragEnded,
          deleteZoneKey: oldText.deleteZoneKey,
          onTextEdit: oldText.onTextEdit,
        );
      }
    });
  }

  Future<void> _shareToInstagram() async {
    try {
      // Capture the edited image
      final RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // Use a more appropriate pixel ratio to match Instagram's recommended size
      // Instagram recommends 1080x1920 (9:16 aspect ratio)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to capture image');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save caption to app state
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setCaption(_captionController.text);

      // Share to Instagram using the new service
      final bool success = await InstagramShareService.shareToInstagramStory(
        pngBytes,
        '9190058337716566', // Your Facebook App ID
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share to Instagram. Please try again.'),
          ),
        );
      }

      // Clear the image after sharing
      // appState.clearImage();
    } catch (e) {
      debugPrint('Error sharing to Instagram: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share to Instagram. Please try again.'),
          ),
        );
      }
    }
  }

  void _discardChanges() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.clearImage();
  }

  Widget _iconButton(
    IconData icon,
    Function() onPressed, {
    bool isSelected = false,
    required ToolBarButtonType type,
  }) {
    return SizedBox(
      height: 40,
      width: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white12,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> discard() async {
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Discard Changes?'),
          content: Text('Are you sure you want to discard all changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _discardChanges();
                Navigator.of(context).pop(true);
              },
              child: Text('Discard'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (appState.capturedImage == null || !_isImageLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (val, res) async {
        if (!val) {
          if (appState.capturedImage != null) {
            await discard();
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black26,
          title: Text(
            _currentMode == EditorMode.drawing
                ? 'Drawing Mode'
                : _currentMode == EditorMode.text
                    ? 'Text Mode'
                    : 'Edit Photo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await discard();
            },
          ),
          actions: [
            if (_currentMode == EditorMode.drawing ||
                _currentMode == EditorMode.text)
              CustomButton(
                onPressed: _currentMode == EditorMode.drawing
                    ? _exitDrawMode
                    : _exitTextMode,
                text: 'Done',
              )
            else
              CustomButton(
                onPressed: () {
                  _shareToInstagram();
                },
                text: 'Share',
                icon: Icons.share,
              )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            // Repaint boundary to capture the entire edited image
                            RepaintBoundary(
                              key: _repaintBoundaryKey,
                              child: Stack(
                                children: [
                                  // Image with drawing capability
                                  FlutterPainter(
                                    controller: _controller,
                                  ),

                                  // Stickers layer
                                  ..._stickers,

                                  // Text elements layer
                                  ..._textElements,
                                ],
                              ),
                            ),
                            if (_currentMode == EditorMode.drawing)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: 40,
                                  color: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  child: Center(
                                    child: // show stroke width as a container height
                                        Container(
                                      height: _controller.freeStyleStrokeWidth,
                                      width: _controller.freeStyleStrokeWidth,
                                      decoration: BoxDecoration(
                                        color: _controller.freeStyleColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),

                      // Bottom toolbar - changes based on mode
                      Container(
                        color: Colors.black12,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _buildToolbar(),
                      ),
                    ],
                  ),

                  // Delete zone that appears when a sticker or text is being dragged
                  if (_showDeleteZone)
                    Positioned(
                      bottom: 80,
                      left: 0,
                      right: 0,
                      child: Container(
                        key: _deleteZoneKey,
                        height: 80,
                        color: Colors.red.withAlpha(200),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_forever,
                                color: Colors.white,
                                size: 32,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Drop here to delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildToolbar() {
    switch (_currentMode) {
      case EditorMode.drawing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 10,
          children: [
            _iconButton(
              Icons.color_lens,
              () {
                _showColorPicker();
              },
              type: ToolBarButtonType.color,
            ),
            _iconButton(
              Icons.exposure_minus_1_outlined,
              () {
                // Toggle brush size
                setState(() {
                  // min 5, max 25
                  if (_controller.freeStyleStrokeWidth > 5) {
                    _controller.freeStyleStrokeWidth -= 5;
                  }
                });
              },
              isSelected: true,
              type: ToolBarButtonType.pen,
            ),
            _iconButton(
              Icons.exposure_plus_1_rounded,
              () {
                // Toggle brush size
                setState(() {
                  // min 5, max 25
                  if (_controller.freeStyleStrokeWidth < 25) {
                    _controller.freeStyleStrokeWidth += 5;
                  }
                });
              },
              isSelected: true,
              type: ToolBarButtonType.pen,
            ),
            _iconButton(
              Icons.undo,
              () {
                _controller.undo();
              },
              type: ToolBarButtonType.undo,
            ),
          ],
        );
      case EditorMode.text:
      case EditorMode.normal:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 10,
          children: [
            // Drawing tool
            _iconButton(
              Icons.brush,
              () {
                _enterDrawMode();
              },
              isSelected: false,
              type: ToolBarButtonType.pen,
            ),

            // Text tool
            _iconButton(
              Icons.text_fields,
              () {
                _enterTextMode();
              },
              isSelected: false,
              type: ToolBarButtonType.text,
            ),

            // Sticker picker
            _iconButton(
              Icons.emoji_emotions,
              () {
                _showStickerPicker();
              },
              type: ToolBarButtonType.sticker,
            ),

            // Background color picker (only show for non-standard aspect ratio images)
            if (_imageAspectRatio != null &&
                ((_imageAspectRatio! - 9 / 16).abs() > 0.01))
              _iconButton(
                Icons.format_color_fill,
                () {
                  _showBackgroundColorPicker();
                },
                type: ToolBarButtonType.color,
              ),

            // Undo
            _iconButton(
              Icons.undo,
              () {
                _controller.undo();
              },
              type: ToolBarButtonType.undo,
            ),

            // Clear all
            _iconButton(
              Icons.delete,
              () {
                _controller.clearDrawables();
                setState(() {
                  _stickers = [];
                  _textElements = [];
                });
              },
              type: ToolBarButtonType.delete,
            ),

            //save to gallery
            _iconButton(
              Icons.save,
              () async {
                final RenderRepaintBoundary boundary =
                    _repaintBoundaryKey.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                final ByteData? byteData =
                    await image.toByteData(format: ui.ImageByteFormat.png);

                if (byteData == null) {
                  throw Exception('Failed to capture image');
                }

                final Uint8List pngBytes = byteData.buffer.asUint8List();

                // Save the image to a temporary file
                final tempDir = await getTemporaryDirectory();
                final File file = File(
                    '${tempDir.path}/pixeloid_${DateTime.now().millisecondsSinceEpoch}.png');
                await file.writeAsBytes(pngBytes);
                if (!mounted) return;
                Gal.putImage(file.path, album: 'Pixeloid');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Image saved to gallery'),
                    action: SnackBarAction(
                      label: 'View',
                      onPressed: () {
                        OpenFile.open(file.path);
                      },
                    ),
                  ),
                );
              },
              type: ToolBarButtonType.save,
            ),
          ],
        );
    }
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, ss) {
          return Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: Colors.primaries.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    // Select color
                    setState(() {
                      _controller.freeStyleColor = Colors.primaries[index];
                    });
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: Colors.primaries[index],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12, width: 2),
                    ),
                  ),
                );
              },
            ),
          );
        });
      },
    );
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StickerPicker(
          onStickerSelected: (stickerPath) {
            _addSticker(stickerPath);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showTextBottomSheet({Key? editingKey, String? initialText}) {
    // Set initial text if editing an existing text element
    if (initialText != null) {
      _textInputController.text = initialText;
    } else {
      _textInputController.clear();
    }

    // If editing, get the current text style
    if (editingKey != null) {
      final int index =
          _textElements.indexWhere((element) => element.key == editingKey);
      if (index != -1) {
        final DraggableText textElement = _textElements[index] as DraggableText;
        // Extract style properties from the existing text element
        _textColor = textElement.textStyle.color ?? Colors.white;
        _fontSize = textElement.textStyle.fontSize ?? 24.0;
        _fontWeight = textElement.textStyle.fontWeight ?? FontWeight.normal;
        _lineHeight = textElement.textStyle.height ??
            1.2; // Get line height from existing text

        // Try to determine font family
        final String fontFamily = textElement.textStyle.fontFamily ?? 'Roboto';
        if (_availableFonts.contains(fontFamily)) {
          _currentFontFamily = fontFamily;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: false,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          editingKey != null ? 'Edit Text' : 'Add Text',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _exitTextMode();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                if (editingKey != null) {
                                  // Update existing text
                                  _applyTextUpdate(
                                      editingKey, _textInputController.text);
                                } else {
                                  // Add new text
                                  _addText(_textInputController.text);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child:
                                  Text(editingKey != null ? 'Update' : 'Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Text preview
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _textColor.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _textInputController.text.isEmpty
                            ? 'Preview Text\nMultiple Lines\nTo Show Spacing'
                            : _textInputController.text,
                        style: GoogleFonts.getFont(
                          _currentFontFamily,
                          fontSize: _fontSize,
                          color: _textColor,
                          fontWeight: _fontWeight,
                          height: _lineHeight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Expanded(
                      child: ListView(
                        children: [
                          // Text input
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _textInputController,
                              decoration: InputDecoration(
                                hintText: 'Enter your text...',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                border: InputBorder.none,
                              ),
                              style: TextStyle(color: Colors.grey[800]),
                              maxLines: 3,
                              autofocus: true,
                              onChanged: (value) {
                                setModalState(() {});
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Section title
                          Text(
                            'Text Size',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Font size slider
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.text_fields,
                                  size: 20,
                                  color: Colors.grey[700],
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _fontSize,
                                    min: 12,
                                    max: 72,
                                    divisions: 60,
                                    label: _fontSize.round().toString(),
                                    activeColor: Theme.of(context).primaryColor,
                                    inactiveColor: Colors.grey[300],
                                    onChanged: (value) {
                                      setModalState(() {
                                        _fontSize = value;
                                      });
                                    },
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_fontSize.round()}',
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Section title
                          Text(
                            'Text Color',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Text color picker
                          Container(
                            height: 70,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                ...Colors.primaries.map((color) {
                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        _textColor = color;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _textColor == color
                                              ? Theme.of(context).primaryColor
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                        boxShadow: _textColor == color
                                            ? [
                                                BoxShadow(
                                                  color: color.withOpacity(0.5),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  );
                                }),
                                // Add white and black
                                GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _textColor = Colors.white;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _textColor == Colors.white
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey[400]!,
                                        width: 3,
                                      ),
                                      boxShadow: _textColor == Colors.white
                                          ? [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.5),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _textColor = Colors.black;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _textColor == Colors.black
                                            ? Theme.of(context).primaryColor
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: _textColor == Colors.black
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.5),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Section title
                          Text(
                            'Font Style',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Font family picker
                          Container(
                            height: 120,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _availableFonts.length,
                              itemBuilder: (context, index) {
                                final fontFamily = _availableFonts[index];
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _currentFontFamily = fontFamily;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _currentFontFamily == fontFamily
                                          ? Theme.of(context)
                                              .primaryColor
                                              .withOpacity(0.2)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _currentFontFamily == fontFamily
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey[300]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Aa',
                                          style: GoogleFonts.getFont(
                                            fontFamily,
                                            fontSize: 28,
                                            color: _currentFontFamily ==
                                                    fontFamily
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          fontFamily,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _currentFontFamily ==
                                                    fontFamily
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Section title
                          Text(
                            'Font Weight',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Font weight
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    setModalState(() {
                                      _fontWeight = FontWeight.normal;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _fontWeight == FontWeight.normal
                                            ? Theme.of(context).primaryColor
                                            : Colors.white,
                                    foregroundColor:
                                        _fontWeight == FontWeight.normal
                                            ? Colors.white
                                            : Colors.grey[800],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Normal'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setModalState(() {
                                      _fontWeight = FontWeight.bold;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _fontWeight == FontWeight.bold
                                            ? Theme.of(context).primaryColor
                                            : Colors.white,
                                    foregroundColor:
                                        _fontWeight == FontWeight.bold
                                            ? Colors.white
                                            : Colors.grey[800],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Bold'),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Line Height section
                          Text(
                            'Line Spacing',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Line height slider
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.format_line_spacing,
                                  size: 20,
                                  color: Colors.grey[700],
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _lineHeight,
                                    min: 0.8,
                                    max: 2.5,
                                    divisions: 17,
                                    label: _lineHeight.toStringAsFixed(1),
                                    activeColor: Theme.of(context).primaryColor,
                                    inactiveColor: Colors.grey[300],
                                    onChanged: (value) {
                                      setModalState(() {
                                        _lineHeight = value;
                                      });
                                    },
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _lineHeight.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBackgroundColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, ss) {
          return Container(
            height: 320,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount:
                        Colors.primaries.length + 2, // +2 for black and white
                    itemBuilder: (context, index) {
                      Color color;
                      if (index < Colors.primaries.length) {
                        color = Colors.primaries[index];
                      } else if (index == Colors.primaries.length) {
                        color = Colors.black;
                      } else {
                        color = Colors.white;
                      }

                      return GestureDetector(
                        onTap: () {
                          // Select color
                          _changeBackgroundColor(color);
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _backgroundColor == color
                                  ? Colors.blue
                                  : Colors.black12,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // Add this method to the class to allow changing the background color
  void _changeBackgroundColor(Color color) {
    setState(() {
      _backgroundColor = color;

      // Update the background if we have a non-standard aspect ratio image
      if (_backgroundImage != null &&
          _imageAspectRatio != null &&
          ((_imageAspectRatio! - 9 / 16).abs() > 0.01)) {
        _controller.background = CustomImageBackgroundDrawable(
          image: _backgroundImage!,
          aspectRatio: _imageAspectRatio!,
          backgroundColor: _backgroundColor,
        );
      }
    });
  }
}

// Add this custom drawable class at the end of the file, outside the _EditorScreenState class
class CustomImageBackgroundDrawable extends BackgroundDrawable {
  final ui.Image image;
  final double aspectRatio;
  final Color backgroundColor;

  CustomImageBackgroundDrawable({
    required this.image,
    required this.aspectRatio,
    required this.backgroundColor,
  });

  @override
  void draw(Canvas canvas, Size size) {
    // Fill the entire canvas with the background color
    final Paint backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    // Calculate dimensions to maintain aspect ratio
    double targetWidth = size.width;
    double targetHeight = size.height;

    // Instagram's aspect ratio is 9:16 (0.5625)
    const double instagramAspectRatio = 9 / 16;

    if (aspectRatio > instagramAspectRatio) {
      // Image is wider than Instagram's aspect ratio
      targetHeight = size.width / aspectRatio;
      // Center the image vertically
      double topOffset = (size.height - targetHeight) / 2;

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, topOffset, targetWidth, targetHeight),
        Paint(),
      );
    } else {
      // Image is taller than Instagram's aspect ratio
      targetWidth = size.height * aspectRatio;
      // Center the image horizontally
      double leftOffset = (size.width - targetWidth) / 2;

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(leftOffset, 0, targetWidth, targetHeight),
        Paint(),
      );
    }
  }
}
