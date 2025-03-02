import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:instaplus/models/enum/tool_bar_button_type.dart';
import 'package:instaplus/widgets/custom_button.dart';
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

      setState(() {
        _backgroundImage = frameInfo.image;
        _isImageLoaded = true;
        _controller.background = ImageBackgroundDrawable(
          image: _backgroundImage!,
        );
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
  void _updateTextElement(Key key, String newText) {
    if (newText.trim().isEmpty) return;

    setState(() {
      final int index =
          _textElements.indexWhere((element) => element.key == key);
      if (index != -1) {
        final DraggableText oldText = _textElements[index] as DraggableText;
        _textElements[index] = DraggableText(
          key: oldText.key!,
          text: newText,
          textStyle: oldText.textStyle,
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
    setState(() {
      _isLoading = true;
    });

    try {
      // Capture the edited image
      final RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // Use a more appropriate pixel ratio to match Instagram's recommended size
      // Instagram recommends 1080x1920 (9:16 aspect ratio)
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
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
      appState.clearImage();
    } catch (e) {
      debugPrint('Error sharing to Instagram: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share to Instagram. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

    return Scaffold(
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
          onPressed: _discardChanges,
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
                                color: Colors.black12,
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
                    '${tempDir.path}/instaPlus_${DateTime.now().millisecondsSinceEpoch}.png');
                await file.writeAsBytes(pngBytes);
                if (!mounted) return;
                Gal.putImage(file.path, album: 'InstaPlus');
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

  void _showTextBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: false,
      useSafeArea: true,
      // backgroundColor: Colors.white,
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _exitTextMode();
                              },
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _addText(_textInputController.text);
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Text preview
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        // color according to the luminance of the text color
                        color: _textColor.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        _textInputController.text.isEmpty
                            ? 'Preview Text'
                            : _textInputController.text,
                        style: GoogleFonts.getFont(
                          _currentFontFamily,
                          fontSize: _fontSize,
                          color: _textColor,
                          fontWeight: _fontWeight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Expanded(
                      child: ListView(
                        children: [
                          // Text input
                          TextField(
                            controller: _textInputController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your text...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            autofocus: true,
                            onChanged: (value) {
                              setModalState(() {});
                            },
                          ),

                          const SizedBox(height: 16),

                          // Font size slider
                          Row(
                            children: [
                              const Icon(Icons.text_fields, size: 16),
                              Expanded(
                                child: Slider(
                                  value: _fontSize,
                                  min: 12,
                                  max: 72,
                                  divisions: 60,
                                  label: _fontSize.round().toString(),
                                  onChanged: (value) {
                                    setModalState(() {
                                      _fontSize = value;
                                    });
                                  },
                                ),
                              ),
                              Text('${_fontSize.round()}'),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Text color picker
                          const Text(
                            'Text Color',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 50,
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
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _textColor == color
                                              ? Colors.black
                                              : Colors.transparent,
                                          width: 2,
                                        ),
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
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _textColor == Colors.white
                                            ? Colors.black
                                            : Colors.grey,
                                        width: 2,
                                      ),
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
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _textColor == Colors.black
                                            ? Colors.blue
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Font family picker
                          const Text(
                            'Font Style',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 80,
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
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _currentFontFamily == fontFamily
                                          ? Colors.blue.withOpacity(0.2)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _currentFontFamily == fontFamily
                                            ? Colors.blue
                                            : Colors.grey.shade300,
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
                                            fontSize: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          fontFamily,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Font weight
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 10,
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
                                          : Colors.grey.shade300,
                                  foregroundColor:
                                      _fontWeight == FontWeight.normal
                                          ? Colors.white
                                          : Colors.black,
                                ),
                                child: const Text('Normal'),
                              ),
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
                                          : Colors.grey.shade300,
                                  foregroundColor:
                                      _fontWeight == FontWeight.bold
                                          ? Colors.white
                                          : Colors.black,
                                ),
                                child: const Text('Bold'),
                              ),
                            ],
                          ),
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
}
