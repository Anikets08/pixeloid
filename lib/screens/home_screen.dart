import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_state.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstLoad) {
      _preFetchImages();
      _isFirstLoad = false;
    }
  }

  Future<void> _preFetchImages() async {
    await precacheImage(
      const AssetImage('assets/main.jpg'),
      context,
    );
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 600;

    // If we have a captured image and we're in editing mode, show the editor
    if (appState.capturedImage != null && appState.isEditing) {
      return EditorScreen();
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          children: [
            Flexible(
              flex: 3,
              child: Image.asset(
                'assets/main.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            Flexible(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.06,
                  vertical: isSmallScreen ? 12 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      'PIXELOID',
                      style: GoogleFonts.montserrat(
                        fontSize: isSmallScreen ? 26 : 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 2),
                    // Description
                    Text(
                      'Capture photos, add stickers, text, and drawings, then share directly to Instagram',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 32),

                    // Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          XFile? img = await ImagePicker().pickImage(
                            source: ImageSource.camera,
                            preferredCameraDevice: CameraDevice.rear,
                            requestFullMetadata: true,
                            imageQuality: 100,
                          );
                          if (img != null && context.mounted) {
                            Provider.of<AppState>(context, listen: false)
                                .setCapturedImage(
                              File(img.path),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 8 : 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Take a Photo',
                              style: GoogleFonts.roboto(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8),

                    // Secondary Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          XFile? img = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (img != null && context.mounted) {
                            Provider.of<AppState>(context, listen: false)
                                .setCapturedImage(
                              File(img.path),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side:
                              const BorderSide(color: Colors.black, width: 1.5),
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 8 : 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Choose from Gallery',
                              style: GoogleFonts.roboto(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
