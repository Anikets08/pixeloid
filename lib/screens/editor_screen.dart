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
    'Raleway',
    'Elsie',
    'Merriweather',
    'Poppins',
    'Playfair Display',
    'Dancing Script',
    'Oswald',
    'Quicksand',
    'Abril Fatface',
    'Pacifico',
    'Comfortaa',
    'Righteous',
    'Sacramento',
    'Bebas Neue',
    'Satisfy',
    'Permanent Marker',
    'Caveat',
    'Amatic SC',
    'Great Vibes',
    'Lobster',
    'Monoton',
    'Courgette',
    'Kalam',
    'Indie Flower',
    'Shadows Into Light',
    'Architects Daughter',
  ];

  // Add these properties to track image dimensions and aspect ratio
  double? _imageAspectRatio;
  Color _backgroundColor = Colors.black;

  // Add a line height property to the class
  double _lineHeight = 1.2;
  double _letterSpacing = 0.0;

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
            height: _lineHeight,
            letterSpacing: _letterSpacing,
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
            height: _lineHeight,
            letterSpacing: _letterSpacing,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 44,
      width: 44,
      child: Material(
        color: isSelected
            ? Theme.of(context).primaryColor.withOpacity(0.2)
            : Colors.white12,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? Theme.of(context).primaryColor : Colors.white,
            ),
          ),
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
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading image...',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
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
          backgroundColor: Colors.black.withOpacity(0.5),
          elevation: 0,
          title: Text(
            _currentMode == EditorMode.drawing
                ? 'Drawing Mode'
                : _currentMode == EditorMode.text
                    ? 'Text Mode'
                    : 'Edit Photo',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () async {
              await discard();
            },
          ),
          actions: [
            if (_currentMode == EditorMode.drawing ||
                _currentMode == EditorMode.text)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: _currentMode == EditorMode.drawing
                      ? _exitDrawMode
                      : _exitTextMode,
                  style: TextButton.styleFrom(
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
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  onPressed: () {
                    _shareToInstagram();
                  },
                  icon: const Icon(
                    Icons.share_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Share',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
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
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            RepaintBoundary(
                              key: _repaintBoundaryKey,
                              child: Stack(
                                children: [
                                  FlutterPainter(
                                    controller: _controller,
                                  ),
                                  ..._stickers,
                                  ..._textElements,
                                ],
                              ),
                            ),
                            if (_currentMode == EditorMode.drawing)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 60,
                                  color: Colors.black.withOpacity(0.7),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.remove,
                                          color: _controller.freeStyleColor,
                                          size: 24,
                                        ),
                                        onPressed: () {
                                          if (_controller.freeStyleStrokeWidth >
                                              2) {
                                            setState(() {
                                              _controller
                                                  .freeStyleStrokeWidth -= 2;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          height:
                                              _controller.freeStyleStrokeWidth,
                                          decoration: BoxDecoration(
                                            color: _controller.freeStyleColor,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: Icon(
                                          Icons.add,
                                          color: _controller.freeStyleColor,
                                          size: 24,
                                        ),
                                        onPressed: () {
                                          if (_controller.freeStyleStrokeWidth <
                                              25) {
                                            setState(() {
                                              _controller
                                                  .freeStyleStrokeWidth += 2;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: SafeArea(
                          top: false,
                          child: _buildToolbar(),
                        ),
                      ),
                    ],
                  ),
                  if (_showDeleteZone)
                    Positioned(
                      bottom: 100,
                      left: 16,
                      right: 16,
                      child: Container(
                        key: _deleteZoneKey,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white24,
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_forever_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Drop here to delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
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
          spacing: 12,
          children: [
            _iconButton(
              Icons.palette_rounded,
              () {
                _showColorPicker();
              },
              type: ToolBarButtonType.color,
            ),
            _iconButton(
              Icons.undo_rounded,
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
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _iconButton(
              Icons.brush_rounded,
              () {
                _enterDrawMode();
              },
              isSelected: _currentMode == EditorMode.drawing,
              type: ToolBarButtonType.pen,
            ),
            _iconButton(
              Icons.text_fields_rounded,
              () {
                _enterTextMode();
              },
              isSelected: _currentMode == EditorMode.text,
              type: ToolBarButtonType.text,
            ),
            _iconButton(
              Icons.emoji_emotions_rounded,
              () {
                _showStickerPicker();
              },
              type: ToolBarButtonType.sticker,
            ),
            if (_imageAspectRatio != null &&
                ((_imageAspectRatio! - 9 / 16).abs() > 0.01))
              _iconButton(
                Icons.format_color_fill_rounded,
                () {
                  _showBackgroundColorPicker();
                },
                type: ToolBarButtonType.color,
              ),
            _iconButton(
              Icons.undo_rounded,
              () {
                _controller.undo();
              },
              type: ToolBarButtonType.undo,
            ),
            _iconButton(
              Icons.delete_outline_rounded,
              () {
                _showClearConfirmation();
              },
              type: ToolBarButtonType.delete,
            ),
            _iconButton(
              Icons.save_rounded,
              () async {
                await _saveToGallery();
              },
              type: ToolBarButtonType.save,
            ),
          ],
        );
    }
  }

  Future<void> _saveToGallery() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
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

      await Gal.putImage(file.path, album: 'Pixeloid');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Image saved to gallery',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              OpenFile.open(file.path);
            },
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to save image',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Clear All Changes?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'This will remove all drawings, stickers, and text. This action cannot be undone.',
            style: GoogleFonts.poppins(),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey[800],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _controller.clearDrawables();
                setState(() {
                  _stickers = [];
                  _textElements = [];
                });
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(
                'Clear All',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, ss) {
            return Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Color',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                            setState(() {
                              _controller.freeStyleColor = color;
                            });
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _controller.freeStyleColor == color
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[300]!,
                                width: 3,
                              ),
                              boxShadow: _controller.freeStyleColor == color
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
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
    if (initialText != null) {
      _textInputController.text = initialText;
    } else {
      _textInputController.clear();
    }

    if (editingKey != null) {
      final int index =
          _textElements.indexWhere((element) => element.key == editingKey);
      if (index != -1) {
        final DraggableText textElement = _textElements[index] as DraggableText;
        _textColor = textElement.textStyle.color ?? Colors.white;
        _fontSize = textElement.textStyle.fontSize ?? 24.0;
        _fontWeight = textElement.textStyle.fontWeight ?? FontWeight.normal;
        _lineHeight = textElement.textStyle.height ?? 1.2;
        _letterSpacing = textElement.textStyle.letterSpacing ?? 0.0;

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          editingKey != null ? 'Edit Text' : 'Add Text',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
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
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(context);
                                if (editingKey != null) {
                                  _applyTextUpdate(
                                      editingKey, _textInputController.text);
                                } else {
                                  _addText(_textInputController.text);
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                editingKey != null ? 'Update' : 'Add',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
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
                          letterSpacing: _letterSpacing,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        children: [
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
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                                border: InputBorder.none,
                              ),
                              style: GoogleFonts.poppins(
                                color: Colors.grey[800],
                              ),
                              maxLines: 3,
                              autofocus: true,
                              onChanged: (value) {
                                setModalState(() {});
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextStyleSection(
                            'Font Style',
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
                                          color: _currentFontFamily ==
                                                  fontFamily
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
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Colors.grey[800],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            fontFamily,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: _currentFontFamily ==
                                                      fontFamily
                                                  ? Theme.of(context)
                                                      .primaryColor
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
                          ),
                          const SizedBox(height: 24),
                          _buildTextStyleSection(
                            'Text Size',
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
                                    Icons.text_fields_rounded,
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
                                      activeColor:
                                          Theme.of(context).primaryColor,
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
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextStyleSection(
                            'Text Color',
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
                                    return _buildColorButton(
                                      color,
                                      setModalState,
                                    );
                                  }),
                                  _buildColorButton(
                                    Colors.white,
                                    setModalState,
                                  ),
                                  _buildColorButton(
                                    Colors.black,
                                    setModalState,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextStyleSection(
                            'Font Weight',
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
                                  _buildWeightButton(
                                    'Normal',
                                    FontWeight.normal,
                                    setModalState,
                                  ),
                                  const SizedBox(width: 16),
                                  _buildWeightButton(
                                    'Bold',
                                    FontWeight.bold,
                                    setModalState,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextStyleSection(
                            'Line Spacing',
                            _buildSliderControl(
                              Icons.format_line_spacing_rounded,
                              _lineHeight,
                              0.8,
                              2.5,
                              17,
                              (value) {
                                setModalState(() {
                                  _lineHeight = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextStyleSection(
                            'Letter Spacing',
                            _buildSliderControl(
                              Icons.space_bar,
                              _letterSpacing,
                              -2.0,
                              10.0,
                              24,
                              (value) {
                                setModalState(() {
                                  _letterSpacing = value;
                                });
                              },
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

  Widget _buildTextStyleSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildColorButton(Color color, StateSetter setState) {
    return GestureDetector(
      onTap: () {
        setState(() {
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
                : color == Colors.white
                    ? Colors.grey[400]!
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
  }

  Widget _buildWeightButton(
      String text, FontWeight weight, StateSetter setState) {
    final bool isSelected = _fontWeight == weight;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _fontWeight = weight;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? Theme.of(context).primaryColor : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.grey[800],
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSliderControl(
    IconData icon,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) {
    return Container(
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
            icon,
            size: 20,
            color: Colors.grey[700],
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: value.toStringAsFixed(1),
              activeColor: Theme.of(context).primaryColor,
              inactiveColor: Colors.grey[300],
              onChanged: onChanged,
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
              value.toStringAsFixed(1),
              style: GoogleFonts.poppins(
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
